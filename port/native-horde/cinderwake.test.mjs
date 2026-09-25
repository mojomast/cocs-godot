import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match} from '../../game/core.mjs';
import {HORDE_MAPS,createHordeMatch,validateConfig} from './authority.mjs';
import {readCinderwake} from './cinderwake-schema.mjs';
import {options} from '../../tools/godot-package/options.mjs';
import {launchOptions} from '../../tools/godot-dev/launch_options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../contracts/map-selection.json',import.meta.url)));
test('Cinderwake literal launch route selects its new scene, bounded waves and local authority',()=>{
 assert(HORDE_MAPS.includes('cinderwake-drydock'));
 for(const waves of [1,10,30]){
  const args=['--experience=horde','--map=cinderwake-drydock',`--waves=${waves}`];
  assert.equal(options(args,catalog).scene,'res://horde_maps/demo.tscn');
  assert(launchOptions(args,catalog).args.includes('res://horde_maps/demo.tscn'));
 }
 for(const map of ['../cinderwake-drydock','cinderwake-drydock.json','Cinderwake-Drydock'])assert.throws(()=>options(['--experience=horde',`--map=${map}`],catalog));
 assert.throws(()=>options(['--experience=native-dm','--map=cinderwake-drydock'],catalog));
});
test('literal recipe validates and source intake is mandatory, never a static-play fallback',()=>{
 const data=readCinderwake();assert.equal(data.arena.hordeCaches,undefined);
 const config=validateConfig({mapId:'cinderwake-drydock',config:{mode:'horde',fragLimit:10}});
 const construct=()=>createHordeMatch({mapId:'cinderwake-drydock',config,random:()=>.5});
 if(typeof Match.prototype.applyHordeGateMask!=='function')assert.throws(construct,/approved source Horde-stage intake/);
 else {const m=construct();assert.equal(m.modeState.stage.stageId,'B');assert.equal(m.modeState.stage.gateMask,0);assert.equal(m.modeState.lives,3);}
});
