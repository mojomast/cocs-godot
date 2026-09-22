// Owned normal-rate authority and Xvfb. Passive recipient-only witness.
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, appendFileSync, mkdirSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
import {audit} from './audit.mjs';

const options = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const map = options.map, size = options.size;
if (!['asterion-relay','monsoon-foundry'].includes(map) || !['960x640','1280x800'].includes(size) || !options.output) throw Error('Require --map, --size, --output');
const out = resolve(options.output);
mkdirSync(out); // Exclusive: failed attempts are never overwritten.
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
verifySource(lock);
const bin = process.env.GODOT_BIN;
if (!bin || execFileSync(bin, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Pinned GODOT_BIN required');
const sha = path => createHash('sha256').update(readFileSync(path)).digest('hex');
const runtime = mkdtempSync('/tmp/opencode/world-coop-runtime-'), env = {...process.env};
for (const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) { env[key] = join(runtime,key); mkdirSync(env[key]); }
const records = [];
const started = performance.now();
let overflow = false;
const record = value => {
 if (records.length >= 20000) { overflow = true; return; }
 value.ms = Math.round(performance.now() - started);
 records.push(value); appendFileSync(join(out,'wire.jsonl'), JSON.stringify(value)+'\n');
};
const pick = (value, keys) => Object.fromEntries(keys.filter(key => value?.[key] !== undefined).map(key => [key,value[key]]));
const game = createGameServer({historyPath:null,progressionPath:null});
game.wss.on('connection', ws => {
 let peer, actor, latest;
 const send = ws.send;
 ws.send = function(data, ...args) {
  const frame = JSON.parse(String(data));
  if (frame.type === 'welcome') { peer = frame.peerId; record({type:'welcome',peer}); }
  if (frame.type === 'lobby') { actor = frame.players.find(p => p.peerId === peer)?.actorId; record({type:'lobby',peer,actor}); }
  if (frame.type === 'start') record({type:'start',peer,actor,map:frame.mapId,config:frame.config,round:frame.roundRevision});
  if (frame.type === 'snapshot') {
   const own = frame.state.actors.find(a => a.id === actor), b = frame.state.cocs;
   const window = b?.director?.intermission;
   latest = {type:'recipient',peer,actor,seq:frame.seq,ack:frame.acks?.[actor],round:b?.roundRevision,
    own:pick(own,['id','x','y','z','health','team','shots']),
    fluxKeys:Object.keys(b?.flux ?? {}),flux:b?.flux?.[own?.team],spent:b?.fluxSpent?.[own?.team],
    req:pick(b?.req?.find(w => w.id === actor),['id','req','spent']),spawned:b?.roles?.spawned,
    wave:b?.director?.wave,phase:b?.director?.phase,open:window?.open,
    sink:pick(window?.sinks?.find(s => s.id === 'REINFORCE'),['cost','available','enabled','affordable']),
    command:pick(b?.command,['executor','leaseUntil','threads']),
    ownSlice:pick(b?.command?.slices?.find(s => s.id === actor),['id','allowance','spent']),
    cards:b?.cards?.filter(c => c.actorId === actor && String(c.peerId) === String(peer)).map(c => pick(c,['id','actorId','peerId','state','accepted','ok','reason','verb','role']))};
   record(latest);
  }
  if (frame.type === 'events') for (const item of frame.items ?? []) {
   if (['cocs-order','cocs-order-rejected','cocs-order-complete','coop-intermission-open','director-intermission'].includes(item.type)) record({type:'event',peer,actor,item});
  }
  if (frame.type === 'cocs-reject') record({type:'rejection',peer,actor,frame:pick(frame,['type','cardId','reason','roundRev','actionSeq'])});
  return send.call(this,data,...args);
 };
 ws.prependListener('message', data => {
  const frame = JSON.parse(String(data));
  if (['input','order','economy'].includes(frame.type)) record({type:'request',peer,actor,frame,priorSeq:latest?.seq});
 });
});
let child, xvfb, timer, killTimer, native = '', port, exit = 1, timedOut = false;
const ended = proc => !proc || proc.exitCode !== null || proc.signalCode !== null;
const terminate = async proc => {
 if (ended(proc)) return;
 await new Promise(done => {
  const force = setTimeout(() => proc.kill('SIGKILL'), 2000);
  proc.once('exit', () => {clearTimeout(force); done();});
  proc.kill('SIGTERM');
 });
};
const stop = () => {
 timedOut = true;
 if (!ended(child)) {
  child.kill('SIGTERM');
  killTimer = setTimeout(() => {if (!ended(child)) child.kill('SIGKILL');}, 2000);
 }
};
process.once('SIGINT',stop); process.once('SIGTERM',stop);
let manifest;
try {
 const xargs = ['-displayfd','3','-screen','0','1400x1000x24','-nolisten','tcp','-nolisten','unix'];
 xvfb = spawn('Xvfb',xargs,{stdio:['ignore','ignore','pipe','pipe']});
 xvfb.stderr.on('data',data => appendFileSync(join(out,'xvfb.log'),data));
 const display = await new Promise((done,fail) => {
  let text = '';
  const timeout = setTimeout(() => fail(Error('Xvfb readiness timeout')),5000);
  xvfb.once('error',err => {clearTimeout(timeout); fail(err);});
  xvfb.stdio[3].on('data', data => {text += data; if (text.includes('\n')) {clearTimeout(timeout); done(text.trim());}});
 });
 if (!/^\d+$/.test(display)) throw Error('Invalid private display');
 env.DISPLAY = `:${display}`;
 delete env.XAUTHORITY;
 await new Promise((done,fail) => {game.server.once('error',fail); game.server.listen(0,'127.0.0.1',done);});
 port = game.server.address().port;
 if (!(await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)})).ok) throw Error('Authority readiness failed');
 const args = ['--audio-driver','Dummy','--path','godot','--resolution',size,
  '--script','res://tests/lattice/world_coop_live.gd','res://lattice/world_demo.tscn','--',
  `--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,'--mode=cocs-coop',`--world-output=${out}`];
 const files = ['server/game-server.mjs','server/room.mjs','game/core.mjs','game/protocol.mjs','game/cocs.mjs','game/cocs-intel.mjs',
  'game/cocs-coop.mjs','game/cocs-difficulty.mjs','game/cocs-economy.mjs','game/cocs-roles.mjs',
  'godot/net/client.gd','godot/world/session.gd','godot/world/viewer.gd','godot/world/presentation.gd',
  'godot/lattice/transport.gd','godot/lattice/world_demo.gd','godot/lattice/world_transport.gd','godot/lattice/world_hud.gd',
  'godot/lattice/world_commands.gd','godot/tests/lattice/world_commands_live.gd','godot/tests/lattice/world_coop_live.gd',
  'port/native-lattice-world-coop/run.mjs','port/native-lattice-world-coop/audit.mjs','port/native-lattice-world-coop/verify.py'];
 manifest = {base:'8a58c97e48493e41903c2c9a729e753cb3579500',revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
  source:lock.source_commit,godot:lock.godot_version,godotSha256:sha(bin),options,command:[bin,...args],
  port,display:env.DISPLAY,xvfb:{pid:xvfb.pid,command:['Xvfb',...xargs]},serverPid:process.pid,
  serverOptions:{historyPath:null,progressionPath:null},deadlineSeconds:210,
  simulation:'default tickDt 1/60, tickMs 1000/60, snapshotHz unchanged',input:'Godot engine events, not OS/human input',
  hashes:Object.fromEntries(files.map(file => [file,sha(file)]))};
 child = spawn(bin,args,{env,stdio:['ignore','pipe','pipe']});
 manifest.nativePid = child.pid;
 writeFileSync(join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
 for (const stream of [child.stdout,child.stderr]) stream.on('data', data => {
  if (native.length + data.length > 512000) {overflow = true; stop(); return;}
  native += data; appendFileSync(join(out,'native.log'),data);
 });
 timer = setTimeout(stop,Math.max(1,203000 - (performance.now() - started)));
 exit = await new Promise((done,fail) => {child.once('error',fail); child.once('exit',code => done(code ?? 1));});
 const result = audit(records,native,{exit,overflow,timedOut,manifest});
 writeFileSync(join(out,'result.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({out,...result}));
 process.exitCode = result.passed ? 0 : 1;
} catch (error) {
 writeFileSync(join(out,'runner-error.txt'),String(error.stack)+'\n');
 process.exitCode = 1;
} finally {
 clearTimeout(timer); clearTimeout(killTimer);
 await terminate(child); await game.close(); await terminate(xvfb);
 rmSync(runtime,{recursive:true,force:true});
 const closed = port ? await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(1000)}).then(() => false, () => true) : true;
 writeFileSync(join(out,'cleanup.json'),JSON.stringify({port,httpClosed:closed,nativeExited:ended(child),xvfbExited:ended(xvfb),
  runtimeRemoved:!existsSync(runtime),elapsedSeconds:(performance.now()-started)/1000},null,2)+'\n');
 process.removeListener('SIGINT',stop); process.removeListener('SIGTERM',stop);
}
