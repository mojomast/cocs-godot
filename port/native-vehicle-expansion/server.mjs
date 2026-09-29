// Passive wire witness for TWO separately launched native Godot processes.
// The Room and GameServer run unmodified; neither authority nor input is seeded.
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
import {writeFileSync} from 'node:fs';
const [root, output] = process.argv.slice(2);
if (!root || !output) throw Error('server.mjs ROOT OUTPUT');
const {createGameServer} = await import(pathToFileURL(resolve(root, 'server/game-server.mjs')));
const game = createGameServer({historyPath:null, progressionPath:null});
const witness = {classification:'unmodified Room; real WebSocket clients; default fixed step', connections:[], starts:[], inputs:[], accepted:[], snapshots:[], events:[]};
let serial = 0, roomPublished = false;
const observed = new WeakSet();
function witnessAccepted(roomId) {
  const match=game.registry.rooms.get(roomId)?.match;
  if (!match || observed.has(match)) return;
  observed.add(match);
  // Transparent observation at the only Room->Match input boundary. Record
  // effective rising edges after Room transformed the wire, then delegate
  // unchanged arguments to the original source implementation exactly once.
  const step=match.step;
  match.step=function(dt, values) {
    if (witness.accepted.length<12000) witness.accepted.push({roomId,time:this.time,
      inputs:structuredClone(values?.inputs??{})});
    return step.call(this,dt,values);
  };
}
game.wss.on('connection', socket => {
  const connection = ++serial;
  const record = {connection, peerId:null, actorId:null, roomId:null};
  witness.connections.push(record);
  socket.on('message', raw => {
    let frame; try {frame=JSON.parse(raw.toString());} catch {return;}
    if (frame.type==='input' && witness.inputs.length<12000)
      witness.inputs.push({connection, seq:frame.seq, input:frame.input});
    else if (['create','join','host','start'].includes(frame.type))
      (record.commands??=[]).push({type:frame.type, roomId:frame.roomId??null,
        mapId:frame.mapId??null, mode:frame.config?.mode??null, botCount:frame.config?.botCount??null});
  });
  const send = socket.send;
  socket.send = function(raw,...args) {
    let frame; try {frame=JSON.parse(raw.toString());} catch {return send.call(this,raw,...args);}
    if (frame.type==='welcome') {record.peerId=frame.peerId; record.roomId=frame.roomId;}
    if (frame.type==='lobby') {
      record.roomId=frame.roomId;
      const seat=frame.players?.find(p=>p.peerId===record.peerId);
      if (seat?.actorId!=null) record.actorId=seat.actorId;
      if (!roomPublished && frame.roomId && frame.hostId===record.peerId) {
        roomPublished=true; console.log(`ROOM ${frame.roomId}`);
      }
    }
    if (frame.type==='start') {
      witnessAccepted(record.roomId);
      if (witness.starts.length<20) witness.starts.push({connection, mapId:frame.mapId, mode:frame.config?.mode,
        botCount:frame.config?.botCount, roundRevision:frame.roundRevision});
    }
    if (frame.type==='snapshot' && witness.snapshots.length<16000) {
      const state=frame.state;
      witness.snapshots.push({connection, seq:frame.seq, ack:frame.acks?.[record.actorId],
        actorId:record.actorId, time:state?.time,
        actor:state?.actors?.find(a=>a.id===record.actorId)??null,
        vehicles:state?.vehicles??[], over:state?.over,
        teamScores:state?.teamScores, objective:state?.objectives});
    }
    if (frame.type==='events' && witness.events.length<12000)
      witness.events.push(...(frame.items??[]).filter(e=>e?.type?.startsWith('vehicle-'))
        .map(e=>({connection,...e})));
    return send.call(this,raw,...args);
  };
});
await new Promise((ok,fail)=>{game.server.once('error',fail);game.server.listen(0,'127.0.0.1',ok);});
console.log(`ENDPOINT ws://127.0.0.1:${game.server.address().port}`);
let closing = false;
async function close() {
  if (closing) return;
  closing=true; clearTimeout(deadline);
  for (const socket of game.wss.clients) socket.terminate();
  await game.close();
  witness.cleanup={serverClosed:!game.server.listening, sockets:game.wss.clients.size};
  writeFileSync(output,JSON.stringify(witness));
}
process.on('SIGTERM',close); process.on('SIGINT',close);
const deadline=setTimeout(close,155000);
