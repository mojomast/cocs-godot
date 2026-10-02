import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options, EXPERIENCES, NATIVE_EXPERIENCES, HELP} from './options.mjs';
import {nativeScenes, rejectedOptions} from '../../port/native-graphics-launchers/fixtures.mjs';

test('package graphics routes are independent of the source routes and nine map identities', () => {
  assert.deepEqual(Object.keys(EXPERIENCES).sort(), ['combat','lobby','arms-race','horde','zones','assault','combined-arms','sports','objectives','lattice','lattice-world','campaign','multiplayer-worlds','mode-expansion'].sort());
  assert.deepEqual(Object.keys(NATIVE_EXPERIENCES),Object.keys(nativeScenes));
  const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));
  assert.equal(catalog.maps.length,9);
  const campaign = options(['--experience=campaign','--smoke'],catalog);
  assert.equal(campaign.campaign,true);
  assert.equal(campaign.nativeOnly,undefined);
  assert.equal(campaign.endpoint,null);
  assert.equal(campaign.scene,'res://campaign/demo.tscn');
  assert.ok(!catalog.maps.some(map=>map.id===campaign.map));
  assert.ok(!Object.hasOwn(NATIVE_EXPERIENCES,'campaign'));
  for (const [experience,scene] of Object.entries(nativeScenes)) {
    assert.ok(!catalog.maps.some(map=>map.id===experience));
    assert.ok(!Object.hasOwn(EXPERIENCES,experience));
    assert.deepEqual(options([`--experience=${experience}`],null),{experience,scene,nativeOnly:true,endpoint:null,userArgs:[]});
    assert.deepEqual(options(['--experience',experience,'--smoke'],{maps:[]}).userArgs,['--smoke']);
    assert.ok(HELP.includes(`--experience=${experience}`));
    for (const args of rejectedOptions) assert.throws(()=>options([`--experience=${experience}`,...args],catalog),Error,args.join(' '));
  }
  for (const experience of ['__proto__','constructor','unknown','Showcase']) assert.throws(()=>options([`--experience=${experience}`],catalog));
  assert.match(HELP,/no Node authority/);
  assert.match(HELP,/not source map catalog choices/);
});

// Batch forwarding/exit behavior is exercised by verify_windows.mjs using the
// real Graphics Showcase.cmd. The no-argument path now opens a five-route menu;
// matching its source layout with a regular expression is not execution proof.
