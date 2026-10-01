import test from 'node:test';
import assert from 'node:assert/strict';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {createAuthority,createHordeMatch,HORDE_MAPS} from '../native-horde/authority.mjs';
import {attachSoloCheats} from './solo_cheats.mjs';

const config={mode:'horde',botCount:0,difficulty:'easy',fragLimit:10,timeLimit:900};
test('six Horde maps retain normal simulation with cheats off and support controlled flight', () => {
  for(const mapId of HORDE_MAPS) {
    const make=()=>createHordeMatch({mapId,config,random:()=>.5});
    const baseline=make(), match=make(), cheats=attachSoloCheats(match);
    for(let i=0;i<8;i++) {
      baseline.step(1/60,{inputs:{0:{}}});match.step(1/60,{inputs:{0:{}}});
      const {soloCheats,...state}=match.snapshot();
      assert.deepEqual(state,baseline.snapshot(),mapId);
      assert.equal(soloCheats.available,true);
    }
    const player=match.actors[0], y=player.y;
    cheats.apply({action:'invulnerable',enabled:true});
    cheats.apply({action:'weapons'});
    assert.ok(player.ammo.every(value=>value>0),mapId);
    cheats.apply({action:'flight',enabled:true});
    for(let i=0;i<20;i++)match.step(1/60,{inputs:{0:{jump:true}}});
    assert.ok(player.y>y+3,mapId);
    assert.ok(Number.isFinite(player.x)&&Number.isFinite(player.z),mapId);
    cheats.apply({action:'clear'});
    assert.equal(player.grounded,true,mapId);
    assert.ok(player.health>0,mapId);
  }
});

test('ordinary Blackwater launch accepts in-game cheats without an environment flag', {timeout:12000}, async () => {
  const authority=createAuthority({debug:false});
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  const socket=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
  const frames=[];socket.on('message',bytes=>frames.push(JSON.parse(String(bytes))));
  const wait=async predicate=>{for(let i=0;i<300;i++){const item=frames.findLast(predicate);if(item)return item;await new Promise(resolve=>setTimeout(resolve,10));}throw Error('Horde cheat frame timeout');};
  try {
    await once(socket,'open');
    const send=frame=>socket.send(JSON.stringify(frame));
    send({type:'create',v:3});await wait(f=>f.type==='lobby');
    send({type:'host',mapId:'blackwater-reclamation',config});await wait(f=>f.type==='lobby'&&f.config);
    send({type:'start'});
    const start=await wait(f=>f.type==='snapshot');
    assert.equal(start.state.soloCheats.available,true);
    send({type:'solo-cheat',v:1,inputEpoch:start.inputEpoch,action:'pause',enabled:true});
    const paused=await wait(f=>f.state?.soloCheats?.paused===true);
    const later=await wait(f=>f.type==='snapshot'&&f.seq>paused.seq+4);
    assert.equal(later.state.time,paused.state.time);
    assert.ok(later.inputEpoch>start.inputEpoch);
    send({type:'solo-cheat',v:1,inputEpoch:later.inputEpoch,action:'weapons'});
    const granted=await wait(f=>f.state?.soloCheats?.notice==='All ten weapons granted');
    assert.equal(granted.state.actors[0].ammo.length,10);
    assert.ok(granted.state.actors[0].ammo.every(value=>value==='∞'||value>0));
    send({type:'solo-cheat',v:1,inputEpoch:granted.inputEpoch,action:'pause',enabled:false});
    const resumed=await wait(f=>f.state?.soloCheats?.paused===false&&f.inputEpoch>granted.inputEpoch);
    assert.equal(resumed.state.soloCheats.available,true);
    assert.ok(!frames.some(f=>f.type==='error'));
  } finally {
    if(socket.readyState===WebSocket.OPEN){socket.close();await once(socket,'close');}
    await authority.close();
  }
});
