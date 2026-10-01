import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {options} from './options.mjs';
import {launchOptions} from '../godot-dev/launch_options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../../port/contracts/map-selection.json',import.meta.url)));
const parse=argv=>[options(argv,catalog),launchOptions(argv,catalog)];

test('world routes select independent scene families and preserve exact map/mode',()=>{
 for(const [map,mode,scene] of [
  ['switchyard-ward','ctf','demo'],['breakwater-exchange','payload','demo'],
  ['sirocco-circuit','puma-race','sports_demo'],['copper-bowl','puma-soccer','sports_demo'],
  ['tern-archipelago','cocs-coop','lattice_demo']]){
  const [pack,dev]=parse([`--experience=multiplayer-worlds`,`--map=${map}`,`--mode=${mode}`]);
  assert.equal(pack.scene,`res://multiplayer_worlds/${scene}.tscn`);
  assert.ok(dev.args.includes(pack.scene));
  assert.equal(pack.map,dev.map);
  assert.equal(pack.mode,dev.mode);
  assert.equal(pack.world,true);assert.equal(dev.world,true);
 }
});

test('sports targets are selected by mode, not the old stadium map ID',()=>{
 for(const [map,mode,max] of [['sirocco-circuit','puma-race',10],['copper-bowl','puma-soccer',15]]){
  const args=['--experience=multiplayer-worlds',`--map=${map}`,`--mode=${mode}`];
  const [pack,dev]=parse([...args,`--round-target=${max}`,'--time-limit=180']);
  assert.ok(pack.userArgs.includes(`--round-target=${max}`));
  assert.ok(dev.sessionOptions.includes('--time-limit=180'));
  for(const invalid of [0,max+1])for(const parser of [options,launchOptions])assert.throws(()=>parser([...args,`--round-target=${invalid}`],catalog));
 }
 for(const parser of [options,launchOptions])assert.throws(()=>parser(['--experience=multiplayer-worlds','--map=thermal-divide','--round-target=3'],catalog));
});

test('external guest consumes a room without host settings; Tern permits source bot cap',()=>{
 const args=['--experience=multiplayer-worlds','--map=tern-archipelago','--mode=cocs','--endpoint=ws://127.0.0.1:4821','--join-room=ROOM'];
 const [pack,dev]=parse(args);
 assert.equal(pack.endpoint,dev.endpoint);
 assert.deepEqual(pack.userArgs,['--map=tern-archipelago','--mode=cocs','--join-room=ROOM']);
 assert.deepEqual(dev.sessionOptions,pack.userArgs);
 for(const parser of [options,launchOptions]){
  assert.doesNotThrow(()=>parser(['--experience=multiplayer-worlds','--map=tern-archipelago','--bots=16'],catalog));
  assert.throws(()=>parser([...args,'--bots=2'],catalog));
  assert.throws(()=>parser(['--experience=multiplayer-worlds','--map=sirocco-circuit','--mode=puma-soccer'],catalog));
 }
});
