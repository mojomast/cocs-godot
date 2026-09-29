// Real source WebSocket authority, with a plainly labelled controlled XP grant.
// Writes only public actor fields; credentials never enter the evidence file.
import assert from 'node:assert/strict';
import {WebSocket} from 'ws';
import {writeFile, mkdir} from 'node:fs/promises';
import {createGameServer} from '../../server/game-server.mjs';

const game = createGameServer({tickMs: 8, tickDt: 1 / 60, historyPath: null, progressionPath: null});
let socket;
try {
  await new Promise(resolve => game.server.listen(0, '127.0.0.1', resolve));
  socket = new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);
  const backlog = [], waiters = [];
  socket.on('message', data => {
    const frame = JSON.parse(data);
    const index = waiters.findIndex(w => w.accept(frame));
    if (index < 0) {backlog.push(frame); if (backlog.length > 500) backlog.shift();}
    else {const w = waiters.splice(index, 1)[0]; clearTimeout(w.timer); w.resolve(frame);}
  });
  await new Promise((resolve, reject) => {socket.once('open', resolve); socket.once('error', reject);});
  const send = frame => socket.send(JSON.stringify(frame));
  const until = accept => {
    const index = backlog.findIndex(accept);
    if (index >= 0) return Promise.resolve(backlog.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const w = {accept, resolve, timer: setTimeout(() => {waiters.splice(waiters.indexOf(w), 1); reject(Error('Source WS timeout'));}, 10000)};
      waiters.push(w);
    });
  };
  send({type: 'create', v: 3, name: 'Finish authority fixture', playerName: 'Fixture', delta: 0});
  const welcome = await until(f => f.type === 'welcome');
  send({type: 'host', mapId: 'meridian-exchange', config: {mode: 'deathmatch', botCount: 0, timeLimit: 30}});
  await until(f => f.type === 'lobby' && f.mapId === 'meridian-exchange');
  send({type: 'start'});
  await until(f => f.type === 'start');
  const lobby = await until(f => f.type === 'lobby' && f.started);
  const actorId = lobby.players.find(p => p.peerId === welcome.peerId).actorId;
  const snapshot = () => until(f => f.type === 'snapshot' && f.state?.actors?.[actorId]?.health > 0);
  const actor = async () => {
    const a = (await snapshot()).state.actors[actorId];
    return {id: a.id, weapon: a.weapon, health: a.health, finish: a.finish ?? null};
  };
  const stock = await actor();
  assert.equal(stock.finish, null);
  // CONTROLLED GRANT FIXTURE: awardOwned simulates completed source-authoritative
  // match rewards; 200 credited frags are not a claim of natural progression.
  const grant = game.progression.awardOwned(welcome.profile.id, welcome.progressToken,
    {mode: 'deathmatch', win: true, actor: {frags: 200, deaths: 0, scoreStats: {captures: 1}}, time: 100});
  assert.ok(grant.profile.level >= 4, 'first finish source level gate is 4');
  send({type: 'gear', gear: grant.profile.gear, finish: 'finish-ion'});
  const saved = await until(f => f.type === 'progression' && f.profile?.finish === 'finish-ion');
  assert.equal(saved.profile.finish, 'finish-ion');
  const midmatch = await actor();
  assert.equal(midmatch.finish, null, 'profile change waits for next match');
  send({type: 'start'});
  await until(f => f.type === 'start');
  const rematch = await actor();
  assert.equal(rematch.finish, 'finish-ion');
  const report = {fixture: 'CONTROLLED GRANT: awardOwned source progression reward, 200 credited frags; not natural play',
    transport: 'real WebSocket protocol v3; source Room + ProgressionStore + Match',
    sourceLevel: grant.profile.level, sourceGate: 4, profileSaved: saved.profile.finish,
    actors: [stock, midmatch, rematch]};
  const out = new URL('../../port/native-finishes/evidence/source-journey.json', import.meta.url);
  await mkdir(new URL('./', out), {recursive: true});
  await writeFile(out, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify(report));
} finally {
  socket?.terminate();
  await game.close();
}
