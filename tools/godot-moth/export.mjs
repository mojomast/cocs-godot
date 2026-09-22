#!/usr/bin/env node
// Offline, byte-preserving conversion. Never imports the network bake runner.
import { createHash } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MOTH_BAKED } from '../../game/moth-baked.mjs';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const body = Buffer.concat([Buffer.from(type), data]);
  const header = Buffer.alloc(4), tail = Buffer.alloc(4);
  header.writeUInt32BE(data.length); tail.writeUInt32BE(crc32(body));
  return Buffer.concat([header, body, tail]);
}
export function encodePng(width, height, channels, pixels, colorSpace) {
  if (![width, height].every(n => Number.isSafeInteger(n) && n > 0 && n <= 4096)) throw Error('Invalid dimensions');
  if (![3, 4].includes(channels) || pixels.length !== width * height * channels) throw Error('Invalid pixel plane length/channels');
  if (!['srgb', 'linear'].includes(colorSpace)) throw Error('Invalid color space');
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4);
  header[8] = 8; header[9] = channels === 4 ? 6 : 2;
  const stride = width * channels, raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) pixels.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  // No timestamps, filtering heuristics, premultiplication, palette, resampling or gamma conversion.
  // Godot's PNG decoder applies gAMA, even to data textures. Linear means untagged
  // bytes + a linear shader sampler, NOT a gAMA=1.0 chunk (which changes normals).
  const color = colorSpace === 'srgb' ? chunk('sRGB', Buffer.from([0])) : Buffer.alloc(0);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), color, chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function decode(value) {
  if (typeof value !== 'string' || !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value)) throw Error('Invalid base64');
  const bytes = Buffer.from(value, 'base64');
  if (bytes.toString('base64') !== value) throw Error('Noncanonical base64');
  return bytes;
}
export async function exportAssets(output = resolve(ROOT, 'godot/moth/generated'), source = MOTH_BAKED) {
  const manifest = {
    version: 1,
    provenance: { source: 'game/moth-baked.mjs', source_sha256: sha256(await readFile(resolve(ROOT, 'game/moth-baked.mjs'))), baked_version: source.version, exporter: 'tools/godot-moth/export.mjs', rights: 'Unresolved; see port/asset-audit/HANDOFF.md. Conversion is not clearance.' },
    textures: {}, normals: {}, sky: {}, materials: {}, effects: {},
  };
  // Build and validate everything before writing any output, so malformed sources cannot partially overwrite a delivery.
  const files = new Map();
  function plane(bucket, key, image, channels, colorSpace) {
    if (!/^[a-z0-9_-]+$/.test(key)) throw Error(`Unsafe key: ${key}`);
    const pixels = decode(image.data);
    const png = encodePng(image.width, image.height, channels, pixels, colorSpace);
    const relative = `${bucket}/${key}.png`;
    files.set(relative, png);
    const resource = `res://moth/generated/${relative}`;
    const imported = `res://.godot/imported/${key}.png-${createHash('md5').update(resource).digest('hex')}.ctex`;
    files.set(`${relative}.import`, Buffer.from(`[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="${imported}"\nmetadata={\n"vram_texture": false\n}\n\n[deps]\nsource_file="${resource}"\ndest_files=["${imported}"]\n\n[params]\ncompress/mode=0\ncompress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=true\nmipmaps/limit=-1\nroughness/mode=0\nprocess/fix_alpha_border=false\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=0\n`));
    return { path: `res://moth/generated/${relative}`, width: image.width, height: image.height, channels, color_space: colorSpace, alpha: channels === 4 ? 'straight' : 'opaque', pixel_sha256: sha256(pixels), png_sha256: sha256(png) };
  }
  for (const bucket of ['textures', 'normals', 'sky']) {
    for (const key of Object.keys(source[bucket]).sort()) {
      const linear = bucket === 'normals' || (bucket === 'textures' && ['macro-organic', 'dust-field', 'flow-field'].includes(key));
      manifest[bucket][key] = plane(bucket, key, source[bucket][key], 4, linear ? 'linear' : 'srgb');
      if (bucket === 'sky') manifest[bucket][key].equirect = source[bucket][key].equirect === true;
    }
  }
  for (const key of Object.keys(source.materials).sort()) {
    const lut = source.materials[key];
    manifest.materials[key] = { width: lut.size, height: lut.size };
    for (const part of ['r', 't']) manifest.materials[key][part] = plane('materials', `${key}-${part}`, { width: lut.size, height: lut.size, data: lut[part] }, 3, 'linear');
  }
  for (const key of Object.keys(source.effects).sort()) {
    const effect = source.effects[key];
    if (!Number.isFinite(effect.fps) || effect.fps <= 0 || effect.fps > 240 || !effect.frames.length) throw Error(`Invalid effect: ${key}`);
    const frames = effect.frames.map((frame, index) => plane('effects', `${key}-${index}`, frame, 4, 'srgb'));
    if (frames.some(f => f.width !== frames[0].width || f.height !== frames[0].height)) throw Error(`Inconsistent effect dimensions: ${key}`);
    manifest.effects[key] = { width: frames[0].width, height: frames[0].height, fps: effect.fps, frames };
  }
  for (const [file, bytes] of files) {
    await mkdir(dirname(resolve(output, file)), { recursive: true });
    if (file.endsWith('.import')) {
      // Godot augments these policies with resource UIDs. Keep existing stable UIDs.
      try { await writeFile(resolve(output, file), bytes, { flag: 'wx' }); }
      catch (error) { if (error.code !== 'EEXIST') throw error; }
    } else await writeFile(resolve(output, file), bytes);
  }
  await writeFile(resolve(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length > 3) throw Error('Usage: node tools/godot-moth/export.mjs [output-directory]');
  const manifest = await exportAssets(process.argv[2] && resolve(process.argv[2]));
  console.log(JSON.stringify({ textures: Object.keys(manifest.textures).length, normals: Object.keys(manifest.normals).length, skies: Object.keys(manifest.sky).length, lut_pairs: Object.keys(manifest.materials).length, effect_sequences: Object.keys(manifest.effects).length, effect_frames: Object.values(manifest.effects).reduce((n, e) => n + e.frames.length, 0) }));
}
