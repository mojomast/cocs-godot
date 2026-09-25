import test from 'node:test';
import assert from 'node:assert/strict';
import {validateConfig,MAPS,createAuthority} from './authority.mjs';
import {validate} from './validate.mjs';
import {WebSocket} from 'ws';
import {once} from 'node:events';
for(const mapId of MAPS)test(`legal one-wave source preset ${mapId}`,()=>{const c=validateConfig({mapId,config:{mode:'horde',fragLimit:1}});assert.equal(c.fragLimit,1);assert.equal(c.botCount,0);assert.equal(c.mode,'horde');});
test('invalid targets rejected rather than silently clamped',()=>{for(const fragLimit of [0,31,1.2,'1',null])assert.throws(()=>validateConfig({mapId:MAPS[0],config:{mode:'horde',fragLimit}}));});
test('foreign maps and mode rejected',()=>{assert.throws(()=>validateConfig({mapId:'exchange',config:{mode:'horde'}}));assert.throws(()=>validateConfig({mapId:MAPS[0],config:{mode:'campaign'}}));});
test('default is ten waves',()=>assert.equal(validateConfig({mapId:MAPS[0],config:{mode:'horde'}}).fragLimit,10));
test('missing evidence cannot pass',()=>assert.throws(()=>validate([],'')));
test('malformed native records rejected',()=>assert.throws(()=>validate([],'HORDE_NATIVE nope')));
// Synthetic fixtures below are parser regressions, NOT live acceptance.
function fixture(){const singleplayer={wave:1,waveTarget:1,lives:3,enemiesAlive:1,enemiesTotal:1,phase:'wave',score:0,winner:null};const actors=[{id:0,x:1,y:0,z:2,health:100,dead:0}];const wire=[],rows=[];for(let seq=1;seq<=11;seq++){wire.push({direction:'out',round:1,frame:{type:'snapshot',seq,state:{singleplayer,actors}}});rows.push({round:1,seq,actor_id:0,ack:1,model:singleplayer,hud:'WAVE 1 / 1 LIVES 3',rendered:{0:{position:[1,.9,2],visible:false}}});}return{wire,rows};}
const text=rows=>rows.map(r=>'HORDE_NATIVE '+JSON.stringify(r)).join('\n')+'\nHORDE_DONE {"ok":true}';
test('synthetic correlation baseline',()=>{const f=fixture();assert.equal(validate(f.wire,text(f.rows)).correlated,11);});
test('mismatched actor rejected',()=>{const f=fixture();f.rows[0].actor_id=1;assert.throws(()=>validate(f.wire,text(f.rows)));});
test('wrong rendered position rejected',()=>{const f=fixture();f.rows[0].rendered[0].position[0]=8;assert.throws(()=>validate(f.wire,text(f.rows)));});
test('snapshot gaps rejected',()=>{const f=fixture();f.wire.shift();assert.throws(()=>validate(f.wire,text(f.rows)));});
test('ACK/receipt cannot stand in for victory',()=>{const f=fixture();f.wire.push({direction:'in',frame:{type:'input',input:{fire:true}}});assert.throws(()=>validate(f.wire,text(f.rows),'combat'));});
test('owned local server rejects browser origins and closes listeners',async()=>{const a=createAuthority();await new Promise(r=>a.server.listen(0,'127.0.0.1',r));const ws=new WebSocket(`ws://127.0.0.1:${a.server.address().port}`,{origin:'https://example.com'});ws.on('error',()=>{});await new Promise(r=>ws.once('close',r));await a.close();assert.equal(a.server.listening,false);assert.equal(a.wss.clients.size,0);});
test('local Horde create echoes selected loadout and source spawns it',async()=>{
  const authority=createAuthority();
  await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
  const ws=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
  const frames=[];
  ws.on('message',bytes=>frames.push(JSON.parse(String(bytes))));
  const until=async(predicate)=>{
    for(let i=0;i<100;i++){
      const found=frames.find(predicate);
      if(found)return found;
      await new Promise(r=>setTimeout(r,20));
    }
    throw Error('Horde live loadout frame timed out');
  };
  try{
    await once(ws,'open');
    ws.send(JSON.stringify({type:'create',v:3,character:'claude',harness:'claudecode'}));
    const lobby=await until(f=>f.type==='lobby');
    assert.equal(lobby.players[0].character,'claude');
    assert.equal(lobby.players[0].harness,'claudecode');
    ws.send(JSON.stringify({type:'host',mapId:'nacre-engine',config:{mode:'horde',fragLimit:1}}));
    await until(f=>f.type==='lobby'&&f.config);
    ws.send(JSON.stringify({type:'start'}));
    const start=await until(f=>f.type==='start');
    const snapshot=await until(f=>f.type==='snapshot'&&f.inputEpoch===start.inputEpoch);
    assert.equal(snapshot.state.actors[0].character,'claude');
    assert.equal(snapshot.state.actors[0].harness,'claudecode');
  }finally{
    ws.close();
    await authority.close();
  }
});
