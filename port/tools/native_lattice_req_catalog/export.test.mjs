import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {
  REPO_ROOT, ReqCatalogSourceError, canonicalRow, catalogRows, digestRows,
  parseItemsBlock, readEconomyText, assertSourceViewMatches, locateItemsBlock,
} from './source.mjs';
import {renderBlock, replaceBlock, BEGIN, END} from './render.mjs';

const EXPORT = join(REPO_ROOT, 'port/tools/native_lattice_req_catalog/export.mjs');
const TARGET = join(REPO_ROOT, 'godot/lattice/req_catalog.gd');
const item = (over = {}) => ({id: 'probe', name: 'Probe', category: 'equipment', cost: 10,
  launch: true, modes: ['cocs'], effect: {kind: 'heal'}, effectCopy: 'probe', ...over});

test('launched rows are mirrored with source cost/copy/modes/flags', () => {
  const rows = catalogRows();
  assert.deepEqual(rows.map(row => row.id),
    ['field-repair', 'ammo-crate', 'haste', 'overshield', 'spot-drone', 'repair-tool', 'sentry', 'puma', 'recon-pulse']);
  assert.deepEqual(rows.map(row => row.cost), [40, 25, 35, 50, 45, 30, 60, 150, 60]);
  assert.equal(rows.find(row => row.id === 'puma').coopLaunch, true);
  assert.equal(rows.find(row => row.id === 'puma').launch, false);
  assert.equal(rows.find(row => row.id === 'repair-tool').target, 'cut-link');
  assert.equal(rows.find(row => row.id === 'field-repair').personalBuff, true);
  assert.equal(rows.find(row => row.id === 'spot-drone').personalBuff, false);
  assert.ok(rows.every(row => row.effectKind && row.modes.length > 0));
});

test('the imported and text source views agree field-for-field', () => {
  assert.deepEqual(assertSourceViewMatches(readEconomyText()), catalogRows());
});

test('an unknown effect kind is refused instead of offered (fail-closed)', () => {
  assert.throws(() => catalogRows([item({effect: {kind: 'smoke'}})]), error => {
    assert.ok(error instanceof ReqCatalogSourceError);
    assert.match(error.message, /unknown effect kind 'smoke'/);
    return true;
  });
});

test('a launched row without a machine effect is refused', () => {
  assert.throws(() => catalogRows([item({effect: undefined})]), /no machine effect descriptor/);
});

test('modes without a launch flag are refused (no pay-for-no-op)', () => {
  assert.throws(() => catalogRows([item({launch: false, coopLaunch: false})]),
    /has modes but is not launchable/);
});

test('a launched row with empty modes is refused (never offered)', () => {
  assert.throws(() => catalogRows([item({modes: []})]), /launchable but has empty modes/);
});

test('rendering is deterministic and keeps the generated markers', () => {
  const rows = catalogRows();
  const first = renderBlock(rows);
  assert.equal(first, renderBlock(rows));
  assert.ok(first.startsWith(BEGIN));
  assert.ok(first.endsWith(END));
  for (const row of rows) assert.match(first, new RegExp(`"id":"${row.id}"`));
  assert.notEqual(digestRows(rows), digestRows(rows.slice(0, -1)));
});

test('replaceBlock rewrites only the marked region', () => {
  const source = `head\n${BEGIN}\nold\n${END}\ntail\n`;
  const updated = replaceBlock(source, renderBlock(catalogRows()));
  assert.ok(updated.startsWith('head\n'));
  assert.ok(updated.endsWith('tail\n'));
  assert.ok(!updated.includes('\nold\n'));
  assert.throws(() => replaceBlock('no markers', 'x'), /missing generated-region marker/);
});

test('committed mirror is current, and a newly launched source row would be stale', () => {
  const check = spawnSync(process.execPath, [EXPORT, '--check'], {cwd: REPO_ROOT, encoding: 'utf8'});
  assert.equal(check.status, 0, check.stderr || check.stdout);
  const committed = readFileSync(TARGET, 'utf8');
  // A source lane that launches an eighth row changes the generated region, so
  // `--check` (and the Godot parity contract) fails until the mirror is re-run.
  const grown = renderBlock([...catalogRows(), canonicalRow(item({id: 'new-row'}))]);
  assert.notEqual(replaceBlock(committed, grown), committed);
  assert.ok(locateItemsBlock(readEconomyText()).block.includes("id:'field-repair'"));
});
