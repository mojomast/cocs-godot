import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const selected = resolve(root, 'port/contracts/lattice-catalog-derivative.json');

function preflight(script, args, derivative) {
  const env = {...process.env, GODOT_BIN: ''};
  delete env.COCS_SOURCE_DERIVATIVE;
  if (derivative) env.COCS_SOURCE_DERIVATIVE = derivative;
  const result = spawnSync(process.execPath, [script, ...args], {cwd: root, env, encoding: 'utf8', timeout: 30000});
  assert.equal(result.error, undefined);
  return result.stderr + result.stdout;
}

test('dev launcher rejects unselected and inventoried-wrong sources before Godot, accepts explicit frozen derivative', () => {
  assert.match(preflight('tools/godot-dev/launch.mjs', [], null), /Locked source differs from working tree/);
  assert.match(preflight('tools/godot-dev/launch.mjs', [], selected), /Set GODOT_BIN/);
  const dir = mkdtempSync(join(process.env.TMPDIR ?? tmpdir(), 'cocs-source-selection-'));
  try {
    const altered = JSON.parse(readFileSync(selected, 'utf8'));
    altered.runtime_files['game/cocs.mjs'] = '0'.repeat(64);
    const wrong = join(dir, 'wrong-derivative.json');
    writeFileSync(wrong, JSON.stringify(altered));
    assert.match(preflight('tools/godot-dev/launch.mjs', [], wrong), /Derivative source byte mismatch/);
    // The browser probe rejects this map before opening a server or browser.
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], null), /Locked source differs from working tree/);
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], selected), /Map not allowlisted/);
    assert.match(preflight('tools/godot-export/browser-export.mjs', ['not-a-locked-map'], wrong), /Derivative source byte mismatch/);
    // Public zone play validates the source before checking GODOT_BIN or opening its server.
    assert.match(preflight('port/native-zone-modes/play.mjs', [], null), /Locked source differs from working tree/);
    assert.match(preflight('port/native-zone-modes/play.mjs', [], selected), /Pinned GODOT_BIN required/);
    assert.match(preflight('port/native-zone-modes/play.mjs', [], wrong), /Derivative source byte mismatch/);
  } finally {
    rmSync(dir, {recursive: true, force: true});
  }
});
