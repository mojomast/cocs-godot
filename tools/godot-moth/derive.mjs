#!/usr/bin/env node
// Deterministic offline derivation of the missing Moth maps.
//
// The baked set ships 31 albedo textures and 13 normals but no roughness,
// occlusion, detail or accent masks, and twelve base textures used by the
// material language have no baked normal at all. This tool derives those from
// the exact shipped pixels. It never re-bakes, never touches
// res://moth/generated and never changes the 101-plane inventory.
//
// Uniqueness pass (2026-09-24): the thirteen baked normals are all the same
// class of quantum noise (pairwise low-frequency correlation up to 1.00), so the
// material families whose own albedo carries real structure bind a derived
// normal instead. Each target carries its own magnitude and blur radius so the
// kernels differ per material, not just per seed.
//
// Reproducibility: integer kernels (rounded box blur, Sobel difference,
// min/max normalisation). The only floating point is sqrt/division/round, which
// are IEEE-deterministic. No timestamps, no filtering heuristics, no RNG, no
// locale, no colour management. Re-running yields byte-identical files.
//
// Usage:
//   node tools/godot-moth/derive.mjs            # write res://moth/derived + manifest
//   node tools/godot-moth/derive.mjs --check    # verify committed outputs reproduce
import { createHash } from 'node:crypto';
import { readFile, readdir, mkdir, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { decodePng } from '../../scripts/moth-bake.mjs';
import { encodePng } from './export.mjs';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const GENERATED = resolve(ROOT, 'godot/moth/generated');
export const DERIVED = resolve(ROOT, 'godot/moth/derived');
export const DERIVED_VERSION = 1;

// ------------------------------------------------------------------ inputs ---
// Every base texture the material language binds, with the roughness prior for
// its class. The prior is the only hand-authored number: the maps themselves are
// derived from pixels.
export const DATA_TARGETS = {
  'hex_paneling-mottle': 0.35, 'hex_paneling': 0.30, 'weathered_concrete': 0.88,
  'weathered_concrete-worn': 0.90, 'weathered_concrete-damp': 0.80,
  'rough_stucco-weathered': 0.86, 'ice-cracked': 0.24, 'ice': 0.20,
  'brushed_metal': 0.34, 'diamond_plate': 0.40, 'metal_grating': 0.45,
  'circuit_board-etch': 0.35, 'metal-oxide': 0.72, 'riveted_armor-scorched': 0.66,
  'riveted_armor': 0.58, 'metal': 0.38, 'alien_chitin': 0.45, 'sand': 0.95,
  'rock': 0.95, 'rock-moss': 0.92, 'grass': 0.82, 'hazard_stripes': 0.62,
  'corrugated_metal': 0.50, 'macro-organic': 0.50,
};
// Target mean slope magnitude for the two textures whose baked normal is absent.
export const NORMAL_TARGETS = {
  // Baked-normal-free textures whose own albedo structure beats the duplicate
  // quantum-noise normals. Numbers are magnitude, optional blur radius (default
  // 1) for a per-material kernel character.
  'alien_chitin': 0.30, 'riveted_armor': 0.55,
  'hex_paneling-mottle': { magnitude: 0.30, radius: 2 },
  'weathered_concrete-worn': { magnitude: 0.42, radius: { x: 1, y: 3 } },   // drip streaks
  'weathered_concrete-damp': { magnitude: 0.34, radius: 2 },
  'rough_stucco-weathered': { magnitude: 0.48, radius: 2 },
  'ice-cracked': { magnitude: 0.55, radius: { x: 3, y: 1 } },   // crack lines, directional
  'metal-oxide': { magnitude: 0.44, radius: 2 },                  // broad pitting, not fine grain
  'circuit_board-etch': { magnitude: 0.46, radius: 1 },
  'riveted_armor-scorched': { magnitude: 0.50, radius: 1 },
  'rock-moss': { magnitude: 0.60, radius: 2 },
  'macro-organic': { magnitude: 0.36, radius: 2 },
};
export const MASK_TARGETS = { 'hazard_stripes': 'yellow-band', 'circuit_board': 'trace' };
// Keys used only to calibrate the green-channel sign convention: they ship both
// an albedo and a baked normal, so a derived normal can be correlated against the
// bake. The magnitude here is a calibration constant, not a family value.
const CALIBRATION_KEYS = {
  'rock': 0.25, 'sand': 0.25, 'metal': 0.25, 'weathered_concrete': 0.25,
  'hex_paneling': 0.25, 'hazard_stripes': 0.25, 'ice': 0.25, 'grass': 0.25,
};

const DATA_PARAMS = {
  'ao_radius': 6, 'ao_relative_gain': 1.6, 'ao_reference_floor': 24,
  'ao_floor': 80, 'ao_ceiling': 255,
  'roughness_hf_radius': 1, 'roughness_hf_smooth_radius': 2, 'roughness_hf_pivot': 12, 'roughness_hf_scale': 0.7,
  'roughness_floor': 20, 'roughness_ceiling': 250,
  'detail_radius': 2, 'detail_scale': 2,
};
const NORMAL_PARAMS = { 'height_radius': 1 };
const MASK_PARAMS = { 'yellow-band': { 'signal': '(r+g)/2-b' }, 'trace': { 'signal': '(g+b)/2-r' } };
const HEIGHT_MODES = { 'luminance': 'rec709 rounded', 'max-mix': 'mean of rec709 luminance and the max channel' };

export function sha256(bytes) { return createHash('sha256').update(bytes).digest('hex'); }

// ------------------------------------------------------------------ kernels ---

export function luminance(rgba, width, height) {
  const out = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i++) {
    out[i] = (54 * rgba[i * 4] + 183 * rgba[i * 4 + 1] + 19 * rgba[i * 4 + 2] + 128) >> 8;
  }
  return out;
}

// Chroma-aware height for saturated tiles: alien chitin and circuit traces are
// near-flat in luminance but structured in colour, so the height field is the
// mean of luminance and the max channel. The mode is chosen per texture from
// measured contrast and recorded in the manifest.
export function heightField(rgba, width, height, mode) {
  const out = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i++) {
    const r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
    const light = (54 * r + 183 * g + 19 * b + 128) >> 8;
    out[i] = mode === 'max-mix' ? Math.round((light + Math.max(r, g, b)) / 2) : light;
  }
  return out;
}

export function boxBlurWrap(src, width, height, radius) {
  return boxBlurWrapAxes(src, width, height, radius, radius);
}

export function chooseHeightMode(rgba, width, height) {
  const light = heightField(rgba, width, height, 'luminance');
  const mix = heightField(rgba, width, height, 'max-mix');
  const deviation = (plane) => {
    let mean = 0;
    for (const value of plane) mean += value;
    mean /= plane.length;
    let variance = 0;
    for (const value of plane) variance += (value - mean) ** 2;
    return Math.sqrt(variance / plane.length);
  };
  const luminanceDeviation = deviation(light);
  const mixDeviation = deviation(mix);
  return {
    mode: mixDeviation > luminanceDeviation * 1.15 ? 'max-mix' : 'luminance',
    luminance_stddev: Number(luminanceDeviation.toFixed(3)),
    max_mix_stddev: Number(mixDeviation.toFixed(3)),
  };
}

// Tiling mean filter, optionally anisotropic: RX x RY kernel with wrap-around
// edges, integer sums and round-half-up division, so the derived tile stays
// seamlessly repeatable and free of FP drift. The square form (RX == RY) is
// arithmetic-identical to the pre-2026-09-24 kernel.
export function boxBlurWrapAxes(src, width, height, radiusX, radiusY) {
  const out = new Uint8Array(width * height);
  const spanX = 2 * radiusX + 1, spanY = 2 * radiusY + 1;
  const count = spanX * spanY;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let sum = 0;
      for (let dy = -radiusY; dy <= radiusY; dy++) {
        const sy = ((y + dy) % height + height) % height;
        for (let dx = -radiusX; dx <= radiusX; dx++) {
          const sx = ((x + dx) % width + width) % width;
          sum += src[sy * width + sx];
        }
      }
      out[y * width + x] = Math.floor((sum + Math.floor(count / 2)) / count);
    }
  }
  return out;
}

function sobelWrap(heightFieldData, width, height) {
  const gx = new Float64Array(width * height);
  const gy = new Float64Array(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const at = (dx, dy) => heightFieldData[(((y + dy) % height + height) % height) * width + (((x + dx) % width + width) % width)];
      gx[y * width + x] = (at(1, -1) + 2 * at(1, 0) + at(1, 1)) - (at(-1, -1) + 2 * at(-1, 0) + at(-1, 1));
      gy[y * width + x] = (at(-1, 1) + 2 * at(0, 1) + at(1, 1)) - (at(-1, -1) + 2 * at(0, -1) + at(1, -1));
    }
  }
  return { gx, gy };
}

const clamp = (value, low, high) => value < low ? low : (value > high ? high : value);

export function dataMap(rgba, width, height, prior) {
  const mode = chooseHeightMode(rgba, width, height);
  const light = heightField(rgba, width, height, mode.mode);
  const broad = boxBlurWrap(light, width, height, DATA_PARAMS.ao_radius);
  const tight = boxBlurWrap(light, width, height, DATA_PARAMS.detail_radius);
  const micro = boxBlurWrap(light, width, height, DATA_PARAMS.roughness_hf_radius);
  const microSmooth = boxBlurWrap(micro, width, height, DATA_PARAMS.roughness_hf_smooth_radius);
  const out = Buffer.alloc(width * height * 4);
  const priorByte = prior * 255;
  for (let i = 0; i < width * height; i++) {
    // Occlusion is relative to the local mean, with a small absolute floor so
    // the near-black rock and ice tiles still produce creases instead of noise.
    const reference = Math.max(broad[i], DATA_PARAMS.ao_reference_floor);
    const relative = Math.max(0, broad[i] - light[i]) / reference;
    const ao = clamp(Math.round(255 - 255 * DATA_PARAMS.ao_relative_gain * relative), DATA_PARAMS.ao_floor, DATA_PARAMS.ao_ceiling);
    const highFrequency = Math.abs(light[i] - microSmooth[i]);
    const rough = clamp(Math.round(priorByte + (highFrequency - DATA_PARAMS.roughness_hf_pivot) * DATA_PARAMS.roughness_hf_scale), DATA_PARAMS.roughness_floor, DATA_PARAMS.roughness_ceiling);
    const detail = clamp(Math.round(128 + (light[i] - tight[i]) * DATA_PARAMS.detail_scale), 0, 255);
    out[i * 4] = ao;
    out[i * 4 + 1] = rough;
    out[i * 4 + 2] = detail;
    out[i * 4 + 3] = 255;
  }
  return { pixels: out, height: mode };
}

// Sign convention: the baked normals and the runtime sampler both treat +V as
// image-down, so the derived green channel is 128 + 127 * (+dX/dV). The choice
// is not asserted: it is calibrated against the baked maps in resolveCalibration().
//
// Magnitude is normalised per texture: the Sobel response is divided by its own
// mean so the declared target magnitude is what the file actually contains. That
// keeps a low-contrast tile from being flattened or a busy one from saturating.
export function normalMap(rgba, width, height, targetMagnitude, greenSign, mode, heightRadius = NORMAL_PARAMS.height_radius) {
  const light = heightField(rgba, width, height, mode);
  const rx = typeof heightRadius === 'object' ? Math.max(0, heightRadius.x | 0) : Math.max(0, heightRadius | 0);
  const ry = typeof heightRadius === 'object' ? Math.max(0, heightRadius.y | 0) : rx;
  const smooth = boxBlurWrapAxes(light, width, height, rx, ry);
  const { gx, gy } = sobelWrap(smooth, width, height);
  const count = width * height;
  let magnitudeSum = 0;
  for (let i = 0; i < count; i++) magnitudeSum += Math.abs(gx[i]) + Math.abs(gy[i]);
  const meanSlope = magnitudeSum / Math.max(1, count * 2 * 4 * 255);
  const scale = meanSlope > 0 ? targetMagnitude / meanSlope : 0;
  const out = Buffer.alloc(count * 4);
  let encodedSum = 0;
  for (let i = 0; i < count; i++) {
    const nx = (-gx[i] / (4 * 255)) * scale;
    const ny = (-gy[i] / (4 * 255)) * scale * greenSign;
    const length = Math.sqrt(nx * nx + ny * ny + 1);
    out[i * 4] = clamp(Math.round(128 + (127 * nx) / length), 0, 255);
    out[i * 4 + 1] = clamp(Math.round(128 + (127 * ny) / length), 0, 255);
    out[i * 4 + 2] = clamp(Math.round(128 + 127 / length), 0, 255);
    out[i * 4 + 3] = 255;
    encodedSum += Math.abs(nx) + Math.abs(ny);
  }
  return {
    pixels: out,
    scale: Number(scale.toFixed(6)),
    mean_slope: Number(meanSlope.toFixed(6)),
    mean_magnitude: Number((encodedSum / Math.max(1, count * 2)).toFixed(4)),
  };
}

// Accent masks are min/max normalised per texture so "off" is exactly 0 and
// "on" is exactly 255, and the measured on-fraction is recorded.
export function maskMap(rgba, width, height, kind) {
  if (!MASK_PARAMS[kind]) throw new Error(`Unknown mask kind: ${kind}`);
  const count = width * height;
  const raw = new Float64Array(count);
  let low = Infinity, high = -Infinity;
  for (let i = 0; i < count; i++) {
    const r = rgba[i * 4], g = rgba[i * 4 + 1], b = rgba[i * 4 + 2];
    const signal = kind === 'yellow-band' ? (r + g) / 2 - b : (g + b) / 2 - r;
    raw[i] = signal;
    low = Math.min(low, signal);
    high = Math.max(high, signal);
  }
  const span = high - low;
  const out = Buffer.alloc(count * 4);
  let on = 0;
  for (let i = 0; i < count; i++) {
    const value = span > 0 ? clamp(Math.round((255 * (raw[i] - low)) / span), 0, 255) : 0;
    out[i * 4] = value;
    out[i * 4 + 1] = value;
    out[i * 4 + 2] = value;
    out[i * 4 + 3] = 255;
    if (value > 127) on++;
  }
  return {
    pixels: out,
    raw_range: [Number(low.toFixed(2)), Number(high.toFixed(2))],
    on_fraction: Number((on / count).toFixed(4)),
  };
}

// ---------------------------------------------------------------- assembly ---

function check(condition, message) { if (!condition) throw new Error(message); }

async function loadManifest() {
  const bytes = await readFile(resolve(GENERATED, 'manifest.json'));
  const manifest = JSON.parse(bytes.toString('utf8'));
  check(manifest.version === 1, 'Unsupported generated manifest version');
  return { manifest, sha: sha256(bytes) };
}

function decodePlane(manifest, bucket, key) {
  const entry = manifest[bucket]?.[key];
  check(entry, `Unknown ${bucket} key: ${key}`);
  const bytes = readFileSync(resolve(GENERATED, `${bucket}/${key}.png`));
  const image = decodePng(bytes);
  check(image.width === entry.width && image.height === entry.height, `${bucket}/${key}: PNG size disagrees with manifest`);
  const pixels = entry.channels === 3 ? stripAlpha(image.data) : Buffer.from(image.data);
  check(sha256(pixels) === entry.pixel_sha256, `${bucket}/${key}: shipped pixels do not match the manifest hash`);
  return { image, pixels, entry, pngSha: sha256(bytes) };
}

function stripAlpha(data) {
  const out = Buffer.alloc((data.length / 4) * 3);
  for (let i = 0, j = 0; i < data.length; i += 4) {
    out[j++] = data[i]; out[j++] = data[i + 1]; out[j++] = data[i + 2];
  }
  return out;
}

// Pearson correlation between two equal-length float arrays; used only for the
// recorded calibration, never to alter pixels.
function correlate(a, b) {
  const n = a.length;
  let ma = 0, mb = 0;
  for (let i = 0; i < n; i++) { ma += a[i]; mb += b[i]; }
  ma /= n; mb /= n;
  let num = 0, da = 0, db = 0;
  for (let i = 0; i < n; i++) {
    const x = a[i] - ma, y = b[i] - mb;
    num += x * y; da += x * x; db += y * y;
  }
  return da === 0 || db === 0 ? 0 : num / Math.sqrt(da * db);
}

export function calibrate(manifest, greenSign) {
  // Compare derived normals against the baked ones for every calibration key,
  // at the baked resolution. The sign convention with the higher mean
  // correlation wins; the measured value is recorded in the manifest.
  const samples = {};
  const correlations = [];
  for (const [key, magnitude] of Object.entries(CALIBRATION_KEYS)) {
    if (!manifest.normals?.[key]) continue;
    const source = decodePlane(manifest, 'textures', key);
    const baked = decodePlane(manifest, 'normals', key);
    const width = baked.image.width, height = baked.image.height;
    const mode = chooseHeightMode(source.pixels, source.image.width, source.image.height).mode;
    const derived = normalMap(source.pixels, source.image.width, source.image.height, magnitude, greenSign, mode);
    const dx = [], dy = [], bx = [], by = [];
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const si = (Math.floor((y * source.image.height) / height) * source.image.width + Math.floor((x * source.image.width) / width)) * 4;
        const bi = (y * width + x) * 4;
        dx.push((derived.pixels[si] - 128) / 127); dy.push((derived.pixels[si + 1] - 128) / 127);
        bx.push((baked.pixels[bi] - 128) / 127); by.push((baked.pixels[bi + 1] - 128) / 127);
      }
    }
    const cx = correlate(dx, bx), cy = correlate(dy, by);
    samples[key] = {
      normal_x: Number(cx.toFixed(4)), normal_y: Number(cy.toFixed(4)),
      mean_magnitude_derived: derived.mean_magnitude,
      mean_magnitude_baked: Number(((meanAbs(bx) + meanAbs(by)) / 2).toFixed(4)),
      height_mode: mode,
      pixels: dx.length,
    };
    correlations.push(cx, cy);
  }
  const mean = correlations.reduce((sum, value) => sum + value, 0) / Math.max(1, correlations.length);
  return { samples, mean_correlation: Number(mean.toFixed(4)) };
}

function meanAbs(values) {
  let sum = 0;
  for (const value of values) sum += Math.abs(value);
  return sum / Math.max(1, values.length);
}

// Measured per-file statistics recorded in the manifest so the design document
// can quote facts instead of intentions.
function planeStats(pixels, kind) {
  const count = pixels.length / 4;
  let r = 0, g = 0, b = 0;
  for (let i = 0; i < count; i++) { r += pixels[i * 4]; g += pixels[i * 4 + 1]; b += pixels[i * 4 + 2]; }
  const meanB = b / count;
  let variance = 0;
  for (let i = 0; i < count; i++) { const d = pixels[i * 4 + 2] - meanB; variance += d * d; }
  if (kind === 'data') {
    return {
      ao_mean: Number((r / count / 255).toFixed(4)),
      roughness_mean: Number((g / count / 255).toFixed(4)),
      detail_stddev: Number(Math.sqrt(variance / count).toFixed(2)),
    };
  }
  return {};
}

export async function deriveAssets(output = DERIVED) {
  const { manifest, sha: manifestSha } = await loadManifest();
  const calibration = resolveCalibration(manifest);
  const files = new Map();
  const derived = {};
  const channelMaps = {
    data: { r: 'ao', g: 'roughness', b: 'detail', a: 'unused' },
    normal: { r: 'normal_x', g: 'normal_y', b: 'normal_z', a: 'unused' },
    mask: { r: 'accent_mask', g: 'accent_mask', b: 'accent_mask', a: 'unused' },
  };
  const source_ = (bucket, key, entry, pngSha) => [{ bucket, key, pixel_sha256: entry.pixel_sha256, png_sha256: pngSha }];

  function emit(key, kind, width, height, pixels, source, algorithm, parameters, stats) {
    const png = encodePng(width, height, 4, pixels, 'linear');
    const folder = kind === 'data' ? 'data' : (kind === 'normal' ? 'normals' : 'masks');
    const name = key.slice(key.indexOf('--') + 2);
    files.set(`${folder}/${name}.png`, png);
    derived[key] = {
      path: `res://moth/derived/${folder}/${name}.png`,
      kind, width, height, channels: 4, color_space: 'linear',
      channel_map: channelMaps[kind],
      source,
      algorithm,
      parameters,
      stats,
      pixel_sha256: sha256(pixels),
      png_sha256: sha256(png),
    };
  }

  for (const [key, prior] of Object.entries(DATA_TARGETS)) {
    const source = decodePlane(manifest, 'textures', key);
    const result = dataMap(source.pixels, source.image.width, source.image.height, prior);
    emit(`data--${key}`, 'data', source.image.width, source.image.height, result.pixels,
      source_('textures', key, source.entry, source.pngSha),
      'luminance-ao-roughness-detail',
      {
        ...DATA_PARAMS, roughness_prior: prior,
        height_channel: result.height.mode, height_channel_note: HEIGHT_MODES[result.height.mode],
        height_stddev_luminance: result.height.luminance_stddev, height_stddev_max_mix: result.height.max_mix_stddev,
      },
      planeStats(result.pixels, 'data'));
  }
  for (const [key, spec] of Object.entries(NORMAL_TARGETS)) {
    check(!manifest.normals?.[key], `${key}: a baked normal exists; deriving one would shadow the bake`);
    const { magnitude: targetMagnitude, radius: heightRadius = NORMAL_PARAMS.height_radius } = typeof spec === 'number'
      ? { magnitude: spec, radius: NORMAL_PARAMS.height_radius } : spec;
    const source = decodePlane(manifest, 'textures', key);
    const mode = chooseHeightMode(source.pixels, source.image.width, source.image.height);
    const result = normalMap(source.pixels, source.image.width, source.image.height, targetMagnitude, calibration.chosen_green_sign, mode.mode, heightRadius);
    emit(`normal--${key}`, 'normal', source.image.width, source.image.height, result.pixels,
      source_('textures', key, source.entry, source.pngSha),
      'luminance-sobel-height-normalised',
      {
        ...NORMAL_PARAMS, target_magnitude: targetMagnitude,
        height_radius: (typeof heightRadius === 'object' ? { x: heightRadius.x, y: heightRadius.y } : heightRadius),
        applied_scale: result.scale,
        mean_slope: result.mean_slope, green_sign: calibration.chosen_green_sign,
        height_channel: mode.mode, height_channel_note: HEIGHT_MODES[mode.mode],
      },
      { mean_magnitude: result.mean_magnitude });
  }
  for (const [key, kind] of Object.entries(MASK_TARGETS)) {
    const source = decodePlane(manifest, 'textures', key);
    const result = maskMap(source.pixels, source.image.width, source.image.height, kind);
    emit(`mask--${key}`, 'mask', source.image.width, source.image.height, result.pixels,
      source_('textures', key, source.entry, source.pngSha),
      `mask-${kind}`,
      { ...MASK_PARAMS[kind], normalisation: 'min/max of the raw signal', raw_signal_range: result.raw_range },
      { mask_on_fraction: result.on_fraction });
  }

  const keys = Object.keys(derived).sort();
  const sorted = {};
  for (const key of keys) sorted[key] = derived[key];
  const output_manifest = {
    version: DERIVED_VERSION,
    provenance: {
      tool: 'tools/godot-moth/derive.mjs',
      tool_sha256: sha256(readFileSync(fileURLToPath(import.meta.url))),
      source_manifest: 'godot/moth/generated/manifest.json',
      source_manifest_sha256: manifestSha,
      source_bake: manifest.provenance?.source ?? 'unknown',
      derived_version: DERIVED_VERSION,
      encoder: 'tools/godot-moth/export.mjs encodePng (untagged linear, deflate level 9)',
      rights: manifest.provenance?.rights ?? 'Unresolved; derivation grants no new clearance.',
      determinism: 'integer kernels, IEEE sqrt/round, no timestamps, no RNG',
    },
    calibration,
    derived: sorted,
  };
  files.set('manifest.json', Buffer.from(JSON.stringify(output_manifest, null, 2) + '\n'));
  for (const folder of ['data', 'normals', 'masks']) await mkdir(resolve(output, folder), { recursive: true });
  for (const [relative, bytes] of files) await writeFile(resolve(output, relative), bytes);
  return output_manifest;
}

// The sign convention is part of the tool's identity: it is resolved before
// anything is written and recorded in the manifest, never asserted silently.
function resolveCalibration(manifest) {
  const positive = calibrate(manifest, 1);
  const negative = calibrate(manifest, -1);
  const sign = positive.mean_correlation >= negative.mean_correlation ? 1 : -1;
  return {
    chosen_green_sign: sign,
    positive_sign: positive,
    negative_sign: negative,
    method: 'pearson correlation of derived vs baked normal X/Y at baked resolution across calibration keys',
    caveat: 'baked normals are sparse and 8-bit quantised, so correlations are weak; the sign choice only fixes texture-space orientation',
  };
}

// Godot regenerates .import files with detect_3d/compress_to=1 (auto VRAM
// compression on first 3D use), which would silently damage these data planes.
// The tool owns its bucket, so it repairs the policy after Godot has written it.
async function normaliseImportPolicy(root = DERIVED) {
  let changed = 0;
  const entries = await readdir(root, { recursive: true, withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.png.import')) continue;
    const path = resolve(entry.parentPath ?? entry.path, entry.name);
    const text = await readFile(path, 'utf8');
    const repaired = text
      .replace(/compress\/mode=\d+/g, 'compress/mode=0')
      .replace(/mipmaps\/generate=\w+/g, 'mipmaps/generate=true')
      .replace(/detect_3d\/compress_to=\d+/g, 'detect_3d/compress_to=0');
    if (repaired !== text) { await writeFile(path, repaired); changed++; }
  }
  return changed;
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--check')) {
    const temporary = await mkdtemp(resolve(tmpdir(), 'moth-derived-check-'));
    try {
      const fresh = await deriveAssets(temporary);
      const committedManifest = JSON.parse(await readFile(resolve(DERIVED, 'manifest.json'), 'utf8'));
      check(JSON.stringify(committedManifest) === JSON.stringify(fresh), 'Committed derived manifest differs from a fresh run');
      for (const [key, entry] of Object.entries(fresh.derived)) {
        const relative = entry.path.replace('res://moth/derived/', '');
        const freshBytes = await readFile(resolve(temporary, relative));
        const committedBytes = await readFile(resolve(DERIVED, relative));
        check(sha256(freshBytes) === entry.png_sha256, `${key}: fresh derivation hash mismatch`);
        check(sha256(freshBytes) === sha256(committedBytes), `${key}: committed file differs from a fresh run`);
      }
      console.log(`MOTH_DERIVED_CHECK_OK files=${Object.keys(fresh.derived).length} sign=${fresh.calibration.chosen_green_sign}`);
    } finally {
      await rm(temporary, { recursive: true, force: true });
    }
    return;
  }
  const manifest = await deriveAssets(DERIVED);
  const repaired = await normaliseImportPolicy();
  const data = Object.values(manifest.derived).filter(entry => entry.kind === 'data');
  const ao = data.reduce((sum, entry) => sum + entry.stats.ao_mean, 0) / Math.max(1, data.length);
  console.log(`MOTH_DERIVED_OK repaired_imports=${repaired} files=${Object.keys(manifest.derived).length} data=${Object.keys(DATA_TARGETS).length} normals=${Object.keys(NORMAL_TARGETS).length} masks=${Object.keys(MASK_TARGETS).length} sign=${manifest.calibration.chosen_green_sign} mean_ao=${ao.toFixed(3)}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { console.error(error); process.exit(1); });
}
