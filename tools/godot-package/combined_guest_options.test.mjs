import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options} from './options.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';

const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json', import.meta.url)));
const endpoint = 'ws://127.0.0.1:44321';

test('Combined Arms host and genuine external guest preserve one locked identity and owner', () => {
  const host = ['--experience=combined-arms','--bots=0','--wait-for-players=2'];
  const guest = ['--experience=combined-arms',`--endpoint=${endpoint}`,'--join-room=duo'];
  for (const argv of [host,guest]) {
    const pkg = options(argv,catalog), dev = launchOptions(argv,catalog);
    assert.equal(pkg.scene,'res://combined_arms/demo.tscn');
    assert.deepEqual(pkg.userArgs,dev.sessionOptions);
    assert.equal(pkg.endpoint,dev.endpoint);
    assert.equal(pkg.map,'sunscar-convoy');
    assert.equal(pkg.mode,'combined-arms');
  }
  assert.equal(options(guest,catalog).endpoint,endpoint);
  assert.equal(options(host,catalog).endpoint,null);
  assert.deepEqual(options(guest,catalog).userArgs,['--map=sunscar-convoy','--mode=combined-arms','--join-room=duo']);
});

test('Combined Arms guest rejects host settings and other routes reject its host/guest controls', () => {
  const cases = [
    ['--experience=combined-arms','--join-room=duo'],
    ['--experience=combined-arms',`--endpoint=${endpoint}`,'--join-room=duo','--bots=0'],
    ['--experience=combined-arms',`--endpoint=${endpoint}`,'--join-room=duo','--wait-for-players=2'],
    ['--experience=combined-arms','--wait-for-players=0'],
    ['--experience=combined-arms','--wait-for-players=9'],
    ['--experience=combined-arms','--bots=17'],
    ['--experience=assault',`--endpoint=${endpoint}`],
    ['--experience=zones','--wait-for-players=2'],
  ];
  for (const argv of cases) {
    assert.throws(() => options(argv,catalog), Error, argv.join(' '));
    assert.throws(() => launchOptions(argv,catalog), Error, argv.join(' '));
  }
});
