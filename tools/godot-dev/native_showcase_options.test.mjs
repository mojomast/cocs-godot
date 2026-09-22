import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {launchOptions, EXPERIENCES, NATIVE_EXPERIENCES, HELP} from './launch_options.mjs';
import {nativeScenes, rejectedOptions} from '../../port/native-graphics-launchers/fixtures.mjs';

test('source graphics routes are native-only, headless only on request, outside the map catalog', () => {
  assert.equal(Object.keys(EXPERIENCES).length,10);
  assert.deepEqual(Object.keys(NATIVE_EXPERIENCES),Object.keys(nativeScenes));
  const catalog = JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));
  assert.equal(catalog.maps.length,9);
  for (const [experience,scene] of Object.entries(nativeScenes)) {
    assert.ok(!catalog.maps.some(map=>map.id===experience));
    assert.ok(!Object.hasOwn(EXPERIENCES,experience));
    assert.deepEqual(launchOptions([`--experience=${experience}`],null),{
      experience,nativeOnly:true,endpoint:null,smoke:null,sessionOptions:[],args:['--path','godot',scene],
    });
    assert.deepEqual(launchOptions(['--smoke','--experience',experience],{maps:[]}),{
      experience,nativeOnly:true,endpoint:null,smoke:'--smoke',sessionOptions:['--smoke'],
      args:['--headless','--audio-driver','Dummy','--path','godot',scene],
    });
    for (const args of rejectedOptions) assert.throws(()=>launchOptions([`--experience=${experience}`,...args],catalog),Error,args.join(' '));
    assert.ok(HELP.includes(`--experience=${experience}`));
  }
  for (const experience of ['combat','horde','lobby','sports']) assert.throws(()=>launchOptions([`--experience=${experience}`,'--smoke'],catalog));
  for (const experience of ['__proto__','constructor','unknown','Showcase']) assert.throws(()=>launchOptions([`--experience=${experience}`],catalog));
  assert.match(HELP,/no Node authority/);
  assert.match(HELP,/not source map catalog choices/);
});
