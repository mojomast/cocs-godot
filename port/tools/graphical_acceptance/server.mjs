// Read-only observation of the unmodified, normal-rate source server.
import {pathToFileURL} from 'node:url';
import {appendFileSync, writeFileSync} from 'node:fs';
import {resolve} from 'node:path';

const [source, output] = process.argv.slice(2);
const {createGameServer} = await import(pathToFileURL(resolve(source, 'server/game-server.mjs')));
const game = createGameServer({historyPath:null, progressionPath:null});
let count = 0;
const record = value => {
  if (++count > 20000) throw Error('Wire evidence cap exceeded');
  appendFileSync(resolve(output, 'wire.jsonl'), JSON.stringify({at_ms:Date.now(), ...value})+'\n');
};
game.wss.on('connection', ws => {
  let actorId = null, peerId = null;
  const send = ws.send.bind(ws);
  ws.send = (data, ...args) => {
    const frame = JSON.parse(String(data));
    if (frame.type === 'welcome') peerId = frame.peerId;
    if (frame.type === 'lobby') actorId = frame.players?.find(p => p.peerId === peerId)?.actorId ?? actorId;
    if (frame.type === 'snapshot') {
      const a = frame.state.actors.find(a => a.id === actorId);
      record({event:'snapshot', seq:frame.seq, ack:frame.acks?.[String(actorId)], actor_id:actorId,
        actor:a ? Object.fromEntries(['id','x','y','z','yaw','pitch','health','dead','shots'].map(k=>[k,a[k]])) : null});
    } else if (frame.type === 'events') {
      record({event:'events', items:frame.items.filter(e => e.actorId === actorId || e.actor === actorId || e.source === actorId)});
    } else if (['start','results','error'].includes(frame.type)) {
      record({event:frame.type, mapId:frame.mapId});
    }
    return send(data, ...args);
  };
  ws.on('message', data => {
    const frame = JSON.parse(String(data));
    if (frame.type === 'input') record({event:'input', seq:frame.seq, controls:frame.input});
    else record({event:'request', type:frame.type, mapId:frame.mapId, config:frame.config});
  });
});
await new Promise((ok, fail) => { game.server.once('error',fail); game.server.listen(0,'127.0.0.1',ok); });
const port = game.server.address().port;
writeFileSync(resolve(output,'server-ready.json'),JSON.stringify({port,pid:process.pid,normalRate:true,historyPath:null,progressionPath:null}));
console.log(`PRIVATE_SERVER_READY loopback=${port} normal_rate=true persistence=false`);
let stopping = false;
async function stop(reason) {
  if (stopping) return;
  stopping = true;
  record({event:'harness_server_stop',reason});
  for (const ws of game.wss.clients) ws.terminate();
  await game.close();
  console.log('PRIVATE_SERVER_STOPPED');
  process.exit(0);
}
process.once('SIGTERM',()=>stop('SIGTERM'));
process.once('SIGINT',()=>stop('SIGINT'));
setTimeout(()=>stop('deadline'),90000).unref();
