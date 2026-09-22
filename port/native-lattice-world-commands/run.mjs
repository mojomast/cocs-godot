// One ordinary authority, one native actor socket; passive recipient-only audit.
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, appendFileSync, mkdirSync, mkdtempSync, rmSync, existsSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';

const options = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const map = options.map ?? 'asterion-relay', mode = options.mode ?? 'cocs', play = 'play' in options;
if (!['asterion-relay','monsoon-foundry'].includes(map) || !['cocs','cocs-coop'].includes(mode)) throw Error('Unsupported map/mode');
const out = resolve(options.output ?? `port/native-lattice-world-commands/evidence/${Date.now()}-${map}-${mode}`);
mkdirSync(out, {recursive:true});
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
verifySource(lock);
const bin = process.env.GODOT_BIN;
if (!bin || execFileSync(bin, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Pinned GODOT_BIN required');
const runtime = mkdtempSync('/tmp/opencode/world-commands-runtime-'), env = {...process.env};
for (const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) { env[key] = join(runtime,key); mkdirSync(env[key]); }
const records = [];
const record = value => {
 if (records.length >= 20000) return;
 records.push(value); appendFileSync(join(out,'wire.jsonl'), JSON.stringify(value)+'\n');
};
const pick = (value, keys) => Object.fromEntries(keys.filter(key => value?.[key] !== undefined).map(key => [key,value[key]]));
const game = createGameServer({historyPath:null,progressionPath:null});
game.wss.on('connection', ws => {
 let peer, actor;
 const send = ws.send;
 ws.send = function(data, ...args) {
  const frame = JSON.parse(String(data));
  if (frame.type === 'welcome') { peer = frame.peerId; record({type:'welcome',peer}); }
  if (frame.type === 'lobby') { actor = frame.players.find(p => p.peerId === peer)?.actorId; record({type:'lobby',peer,actor}); }
  if (frame.type === 'start') record({type:'start',peer,actor,map:frame.mapId,config:frame.config,round:frame.roundRevision});
  if (frame.type === 'snapshot') {
   const own = frame.state.actors.find(a => a.id === actor), b = frame.state.cocs;
   record({type:'recipient',peer,actor,seq:frame.seq,ack:frame.acks?.[actor],round:b?.roundRevision,
    own:pick(own,['id','x','y','z','health','team','req']),
    actors:frame.state.actors.map(a => pick(a,['id','x','y','z','health','team','role'])),
    fluxKeys:Object.keys(b?.flux ?? {}),flux:b?.flux?.[own?.team],spent:b?.fluxSpent?.[own?.team],
    roles:b?.roleBoard?.[own?.team],cards:b?.cards?.filter(c => c.actorId === actor && String(c.peerId) === String(peer))});
  }
  if (frame.type === 'events') for (const item of frame.items ?? []) {
   if (['cocs-order','cocs-order-rejected','cocs-order-complete','cocs-role-spawn','cocs-capture'].includes(item.type)) record({type:'event',peer,actor,item});
  }
  if (frame.type === 'cocs-reject') record({type:'rejection',peer,actor,frame});
  return send.call(this,data,...args);
 };
 ws.prependListener('message', data => {
  const frame = JSON.parse(String(data));
  if (['input','order','economy'].includes(frame.type)) record({type:'request',peer,actor,frame});
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
  ...(!play ? ['--script','res://tests/lattice/world_commands_live.gd'] : []),'res://lattice/world_demo.tscn','--',
  `--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,`--mode=${mode}`,`--world-output=${out}`];
 const files = ['server/game-server.mjs','server/room.mjs','game/core.mjs','game/protocol.mjs','game/cocs.mjs','game/cocs-intel.mjs',
  'godot/net/client.gd','godot/world/session.gd','godot/world/viewer.gd','godot/world/presentation.gd',
  'godot/lattice/transport.gd','godot/lattice/world_demo.gd','godot/lattice/world_transport.gd','godot/lattice/world_hud.gd',
  'godot/lattice/world_commands.gd','godot/tests/lattice/world_commands_live.gd','port/native-lattice-world-commands/run.mjs'];
 writeFileSync(join(out,'manifest.json'),JSON.stringify({base:'6116f12',source:lock.source_commit,godot:lock.godot_version,
  options,command:[bin,...args],port,display:env.DISPLAY,serverOptions:{historyPath:null,progressionPath:null},
  simulation:'default tickDt 1/60, tickMs 1000/60, snapshotHz unchanged',input:'Godot engine events, not OS/human input',
  hashes:Object.fromEntries(files.map(file => [file,createHash('sha256').update(readFileSync(file)).digest('hex')]))},null,2)+'\n');
 console.log('WORLD_COMMANDS_RUN',JSON.stringify({endpoint:`ws://127.0.0.1:${port}`,map,mode,out}));
 child = spawn(bin,args,{env,stdio:['ignore','pipe','pipe']});
 for (const stream of [child.stdout,child.stderr]) stream.on('data', data => {native += data; appendFileSync(join(out,'native.log'),data);});
 if (!play) timer = setTimeout(stop,60000);
 exit = await new Promise((done,fail) => {child.once('error',fail); child.once('exit',code => done(code ?? 1));});
 if (!play) {
  const observations = native.split('\n').filter(line => line.startsWith('WORLD_COMMANDS ')).map(line => JSON.parse(line.slice(15)));
  const result = observations.find(r => r.event === 'result');
  const requests = records.filter(r => r.type === 'request');
  const commands = requests.filter(r => r.frame.type !== 'input');
  const recipients = records.filter(r => r.type === 'recipient');
  const opened = observations.find(r => r.event === 'opened'), resumeClick = observations.find(r => r.event === 'resume-click');
  const paused = requests.filter(r => r.frame.type === 'input' && r.frame.seq >= opened?.inputSeq && r.frame.seq <= resumeClick?.inputSeq);
  const neutral = r => ['x','z'].every(k => r.frame.input[k] === 0) && ['fire','jump','reload','sprint','crouch','interact','mobility'].every(k => r.frame.input[k] === false) && !('weapon' in r.frame.input);
  const before = observations.find(r => r.event === 'before-purchase'), after = observations.find(r => r.event === 'purchase-receipt');
  const beforeWire = recipients.find(r => r.seq === before?.snapshotSeq), afterWire = recipients.find(r => r.seq === after?.snapshotSeq);
  const spawn = records.find(r => r.type === 'event' && r.item.type === 'cocs-role-spawn' && r.item.role === 'fighter' && r.item.cost === 12);
  const checks = {
   native:exit === 0 && !!result && result.failures === 0 && !/SCRIPT ERROR|ERROR:/.test(native),
   oneSocket:records.filter(r => r.type === 'welcome').length === 1,
   sameIdentity:commands.length > 0 && commands.every(r => r.peer === opened?.peer && r.actor === opened?.actor),
   neutralWhileOpen:paused.length > 10 && paused.every(neutral),
   ackHighWater:recipients.some(r => r.ack >= opened?.inputSeq),
   singleHold:commands.filter(r => r.frame.type === 'order' && r.frame.verb === 'HOLD').length === 1,
   executedHold:records.some(r => r.type === 'event' && r.item.type === 'cocs-order' && r.item.cardId === commands.find(c => c.frame.type === 'order')?.frame.cardId),
   economy:mode === 'cocs' ? commands.filter(r => r.frame.type === 'economy').length === 1 && after?.spent - before?.spent === 12 && after?.spawned - before?.spawned === 1 : !commands.some(r => r.frame.type === 'economy'),
   sourceUnitDelta:mode === 'cocs' ? afterWire?.spent - beforeWire?.spent === 12 && afterWire?.roles?.spawned - beforeWire?.roles?.spawned === 1 && !!spawn && !beforeWire.actors.some(a => a.id === spawn.item.actor) && afterWire.actors.some(a => a.id === spawn.item.actor) : true,
   ownBudgetOnly:recipients.length > 0 && recipients.every(r => r.fluxKeys.length === 1 && r.fluxKeys[0] === String(r.own.team)),
   normalHost:records.some(r => r.type === 'start' && r.config.mode === mode && r.config.botCount === 2)
  };
  const passed = Object.values(checks).every(Boolean);
  writeFileSync(join(out,'result.json'),JSON.stringify({passed,checks,nativeExit:exit,nativeResult:result,commands,ackMeaning:'High-water receipt; no individual input-application claim',captureClaim:false},null,2)+'\n');
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
