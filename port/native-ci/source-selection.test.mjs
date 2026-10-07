import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
// The reviewed active descriptor is the current source (F01). The lattice
// contract is frozen evidence for an earlier candidate: it must be refused
// against this tree rather than accepted as if it still described it.
const active = resolve(root, 'port/contracts/contact-candidate-derivative.json');
const frozen = resolve(root, 'port/contracts/lattice-catalog-derivative.json');

function preflight(script, args, derivative) {
  const env = {...process.env, GODOT_BIN: ''};
  delete env.COCS_SOURCE_DERIVATIVE;
  if (derivative) env.COCS_SOURCE_DERIVATIVE = derivative;
  const result = spawnSync(process.execPath, [script, ...args], {cwd: root, env, encoding: 'utf8', timeout: 30000});
  assert.equal(result.error, undefined);
  return result.stderr + result.stdout;
}

test('dev launcher resolves the active source, and still refuses a wrong source before Godot', () => {
  // Unset: the launcher resolves the reviewed active descriptor and gets as far
  // as the engine pin, so the current tree is no longer refused as drift.
  assert.match(preflight('tools/godot-dev/launch.mjs', [], null), /Set GODOT_BIN/);
  // An explicit reviewed active contract is accepted on the same path.
  assert.match(preflight('tools/godot-dev/launch.mjs', [], active), /Set GODOT_BIN/);
  // A frozen earlier candidate does not describe this tree and is refused.
  assert.match(preflight('tools/godot-dev/launch.mjs', [], frozen), /Derivative source inventory differs from locked source/);
  const dir = mkdtempSync(join(process.env.TMPDIR ?? tmpdir(), 'cocs-source-selection-'));
  try {
    const altered = JSON.parse(readFileSync(active, 'utf8'));
    altered.runtime_overrides['game/core.mjs'].after = '0'.repeat(64);
    const wrong = join(dir, 'wrong-active.json');
    writeFileSync(wrong, JSON.stringify(altered));
    assert.match(preflight('tools/godot-dev/launch.mjs', [], wrong), /Recorded contact overlay differs/);
    // The browser probe resolves the active source, then rejects this map
    // before opening a server or browser.
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], null), /Map not allowlisted/);
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], frozen), /Derivative source inventory differs from locked source/);
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], wrong), /Recorded contact overlay differs/);
    // Public zone play validates the source before checking GODOT_BIN or opening its server.
    assert.match(preflight('port/native-zone-modes/play.mjs', [], null), /Pinned GODOT_BIN required/);
    assert.match(preflight('port/native-zone-modes/play.mjs', [], active), /Pinned GODOT_BIN required/);
    assert.match(preflight('port/native-zone-modes/play.mjs', [], frozen), /Derivative source inventory differs from locked source/);
    assert.match(preflight('port/native-zone-modes/play.mjs', [], wrong), /Recorded contact overlay differs/);
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
});