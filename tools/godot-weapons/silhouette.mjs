// Silhouette distinctness metric for the first-person weapon exports.
//
// "The ten weapons look different" is only half-checked by the six identity
// channels (they are authored strings). This module measures the *shape* that
// actually leaves the exporter: every exported triangle is rasterized into a
// fixed weapon-space orthographic mask, and two weapons are compared by the
// intersection-over-union (IoU) of their masks. Pairwise IoU is a strict read
// of "do these read as the same object at a glance": it ignores material tone,
// trim colour and every interior detail and keeps only the outline.
//
// Grids are fixed in weapon space (+Z stock, -Z muzzle, y = bore line), so the
// masks of every weapon are directly comparable and the numbers are
// reproducible from the manifest alone (verify.mjs re-checks them).
//
//   side  - looking along +X: the hip/aim silhouette the player reads.
//   top   - looking down +Y: receiver width, twin bores, side hardware.
//   sideDetail - the same side view of *authored detail geometry only*, so the
//                identity pass itself (not the locked source chassis) is what
//                the distinctness number reports.
//
// No rendering, no environment reads, fixed arithmetic: deterministic.

export const GRID = Object.freeze({
  // Bounds cover every exported extreme: the forward-most fork prong (muzzle
  // -1.04 minus 0.28), the rear-most venturi bell (+0.31), the deepest
  // oversized magazine (-0.45) and the widest collar/feed hardware (+-0.34).
  z0: -1.36, z1: 0.50,
  y0: -0.50, y1: 0.42,
  x0: -0.36, x1: 0.36,
  cell: 0.02,
});

export function gridSize(axis) {
  const {z0, z1, y0, y1, x0, x1, cell} = GRID;
  const span = axis === 'z' ? [z0, z1] : axis === 'y' ? [y0, y1] : [x0, x1];
  return Math.max(1, Math.ceil((span[1] - span[0]) / cell));
}

export function axesFor(view) {
  // [horizontal, vertical]: side drops X, top drops Y.
  return view.startsWith('top') ? ['z', 'x'] : ['z', 'y'];
}

const ORIGIN = {x: GRID.x0, y: GRID.y0, z: GRID.z0};

function cellOf(axis, value) {
  return Math.floor((value - ORIGIN[axis]) / GRID.cell);
}

// Rasterize one triangle (three weapon-space points) into the bit mask.
function fillTriangle(mask, width, triangle, axisA, axisB) {
  const a = [cellOf(axisA, triangle[0][axisA]), cellOf(axisB, triangle[0][axisB])];
  const b = [cellOf(axisA, triangle[1][axisA]), cellOf(axisB, triangle[1][axisB])];
  const c = [cellOf(axisA, triangle[2][axisA]), cellOf(axisB, triangle[2][axisB])];
  // Triangle corners in continuous cell space, for the edge tests.
  const p0 = [(triangle[0][axisA] - ORIGIN[axisA]) / GRID.cell, (triangle[0][axisB] - ORIGIN[axisB]) / GRID.cell];
  const p1 = [(triangle[1][axisA] - ORIGIN[axisA]) / GRID.cell, (triangle[1][axisB] - ORIGIN[axisB]) / GRID.cell];
  const p2 = [(triangle[2][axisA] - ORIGIN[axisA]) / GRID.cell, (triangle[2][axisB] - ORIGIN[axisB]) / GRID.cell];
  const area = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (p1[1] - p0[1]);
  if (Math.abs(area) < 1e-12) return;
  const min = [Math.min(a[0], b[0], c[0]), Math.min(a[1], b[1], c[1])];
  const max = [Math.max(a[0], b[0], c[0]), Math.max(a[1], b[1], c[1])];
  const height = mask.length / ((width + 7) >> 3);
  for (let i = Math.max(0, min[0]); i <= Math.min(width - 1, max[0]); i++) {
    for (let j = Math.max(0, min[1]); j <= Math.min(height - 1, max[1]); j++) {
      const px = i + 0.5, py = j + 0.5;
      const w0 = ((p1[0] - p0[0]) * (py - p0[1]) - (px - p0[0]) * (p1[1] - p0[1])) / area;
      const w1 = ((px - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (py - p0[1])) / area;
      const w2 = 1 - w0 - w1;
      if (w0 < -1e-9 || w1 < -1e-9 || w2 < -1e-9) continue;
      const byte = j * ((width + 7) >> 3) + (i >> 3);
      mask[byte] |= 1 << (i & 7);
    }
  }
}

// Accumulate every triangle of `root` (a three.js Mesh/Group subtree) into a
// bit mask. `onlyDetail` keeps the authored detail pass only.
export function maskFrom(root, view, {onlyDetail = false} = {}) {
  const [axisA, axisB] = axesFor(view);
  const width = gridSize(axisA);
  const height = gridSize(axisB);
  const mask = new Uint8Array(((width + 7) >> 3) * height);
  const offset = axisB === 'y' ? 1 : 0;
  const project = v => ({[axisA]: v[2], [axisB]: v[offset]});
  root.updateMatrixWorld(true);
  root.traverse(node => {
    if (!node.isMesh) return;
    if (onlyDetail && !node.userData.detailChannel) return;
    const geometry = node.geometry;
    const position = geometry.attributes.position;
    const index = geometry.index;
    const count = index ? index.count : position.count;
    const e = node.matrixWorld.elements;
    const vertex = i => {
      const source = index ? index.getX(i) : i;
      const x = position.getX(source), y = position.getY(source), z = position.getZ(source);
      return [e[0] * x + e[4] * y + e[8] * z + e[12],
        e[1] * x + e[5] * y + e[9] * z + e[13],
        e[2] * x + e[6] * y + e[10] * z + e[14]];
    };
    for (let i = 0; i + 2 < count; i += 3) {
      fillTriangle(mask, width, [project(vertex(i)), project(vertex(i + 1)), project(vertex(i + 2))], axisA, axisB);
    }
  });
  return {mask, width, height};
}

export function encodeMask({mask, width}) {
  return Buffer.from(mask).toString('hex');
}

export function decodeMask(encoded, view) {
  const [axisA, axisB] = axesFor(view);
  return {mask: new Uint8Array(Buffer.from(encoded, 'hex')), width: gridSize(axisA), height: gridSize(axisB)};
}

export function filledCells({mask, width, height}) {
  const stride = (width + 7) >> 3;
  let filled = 0;
  for (let j = 0; j < height; j++) for (let i = 0; i < width; i++) if (mask[j * stride + (i >> 3)] >> (i & 7) & 1) filled++;
  return filled;
}

const POPCOUNT = Uint8Array.from({length: 256}, (_, n) => {
  let bits = 0;
  for (let i = 0; i < 8; i++) bits += n >> i & 1;
  return bits;
});

// Intersection over union of two encoded masks of the same view.
export function iou(a, b) {
  if (a.length !== b.length) throw new Error('mask length mismatch');
  const left = Buffer.from(a, 'hex'), right = Buffer.from(b, 'hex');
  let intersection = 0, union = 0;
  for (let i = 0; i < left.length; i++) {
    intersection += POPCOUNT[left[i] & right[i]];
    union += POPCOUNT[left[i] | right[i]];
  }
  return union === 0 ? 0 : intersection / union;
}

// Pairwise IoU table for a list of encoded masks. Returns the full symmetric
// matrix plus max/mean off-diagonal values (the numbers verify.mjs gates on).
export function pairwise(masks) {
  const matrix = [];
  let max = 0, sum = 0, count = 0, worst = null;
  for (let i = 0; i < masks.length; i++) {
    matrix.push([]);
    for (let j = 0; j < masks.length; j++) {
      const value = i === j ? 1 : iou(masks[i], masks[j]);
      matrix[i].push(+value.toFixed(4));
      if (j > i) {
        if (value > max) { max = value; worst = [i, j]; }
        sum += value; count++;
      }
    }
  }
  return {matrix, max: +max.toFixed(4), mean: +(sum / Math.max(1, count)).toFixed(4), worstPair: worst};
}
