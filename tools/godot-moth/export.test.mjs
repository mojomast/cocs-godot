import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { MOTH_BAKED as source } from '../../game/moth-baked.mjs';
// Independent, existing decoder handles PNG filters and RGB expansion.
import { decodePng } from '../../scripts/moth-bake.mjs';
import { exportAssets, sha256, encodePng } from './export.mjs';

test('every shipped PNG reproduces locked source bytes; exports deterministic and committed current', async () => {
  const dir = await mkdtemp(resolve(tmpdir(), 'moth-export-test-'));
  try {
    const a = resolve(dir, 'a'), b = resolve(dir, 'b');
    const manifest = await exportAssets(a);
    await exportAssets(b);
    let count = 0;
    async function check(record, original) {
      const relative = record.path.replace('res://moth/generated/', '');
      const png = await readFile(resolve(a, relative));
      const decoded = decodePng(png);
      const bytes = Buffer.from(original, 'base64');
      assert.equal(decoded.width, record.width); assert.equal(decoded.height, record.height);
      const actual = record.channels === 3 ? Buffer.from(decoded.data.filter((_, i) => i % 4 !== 3)) : Buffer.from(decoded.data);
      assert.deepEqual(actual, bytes, relative);
      assert.equal(sha256(bytes), record.pixel_sha256);
      count++;
    }
    for (const bucket of ['textures', 'normals', 'sky']) for (const [key, record] of Object.entries(manifest[bucket])) await check(record, source[bucket][key].data);
    for (const [key, pair] of Object.entries(manifest.materials)) for (const part of ['r', 't']) await check(pair[part], source.materials[key][part]);
    for (const [key, effect] of Object.entries(manifest.effects)) {
      assert.equal(effect.fps, source.effects[key].fps);
      for (const [index, record] of effect.frames.entries()) await check(record, source.effects[key].frames[index].data);
    }
    assert.equal(count, 101);
    for (const file of await readdir(a, { recursive: true, withFileTypes: true })) {
      if (!file.isFile()) continue;
      const relative = resolve(file.parentPath ?? file.path, file.name).slice(a.length + 1);
      const bytes = await readFile(resolve(a, relative));
      assert.deepEqual(bytes, await readFile(resolve(b, relative)), `determinism: ${relative}`);
      const committed = await readFile(resolve('godot/moth/generated', relative));
      if (relative.endsWith('.import')) {
        // Godot adds UIDs/defaults. Verify every exported policy survives native import.
        for (const line of bytes.toString().split('\n').filter(line => line.includes('=') && !line.includes('metadata='))) assert.ok(committed.toString().includes(line), `Import policy: ${relative}: ${line}`);
      } else assert.deepEqual(bytes, committed, `committed: ${relative}`);
    }
  } finally { await rm(dir, { recursive: true, force: true }); }
});

test('invalid dimensions, channels, payloads and timing fail before writes', async () => {
  assert.throws(() => encodePng(0, 1, 4, Buffer.alloc(4), 'srgb'), /dimensions/);
  assert.throws(() => encodePng(1, 1, 3, Buffer.alloc(4), 'linear'), /length/);
  const invalid = structuredClone(source);
  invalid.effects['quantum-rift'].fps = NaN;
  await assert.rejects(exportAssets(resolve(tmpdir(), 'moth-must-not-write'), invalid), /Invalid effect/);
  invalid.effects['quantum-rift'].fps = 10;
  invalid.textures.rock.data = '!!';
  await assert.rejects(exportAssets(resolve(tmpdir(), 'moth-must-not-write'), invalid), /base64/);
});
