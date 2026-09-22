// Own normal-rate server, passive recipient-wire witness and native scene process.
// No raw frames are retained: explicit field allow-lists exclude credentials.
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync, appendFileSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createHash} from 'node:crypto';
import {createGameServer} from '../../server/game-server.mjs';
import {verifySource} from '../../tools/godot-export/semantic.mjs';
const options = Object.fromEntries(process.argv.slice(2).map(arg => arg.replace(/^--/, '').split('=')));
const out = resolve(options.output);
mkdirSync(out, {recursive:true});
const lock = JSON.parse(readFileSync('port/contracts/source-lock.json'));
verifySource(lock);
const bin = process.env.GODOT_BIN;
if (execFileSync(bin, ['--version'], {encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Pinned Godot required');
const runtime = mkdtempSync('/tmp/opencode/lattice-physical-runtime-');
const env = {...process.env};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) {
 env[key] = join(runtime, key); mkdirSync(env[key]);
}
const records = [];
const record = value => { records.push(value); appendFileSync(join(out, 'wire.jsonl'), JSON.stringify(value) + '\n'); };
const pick = (object, keys) => Object.fromEntries(keys.filter(key => object?.[key] !== undefined).map(key => [key, object[key]]));
const game = createGameServer({historyPath:null, progressionPath:null});
game.wss.on('connection', ws => {
 let peer, actor, latest, lastSignature;
 const send = ws.send;
 ws.send = function(data, ...args) {
  const frame = JSON.parse(String(data));
  if (frame.type === 'welcome') { peer = frame.peerId; record({direction:'out', type:'welcome', peer}); }
  if (frame.type === 'lobby') {
   actor = frame.players.find(player => player.peerId === peer)?.actorId;
   record({direction:'out', type:'lobby', peer, actor, map:frame.mapId, mode:frame.config?.mode, round:frame.roundRevision});
  }
  if (frame.type === 'start') record({direction:'out', type:'start', peer, actor, map:frame.mapId, mode:frame.config.mode, round:frame.roundRevision});
  if (frame.type === 'snapshot') {
   const state = frame.state, board = state.cocs;
   const team = state.actors.find(value => value.id === actor)?.team;
   if (board) {
    latest = {direction:'out', type:'recipient-snapshot', peer, actor, team, seq:frame.seq,
     map:state.mapId, round:board.roundRevision, fluxKeys:Object.keys(board.flux ?? {}),
     spent:board.fluxSpent?.[team], spawned:board.roleBoard?.[team]?.spawned,
     ownFront:pick(board.nodes.find(node => node.id === `front-${team}`), ['id','owner','live']),
     cards:(board.cards ?? []).filter(card => String(card.peerId) === String(peer)).map(card => pick(card, ['id','actorId','peerId','team','verb','target','role','state','accepted','ok','reason']))};
    const signature = JSON.stringify({...latest, seq:undefined});
    if (signature !== lastSignature) { record(latest); lastSignature = signature; }
   }
  }
  if (frame.type === 'cocs-reject') record({direction:'out', peer, ...pick(frame, ['type','cardId','reason','roundRevision','roundRev','actionSeq'])});
  return send.call(this, data, ...args);
 };
 ws.prependListener('message', data => {
  const frame = JSON.parse(String(data));
  if (['order','economy'].includes(frame.type)) record({direction:'in', peer, actor,
   ...pick(frame, ['type','cardId','roundRev','actionSeq','verb','target','action','role']),
   priorRecipient:latest ? {seq:latest.seq, spent:latest.spent, spawned:latest.spawned, team:latest.team} : null});
 });
});
let child, timer, native = '', port, code = 1;
const stop = () => child?.kill('SIGTERM');
process.once('SIGINT', stop); process.once('SIGTERM', stop);
try {
 await new Promise((done, fail) => { game.server.once('error', fail); game.server.listen(0, '127.0.0.1', done); });
 port = game.server.address().port;
 if (!(await fetch(`http://127.0.0.1:${port}`, {signal:AbortSignal.timeout(5000)})).ok) throw Error('Readiness failed');
 const args = ['--audio-driver','Dummy','--path','godot','--resolution',options.size,
  '--script','res://tests/lattice/physical.gd','res://lattice/board.tscn','--',
  `--endpoint=ws://127.0.0.1:${port}`,`--map=${options.map}`,`--mode=${options.mode}`,`--physical-output=${out}`];
 const sourceFiles = ['game/protocol.mjs','game/cocs-intel.mjs','game/cocs.mjs','game/cocs-coop.mjs','game/cocs-orders.mjs','game/cocs-roles.mjs','server/game-server.mjs','server/room.mjs','godot/lattice/transport.gd'];
 writeFileSync(join(out, 'manifest.json'), JSON.stringify({base:'658b4e76a65e7ca37489a948ed466cd8a2872d98', source:lock.source_commit,
  godot:lock.godot_version, options, command:[bin,...args], port, display:env.DISPLAY,
  serverOptions:{historyPath:null,progressionPath:null}, simulation:'defaults: tickDt=1/60; tickMs=1000/60; snapshotHz unmodified',
  hashes:Object.fromEntries(sourceFiles.map(path => [path, createHash('sha256').update(readFileSync(path)).digest('hex')]))}, null, 2) + '\n');
 child = spawn(bin, args, {env, stdio:['ignore','pipe','pipe']});
 for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {native += data; process.stdout.write(data); appendFileSync(join(out, 'native.log'), data);});
 timer = setTimeout(() => {console.error('Physical attempt 90s deadline'); stop();}, 90000);
 code = await new Promise((done, fail) => { child.once('error', fail); child.once('exit', value => done(value ?? 1)); });
 const inbound = records.filter(value => value.direction === 'in');
 const snapshots = records.filter(value => value.type === 'recipient-snapshot');
 const hold = inbound.filter(value => value.type === 'order');
 const spend = inbound.filter(value => value.type === 'economy');
 const ownCard = (snapshot, action, state) => snapshot.peer === action.peer && snapshot.actor === action.actor && snapshot.round === action.roundRev && snapshot.cards.some(card => card.id === action.cardId && card.actorId === action.actor && String(card.peerId) === String(action.peer) && card.state === state && card.ok === true && (state !== 'running' || card.accepted === true));
 const checks = {
  nativeExit:code === 0 && !/SCRIPT ERROR|ERROR:/.test(native) && native.includes('"event":"result"'),
  holdExactlyOnce:hold.length === 1 && hold[0].verb === 'HOLD' && hold[0].target === `front-${hold[0].priorRecipient.team}`,
  holdRunning:hold.length === 1 && snapshots.some(snapshot => ownCard(snapshot, hold[0], 'running')),
  recipientKeys:snapshots.length > 0 && snapshots.every(snapshot => snapshot.fluxKeys.length === 1 && snapshot.fluxKeys[0] === String(snapshot.team)),
  spendExactlyOnce:options.mode === 'cocs' ? spend.length === 1 && spend[0].action === 'spawn' && spend[0].role === 'fighter' : spend.length === 0,
  spendDoneAndCost:options.mode !== 'cocs' || (spend.length === 1 && snapshots.some(snapshot => ownCard(snapshot, spend[0], 'done') && snapshot.spent - spend[0].priorRecipient.spent === 12 && snapshot.spawned - spend[0].priorRecipient.spawned === 1)),
  nativeWireIdentity:inbound.every(action => action.cardId === `native-r${action.roundRev}-p${action.peer}-s${action.actionSeq}` && native.includes(action.cardId))
 };
 const passed = Object.values(checks).every(Boolean);
 writeFileSync(join(out, 'result.json'), JSON.stringify({passed, checks, nativeExit:code, inboundCount:inbound.length}, null, 2) + '\n');
 process.exitCode = passed ? 0 : 1;
} finally {
 clearTimeout(timer); stop(); await game.close();
 rmSync(runtime, {recursive:true,force:true});
 const closed = port ? await fetch(`http://127.0.0.1:${port}`, {signal:AbortSignal.timeout(1000)}).then(() => false, () => true) : true;
 writeFileSync(join(out, 'cleanup.json'), JSON.stringify({port, httpClosed:closed, nativeExited:child?.exitCode !== null, runtimeRemoved:true}, null, 2) + '\n');
 process.removeListener('SIGINT', stop); process.removeListener('SIGTERM', stop);
}
