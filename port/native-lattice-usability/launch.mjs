// Ordinary public server, default rate. Passive recipient/input audit only.
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, appendFileSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {createHash} from 'node:crypto';

const [project, out, map, mode, size] = process.argv.slice(2);
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
verifySource(lock);
const bin = process.env.GODOT_BIN;
if (execFileSync(bin, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Wrong Godot');
if (process.env.PORT !== '0') throw Error('PORT=0 required');
const game = createGameServer({historyPath:null, progressionPath:null});
let child, port, count = 0;
const record = value => {
  if (++count > 10000) throw Error('Audit bound exceeded');
  appendFileSync(join(out,'wire.jsonl'), JSON.stringify({time:Date.now(), ...value})+'\n');
};
game.wss.on('connection', ws => {
  let peer, actor, lastInput;
  const send = ws.send;
  ws.send = function(data, ...args) {
    const f = JSON.parse(String(data));
    if (f.type === 'welcome') peer = f.peerId;
    if (f.type === 'lobby') actor = f.players.find(p => p.peerId === peer)?.actorId;
    if (f.type === 'start') record(f);
    if (f.type === 'snapshot') record({type:'recipient',seq:f.seq,ack:f.acks?.[actor],own:f.state.actors.find(a => a.id === actor),nodes:f.state.cocs?.nodes,cards:f.state.cocs?.cards});
    return send.call(this, data, ...args);
  };
  ws.prependListener('message', data => {
    const f = JSON.parse(String(data));
    if (f.type === 'input') {
      const signature = JSON.stringify(f.input);
      if (signature !== lastInput || f.seq % 60 === 0) record(f);
      lastInput = signature;
    } else if (['order','economy'].includes(f.type)) record(f);
  });
});
const stop = () => { if (child?.exitCode === null) child.kill('SIGTERM'); };
process.once('SIGINT', stop); process.once('SIGTERM', stop);
try {
  await new Promise((done,fail) => { game.server.once('error',fail); game.server.listen(0,'127.0.0.1',done); });
  port = game.server.address().port;
  const args = ['--audio-driver','Dummy','--path',project,'--resolution',size,'--script','res://tests/lattice/usability_observe.gd','--',`--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,`--mode=${mode}`,'--native-trace'];
  const files = ['world_demo.gd','world_hud.gd','world_guidance.gd','world_commands.gd'];
  const hash = path => createHash('sha256').update(readFileSync(path)).digest('hex');
  const manifest = {base:'e1defc00e37c0b560ff9fa55f1e3c4ad9f853b21',source:lock.source_commit,godot:lock.godot_version,command:[bin,...args],port,display:process.env.DISPLAY,serverOptions:{historyPath:null,progressionPath:null},normalRate:true,hashes:Object.fromEntries(files.map(f => [`godot/lattice/${f}`,hash(join(project,'lattice',f))])),observer:hash(join(project,'tests/lattice/usability_observe.gd')),sourceHashes:Object.fromEntries(['game/cocs.mjs','game/cocs-intel.mjs','server/room.mjs'].map(f => [f,hash(f)]))};
  child = spawn(bin,args,{env:process.env,stdio:'inherit'});
  manifest.nativePid = child.pid;
  writeFileSync(join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  process.exitCode = await new Promise((done,fail) => { child.once('error',fail); child.once('exit',code => done(code ?? 0)); });
} finally {
  stop(); await game.close();
  writeFileSync(join(out,'authority-cleanup.json'),JSON.stringify({port,nativeExited:child?.exitCode !== null || child?.signalCode !== null,sourceVerified:true})+'\n');
}
