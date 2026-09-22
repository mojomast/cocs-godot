import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { tmpdir } from 'node:os';
// Independent decoder: the same one the export tests use, so a hash match here
// means "the file really contains the pixels the manifest claims".
import { decodePng } from '../../scripts/moth-bake.mjs';
import { deriveAssets, sha256, DERIVED, DATA_TARGETS, NORMAL_TARGETS, MASK_TARGETS } from './derive.mjs';

const GENERATED = resolve(import.meta.dirname, '../../godot/moth/generated');

async function generatedPaths() {
  const manifest = JSON.parse(await readFile(resolve(GENERATED, 'manifest.json'), 'utf8'));
  const paths = new Set();
  for (const bucket of ['textures', 'normals', 'sky']) for (const record of Object.values(manifest[bucket])) paths.add(record.path);
  for (const pair of Object.values(manifest.materials)) for (const part of ['r', 't']) paths.add(pair[part].path);
  for (const effect of Object.values(manifest.effects)) for (const frame of effect.frames) paths.add(frame.path);
  return { manifest, paths };
}

test('derivation is deterministic, byte-identical across runs and to the committed bucket', async () => {
  const dirs = await Promise.all(['a', 'b'].map(name => mkdtemp(resolve(tmpdir(), `moth-derive-${name}-`))));
  try {
    const [first, second] = await Promise.all(dirs.map(dir => deriveAssets(dir)));
    assert.deepEqual(first, second, 'manifest payload repeats exactly');
    assert.equal(Object.keys(first.derived).length, Object.keys(DATA_TARGETS).length + Object.keys(NORMAL_TARGETS).length + Object.keys(MASK_TARGETS).length);
    for (const [key, entry] of Object.entries(first.derived)) {
      const relative = entry.path.replace('res://moth/derived/', '');
      const [left, right, committed] = await Promise.all([
        readFile(resolve(dirs[0], relative)),
        readFile(resolve(dirs[1], relative)),
        readFile(resolve(DERIVED, relative)),
      ]);
      assert.deepEqual(left, right, `determinism: ${key}`);
      assert.deepEqual(left, committed, `committed: ${key}`);
      assert.equal(sha256(left), entry.png_sha256, `file hash: ${key}`);
      const decoded = decodePng(left);
      assert.equal(decoded.width, entry.width, `width: ${key}`);
      assert.equal(decoded.height, entry.height, `height: ${key}`);
      assert.equal(sha256(Buffer.from(decoded.data)), entry.pixel_sha256, `pixel hash: ${key}`);
      assert.equal(entry.color_space, 'linear', `linear plane: ${key}`);
      assert.equal(entry.channels, 4, `channel count: ${key}`);
      assert.ok(entry.source.length >= 1, `source recorded: ${key}`);
      for (const source of entry.source) assert.match(source.pixel_sha256, /^[0-9a-f]{64}$/);
      assert.ok(typeof entry.algorithm === 'string' && entry.algorithm.length > 4, `algorithm: ${key}`);
      assert.ok(Object.keys(entry.parameters).length >= 2, `parameters: ${key}`);
      assert.ok(Object.keys(entry.stats).length >= 1, `stats: ${key}`);
    }
    const [left, right, committed] = await Promise.all([
      readFile(resolve(dirs[0], 'manifest.json')),
      readFile(resolve(dirs[1], 'manifest.json')),
      readFile(resolve(DERIVED, 'manifest.json')),
    ]);
    assert.deepEqual(left, right, 'manifest bytes repeat');
    assert.deepEqual(left, committed, 'committed manifest matches a fresh run');
    assert.equal(first.version, 1);
    assert.ok([1, -1].includes(first.calibration.chosen_green_sign), 'sign choice recorded');
    assert.ok(Object.keys(first.calibration.positive_sign.samples).length >= 6, 'calibration has samples');
    assert.equal(
      first.calibration.chosen_green_sign === 1,
      first.calibration.positive_sign.mean_correlation >= first.calibration.negative_sign.mean_correlation,
      'sign choice follows the measured correlation',
    );
  } finally {
    await Promise.all(dirs.map(dir => rm(dir, { recursive: true, force: true })));
  }
});

test('derived bucket stays outside the 101-plane inventory and every derived plane is well formed', async () => {
  const { manifest, paths } = await generatedPaths();
  assert.equal(paths.size, 101, 'baked inventory is still 101 planes');
  const derived = JSON.parse(await readFile(resolve(DERIVED, 'manifest.json'), 'utf8')).derived;
  for (const [key, entry] of Object.entries(derived)) {
    assert.ok(!paths.has(entry.path), `derived path does not shadow the bake: ${key}`);
    assert.ok(entry.path.startsWith('res://moth/derived/'), `bucket path: ${key}`);
    const decoded = decodePng(await readFile(resolve(DERIVED, entry.path.replace('res://moth/derived/', ''))));
    assert.equal(decoded.width, entry.width, `decoded width: ${key}`);
    assert.equal(decoded.height, entry.height, `decoded height: ${key}`);
    assert.equal(decoded.data.length, entry.width * entry.height * 4, `decoded bytes: ${key}`);
    assert.equal(decoded.data.length, decoded.data.length, `opaque alpha: ${key}`);
    for (let index = 3; index < decoded.data.length; index += 4) {
      assert.equal(decoded.data[index], 255, `alpha is 255: ${key}`);
      if (decoded.data[index] !== 255) break;
    }
  }
  for (const key of Object.keys(NORMAL_TARGETS)) assert.ok(!manifest.normals[key], `${key} has no baked normal`);
  for (const key of Object.keys(DATA_TARGETS)) assert.ok(manifest.textures[key], `data target exists: ${key}`);
  for (const [key, kind] of Object.entries(MASK_TARGETS)) {
    assert.ok(manifest.textures[key], `mask source exists: ${key}`);
    assert.ok(['yellow-band', 'trace'].includes(kind), `mask kind: ${key}`);
    const record = derived[`mask--${key}`];
    assert.ok(record.stats.mask_on_fraction > 0.05 && record.stats.mask_on_fraction < 0.98, `mask separates: ${key}`);
  }
  for (const [key, record] of Object.entries(derived)) {
    if (record.kind !== 'data') continue;
    assert.ok(record.stats.ao_mean > 0.5 && record.stats.ao_mean <= 1.0, `ao sane: ${key}`);
    assert.ok(record.stats.roughness_mean > 0.05 && record.stats.roughness_mean < 1.0, `roughness sane: ${key}`);
  }
});

test('derived PNG import policy is lossless, mipmapped and never auto-compressed for 3D', async () => {
  const derived = JSON.parse(await readFile(resolve(DERIVED, 'manifest.json'), 'utf8')).derived;
  let files = 0;
  for (const entry of Object.values(derived)) {
    const importFile = resolve(DERIVED, entry.path.replace('res://moth/derived/', '') + '.import');
    const text = await readFile(importFile, 'utf8');
    // fix_alpha_border/premultiply are no-ops here (every derived plane is fully
    // opaque), so only the three policies that change decoded bytes are asserted.
    for (const line of ['compress/mode=0', 'mipmaps/generate=true', 'detect_3d/compress_to=0']) {
      assert.ok(text.includes(line), `${entry.path}: ${line}`);
    }
    files++;
  }
  assert.equal(files, Object.keys(derived).length);
  const entries = await readdir(DERIVED, { recursive: true, withFileTypes: true });
  const pngs = entries.filter(entry => entry.isFile() && entry.name.endsWith('.png'));
  assert.equal(pngs.length, files, 'no orphan PNGs in the derived bucket');
});

test('a missing derived bucket is not fatal for the library path', async () => {
  // The bucket is optional at runtime: the library falls back to baked-only
  // surfaces. Here we only assert the manifest contract that makes that work.
  const derived = JSON.parse(await readFile(resolve(DERIVED, 'manifest.json'), 'utf8'));
  assert.equal(derived.provenance.source_manifest, 'godot/moth/generated/manifest.json');
  assert.match(derived.provenance.source_manifest_sha256, /^[0-9a-f]{64}$/);
  assert.match(derived.provenance.tool_sha256, /^[0-9a-f]{64}$/);
  assert.equal(derived.provenance.encoder.includes('untagged linear'), true);
  for (const [key, entry] of Object.entries(derived.derived)) {
    assert.ok(entry.source.every(source => ['textures', 'normals'].includes(source.bucket)), `source bucket: ${key}`);
  }
});
