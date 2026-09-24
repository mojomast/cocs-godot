#!/usr/bin/env node
// Uniqueness audit for Moth normal maps (or any same-size plane bucket).
//
// The 2026-09-24 pass found the thirteen baked normals correlate up to 1.00 at
// low frequency: every normal job submitted the same statistics (style xy,
// strength 0.25-0.55, no generateValues), so the engine returned the same class
// of noise thirteen times. This tool measures that: pairwise correlation of the
// 16x16 low-frequency sample (what the eye reads as "the same bump") plus each
// plane's structure energy (full-resolution stddev; near-zero means flat).
//
// Usage:
//   node tools/godot-moth/uniqueness.mjs                      # baked normals
//   node tools/godot-moth/uniqueness.mjs godot/moth/derived/normals
//   node tools/godot-moth/uniqueness.mjs --json               # machine output
//
// Exit code 1 when any pair exceeds the near-duplicate threshold (0.90) or any
// plane is flatter than the structure floor (stddev 2.0), so a future bake can
// gate on it. The shipped baked set deliberately fails this - it is the audit.
import {readFile, readdir} from 'node:fs/promises';
import {resolve, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {decodePng} from '../../scripts/moth-bake.mjs';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const THRESHOLD = 0.90, STRUCTURE_FLOOR = 2.0;

async function load(dir) {
  const planes = [];
  for (const name of (await readdir(dir)).filter(n => n.endsWith('.png')).sort()) {
    const bytes = await readFile(join(dir, name));
    const image = decodePng(bytes);
    const {width, height, data} = image;
    if (width !== height) throw new Error(`${name}: not square (${width}x${height})`);
    const channels = data.length / (width * height);   // decodePng implies channels by length
    if (channels < 3) throw new Error(`${name}: needs RGB(A), got ${channels} channel(s)`);
    const rgb = [];
    for (let i = 0; i < width * height; i++) {
      const o = i * channels;
      rgb.push([data[o], data[o + 1], data[o + 2]]);
    }
    planes.push({name: name.replace(/\.png$/, ''), width, rgb});
  }
  return planes;
}

const sample = (plane, step) => {
  const out = [];
  for (let y = 0; y < plane.width; y += step) {
    for (let x = 0; x < plane.width; x += step) out.push(plane.rgb[y * plane.width + x]);
  }
  return out;
};

function pearson(a, b) {
  const n = a.length;
  let ma = 0, mb = 0;
  for (let i = 0; i < n; i++) { ma += a[i]; mb += b[i]; }
  ma /= n; mb /= n;
  let va = 0, vb = 0, cov = 0;
  for (let i = 0; i < n; i++) { const da = a[i] - ma, db = b[i] - mb; va += da * da; vb += db * db; cov += da * db; }
  return (va < 1e-9 || vb < 1e-9) ? 0 : cov / Math.sqrt(va * vb);
}

function structureStd(plane) {
  const rs = plane.rgb.map(p => p[0]), gs = plane.rgb.map(p => p[1]);
  const std = values => {
    const mean = values.reduce((a, b) => a + b, 0) / values.length;
    return Math.sqrt(values.reduce((a, b) => a + (b - mean) ** 2, 0) / values.length);
  };
  return Math.max(std(rs), std(gs));
}

async function main() {
  const argv = process.argv.slice(2);
  const json = argv.includes('--json');
  const dirs = argv.filter(a => !a.startsWith('--')).map(d => resolve(ROOT, d));
  if (!dirs.length) dirs.push(resolve(ROOT, 'godot/moth/generated/normals'));
  const planes = [];
  for (const dir of dirs) planes.push(...await load(dir));

  const samples = new Map(planes.map(p => [p.name, sample(p, Math.max(1, p.width >> 4))]));
  const pairs = [];
  for (let i = 0; i < planes.length; i++) {
    for (let j = i + 1; j < planes.length; j++) {
      const a = planes[i], b = planes[j];
      const channels = [0, 1].map(c => Math.abs(pearson(samples.get(a.name).map(p => p[c]), samples.get(b.name).map(p => p[c]))));
      pairs.push({a: a.name, b: b.name, similarity: (channels[0] + channels[1]) / 2});
    }
  }
  pairs.sort((x, y) => y.similarity - x.similarity);
  const stats = planes.map(p => ({name: p.name, structure_std: structureStd(p)}));
  const similarities = pairs.map(p => p.similarity).sort((a, b) => a - b);
  const median = similarities.length ? similarities[similarities.length >> 1] : 0;
  const flat = stats.filter(s => s.structure_std < STRUCTURE_FLOOR);
  const near = pairs.filter(p => p.similarity > THRESHOLD);

  const report = {
    planes: planes.length,
    pairs: pairs.length,
    median_similarity: Number(median.toFixed(3)),
    max_similarity: Number((similarities.at(-1) ?? 0).toFixed(3)),
    near_duplicate_pairs: near.length,
    flat_planes: flat.map(s => s.name),
    most_similar: pairs.slice(0, 5).map(p => ({...p, similarity: Number(p.similarity.toFixed(3))})),
    structure: stats,
  };
  if (json) { console.log(JSON.stringify(report, null, 1)); }
  else {
    console.log(`moth uniqueness: planes=${report.planes} pairs=${report.pairs} ` +
      `median_similarity=${report.median_similarity} max=${report.max_similarity} ` +
      `near_duplicates(>${THRESHOLD})=${near.length} flat(<${STRUCTURE_FLOOR})=${flat.length}`);
    for (const p of report.most_similar) console.log(`  ${p.similarity.toFixed(3)}  ${p.a} ~ ${p.b}`);
  }
  const failed = near.length > 0 || flat.length > 0;
  if (!json && failed) console.log('UNIQUENESS_AUDIT failed: near-duplicates or flat planes above');
  else if (!json) console.log('UNIQUENESS_AUDIT passed');
  return failed ? 1 : 0;
}

main().then(code => { process.exitCode = code; })
  .catch(error => { console.error(`uniqueness: ${error.message}`); process.exitCode = 1; });
