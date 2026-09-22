// Owned ephemeral normal-rate source server. Passive allow-listed wire witness.
// No simulator writes, raw frames, credentials or enemy wallets are retained.
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
const runtime = mkdtempSync('/tmp/opencode/lattice-economy-runtime-');
const env = {...process.env};
for (const key of ['XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']) {
 env[key] = join(runtime, key); mkdirSync(env[key]);
}
const records = [];
let overflow = false;
const record = value => {
 if (records.length >= 300) { overflow = true; return; }
 records.push(value); appendFileSync(join(out, 'wire.jsonl'), JSON.stringify(value) + '\n');
};
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
   const self = state.actors.find(value => value.id === actor), team = self?.team;
   if (board) {
    const window = board.director?.intermission;
    latest = {direction:'out', type:'recipient-snapshot', peer, actor, team, seq:frame.seq,
     map:state.mapId, round:board.roundRevision, fluxKeys:Object.keys(board.flux ?? {}),
     flux:board.flux?.[team], spent:board.fluxSpent?.[team], req:board.req?.find(value => value.id === actor)?.req,
     reqSpent:board.req?.find(value => value.id === actor)?.spent,
     spawned:board.roles?.spawned, wave:board.director?.wave, phase:board.director?.phase, open:window?.open,
     sink:pick(window?.sinks?.find(sink => sink.id === 'REINFORCE'), ['cost','available','affordable','enabled']),
     executor:board.command?.executor, threads:pick(board.command?.threads, ['used','cap']),
     ownSlice:pick(board.command?.slices?.find(slice => slice.id === actor), ['id','allowance']),
     cards:(board.cards ?? []).filter(card => String(card.peerId) === String(peer)).map(card => pick(card, ['id','actorId','peerId','team','verb','target','role','state','accepted','ok','reason']))};
    // Wallet income changes every tick. Retain only semantic transitions plus
    // the exact preceding recipient projection on an incoming purchase.
    const signature = JSON.stringify({...latest, seq:undefined, flux:undefined, req:undefined, ownSlice:undefined});
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
   priorRecipient:latest ? pick(latest, ['seq','flux','spent','spawned','team','req','reqSpent','wave','phase','open','executor','threads','ownSlice','sink']) : null});
 });
});
let child, timer, native = '', port, code = 1;
const stop = () => child?.kill('SIGTERM');
process.once('SIGINT', stop); process.once('SIGTERM', stop);
try {
 await new Promise((done, fail) => { game.server.once('error', fail); game.server.listen(0, '127.0.0.1', done); });
 port = game.server.address().port;
 if (!(await fetch(`http://127.0.0.1:${port}`, {signal:AbortSignal.timeout(5000)})).ok) throw Error('Readiness failed');
 const args = ['--audio-driver','Dummy','--path','godot','--resolution',options.size ?? '960x640',
  '--script','res://tests/lattice/economy_physical.gd','res://lattice/board.tscn','--',
  `--endpoint=ws://127.0.0.1:${port}`,`--map=${options.map}`,'--mode=cocs-coop',`--physical-output=${out}`];
 const sourceFiles = ['game/protocol.mjs','game/cocs-intel.mjs','game/cocs.mjs','game/cocs-coop.mjs','game/cocs-difficulty.mjs','game/cocs-economy.mjs','game/cocs-roles.mjs','server/game-server.mjs','server/room.mjs','godot/lattice/transport.gd','godot/lattice/board.gd','godot/lattice/board.tscn','godot/tests/lattice/economy_physical.gd','godot/tests/lattice/physical.gd','port/native-lattice-economy/run.mjs'];
 writeFileSync(join(out, 'manifest.json'), JSON.stringify({base:'c982d25ca335da3983df48ea37f7602bf8ded1f2', source:lock.source_commit,
  revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
  godot:lock.godot_version, godotSha256:createHash('sha256').update(readFileSync(bin)).digest('hex'), options, command:[bin,...args], port, display:env.DISPLAY,
  serverOptions:{historyPath:null,progressionPath:null}, simulation:'defaults: tickDt=1/60; tickMs=1000/60; snapshotHz unmodified',
  hashes:Object.fromEntries(sourceFiles.map(path => [path, createHash('sha256').update(readFileSync(path)).digest('hex')]))}, null, 2) + '\n');
 child = spawn(bin, args, {env, stdio:['ignore','pipe','pipe']});
 for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {
  if (native.length + data.length > 256000) { overflow = true; stop(); return; }
  native += data; process.stdout.write(data); appendFileSync(join(out, 'native.log'), data);
 });
 timer = setTimeout(() => {console.error('Economy attempt 290s deadline'); stop();}, 290000);
 code = await new Promise((done, fail) => { child.once('error', fail); child.once('exit', value => done(value ?? 1)); });
 const inbound = records.filter(value => value.direction === 'in');
 const snapshots = records.filter(value => value.type === 'recipient-snapshot');
 const hold = inbound.filter(value => value.type === 'order');
 const spend = inbound.filter(value => value.type === 'economy');
 const ownCard = (snapshot, action, state) => snapshot.peer === action.peer && snapshot.actor === action.actor && snapshot.round === action.roundRev && snapshot.cards.some(card => card.id === action.cardId && card.actorId === action.actor && String(card.peerId) === String(action.peer) && card.state === state && card.ok === true && (state !== 'running' || card.accepted === true));
 const checks = {
  nativeExit:code === 0 && !/SCRIPT ERROR|ERROR:/.test(native) && native.includes('"event":"result"'),
  bounded:!overflow,
  holdExactlyOnce:hold.length === 1 && hold[0].verb === 'HOLD' && hold[0].target === 'front-0',
  holdRunning:hold.length === 1 && snapshots.some(snapshot => ownCard(snapshot, hold[0], 'running')),
  recipientKeys:snapshots.length > 0 && snapshots.every(snapshot => snapshot.fluxKeys.length === 1 && snapshot.fluxKeys[0] === String(snapshot.team)),
  spendExactlyOnce:spend.length === 1 && spend[0].action === 'reinforce' && spend[0].role === 'fighter',
  sourcePermission:spend.length === 1 && spend[0].priorRecipient.open === true && spend[0].priorRecipient.executor === spend[0].actor && spend[0].priorRecipient.ownSlice.allowance >= 50 && spend[0].priorRecipient.sink.cost === 50,
  spendDoneAndCost:spend.length === 1 && snapshots.some(snapshot => ownCard(snapshot, spend[0], 'done') && snapshot.spent - spend[0].priorRecipient.spent === 50 && snapshot.spawned - spend[0].priorRecipient.spawned === 1 && snapshot.reqSpent === spend[0].priorRecipient.reqSpent),
  nativeWireIdentity:inbound.every(action => action.cardId === `native-r${action.roundRev}-p${action.peer}-s${action.actionSeq}` && native.includes(action.cardId))
 };
 const passed = Object.values(checks).every(Boolean);
 writeFileSync(join(out, 'result.json'), JSON.stringify({passed, checks, nativeExit:code, inboundCount:inbound.length, records:records.length}, null, 2) + '\n');
 process.exitCode = passed ? 0 : 1;
} finally {
 clearTimeout(timer); stop(); await game.close();
 rmSync(runtime, {recursive:true,force:true});
 const closed = port ? await fetch(`http://127.0.0.1:${port}`, {signal:AbortSignal.timeout(1000)}).then(() => false, () => true) : true;
 writeFileSync(join(out, 'cleanup.json'), JSON.stringify({port, httpClosed:closed, nativeExited:child?.exitCode !== null, runtimeRemoved:true}, null, 2) + '\n');
 process.removeListener('SIGINT', stop); process.removeListener('SIGTERM', stop);
}
