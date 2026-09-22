// Explicitly local-only. Public Room continues to reject singleplayer modes.
import http from 'node:http';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {WebSocketServer, WebSocket} from 'ws';
import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {normalizeConfig} from '../../game/config.mjs';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {InputBuffer} from './input-buffer.mjs';
import {applyDebugFrame, applyLiveOverrides, createDebugState, debugEcho, installHumanGuard,
  parseDebugFrame, reconcileHuman, restoreSpawnAmmo, HUMAN_SEAT} from '../native-debug/debug.mjs';
export const MAPS = ['meridian-exchange','verdant-reliquary','ember-crucible'];
// ---------------------------------------------------------------------------
// Identity-family hook (Nacre Engine).
//
// The identity arenas are authored by another lane as static JSON envelopes and
// rendered at runtime by res://identity_maps/map.gd. Horde plays the same arena
// the reviewed Deathmatch route already ships, so this transport resolves
// exactly one allowlisted recipe through one literal package-relative path and
// constructs an unchanged source Match around its geometry.
//
// Deliberately static, by review:
//   * the allowlist is a frozen literal. No CLI argument, environment variable,
//     HTTP request or WebSocket frame can add a map, a path or a JSON document.
//   * the path is a literal lookup in IDENTITY_MAP_SOURCES. It is never a
//     parameter, a concatenation of caller input, a glob or a directory scan.
//   * the recipe is validated here (identity, schema, horde recipe mode, size
//     and the canonical arena hash) before any Match is constructed.
//   * the arena is installed through a local subclass accessor that intercepts
//     the source constructor's own `this.arena = getMap(mapId)` assignment, the
//     reviewed native-arena technique. Nothing is written to the source MAPS
//     registry and no completed Match is transplanted onto another arena.
//   * post-conditions are re-checked after construction: arena identity, horde
//     mode, exactly one human, and a supported, unblocked spawn.
// The hook is intentionally inline in this reviewed adapter file: the package
// closure classifies runtime modules from the static import graph, so a new
// imported helper would change the shipped adapter inventory without a package
// lane review. `game/core.mjs` is already in the closure.
// ---------------------------------------------------------------------------
export const IDENTITY_MAPS = Object.freeze(['nacre-engine']);
export const HORDE_MAPS = Object.freeze([...MAPS, ...IDENTITY_MAPS]);
const IDENTITY_HORDE_MODE = 'horde';
const IDENTITY_MAP_SOURCES = Object.freeze({
 'nacre-engine':'godot/identity_maps/generated/nacre-engine.json',
});
const IDENTITY_MAP_LIMIT = 8*1024*1024;
const HEX64 = /^[a-f0-9]{64}$/;
// Mirrors port/native-arenas/schema.mjs canonicalArenaJSON (SHA-256 of the
// canonical `arena` object: recursive lexicographic key order, array order and
// JSON.stringify number semantics preserved). The value is recomputed from the
// bytes this process actually read, so a regenerated or edited recipe fails
// closed instead of silently changing the played arena.
export function canonicalArenaJSON(value) {
 if (Array.isArray(value)) return `[${value.map(canonicalArenaJSON).join(',')}]`;
 if (value !== null && typeof value === 'object') return `{${Object.keys(value).sort()
  .map(key => `${JSON.stringify(key)}:${canonicalArenaJSON(value[key])}`).join(',')}}`;
 return JSON.stringify(value);
}
export function identityArenaHash(arena) {
 return createHash('sha256').update(canonicalArenaJSON(arena)).digest('hex');
}
const identityFail = label => { throw Error(`Invalid identity Horde map: ${label}`); };
const finiteNumber = (value, label, min = -1e6, max = 1e6) => {
 if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) identityFail(label);
 return value;
};
const identityMesh = (surface, label) => {
 if (!surface || typeof surface !== 'object' || Array.isArray(surface)) identityFail(label);
 if (typeof surface.id !== 'string' || !surface.id.length) identityFail(`${label} id`);
 if (typeof surface.material !== 'string' || !surface.material.length) identityFail(`${label} material`);
 if (!Array.isArray(surface.vertices) || surface.vertices.length < 3) identityFail(`${label} vertices`);
 if (!Array.isArray(surface.triangles) || !surface.triangles.length) identityFail(`${label} triangles`);
 for (const vertex of surface.vertices) {
  if (!Array.isArray(vertex) || vertex.length !== 3) identityFail(`${label} vertex`);
  for (const axis of vertex) finiteNumber(axis, `${label} vertex`);
 }
};
/** Pure, reviewed validator for one identity recipe. Exported so tests can feed
 * a tampered document and prove refusal; it is never reachable from the wire. */
export function validateIdentityEnvelope(data, mapId) {
 if (!data || typeof data !== 'object' || Array.isArray(data)) identityFail('envelope');
 if (data.schemaVersion !== 1) identityFail('schemaVersion');
 if (data.id !== mapId) identityFail('envelope id');
 if (typeof data.name !== 'string' || !data.name.length) identityFail('name');
 if (data.mode !== IDENTITY_HORDE_MODE) identityFail('recipe mode is not horde');
 if (typeof data.geometryHash !== 'string' || !HEX64.test(data.geometryHash)) identityFail('geometryHash');
 const arena = data.arena;
 if (!arena || typeof arena !== 'object' || Array.isArray(arena)) identityFail('arena');
 if (arena.id !== mapId || arena.name !== data.name) identityFail('arena identity');
 const bounds = arena.bounds;
 if (!bounds || typeof bounds !== 'object') identityFail('bounds');
 finiteNumber(bounds.minX, 'bounds.minX'); finiteNumber(bounds.maxX, 'bounds.maxX');
 finiteNumber(bounds.minZ, 'bounds.minZ'); finiteNumber(bounds.maxZ, 'bounds.maxZ');
 if (bounds.minX >= bounds.maxX || bounds.minZ >= bounds.maxZ) identityFail('degenerate bounds');
 if (!Array.isArray(arena.spawns) || arena.spawns.length < 2 || arena.spawns.length > 64) identityFail('spawns');
 for (const spawn of arena.spawns) {
  if (!Array.isArray(spawn) || spawn.length !== 2) identityFail('spawn point');
  finiteNumber(spawn[0], 'spawn x'); finiteNumber(spawn[1], 'spawn z');
 }
 if (!Array.isArray(arena.navNodes)) identityFail('navNodes');
 if (!Array.isArray(arena.blocks)) identityFail('blocks');
 for (const block of arena.blocks) {
  if (!block || typeof block !== 'object') identityFail('block');
  const w = finiteNumber(block.w, 'block width', 0);
  const d = finiteNumber(block.d, 'block depth', 0);
  const h = finiteNumber(block.h, 'block height');
  const baseY = finiteNumber(block.baseY, 'block baseY');
  finiteNumber(block.x, 'block x'); finiteNumber(block.z, 'block z');
  if (w <= 0 || d <= 0 || h <= baseY) identityFail('degenerate block');
 }
 if (!Array.isArray(arena.pickups)) identityFail('pickups');
 for (const pickup of arena.pickups) {
  if (!Array.isArray(pickup) || pickup.length !== 3 || typeof pickup[0] !== 'string' || !pickup[0].length) identityFail('pickup');
  finiteNumber(pickup[1], 'pickup x'); finiteNumber(pickup[2], 'pickup z');
 }
 if (!arena.terrain || typeof arena.terrain !== 'object') identityFail('terrain');
 if (!Array.isArray(arena.terrain.surfaces) || !arena.terrain.surfaces.length) identityFail('terrain surfaces');
 for (const surface of arena.terrain.surfaces) identityMesh(surface, 'terrain surface');
 if (!Array.isArray(arena.terrain.walls)) identityFail('terrain walls');
 for (const wall of arena.terrain.walls) {
  if (!wall || typeof wall !== 'object') identityFail('terrain wall');
  if (wall.vertices === undefined) {
   // Movement-only fence spelling: {a:{x,y,z},b:{x,y,z}}. identity_maps/map.gd
   // deliberately gives these no collider, because the source answers no ray hit.
   for (const endpoint of [wall.a, wall.b]) {
    if (!endpoint || typeof endpoint !== 'object') identityFail('wall endpoint');
    finiteNumber(endpoint.x, 'wall endpoint x');
    finiteNumber(endpoint.y, 'wall endpoint y');
    finiteNumber(endpoint.z, 'wall endpoint z');
   }
   continue;
  }
  if (!Array.isArray(wall.vertices) || wall.vertices.length < 3) identityFail('wall vertices');
  for (const vertex of wall.vertices) {
   if (!Array.isArray(vertex) || vertex.length !== 3) identityFail('wall vertex');
   for (const axis of vertex) finiteNumber(axis, 'wall vertex');
  }
 }
 if (identityArenaHash(arena) !== data.geometryHash) identityFail('geometryHash does not match canonical arena');
 return arena;
}
/** Resolve only the reviewed static recipe for `mapId`. The returned arena is
 * the exact object the source Match will play; callers must not mutate it. */
export function readIdentityMap(mapId) {
 const relative = Object.hasOwn(IDENTITY_MAP_SOURCES, mapId) ? IDENTITY_MAP_SOURCES[mapId] : null;
 if (relative === null) throw Error('Identity Horde map is not allowlisted');
 let bytes;
 try {
  bytes = readFileSync(new URL(`../../${relative}`, import.meta.url));
 } catch (error) {
  throw Error(`Identity Horde map unavailable: ${mapId} (${error.code ?? 'read failure'})`);
 }
 if (bytes.byteLength === 0 || bytes.byteLength > IDENTITY_MAP_LIMIT) identityFail('file size');
 let data;
 try {
  data = JSON.parse(bytes.toString('utf8'));
 } catch (error) {
  identityFail('JSON parse');
 }
 return validateIdentityEnvelope(data, mapId);
}
/** The single static map/factory hook. Source maps keep the historical
 * constructor; the identity family resolves its reviewed recipe and installs it
 * before floor/nav/spawn/actor initialization. */
export function createHordeMatch({mapId, config, random = Math.random} = {}) {
 if (!HORDE_MAPS.includes(mapId)) throw Error('Unsupported local Horde map');
 if (typeof random !== 'function') throw Error('RNG must be a function');
 if (!config || config.mode !== 'horde' || config.botCount !== 0) throw Error('Normalized Horde config required');
 if (!IDENTITY_MAPS.includes(mapId)) return new Match('chatgpt','openclaw',random,mapId,config);
 const arena = readIdentityMap(mapId);
 let assigned = false;
 class IdentityHordeMatch extends Match {
  get arena() { return arena; }
  set arena(_sourceFallback) {
   if (assigned) throw Error('Identity arena reassignment refused');
   assigned = true;
  }
 }
 const match = new IdentityHordeMatch('chatgpt','openclaw',random,mapId,{...config,humanCount:1});
 if (!assigned || match.arena !== arena || match.snapshot().mapId !== mapId) throw Error('Identity constructor contract drift');
 if (match.humanCount !== 1 || match.actors.length !== 1 || match.config.botCount !== 0) throw Error('Identity Horde is single-human only');
 for (const actor of match.actors) {
  if (!Number.isFinite(actor.y) || floorAt(actor.x, actor.z, arena) === null || obstructed(actor.x, actor.y, actor.z, undefined, arena)) {
   throw Error('Identity constructor produced an unsupported/blocked spawn');
  }
 }
 return match;
}
export const LIMITS = Object.freeze({payload:16384, frame:1048576, outbound:2097152,
 messagesPerSecond:120, burst:128, connections:8});
export function validateConfig(frame) {
 if (!HORDE_MAPS.includes(frame.mapId) || frame.config?.mode !== 'horde') throw Error('Unsupported local Horde map/mode');
 const waves = frame.config.fragLimit === undefined ? 10 : frame.config.fragLimit;
 if (!Number.isInteger(waves) || waves < 1 || waves > 30) throw Error('Wave target must be 1..30');
 return normalizeConfig({mode:'horde',botCount:0,difficulty:'easy',fragLimit:waves,timeLimit:900});
}
// Source serial also allocates entities; payload id/type may overwrite emit's
// envelope. Follow retained event OBJECTS, never serial arithmetic or payload
// equality. Wire id is a per-round adapter ordinal, not a source global serial.
export class EventCursor {
 constructor() { this.previous=null; this.ordinal=0; }
 take(match) {
  const ring=match.events;
  const start=this.previous === null ? 0 : ring.indexOf(this.previous)+1;
  if (this.previous !== null && start === 0) throw Error('Source event ring cursor lost');
  const batch=ring.slice(start).map(event => ({...event,sourceId:event.id,id:++this.ordinal}));
  if (ring.length) this.previous=ring.at(-1);
  return batch;
 }
}
export function outboundAllowed(bytes, buffered) {
 return bytes <= LIMITS.frame && buffered + bytes <= LIMITS.outbound;
}
export function createAuthority({observe=()=>{}, debug} = {}) {
 if (debug !== undefined && typeof debug !== 'boolean') throw new TypeError('Debug flag must be boolean');
 // Off by default; explicit constructor flag or the operator's own COCS_DEBUG=1.
 const debugEnabled = debug === true || (debug === undefined && process.env.COCS_DEBUG === '1');
 const debugState = createDebugState({enabled:debugEnabled});
 const server = http.createServer({maxHeaderSize:8192}, (req,res) => {
  res.writeHead(200, {'Content-Type':'application/json'});
  res.end(JSON.stringify({service:'cocs-local-horde', transport:1, localOnly:true, port:server.address()?.port}));
 });
 server.maxConnections = LIMITS.connections;
 server.requestTimeout = 5000; server.headersTimeout = 5000; server.keepAliveTimeout = 1000;
 const wss = new WebSocketServer({noServer:true, maxPayload:LIMITS.payload, perMessageDeflate:false});
 const inputs = new InputBuffer();
 let socket=null, config=null, mapId=null, match=null, created=false, finished=false;
 let baseConfig=null;
 let round=0, seq=0, epoch=0, eventCursor=null, ticks=0, wall=performance.now(), accumulator=0, closing=false, closePromise;
 let tokens=LIMITS.burst, tokenAt=wall;
 const record = value => observe({...value, round, observedMs:performance.now()});
 function debugReset() {
  debugState.live = {godMode:false, playerIncomingScale:1, unlockAllWeapons:false};
  debugState.config = {}; debugState.queued = {}; debugState.autoUnlimited = false;
  debugState.constructed = {};
  baseConfig = null;
 }
 function debugReject(reason) {
  debugState.rejected++; debugState.lastReject = reason;
  record({direction:'debug-reject', reason});
  send({type:'debug-reject', reason});
 }
 // The solo Horde route constructs a fixed reviewed config every round, so it
 // has no construction-time debug knobs: only live knobs are advertised.
 function applyDebugToMatch(active) {
  if (!debugState.enabled || !active) return;
  applyLiveOverrides(active, debugState.config, baseConfig);
  installHumanGuard(active, debugState.live, HUMAN_SEAT);
  reconcileHuman(active, debugState);
 }
 function detach(ws) {
  if (socket !== ws) return;
  socket=null; match=null; config=null; mapId=null; created=false; finished=false;
  inputs.reset(); accumulator=0; eventCursor=null;
  debugReset();
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
 const lobby = () => send({type:'lobby',mapId,config,players:[{peerId:0,actorId:0,name:'Local player'}],
  // Additive debug capability echo; absent for every ordinary connection.
  ...(debugEnabled ? {debug:debugEcho(debugState)} : {})});
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
     // The launch-fixed map id only selects between two reviewed families: the
     // historical source constructor and the static identity hook above.
     match=createHordeMatch({mapId,config,random:Math.random});
     if (match.arena.id !== mapId || match.config.mode !== 'horde') throw Error('Source substituted map/mode');
     baseConfig={...match.config};
     debugState.constructed={...debugState.queued};
     // Round boundary: god mode is round-scoped and always clears here.
     debugState.live.godMode=false;
     applyDebugToMatch(match);
     round++; seq=0; epoch++; eventCursor=new EventCursor(); ticks=0; finished=false; inputs.reset();
     // Consume construction's ring before any step can shift it. The supported
     // solo preset constructs one spawn event; no historical events are inferred.
     const initialEvents=eventCursor.take(match);
     // Construction cost must not advance the new match's source clock.
     wall=performance.now(); accumulator=0;
     send({type:'start',mapId,inputEpoch:epoch});
     if (initialEvents.length) send({type:'events',items:initialEvents});
    } else if (f.type === 'input' && match) {
     if (match.over) return; // benign inputs already in flight at results
     if (f.inputEpoch !== epoch) return; // old round/death/stall cannot re-arm input
     const parsed=parseInputEnvelope(f);
     inputs.receive(f.seq,parsed,now,f.cancel === true);
     // A dying actor's queued actions must not execute on a later respawn.
     if (match.actors[0].health <= 0) inputs.cancel();
    } else if (f.type === 'debug' && created) {
     // Additive debug frame. With the channel disabled this falls through to the
     // unchanged rejection path (error + terminate).
     if (!debugEnabled) throw Error('Invalid local lifecycle command');
     let parsed;
     try { parsed = parseDebugFrame(f); }
     catch (error) { debugReject(error.message); return; }
     if (parsed.set.botCount !== undefined || parsed.set.startingWeapon !== undefined) {
      debugReject('construction-time knobs are not supported on the solo Horde route');
      return;
     }
     if (parsed.set.testDamage !== undefined && (!match || match.over)) {
      debugReject('testDamage requires a live round');
      return;
     }
     const touched=applyDebugFrame(debugState,parsed);
     if (match && !match.over) {
      applyDebugToMatch(match);
      if (touched.includes('unlockAllWeapons') && debugState.live.unlockAllWeapons !== true) {
       restoreSpawnAmmo(match,match.actors[HUMAN_SEAT]);
      }
      if (parsed.set.testDamage !== undefined) {
       match.damage(match.actors[HUMAN_SEAT],parsed.set.testDamage,undefined,false);
      }
     }
     send({type:'debug-state',debug:debugEcho(debugState)});
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
    // Port-only human-seat reconciliation before the death/cancel decision.
    if (debugEnabled) {
     const applied=reconcileHuman(active,debugState);
     if (applied && (applied.restoredDeath || applied.healthLost > 0 || applied.grantedAmmo)) {
      record({direction:'debug-reconcile',...applied,sourceTime:active.time});
     }
    }
    inputs.stepped(sample.seq);
    record({direction:'step',inputSeq:sample.seq,inputEpoch:epoch,controls:sample.input,
     sourceTime:active.time,...inputs.status()});
    if (alive && active.actors[0].health <= 0) cancelControls('death');
    const events=eventCursor.take(active);
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
   socket=null; match=null; eventCursor=null;
  })();
  return closePromise;
 }};
}
