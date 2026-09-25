#!/usr/bin/env node
// Regenerate the native REQ catalogue mirror from `game/cocs-economy.mjs`.
//
//   node port/tools/native_lattice_req_catalog/export.mjs           # rewrite
//   node port/tools/native_lattice_req_catalog/export.mjs --check   # CI/parity
//   node port/tools/native_lattice_req_catalog/export.mjs --print   # stdout
//
// `--check` exits non-zero when the committed mirror is stale, so a source lane
// that launches a new row fails the native contract until this file is
// re-run and reviewed. Nothing here writes game/, server/ or web source.
import {readFileSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {REPO_ROOT, ReqCatalogSourceError} from './source.mjs';
import {generateCatalogText, BEGIN} from './render.mjs';

export const TARGET = join(REPO_ROOT, 'godot/lattice/req_catalog.gd');

export function run({check = false, print = false, target = TARGET} = {}) {
  const current = readFileSync(target, 'utf8');
  const generated = generateCatalogText(current).text;
  const changed = generated !== current;
  if (print) process.stdout.write(generated);
  if (check) return {changed, target};
  if (changed && !print) writeFileSync(target, generated);
  return {changed, target};
}

function main() {
  const args = new Set(process.argv.slice(2));
  if (args.has('--help') || args.has('-h')) {
    process.stdout.write('usage: export.mjs [--check] [--print]\n');
    return 0;
  }
  try {
    const {check, print} = {check: args.has('--check'), print: args.has('--print')};
    const result = run({check, print});
    if (check && result.changed) {
      process.stderr.write(`REQ catalogue mirror is stale: ${result.target}\n` +
        `Run: node port/tools/native_lattice_req_catalog/export.mjs\n` +
        `Then review the generated rows before committing (a launched source row must be mirrored).\n`);
      return 1;
    }
    if (!check && !print) {
      process.stdout.write(result.changed
        ? `updated ${result.target} from game/cocs-economy.mjs\n`
        : `unchanged ${result.target} (mirror already current)\n`);
    }
    return 0;
  } catch (error) {
    if (error instanceof ReqCatalogSourceError) {
      process.stderr.write(`REQ catalogue export refused (fail-closed): ${error.message}\n`);
      return 2;
    }
    throw error;
  }
}

if (import.meta.url === `file://${process.argv[1]}`) process.exitCode = main();
