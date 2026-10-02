import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {REPLAY_FILES, REPLAY_KIND} from '../../godot-package/replay_runtime.mjs';

test('native replay manifest vocabulary exactly matches the separate package closure', () => {
  // Cross-language data contract only; native execution is a separate gate.
  const source = readFileSync(new URL('../../../godot/replay/bridge.gd', import.meta.url), 'utf8');
  const paths = source.match(/^const RUNTIME_FILES := (\[.*\])$/m);
  const kind = source.match(/^const RUNTIME_KIND := (".*")$/m);
  assert.ok(paths); assert.ok(kind);
  assert.deepEqual(JSON.parse(paths[1]), REPLAY_FILES);
  assert.equal(JSON.parse(kind[1]), REPLAY_KIND);
});
