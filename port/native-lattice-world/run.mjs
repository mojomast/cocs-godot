// Owned normal-rate authority + optional native world scene. Passive wire audit.
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, appendFileSync, mkdirSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';

const options = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const map = options.map ?? 'asterion-relay', mode = options.mode ?? 'cocs';
if (!['asterion-relay','monsoon-foundry'].includes(map) || !['cocs','cocs-coop'].includes(mode)) throw Error('World map/mode not allowlisted');
const play = 'play' in options;
const out = resolve(options.output ?? `port/native-lattice-world/evidence/${Date.now()}-${map}-${mode}`);
mkdirSync(out, {recursive:true});
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
verifySource(lock);
const bin = process.env.GODOT_BIN;
if (!bin || execFileSync(bin, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Pinned GODOT_BIN required');
const runtime = mkdtempSync('/tmp/opencode/lattice-world-runtime-');
const env = {...process.env};
for (const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
 env[key] = join(runtime,key); mkdirSync(env[key]);
}
const records = [];
const record = value => {
 if (records.length >= 10000) return;
 records.push(value); appendFileSync(join(out,'wire.jsonl'), JSON.stringify(value)+'\n');
 if (records.length === 10000) appendFileSync(join(out,'wire.jsonl'),JSON.stringify({type:'audit-limit',complete:false})+'\n');
};
const pick = (value, keys) => Object.fromEntries(keys.filter(key => value?.[key] !== undefined).map(key => [key,value[key]]));
const game = createGameServer({historyPath:null,progressionPath:null});
game.wss.on('connection', ws => {
 let peer, actor, previousInput = '';
 const send = ws.send;
 ws.send = function(data, ...args) {
  const frame = JSON.parse(String(data));
  if (frame.type === 'welcome') { peer = frame.peerId; record({type:'welcome',peer}); }
  if (frame.type === 'lobby') {
   actor = frame.players.find(p => p.peerId === peer)?.actorId;
   record({type:'lobby',peer,actor,map:frame.mapId,config:frame.config});
  }
  if (frame.type === 'start') record({type:'start',peer,actor,map:frame.mapId,config:frame.config,round:frame.roundRevision});
  if (frame.type === 'snapshot') {
   const own = frame.state.actors.find(a => a.id === actor), board = frame.state.cocs;
   record({type:'recipient',peer,actor,seq:frame.seq,ack:frame.acks?.[actor],round:board?.roundRevision,
    own:pick(own,['id','x','y','z','yaw','pitch','eyeHeight','health','team','req']),
    actors:frame.state.actors.map(a => pick(a,['id','x','y','z','health','dead'])),
    fluxKeys:Object.keys(board?.flux ?? {}),flux:board?.flux?.[own?.team],
    nodes:board?.nodes.map(n => pick(n,['id','x','y','z','r','owner','progress','live','contested']))});
  }
  if (frame.type === 'events') for (const item of frame.items ?? []) {
   if (item.type === 'cocs-capture') record({type:'capture',peer,actor,...pick(item,['node','team','participants','orderCompleted'])});
  }
  return send.call(this,data,...args);
 };
 ws.prependListener('message', data => {
  const frame = JSON.parse(String(data));
  if (frame.type === 'input') {
   const signature = JSON.stringify(frame.input);
   if (signature !== previousInput || frame.seq % 60 === 0) record({type:'input',peer,actor,seq:frame.seq,input:frame.input});
   previousInput = signature;
  } else if (['order','economy'].includes(frame.type)) record({type:'command',peer,actor,kind:frame.type});
 });
});
let child, timer, native = '', port, exit = 1;
const stop = () => { if (child?.exitCode === null) child.kill('SIGTERM'); };
process.once('SIGINT',stop); process.once('SIGTERM',stop);
try {
 await new Promise((done,fail) => {game.server.once('error',fail); game.server.listen(0,'127.0.0.1',done);});
 port = game.server.address().port;
 if (!(await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)})).ok) throw Error('Authority readiness failed');
 const args = ['--audio-driver','Dummy','--path','godot','--resolution',options.size ?? '1280x800',
  ...(!play ? ['--script','res://tests/lattice/world_walk.gd'] : []),'res://lattice/world_demo.tscn','--',
  `--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,`--mode=${mode}`,`--world-output=${out}`];
 const files = ['server/room.mjs','game/core.mjs','game/protocol.mjs','game/cocs.mjs','game/cocs-intel.mjs',
  'godot/net/client.gd','godot/world/session.gd','godot/world/viewer.gd','godot/world/presentation.gd',
  'godot/lattice/transport.gd','godot/lattice/world_demo.gd','godot/lattice/world_transport.gd','godot/lattice/world_hud.gd',
  'godot/tests/lattice/world_walk.gd','port/native-lattice-world/run.mjs'];
 writeFileSync(join(out,'manifest.json'),JSON.stringify({base:'642c615',source:lock.source_commit,godot:lock.godot_version,
  options,command:[bin,...args],port,display:env.DISPLAY,serverOptions:{historyPath:null,progressionPath:null},
  simulation:'default tickDt 1/60, tickMs 1000/60, snapshotHz unchanged',
  hashes:Object.fromEntries(files.map(file => [file,createHash('sha256').update(readFileSync(file)).digest('hex')]))},null,2)+'\n');
 console.log('LATTICE_WORLD',JSON.stringify({endpoint:`ws://127.0.0.1:${port}`,map,mode,out}));
 child = spawn(bin,args,{env,stdio:['ignore','pipe','pipe']});
 for (const stream of [child.stdout,child.stderr]) stream.on('data', data => {native += data; appendFileSync(join(out,'native.log'),data);});
 if (!play) timer = setTimeout(stop,90000);
 exit = await new Promise((done,fail) => {child.once('error',fail); child.once('exit',code => done(code ?? 1));});
 if (!play) {
  const observations = native.split('\n').filter(line => line.startsWith('WORLD_NATIVE ')).map(line => JSON.parse(line.slice(13)));
  const poses = observations.filter(r => r.event === 'pose');
  const result = observations.find(r => r.event === 'result');
  const recipients = new Map(records.filter(r => r.type === 'recipient').map(r => [r.seq,r]));
  const close = (a,b) => Math.abs(a-b) < 0.0001;
  const checks = {
   native:exit === 0 && !!result && result.failures === 0 && !/SCRIPT ERROR|ERROR:/.test(native),
   movement:result?.maxDisplacement > 5,
   exactCamera:poses.length > 5 && poses.every(p => {
    const wire = recipients.get(p.seq)?.own;
    return wire && p.actor === wire.id && close(p.camera[0],wire.x) && close(p.camera[1],wire.y+(wire.eyeHeight ?? 1.45)) && close(p.camera[2],wire.z);
   }),
   exactRecipientActors:poses.length > 5 && poses.every(p => {
    const wire = recipients.get(p.seq)?.actors;
    return wire && p.rendered.length === wire.length && p.rendered.every(r => {
     const a = wire.find(a => a.id === r.id);
     return a && close(r.position[0],a.x) && close(r.position[1],a.y+0.9) && close(r.position[2],a.z);
    });
   }),
   ownBudgetOnly:recipients.size > 0 && [...recipients.values()].every(r => r.fluxKeys.length === 1 && r.fluxKeys[0] === String(r.own.team)),
   ackObserved:[...recipients.values()].some(r => r.ack > 60),
   noCommands:!records.some(r => r.type === 'command'),
   normalHost:records.some(r => r.type === 'start' && r.config.mode === mode && r.config.botCount === 2)
  };
  const passed = Object.values(checks).every(Boolean);
  writeFileSync(join(out,'result.json'),JSON.stringify({passed,checks,nativeExit:exit,nativeResult:result,poses:poses.length},null,2)+'\n');
  console.log(JSON.stringify({passed,checks,out}));
  process.exitCode = passed ? 0 : 1;
 } else process.exitCode = exit;
} finally {
 clearTimeout(timer); stop(); await game.close();
 rmSync(runtime,{recursive:true,force:true});
 const closed = port ? await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(1000)}).then(() => false, () => true) : true;
 writeFileSync(join(out,'cleanup.json'),JSON.stringify({port,httpClosed:closed,nativeExited:child?.exitCode !== null,runtimeRemoved:!existsSync(runtime)},null,2)+'\n');
 process.removeListener('SIGINT',stop); process.removeListener('SIGTERM',stop);
}
