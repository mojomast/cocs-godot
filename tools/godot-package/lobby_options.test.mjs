import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options} from './options.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';
const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));

for (const [name, parse] of [['package', options], ['dev', launchOptions]]) {
  test(`${name}: opt-in lobby distinguishes owned and explicit external authority`, () => {
    assert.equal(parse(['--experience=lobby'], catalog).endpoint, null);
    for (const endpoint of ['ws://127.0.0.1:12345', 'wss://example.invalid/game', 'ws://[::1]:12345']) {
      const plan = parse(['--experience=lobby', '--endpoint', endpoint, '--map=ember-crucible', '--mode=rockets'], catalog);
      assert.equal(plan.endpoint, endpoint);
      const args = plan.userArgs ?? plan.sessionOptions;
      assert.ok(args.includes('--lobby-menu'));
      assert.ok(!args.includes('--setup'));
      assert.ok(args.includes('--map=ember-crucible'));
    }
  });
  test(`${name}: invalid lobby configuration fails before starting anything`, () => {
    for (const endpoint of ['https://example.invalid', 'file:///tmp/game', 'ws://', 'ws:localhost', 'ws://localhost\\game', 'ws://user:pass@localhost:12345', 'ws://localhost:12345/#secret', 'ws://local host:12345', 'ws://localhost:99999', 'ws://localhost/'+'a'.repeat(2048)]) {
      assert.throws(() => parse(['--experience=lobby', `--endpoint=${endpoint}`], catalog));
    }
    for (const args of [
      ['--endpoint=ws://localhost:12345'],
      ['--experience=sports','--endpoint=ws://localhost:12345'],
      ['--experience=lobby','--map=tidal-citadel'],
      ['--experience=lobby','--mode=armsrace'],
      ['--experience=lobby','--setup'],
      ['--experience=lobby','--endpoint='],
      ['--experience=lobby','--endpoint=ws://localhost:1','--endpoint=ws://localhost:2'],
    ]) assert.throws(() => parse(args, catalog), undefined, JSON.stringify(args));
  });
}
