// Run only after the parent grants the exclusive engine slot.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createGameServer} from '../../../server/game-server.mjs';
import {operators,journey,plans} from './source.mjs';
assert.equal(process.env.PLAYER_GAMEPLAY_ENGINE_GRANTED,'1','parent exclusive engine grant required');
assert.ok(process.env.GODOT_BIN,'pinned Godot 4.5.2 required');
const out=resolve(process.env.EVIDENCE_DIR??'/home/mojo/.tmp-on-disk/cocs-pass-two-gameplay-evidence-20261002/native');
mkdirSync(out,{recursive:true});
for(const operator of (process.env.OPERATORS?.split(',')??operators)) {
  const source=journey(operator);
  const game=createGameServer({random:()=>.5,historyPath:null,progressionPath:null});
  const wire=[],snapshots=[];
  game.wss.on('connection',socket=>{
    socket.on('message',raw=>{const f=JSON.parse(raw);if(f.type==='input')wire.push(f);});
    const send=socket.send;
    socket.send=function(raw,...args){const f=JSON.parse(raw);if(f.type==='snapshot')snapshots.push(f);return send.call(this,raw,...args);};
  });
  await new Promise(r=>game.server.listen(0,'127.0.0.1',r));
  try {
    const args=['-a',process.env.GODOT_BIN,'--audio-driver','Dummy','--path',resolve('godot'),'--script','res://tests/player_gameplay/second_pass_live.gd','--','--bots=0',`--operator=${operator}`,`--harness=${plans[operator].harness}`,`--endpoint=ws://127.0.0.1:${game.server.address().port}`,`--evidence=${out}`];
    const child=spawn('xvfb-run',args,{detached:true,env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1'},stdio:['ignore','pipe','pipe']});
    let log='';child.stdout.on('data',x=>log+=x);child.stderr.on('data',x=>log+=x);
    const timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch(e){if(e.code!=='ESRCH')throw e;}},50000);
    const code=await new Promise((r,j)=>{child.once('error',j);child.once('close',r);});clearTimeout(timer);
    writeFileSync(resolve(out,operator+'.log'),log);
    writeFileSync(resolve(out,operator+'-wire.json'),JSON.stringify(wire));
    writeFileSync(resolve(out,operator+'-snapshots.json'),JSON.stringify(snapshots));
    assert.equal(code,0,operator+' native process');assert.doesNotMatch(log,/SCRIPT ERROR|ERROR:/);
    const native=JSON.parse(readFileSync(resolve(out,operator+'-native.json')));
    const poses=native.poses;
    assert.ok(wire.some(f=>f.input.power),'native Q reached authority');
    assert.ok(poses.some(a=>a.y>source.start.y+.1),'native movement has source vertical response');
    if(operator==='chatgpt') {
      assert.ok(poses.some(a=>a.movement?.grappleLanding),'native source ledge resolved');
      assert.ok(poses.at(-1).grounded&&Math.abs(poses.at(-1).y-source.end.y)<.15,'native mantle roof agrees with independent source oracle');
      assert.ok(native.max_cables>0,'native active grapple cable');
    }
    console.log('SECOND_PASS_NATIVE_OK',operator);
  } finally {
    for(const socket of game.wss.clients)socket.terminate();
    await game.close();
  }
}
