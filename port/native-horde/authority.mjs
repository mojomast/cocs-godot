// Explicitly local-only. Public Room continues to reject singleplayer modes.
import http from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {Match} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {InputBuffer} from './input-buffer.mjs';
export const MAPS = ['meridian-exchange','verdant-reliquary','ember-crucible'];
export const LIMITS = Object.freeze({payload:16384, frame:1048576, outbound:2097152,
 messagesPerSecond:120, burst:128, connections:8});
export function validateConfig(frame) {
 if (!MAPS.includes(frame.mapId) || frame.config?.mode !== 'horde') throw Error('Unsupported local Horde map/mode');
 const waves = frame.config.fragLimit === undefined ? 10 : frame.config.fragLimit;
 if (!Number.isInteger(waves) || waves < 1 || waves > 30) throw Error('Wave target must be 1..30');
 return normalizeConfig({mode:'horde',botCount:0,difficulty:'easy',fragLimit:waves,timeLimit:900});
}
// Source emit spreads payload id/type over its envelope. The actual serial is
// the append position in the bounded event ring, not event.id. Never edit it.
export function eventBatch(match, cursor) {
 const first = match.serial - match.events.length + 1;
 if (cursor < first - 1) throw Error('Source event ring overflow');
 return match.events.flatMap((event, index) => first + index > cursor ?
  [{...event, sourceId:event.id, id:first + index}] : []);
}
export function outboundAllowed(bytes, buffered) {
 return bytes <= LIMITS.frame && buffered + bytes <= LIMITS.outbound;
}
export function createAuthority({observe=()=>{}}={}) {
 const server = http.createServer({maxHeaderSize:8192}, (req,res) => {
  res.writeHead(200, {'Content-Type':'application/json'});
  res.end(JSON.stringify({service:'cocs-local-horde', transport:1, localOnly:true, port:server.address()?.port}));
 });
 server.maxConnections = LIMITS.connections;
 server.requestTimeout = 5000; server.headersTimeout = 5000; server.keepAliveTimeout = 1000;
 const wss = new WebSocketServer({noServer:true, maxPayload:LIMITS.payload, perMessageDeflate:false});
 const inputs = new InputBuffer();
 let socket=null, config=null, mapId=null, match=null, created=false, finished=false;
 let round=0, seq=0, epoch=0, eventCursor=0, ticks=0, wall=performance.now(), accumulator=0, closing=false, closePromise;
 let tokens=LIMITS.burst, tokenAt=wall;
 const record = value => observe({...value, round, observedMs:performance.now()});
 function detach(ws) {
  if (socket !== ws) return;
  socket=null; match=null; config=null; mapId=null; created=false; finished=false;
  inputs.reset(); accumulator=0;
 }
 function terminate(reason) {
  record({direction:'transport-error', reason});
  const ws=socket;
  if (ws) { detach(ws); ws.terminate(); }
 }
 function send(frame) {
  if (socket?.readyState !== WebSocket.OPEN) return;
  const text=JSON.stringify(frame);
  if (!outboundAllowed(Buffer.byteLength(text),socket.bufferedAmount)) { terminate('Outbound limit'); return; }
  record({direction:'out',frame});
  const ws=socket;
  ws.send(text, error => { if (error && socket === ws) terminate('Send failed'); });
 }
 const lobby = () => send({type:'lobby',mapId,config,players:[{peerId:0,actorId:0,name:'Local player'}]});
 function cancelControls(reason) {
  inputs.cancel(); epoch++;
  send({type:'horde-input-reset',inputEpoch:epoch,reason});
  record({direction:'control-reset',reason,inputEpoch:epoch,...inputs.status()});
 }
 // Reject before upgrade: rejected clients never enter a WS close handshake.
 server.on('upgrade', (req, stream, head) => {
  if (closing || socket || !['127.0.0.1','::ffff:127.0.0.1','::1'].includes(req.socket.remoteAddress) ||
      Object.hasOwn(req.headers,'origin')) { stream.destroy(); return; }
  wss.handleUpgrade(req, stream, head, ws => wss.emit('connection',ws,req));
 });
 server.on('clientError', (_error, stream) => stream.destroy());
 wss.on('error', () => terminate('WebSocket server error'));
 wss.on('connection', ws => {
  socket=ws; tokens=LIMITS.burst; tokenAt=performance.now();
  ws.on('error', () => { detach(ws); ws.terminate(); });
  ws.on('close', () => detach(ws));
  ws.on('message', (data,binary) => {
   if (socket !== ws || closing) return;
   const now=performance.now();
   tokens=Math.min(LIMITS.burst,tokens+(now-tokenAt)*LIMITS.messagesPerSecond/1000); tokenAt=now;
   if (--tokens < 0 || binary) { terminate(binary?'Binary input unsupported':'Message rate limit'); return; }
   try {
    const f=JSON.parse(String(data));
    if (!f || typeof f !== 'object' || Array.isArray(f)) throw Error('Object envelope required');
    record({direction:'in',frame:f});
    if (f.type === 'create' && !created) {
     if (f.v !== 3) throw Error('Protocol 3 required');
     created=true; send({type:'welcome',v:3,roomId:'local-horde',peerId:0,hordeTransport:1}); lobby();
    } else if (f.type === 'host' && created && !match) {
     config=validateConfig(f); mapId=f.mapId; lobby();
    } else if (f.type === 'start' && config && (!match || match.over)) {
     match=new Match('chatgpt','openclaw',Math.random,mapId,config);
     if (match.arena.id !== mapId || match.config.mode !== 'horde') throw Error('Source substituted map/mode');
     round++; seq=0; epoch++; eventCursor=0; ticks=0; finished=false; inputs.reset();
     // Construction cost must not advance the new match's source clock.
     wall=performance.now(); accumulator=0;
     send({type:'start',mapId,inputEpoch:epoch});
    } else if (f.type === 'input' && match) {
     if (match.over) return; // benign inputs already in flight at results
     if (f.inputEpoch !== epoch) return; // old round/death/stall cannot re-arm input
     const parsed=parseInputEnvelope(f);
     inputs.receive(f.seq,parsed,now,f.cancel === true);
     // A dying actor's queued actions must not execute on a later respawn.
     if (match.actors[0].health <= 0) inputs.cancel();
    } else throw Error('Invalid local lifecycle command');
   } catch (error) {
    send({type:'error',message:error.message}); terminate(error.message);
   }
  });
 });
 const timer=setInterval(() => {
  const now=performance.now(), elapsed=Math.max(0,(now-wall)/1000); wall=now;
  if (!match || finished) { accumulator=0; return; }
  // Source app/page.tsx local loop: fixed RULES.dt, bounded five-step backlog.
  // No injected clock, accelerated steps, physics or Match state mutations.
  accumulator=Math.min(accumulator+elapsed,5/60);
  try {
   for (let steps=0; accumulator>=1/60 && steps<5 && match && !finished; steps++) {
    accumulator-=1/60;
    if (inputs.expired(now)) cancelControls('stale-input');
    const sample=inputs.take(), active=match;
    const alive=active.actors[0].health > 0;
    active.step(1/60,{inputs:{0:sample.input}});
    inputs.stepped(sample.seq);
    record({direction:'step',inputSeq:sample.seq,inputEpoch:epoch,controls:sample.input,
     sourceTime:active.time,...inputs.status()});
    if (alive && active.actors[0].health <= 0) cancelControls('death');
    const events=eventBatch(active,eventCursor); eventCursor=active.serial;
    if (events.length) send({type:'events',items:events});
    if (++ticks%3 === 0 || active.over) send({type:'snapshot',seq:++seq,acks:{0:inputs.applied},
     inputEpoch:epoch,hordeInput:inputs.status(),state:active.snapshot()});
    if (active.over) {
     finished=true; inputs.cancel();
     send({type:'results',inputEpoch:epoch,hordeInput:inputs.status(),state:active.snapshot()});
    }
   }
  } catch (error) { terminate(`Authority step failed: ${error.message}`); }
 },1000/60);
 return {server,wss, close() {
  if (closePromise) return closePromise;
  closing=true; clearInterval(timer); inputs.cancel();
  closePromise=(async () => {
   for (const ws of wss.clients) ws.terminate();
   await new Promise(resolve => wss.close(resolve));
   server.closeAllConnections();
   if (server.listening) await new Promise(resolve => server.close(resolve));
   socket=null; match=null;
  })();
  return closePromise;
 }};
}
