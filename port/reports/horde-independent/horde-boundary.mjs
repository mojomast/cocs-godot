// Black-box loopback probes; no Match replacement, state edits or timer patches.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';
import {WebSocket} from 'ws';
import {createAuthority, validateConfig, MAPS} from '../../native-horde/authority.mjs';
const out = 'port/reports/horde-independent';
const delay = ms => new Promise(r => setTimeout(r, ms));
const frames = [];
const a = createAuthority({observe:r => frames.push({...r, wall:performance.now()})});
await new Promise(r => a.server.listen(0, '127.0.0.1', r));
const url = `ws://127.0.0.1:${a.server.address().port}`;
let ws;
async function waitFor(predicate, ms=12000) {
 const end = performance.now()+ms;
 while (performance.now()<end) {const found=frames.find(predicate);if(found)return found;await delay(10);}
 throw Error('bounded probe timeout');
}
async function connect() {const s=new WebSocket(url);await new Promise((r,j)=>{s.once('open',r);s.once('error',j);});return s;}
const send = f => ws.send(JSON.stringify(f));
const report = {scope:'black-box transport, no native/human input or full-run acceptance', findings:[]};
try {
 ws = await connect();
 if (process.argv.includes('--oversize-child')) {
  ws.send('x'.repeat(16385));
  await delay(1000);
 } else {
  const second=await connect();
  const secondClose=await new Promise(r=>second.once('close',(code)=>r(code)));
  assert.equal(secondClose,1008);
  send({type:'create',v:3});
  send({type:'host',mapId:MAPS[0],config:{mode:'horde'}});
  send({type:'start'});
  const first=await waitFor(r=>r.frame.type==='snapshot');
  assert.equal(first.frame.state.singleplayer.waveTarget,10);
  assert.equal(first.frame.state.actors.length,1);
  assert.equal(first.frame.state.actors[0].id,0);
  assert.equal(first.frame.state.config.timeLimit,900);
  await delay(450); // expire ordinary initial shot wait
  send({type:'input',seq:1,input:{fire:true,yaw:0.1}});
  send({type:'input',seq:2,input:{fire:false,yaw:0.2}});
  const tap=await waitFor(r=>r.frame.type==='snapshot'&&r.frame.acks[0]===2);
  report.findings.push({name:'same-turn fire press/release coalescing',ack:2,shots:tap.frame.state.actors[0].shots,yaw:tap.frame.state.actors[0].yaw});
  assert.equal(tap.frame.state.actors[0].shots,0,'expected delivery defect: fire tap overwritten');
  send({type:'input',seq:3,input:{fire:true,yaw:0.3}});
  const held=await waitFor(r=>r.frame.type==='snapshot'&&r.frame.acks[0]===3&&r.frame.state.actors[0].shots>0);
  await delay(550);
  const after=frames.filter(r=>r.frame.type==='snapshot').at(-1);
  await delay(350);
  const stale=frames.filter(r=>r.frame.type==='snapshot').at(-1);
  assert.equal(stale.frame.state.actors[0].shots,after.frame.state.actors[0].shots);
  report.findings.push({name:'held fire applied then 250ms expiry stops firing',firstShots:held.frame.state.actors[0].shots,settledShots:stale.frame.state.actors[0].shots,ack:stale.frame.acks[0]});
  send({type:'input',seq:2,input:{fire:true,yaw:0.9}});
  send({type:'input',seq:0,input:{fire:true,yaw:0.9}});
  await delay(150);
  const ignored=frames.filter(r=>r.frame.type==='snapshot').at(-1);
  assert.equal(ignored.frame.acks[0],3);
  assert.equal(ignored.frame.state.actors[0].yaw,0.3);
  const wave=await waitFor(r=>r.frame.type==='snapshot'&&r.frame.state.singleplayer.wave===1);
  const events=frames.filter(r=>r.frame.type==='events').flatMap(r=>r.frame.items);
  assert(events.some(e=>e.type==='horde-wave'));
  assert(!events.some(e=>e.type==='horde-modifier'),'expected delivery defect: string event ID dropped');
  report.findings.push({name:'wave modifier snapshot present but source event missing',modifier:wave.frame.state.singleplayer.waveModifier,eventTypes:[...new Set(events.map(e=>e.type))]});
  report.clock={sourceSeconds:wave.frame.state.time-first.frame.state.time,wallSeconds:(wave.wall-first.wall)/1000};
  report.clock.ratio=report.clock.sourceSeconds/report.clock.wallSeconds;
  const closed=new Promise(r=>ws.once('close',r));ws.close();await closed;
  ws=await connect();
  send({type:'create',v:3});send({type:'host',mapId:MAPS[0],config:{mode:'horde',fragLimit:1}});send({type:'start'});
  const restart=await waitFor(r=>r.round===2&&r.frame.type==='snapshot');
  assert.equal(restart.frame.seq,1);assert.equal(restart.frame.acks[0],0);
  assert.equal(restart.frame.state.singleplayer.wave,0);assert.equal(restart.frame.state.singleplayer.lives,3);
  report.reconnect={round:restart.round,seq:restart.frame.seq,ack:restart.frame.acks[0],waveTarget:restart.frame.state.singleplayer.waveTarget};
  report.secondClientClose=secondClose;
  report.defaultConfig=validateConfig({mapId:MAPS[0],config:{mode:'horde'}});
 }
} finally {
 ws?.terminate();await a.close();
 report.cleanup={serverClosed:!a.server.listening,sockets:a.wss.clients.size};
}
if(!process.argv.includes('--oversize-child')) {
 const child=spawnSync(process.execPath,[process.argv[1],'--oversize-child'],{encoding:'utf8',timeout:5000});
 writeFileSync(`${out}/oversize-child.log`,child.stdout+child.stderr);
 report.oversize={exit:child.status,signal:child.signal,unhandledError:/Unhandled 'error' event/.test(child.stderr)};
 assert.equal(report.oversize.unhandledError,true);
 writeFileSync(`${out}/boundary.json`,JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
}
