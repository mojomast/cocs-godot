#!/usr/bin/env node
// Literal coverage scan of the baked Moth manifest across godot/**, using the
// same conservative method as port/native-material-language/COVERAGE-BASELINE.md:
// a key counts only when its exact name appears in a script, shader or scene.
// Names reached through data tables (the material language family table) still
// count, which is the point: they are now named somewhere reviewable.
//
//   node tools/godot-moth/coverage.mjs [--json=<path>]
import { readFile, readdir, writeFile, mkdir } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const GODOT = resolve(ROOT, 'godot');
const BUCKETS = ['textures', 'normals', 'sky', 'materials', 'effects'];

async function sourceFiles(root) {
  const found = [];
  const entries = await readdir(root, { recursive: true, withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (/\.(gd|gdshader|gdshaderinc|tscn|tres)$/.test(entry.name)) {
      found.push(resolve(entry.parentPath ?? entry.path, entry.name));
    }
  }
  return found;
}

async function main() {
  const manifest = JSON.parse(await readFileSync(resolve(GODOT, 'moth/generated/manifest.json'), 'utf8'));
  const derived = JSON.parse(await readFileSync(resolve(GODOT, 'moth/derived/manifest.json'), 'utf8'));
  const files = await sourceFiles(GODOT);
  const corpus = [];
  for (const file of files) corpus.push({ path: file.slice(GODOT.length + 1), text: await readFile(file, 'utf8') });

  const buckets = {};
  let referenced = 0;
  let strictReferenced = 0;
  let total = 0;
  for (const bucket of BUCKETS) {
    const keys = manifest[bucket] ?? {};
    const rows = {};
    for (const key of Object.keys(keys)) {
      const literal = [];
      const strict = [];
      const pattern = new RegExp(`(?<![A-Za-z0-9_-])${key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![A-Za-z0-9_-])`);
      for (const source of corpus) {
        if (source.text.includes(key)) literal.push(source.path);
        if (pattern.test(source.text)) strict.push(source.path);
      }
      rows[key] = { literal: literal.sort(), strict: strict.sort() };
      total++;
      if (literal.length > 0) referenced++;
      if (strict.length > 0) strictReferenced++;
    }
    buckets[bucket] = rows;
  }
  const derivedRows = {};
  for (const key of Object.keys(derived.derived)) {
    const literal = [];
    const strict = [];
    for (const source of corpus) {
      if (source.text.includes(key)) literal.push(source.path);
      if (source.text.includes(`"${key}"`)) strict.push(source.path);
    }
    derivedRows[key] = { literal: literal.sort(), strict: strict.sort() };
  }
  const report = {
    method: 'literal substring scan of godot/**/*.{gd,gdshader,gdshaderinc,tscn,tres}; conservative lower bound',
    generated_at_manifest: manifest.provenance.source_sha256,
    totals: {
      keys: total,
      referenced,
      unreferenced: total - referenced,
      coverage: Number(((referenced / total) * 100).toFixed(1)),
      strict_referenced: strictReferenced,
      strict_coverage: Number(((strictReferenced / total) * 100).toFixed(1)),
      derived_keys: Object.keys(derived.derived).length,
      derived_referenced: Object.values(derivedRows).filter(row => row.literal.length > 0).length,
    },
    buckets,
    derived: derivedRows,
  };
  const args = process.argv.slice(2);
  const jsonArgument = args.find(argument => argument.startsWith('--json='));
  if (jsonArgument) {
    const path = resolve(jsonArgument.slice('--json='.length));
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, JSON.stringify(report, null, 2) + '\n');
  }
  console.log(`MOTH_COVERAGE referenced=${referenced}/${total} (${report.totals.coverage}%) strict=${strictReferenced}/${total} derived=${report.totals.derived_referenced}/${report.totals.derived_keys}`);
  for (const bucket of BUCKETS) {
    const rows = buckets[bucket];
    const used = Object.values(rows).filter(row => row.literal.length > 0).length;
    const strict = Object.values(rows).filter(row => row.strict.length > 0).length;
    const missing = Object.entries(rows).filter(([, row]) => row.strict.length === 0).map(([key]) => key).join(', ');
    console.log(`  ${bucket.padEnd(10)} ${used}/${Object.keys(rows).length} strict ${strict}  unused: ${missing || 'none'}`);
  }
  const derivedMissing = Object.entries(derivedRows).filter(([, row]) => row.literal.length === 0).map(([key]) => key);
  console.log(`  derived     ${Object.keys(derived.derived).length - derivedMissing.length}/${Object.keys(derived.derived).length} literal; never named: ${derivedMissing.join(', ') || 'none'}`);
}

main().catch(error => { console.error(error); process.exit(1); });
