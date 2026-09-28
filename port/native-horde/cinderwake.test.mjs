import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {WebSocket} from 'ws';
import {once} from 'node:events';
import {Match} from '../../game/core.mjs';
import {HORDE_MAPS,createAuthority,createHordeMatch,validateConfig} from './authority.mjs';
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
test('ordinary local socket publishes matching source-stage snapshot and immutable map contract',async()=>{
  const authority=createAuthority();
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  const ws=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
  const frames=[];
  ws.on('message',bytes=>frames.push(JSON.parse(String(bytes))));
  const until=async predicate=>{
    for(let attempt=0;attempt<150;attempt++){
      const value=frames.find(predicate);
      if(value)return value;
      await new Promise(resolve=>setTimeout(resolve,20));
    }
    throw Error('Cinderwake source socket frame timed out');
  };
  try{
    await once(ws,'open');
    ws.send(JSON.stringify({type:'create',v:3,character:'chatgpt',harness:'openclaw'}));
    await until(frame=>frame.type==='lobby');
    ws.send(JSON.stringify({type:'host',mapId:'cinderwake-drydock',config:{mode:'horde',fragLimit:10}}));
    await until(frame=>frame.type==='lobby'&&frame.mapId==='cinderwake-drydock');
    ws.send(JSON.stringify({type:'start'}));
    const started=await until(frame=>frame.type==='start'&&frame.mapId==='cinderwake-drydock');
    const snapshot=await until(frame=>frame.type==='snapshot'&&frame.inputEpoch===started.inputEpoch);
    const recipe=readCinderwake();
    const contract={version:1,geometryHash:recipe.geometryHash,planHash:recipe.planHash};
    assert.deepEqual(started.hordeMapContract,contract);
    assert.deepEqual(snapshot.hordeMapContract,contract);
    assert.equal(snapshot.state.mapId,'cinderwake-drydock');
    assert.deepEqual(snapshot.state.singleplayer.stage.gateMask,0);
    assert.equal(snapshot.state.singleplayer.stage.geometryRevision,0);
    assert.equal(snapshot.state.singleplayer.lives,3);
    assert.equal(snapshot.state.actors.filter(actor=>actor.isNpc===true).length,0);
  }finally{
    ws.close();
    await authority.close();
  }
});
