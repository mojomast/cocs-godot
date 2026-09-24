// Measure the *exported* third-person GLB triangles, independent of materials.
// Usage: node port/native-world-weapon-identity/silhouette-report.mjs [--output path.json] [--svg path.svg]
import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SOURCE = resolve(HERE, '../../godot/source_operators/generated/world_weapons');
const MANIFEST = join(SOURCE, 'manifest.json');
// Fixed world-space coordinates; never resize/recenter an individual weapon.
// Z: muzzle (-) to stock (+); side projects (Z,Y), top projects (Z,X).
const grid = {cell: 0.01, z: [-1.6, 0.6], y: [-0.6, 0.6], x: [-0.55, 0.55]};
const views = {side: ['z', 'y'], top: ['z', 'x']};
const dims = Object.fromEntries(Object.entries(views).map(([view, axes]) =>
  [view, axes.map(axis => Math.round((grid[axis][1] - grid[axis][0]) / grid.cell))]));
const round = n => +n.toFixed(6);

function loadGlb(file) {
  const bytes = readFileSync(file);
  const bad = message => { throw new Error(`${file}: ${message}`); };
  if (bytes.length < 20 || bytes.toString('ascii', 0, 4) !== 'glTF' || bytes.readUInt32LE(4) !== 2 || bytes.readUInt32LE(8) !== bytes.length) bad('invalid GLB v2 header');
  let json, bin;
  for (let offset = 12; offset < bytes.length;) {
    if (offset + 8 > bytes.length) bad('truncated chunk header');
    const length = bytes.readUInt32LE(offset), type = bytes.readUInt32LE(offset + 4);
    offset += 8;
    if (offset + length > bytes.length) bad('truncated chunk');
    if (type === 0x4e4f534a) json = JSON.parse(bytes.toString('utf8', offset, offset + length));
    if (type === 0x004e4942) bin = bytes.subarray(offset, offset + length);
    offset += length;
  }
  if (!json || !bin || json.buffers?.length !== 1 || json.buffers[0].uri || json.buffers[0].byteLength > bin.length) bad('expected one embedded BIN buffer');
  const data = new DataView(bin.buffer, bin.byteOffset, bin.length);
  const components = {5120: [1, 'getInt8'], 5121: [1, 'getUint8'], 5122: [2, 'getInt16'], 5123: [2, 'getUint16'], 5125: [4, 'getUint32'], 5126: [4, 'getFloat32']};
  const widths = {SCALAR: 1, VEC3: 3};
  function accessor(number, expectedType, types) {
    const a = json.accessors[number], v = json.bufferViews?.[a?.bufferView];
    if (!a || !v || a.sparse || a.normalized || a.type !== expectedType || !types.includes(a.componentType) || v.buffer !== 0) bad(`unsupported accessor ${number}`);
    const [size, method] = components[a.componentType], count = widths[a.type], stride = v.byteStride ?? size * count;
    const start = (v.byteOffset ?? 0) + (a.byteOffset ?? 0);
    if (stride < size * count || start < 0 || start + (a.count - 1) * stride + size * count > (v.byteOffset ?? 0) + v.byteLength || a.count < 1) bad(`out-of-bounds accessor ${number}`);
    return {count: a.count, get(i, c = 0) {
      if (i < 0 || i >= a.count) bad(`index ${i} outside accessor ${number}`);
      return data[method](start + i * stride + c * size, true);
    }};
  }
  const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  function multiply(a, b) {
    const result = Array(16).fill(0);
    for (let col = 0; col < 4; col++) for (let row = 0; row < 4; row++)
      for (let k = 0; k < 4; k++) result[col * 4 + row] += a[k * 4 + row] * b[col * 4 + k];
    return result;
  }
  function localMatrix(node) {
    if (node.matrix) return node.matrix;
    const [x, y, z, w] = node.rotation ?? [0, 0, 0, 1], [sx, sy, sz] = node.scale ?? [1, 1, 1], [tx, ty, tz] = node.translation ?? [0, 0, 0];
    return [(1 - 2 * (y*y + z*z))*sx, 2*(x*y + z*w)*sx, 2*(x*z - y*w)*sx, 0,
      2*(x*y - z*w)*sy, (1 - 2*(x*x + z*z))*sy, 2*(y*z + x*w)*sy, 0,
      2*(x*z + y*w)*sz, 2*(y*z - x*w)*sz, (1 - 2*(x*x + y*y))*sz, 0,
      tx, ty, tz, 1];
  }
  const triangles = [];
  const bounds = {x: [Infinity, -Infinity], y: [Infinity, -Infinity], z: [Infinity, -Infinity]};
  let primitives = 0;
  function visit(id, parent, lineage) {
    if (lineage.has(id)) bad('cyclic scene graph');
    const node = json.nodes[id];
    if (!node) bad(`missing node ${id}`);
    const world = multiply(parent, localMatrix(node));
    if (node.mesh !== undefined) for (const primitive of json.meshes[node.mesh]?.primitives ?? []) {
      if ((primitive.mode ?? 4) !== 4 || primitive.attributes?.POSITION === undefined) bad('expected TRIANGLES with POSITION');
      const position = accessor(primitive.attributes.POSITION, 'VEC3', [5126]);
      const indices = primitive.indices === undefined ? null : accessor(primitive.indices, 'SCALAR', [5121, 5123, 5125]);
      const count = indices?.count ?? position.count;
      if (count % 3) bad('triangle index count not divisible by 3');
      const transformed = Array.from({length: position.count}, (_, i) => {
        const [x, y, z] = [0, 1, 2].map(c => position.get(i, c));
        const p = {x: world[0]*x + world[4]*y + world[8]*z + world[12],
          y: world[1]*x + world[5]*y + world[9]*z + world[13],
          z: world[2]*x + world[6]*y + world[10]*z + world[14]};
        for (const axis of ['x', 'y', 'z']) {
          if (!Number.isFinite(p[axis])) bad('non-finite vertex');
          bounds[axis][0] = Math.min(bounds[axis][0], p[axis]);
          bounds[axis][1] = Math.max(bounds[axis][1], p[axis]);
        }
        return p;
      });
      for (let i = 0; i < count; i += 3) triangles.push([0, 1, 2].map(c => transformed[indices?.get(i + c) ?? i + c]));
      if (triangles.some(t => t.includes(undefined))) bad('invalid triangle index');
      primitives++;
    }
    const descendants = new Set([...lineage, id]);
    for (const child of node.children ?? []) visit(child, world, descendants);
  }
  for (const id of json.scenes?.[json.scene ?? 0]?.nodes ?? []) visit(id, identity, new Set());
  if (!triangles.length) bad('no rendered triangles');
  return {triangles, bounds: Object.fromEntries(Object.entries(bounds).map(([k, v]) => [k, v.map(round)])), primitives,
    sha256: createHash('sha256').update(bytes).digest('hex')};
}

function rasterize(triangles, axes) {
  const [a, b] = axes, [width, height] = dims[Object.keys(views).find(key => views[key] === axes)];
  const mask = new Uint8Array(width * height);
  let clipped = 0;
  for (const triangle of triangles) {
    const p = triangle.map(v => [(v[a] - grid[a][0]) / grid.cell, (v[b] - grid[b][0]) / grid.cell]);
    const minX = Math.floor(Math.min(...p.map(v => v[0]))), maxX = Math.ceil(Math.max(...p.map(v => v[0])));
    const minY = Math.floor(Math.min(...p.map(v => v[1]))), maxY = Math.ceil(Math.max(...p.map(v => v[1])));
    if (minX < 0 || maxX > width || minY < 0 || maxY > height) clipped++;
    const cross = (u, v, q) => (v[0]-u[0])*(q[1]-u[1]) - (v[1]-u[1])*(q[0]-u[0]);
    const area = cross(p[0], p[1], p[2]);
    if (Math.abs(area) < 1e-12) continue; // edge-on projection has zero area
    for (let y = Math.max(0, minY); y < Math.min(height, maxY); y++)
      for (let x = Math.max(0, minX); x < Math.min(width, maxX); x++) {
        const q = [x + 0.5, y + 0.5];
        if (cross(p[0], p[1], q) * area >= -1e-9 &&
            cross(p[1], p[2], q) * area >= -1e-9 &&
            cross(p[2], p[0], q) * area >= -1e-9) mask[y * width + x] = 1;
      }
  }
  if (clipped) throw new Error(`${clipped} triangles exceed ${a}/${b} grid; enlarge the shared grid (do not crop)`);
  let area = 0, minX = width, maxX = -1, minY = height, maxY = -1;
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) if (mask[y * width + x]) {
    area++; minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  if (!area) throw new Error(`empty ${a}/${b} silhouette`);
  return {mask, area, pixels: width * height, pixelExtents: [[minX, minY], [maxX + 1, maxY + 1]]};
}

function compare(a, b) {
  let intersection = 0, union = 0, different = 0;
  for (let i = 0; i < a.mask.length; i++) {
    intersection += a.mask[i] & b.mask[i];
    union += a.mask[i] | b.mask[i];
    different += a.mask[i] ^ b.mask[i];
  }
  return {iou: round(intersection / union), differentPixels: different,
    differingFractionOfGrid: round(different / a.mask.length), differingFractionOfUnion: round(different / union)};
}

function sheetSvg(weapons, masks) {
  const scale = 3, gap = 25, label = 18, column = dims.side[0] * scale + gap;
  const row = Math.max(dims.side[1], dims.top[1]) * scale + label + gap;
  const out = [`<svg xmlns="http://www.w3.org/2000/svg" width="${column*2}" height="${row*weapons.length}" viewBox="0 0 ${column*2} ${row*weapons.length}">`,
    `<rect width="100%" height="100%" fill="#152029"/>`];
  weapons.forEach((weapon, n) => Object.keys(views).forEach((view, col) => {
    const m = masks[n][view].mask, [w, h] = dims[view], ox = col*column, oy = n*row;
    out.push(`<text x="${ox + 4}" y="${oy + 14}" fill="#dce8e9" font-family="monospace" font-size="13">${weapon.id}: ${weapon.name.replaceAll('&', '&amp;').replaceAll('<', '&lt;')} / ${view}</text>`);
    out.push(`<g fill="#7cdcc9">`);
    for (let y = 0; y < h; y++) for (let x = 0; x < w;) {
      if (!m[y*w + x]) { x++; continue; }
      const start = x;
      while (x < w && m[y*w + x]) x++;
      out.push(`<rect x="${ox + start*scale}" y="${oy + label + (h-1-y)*scale}" width="${(x-start)*scale}" height="${scale}"/>`);
    }
    out.push('</g>');
  }));
  return out.join('\n') + '\n</svg>\n';
}

const argv = process.argv.slice(2);
let output, svg;
for (let i = 0; i < argv.length; i++) {
  if (argv[i] === '--output' && argv[i+1]) output = resolve(argv[++i]);
  else if (argv[i] === '--svg' && argv[i+1]) svg = resolve(argv[++i]);
  else throw new Error(`Unknown/incomplete argument ${argv[i]}; use --output path.json and/or --svg path.svg`);
}
const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
if (manifest.weapons.length !== 10 || new Set(manifest.weapons.map(w => w.id)).size !== 10) throw new Error('Expected ten unique manifest weapons');
const masks = [], weapons = [];
for (const entry of manifest.weapons) {
  const file = join(SOURCE, entry.file);
  if (!/^weapon-[0-9]+\.glb$/.test(entry.file)) throw new Error(`Unexpected GLB file: ${entry.file}`);
  const {triangles, bounds, primitives, sha256} = loadGlb(file);
  const silhouette = Object.fromEntries(Object.entries(views).map(([view, axes]) => [view, rasterize(triangles, axes)]));
  masks.push(silhouette);
  weapons.push({id: entry.id, name: entry.name, file: entry.file, sha256, primitives, triangles: triangles.length, bounds,
    views: Object.fromEntries(Object.entries(silhouette).map(([view, m]) => [view,
      {areaPixels: m.area, areaWorldSquared: round(m.area * grid.cell ** 2), pixelExtents: m.pixelExtents}]))});
}
const pairs = [];
for (let i = 0; i < weapons.length; i++) for (let j = i + 1; j < weapons.length; j++) {
  pairs.push({ids: [weapons[i].id, weapons[j].id],
    views: Object.fromEntries(Object.keys(views).map(view => [view, compare(masks[i][view], masks[j][view])]))});
}
const summary = Object.fromEntries(Object.keys(views).map(view => {
  const bySimilarity = [...pairs].sort((a, b) => b.views[view].iou - a.views[view].iou);
  const byDifference = [...pairs].sort((a, b) => a.views[view].differentPixels - b.views[view].differentPixels);
  return [view, {maxIoU: bySimilarity[0].views[view].iou, maxIoUPair: bySimilarity[0].ids,
    meanIoU: round(pairs.reduce((sum, p) => sum + p.views[view].iou, 0) / pairs.length),
    minDifferentPixels: byDifference[0].views[view].differentPixels, minDifferentPixelsPair: byDifference[0].ids,
    minDifferingFractionOfGrid: round(byDifference[0].views[view].differentPixels / masks[0][view].pixels),
    minDifferingFractionOfUnion: Math.min(...pairs.map(p => p.views[view].differingFractionOfUnion))}];
}));
const report = {schema: 1, source: 'godot/source_operators/generated/world_weapons/manifest.json',
  method: 'Embedded GLB POSITION+indices, all scene mesh primitives transformed into weapon space, orthographic triangle-union center-sample raster; no color/material/texture',
  grid, dimensions: dims, pairCount: pairs.length, weapons, pairs, summary};
if (output) writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
if (svg) writeFileSync(svg, sheetSvg(weapons, masks));
console.log(JSON.stringify({output: output ?? null, svg: svg ?? null, weapons: weapons.length, pairs: pairs.length, summary}, null, 2));
