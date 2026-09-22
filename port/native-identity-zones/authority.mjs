// Owned loopback authority for the identity-map Domination route (Vermilion Fold).
//
// Unbound Horde/native-arena-compatible `{server,wss,close}` interface. One
// local human owns actor/peer 0, every other seat is a genuine source bot. The
// existing protocol v3 contract is reused verbatim: `nativeArenaInput:1`
// epochs, FIFO bounded inputs with TTL + explicit cancellation, an event cursor
// with wire ordinals, source snapshots every third tick, source results and
// clean restart. HTTP is a loopback readiness probe on GET `/` only.
//
// Launch-time map/mode come from the static allowlist; a WebSocket frame can
// never select another map, supply a path or send arena JSON. `arenaData` stays
// a trusted in-process synthetic fixture seam.
import http from 'node:http';
import {WebSocketServer, WebSocket} from 'ws';
import {parseInputEnvelope} from '../../game/protocol.mjs';
import {LIMITS, EventCursor, outboundAllowed} from '../native-arenas/authority.mjs';
import {keys, record, readNativeArena, parseArenaEnvelope} from '../native-arenas/schema.mjs';
import {InputBuffer} from '../native-arenas/input-buffer.mjs';
import {applyDebugFrame, applyLiveOverrides, createDebugState, debugEcho, installHumanGuard,
  parseDebugFrame, reconcileHuman, restoreSpawnAmmo, HUMAN_SEAT, RESTART_KNOBS} from '../native-debug/debug.mjs';
// Reviewed bounds for the construction-time debug knobs on THIS route. The zone
// scene advertises bots 0..7, so the debug channel advertises exactly that.
export const DEBUG_RESTART_BOUNDS = Object.freeze({
  botCount:[0, 7], startingWeapon:[RESTART_KNOBS.startingWeapon[0], RESTART_KNOBS.startingWeapon[1]],
});
import {IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE, identityZoneAllowed, identityZoneEntry} from './catalog.mjs';
import {createIdentityZoneMatch, validateIdentityZoneConfig} from './match.mjs';

export {EventCursor};
export const LOOPBACK = Object.freeze(['127.0.0.1', '::1', '::ffff:127.0.0.1']);
const wireInteger = value => Number.isSafeInteger(value) && value >= 0;
const name = value => typeof value === 'string' ? value.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, 20) : 'Local player';
const ruleFields = ['mode', 'botCount', 'difficulty', 'timeLimit', 'fragLimit'];
const minimalConfig = config => Object.fromEntries(ruleFields.map(key => [key, config[key]]));

export function createAuthority(options = {}) {
  if (!record(options)) throw new TypeError('Identity zone authority options must be an object');
  const allowed = ['mapId', 'config', 'random', 'observe', 'arenaData', 'botCount', 'timeLimit',
    'fragLimit', 'difficulty', 'mode', 'bots', 'roundSeconds', 'debug'];
  const unknown = Object.keys(options).filter(key => !allowed.includes(key));
  if (unknown.length) throw new TypeError(`Unsupported identity zone authority option: ${unknown[0]}`);
  const {mapId = IDENTITY_ZONE_MAP_ID, config = {}, random = Math.random, observe = () => {},
    arenaData, botCount, timeLimit, fragLimit, difficulty, mode, bots, roundSeconds, debug} = options;
  if (debug !== undefined && typeof debug !== 'boolean') throw new TypeError('Debug flag must be boolean');
  // Debug is off by default and needs an explicit switch: the constructor flag
  // or the operator's own COCS_DEBUG=1 environment. An explicit `debug:false`
  // overrides the environment so a scripted run can force the channel off.
  const debugEnabled = debug === true || (debug === undefined && process.env.COCS_DEBUG === '1');
  const debugState = createDebugState({enabled:debugEnabled});
  const debugLimits = () => ({botCount:[...DEBUG_RESTART_BOUNDS.botCount], startingWeapon:[...DEBUG_RESTART_BOUNDS.startingWeapon]});
  const entry = identityZoneEntry(mapId);
  if (mode !== undefined && mode !== IDENTITY_ZONE_MODE) throw new TypeError('Identity zone authority supports domination only');
  if (typeof random !== 'function' || typeof observe !== 'function') throw new TypeError('RNG/observer must be functions');
  if (bots !== undefined && botCount !== undefined && bots !== botCount) throw new TypeError('Conflicting bot counts');
  if (roundSeconds !== undefined && timeLimit !== undefined && roundSeconds !== timeLimit) throw new TypeError('Conflicting time limits');
  const overrides = Object.fromEntries(Object.entries({mode, botCount:botCount !== undefined ? botCount : bots,
    timeLimit:timeLimit !== undefined ? timeLimit : roundSeconds, fragLimit, difficulty}).filter(([, value]) => value !== undefined));
  const defaults = minimalConfig(validateIdentityZoneConfig({...config, ...overrides}));
  // Resolve only the launch-selected static asset, before opening any socket.
  const data = arenaData === undefined ? readNativeArena(entry.id) : parseArenaEnvelope(arenaData, entry.id);
  const server = http.createServer({maxHeaderSize:8192}, (req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, {'Content-Type':'application/json', 'Allow':'GET, HEAD'});
      res.end('{"error":"method not allowed"}'); return;
    }
    if ((req.url ?? '/') !== '/') {
      res.writeHead(404, {'Content-Type':'application/json'});
      res.end('{"error":"not found"}'); return;
    }
    res.writeHead(200, {'Content-Type':'application/json'});
    res.end(JSON.stringify({service:'cocs-native-identity-zones', v:1, localOnly:true,
      humanCount:1, mapId:entry.id, mode:IDENTITY_ZONE_MODE, geometryHash:data.geometryHash,
      port:server.address()?.port}));
  });
  server.maxConnections = LIMITS.connections;
  server.requestTimeout = 5000; server.headersTimeout = 5000; server.keepAliveTimeout = 1000;
  const wss = new WebSocketServer({noServer:true, maxPayload:LIMITS.payload, perMessageDeflate:false});
  const inputs = new InputBuffer();
  let socket = null, match = null, selectedConfig = null, created = false, finished = false;
  let round = 0, seq = 0, epoch = 0, eventCursor = null, ticks = 0;
  let wall = performance.now(), accumulator = 0, closing = false, closePromise;
  let tokens = LIMITS.burst, tokenAt = wall, epochRequired = false, playerName = 'Local player';
  const report = value => observe({...value, round, observedMs:performance.now()});
  function resetDebugChannel() {
    debugState.live = {godMode:false, playerIncomingScale:1, unlockAllWeapons:false};
    debugState.config = {}; debugState.queued = {}; debugState.autoUnlimited = false;
    debugState.constructed = {};
  }
  function debugReject(reason) {
    debugState.rejected++; debugState.lastReject = reason;
    report({direction:'debug-reject', reason});
    send({type:'debug-reject', reason});
  }
  // LIVE application: the locked source reads config/mutators/difficulty every tick,
  // so these take effect on the next step. Only knobs the running round was actually
  // constructed with are folded into the live config, so a queued bot count never makes
  // the public config echo claim a roster it does not have. The guard and the post-step
  // reconcile only ever inspect the single human seat.
  function applyDebugToMatch(active) {
    if (!debugState.enabled || !active) return;
    applyLiveOverrides(active, {...debugState.constructed, ...debugState.config}, defaults);
    installHumanGuard(active, debugState.live, HUMAN_SEAT);
    reconcileHuman(active, debugState);
  }
  function detach(ws) {
    if (socket !== ws) return;
    socket = null; match = null; selectedConfig = null; created = false; finished = false;
    epochRequired = false; inputs.reset(); accumulator = 0; eventCursor = null;
    resetDebugChannel();
  }
  function terminate(reason) {
    report({direction:'transport-error', reason});
    const ws = socket;
    if (ws) { detach(ws); ws.terminate(); }
  }
  function send(frame) {
    if (socket?.readyState !== WebSocket.OPEN) return;
    const text = JSON.stringify(frame);
    if (!outboundAllowed(Buffer.byteLength(text), socket.bufferedAmount)) { terminate('Outbound limit'); return; }
    report({direction:'out', frame:JSON.parse(text)});
    const ws = socket;
    ws.send(text, error => { if (error && socket === ws) terminate('Send failed'); });
  }
  const lobby = () => send({type:'lobby', roomId:'local-identity-zone', hostId:0,
    mapId:selectedConfig ? entry.id : null, config:selectedConfig,
    started:!!match && !finished, roundRevision:round,
    // Additive debug capability echo: only present when the operator enabled the
    // channel, so an ordinary lobby frame is byte-identical to before.
    ...(debugEnabled ? {debug:debugEcho(debugState, debugLimits())} : {}),
    players:[{peerId:0, actorId:0, name:playerName, connected:true, spectate:false}]});
  function cancelControls(reason) {
    inputs.cancel(); epoch++;
    send({type:'native-arena-input-reset', inputEpoch:epoch, reason});
    report({direction:'control-reset', reason, inputEpoch:epoch, ...inputs.status()});
  }
  server.on('upgrade', (req, stream, head) => {
    if (closing || socket || !LOOPBACK.includes(req.socket.remoteAddress) ||
        Object.hasOwn(req.headers, 'origin') || !['/', '/native-zones'].includes(req.url)) {
      stream.destroy(); return;
    }
    wss.handleUpgrade(req, stream, head, ws => wss.emit('connection', ws, req));
  });
  server.on('clientError', (_error, stream) => stream.destroy());
  wss.on('error', () => terminate('WebSocket server error'));
  wss.on('connection', ws => {
    socket = ws; tokens = LIMITS.burst; tokenAt = performance.now();
    ws.on('error', () => { detach(ws); ws.terminate(); });
    ws.on('close', () => detach(ws));
    ws.on('message', (bytes, binary) => {
      if (socket !== ws || closing) return;
      const now = performance.now();
      tokens = Math.min(LIMITS.burst, tokens + (now - tokenAt) * LIMITS.messagesPerSecond / 1000);
      tokenAt = now;
      if (--tokens < 0 || binary) { terminate(binary ? 'Binary input unsupported' : 'Message rate limit'); return; }
      try {
        const f = JSON.parse(String(bytes));
        if (!record(f)) throw new TypeError('Object envelope required');
        report({direction:'in', frame:structuredClone(f)});
        if (f.type === 'create' && !created) {
          keys(f, ['type', 'v', 'name', 'playerName', 'delta', 'nativeArenaInput'], 'create frame');
          if (f.v !== 3 || (f.delta !== undefined && f.delta !== 0)) throw new TypeError('Protocol 3 full snapshots required');
          if (f.nativeArenaInput !== undefined && f.nativeArenaInput !== 1) throw new TypeError('Unsupported native input extension');
          for (const key of ['name', 'playerName']) if (f[key] !== undefined && (typeof f[key] !== 'string' || f[key].length > 128)) throw new TypeError('Invalid player/room name');
          created = true; epochRequired = f.nativeArenaInput === 1; playerName = name(f.playerName);
          send({type:'welcome', v:3, roomId:'local-identity-zone', peerId:0, host:true,
            nativeArenaInput:1, humanCount:1, geometryHash:data.geometryHash});
          lobby();
        } else if (f.type === 'host' && created && (!match || match.over)) {
          keys(f, ['type', 'mapId', 'config'], 'host frame');
          if (f.mapId !== entry.id || f.config?.mode !== IDENTITY_ZONE_MODE) throw new TypeError('Unsupported launch map/mode');
          keys(f.config, ruleFields, 'Domination config');
          selectedConfig = validateIdentityZoneConfig({...defaults, ...f.config});
          match = null; finished = false; lobby();
        } else if (f.type === 'start' && selectedConfig && (!match || match.over)) {
          keys(f, ['type'], 'start frame');
          match = createIdentityZoneMatch({mapId:entry.id, config:minimalConfig(selectedConfig), random, arenaData:data});
          debugState.constructed = {...debugState.config};
          applyDebugToMatch(match);
          round++; seq = 0; epoch++; ticks = 0; finished = false; inputs.reset();
          eventCursor = new EventCursor();
          const initialEvents = eventCursor.take(match);
          // Constructor work is not simulation time.
          wall = performance.now(); accumulator = 0;
          send({type:'start', mapId:entry.id, mode:IDENTITY_ZONE_MODE, inputEpoch:epoch,
            roundRevision:round, geometryHash:data.geometryHash});
          if (initialEvents.length) send({type:'events', items:initialEvents});
          send({type:'snapshot', seq:++seq, acks:{0:0}, inputEpoch:epoch,
            nativeArenaInput:inputs.status(), state:match.snapshot()});
        } else if (f.type === 'input' && match) {
          keys(f, ['type', 'seq', 'input', 'inputEpoch', 'cancel'], 'input frame');
          if (!wireInteger(f.seq) || f.seq < 1 || !record(f.input)) throw new TypeError('Invalid input sequence/payload');
          keys(f.input, ['x', 'z', 'yaw', 'pitch', 'weapon', 'fire', 'jump', 'power', 'interact',
            'sprint', 'crouch', 'ads', 'reload', 'melee', 'grenade', 'mobility', 'altFire'], 'controls');
          if (f.cancel !== undefined && typeof f.cancel !== 'boolean') throw new TypeError('Invalid input cancellation');
          if (f.inputEpoch !== undefined && (!wireInteger(f.inputEpoch) || f.inputEpoch < 1)) throw new TypeError('Invalid input epoch');
          if (match.over) return;
          if ((epochRequired || f.inputEpoch !== undefined) && f.inputEpoch !== epoch) return;
          const parsed = parseInputEnvelope(f);
          inputs.receive(f.seq, parsed, now, f.cancel === true);
          if (match.actors[0].health <= 0) inputs.cancel();
        } else if (f.type === 'debug' && created) {
          // Additive debug frame. With the channel disabled this falls through to the
          // unchanged rejection path below (error + terminate), so an ordinary
          // authority never gains a debug surface.
          if (!debugEnabled) throw new Error('Invalid local identity zone lifecycle command');
          let parsed;
          try { parsed = parseDebugFrame(f); }
          catch (error) { debugReject(error.message); return; }
          const bound = DEBUG_RESTART_BOUNDS.botCount;
          if (parsed.set.botCount !== undefined && (parsed.set.botCount < bound[0] || parsed.set.botCount > bound[1])) {
            debugReject(`botCount must be ${bound[0]}..${bound[1]} on this route`);
            return;
          }
          if (parsed.set.testDamage !== undefined && (!match || match.over)) {
            debugReject('testDamage requires a live round');
            return;
          }
          const touched = applyDebugFrame(debugState, parsed);
          if (match && !match.over) {
            applyDebugToMatch(match);
            // Reversibility: switching unlock-all off restores the source's spawn ammo belt.
            if (touched.includes('unlockAllWeapons') && debugState.live.unlockAllWeapons !== true) {
              restoreSpawnAmmo(match, match.actors[HUMAN_SEAT]);
            }
            if (parsed.set.testDamage !== undefined) {
              match.damage(match.actors[HUMAN_SEAT], parsed.set.testDamage, undefined, false);
            }
          }
          send({type:'debug-state', debug:debugEcho(debugState, debugLimits())});
        } else if (f.type === 'ping' && created) {
          keys(f, ['type', 't'], 'ping frame');
          send({type:'pong', ...(Number.isFinite(f.t) ? {t:f.t} : {})});
        } else throw new Error('Invalid local identity zone lifecycle command');
      } catch (error) {
        send({type:'error', message:error.message}); terminate(error.message);
      }
    });
  });
  const timer = setInterval(() => {
    const now = performance.now(), elapsed = Math.max(0, (now - wall) / 1000); wall = now;
    if (!match || finished) { accumulator = 0; return; }
    accumulator = Math.min(accumulator + elapsed, 5 / 60);
    try {
      for (let steps = 0; accumulator >= 1 / 60 && steps < 5 && match && !finished; steps++) {
        accumulator -= 1 / 60;
        if (inputs.expired(now)) cancelControls('stale-input');
        const sample = inputs.take(), active = match, alive = active.actors[0].health > 0;
        active.step(1 / 60, {inputs:{0:sample.input}});
        const reconciled = reconcileHuman(active, debugState);
        inputs.stepped(sample.seq);
        report({direction:'step', inputSeq:sample.seq, inputEpoch:epoch,
          controls:{...sample.input}, sourceTime:active.time, ...inputs.status()});
        if (alive && active.actors[0].health <= 0) cancelControls('death');
        const events = eventCursor.take(active);
        if (events.length) send({type:'events', items:events});
        if (++ticks % 3 === 0 || active.over) send({type:'snapshot', seq:++seq, acks:{0:inputs.applied},
          inputEpoch:epoch, nativeArenaInput:inputs.status(), state:active.snapshot()});
        if (active.over) {
          finished = true; inputs.cancel();
          send({type:'results', inputEpoch:epoch, nativeArenaInput:inputs.status(), state:active.snapshot()});
        }
      }
    } catch (error) { terminate(`Authority step failed: ${error.message}`); }
  }, 1000 / 60);
  return {server, wss, mapId:entry.id, mode:IDENTITY_ZONE_MODE, close() {
    if (closePromise) return closePromise;
    closing = true; clearInterval(timer); inputs.cancel();
    closePromise = (async () => {
      for (const ws of wss.clients) ws.terminate();
      await new Promise(resolve => wss.close(resolve));
      server.closeAllConnections();
      if (server.listening) await new Promise(resolve => server.close(resolve));
      socket = null; match = null; eventCursor = null;
    })();
    return closePromise;
  }};
}

/** Launch-ready API. Resolves only after binding; close owns its sockets/timer. */
export async function createIdentityZoneAuthority({port = 0, host = '127.0.0.1', ...options} = {}) {
  if (!['127.0.0.1', '::1'].includes(host)) throw new TypeError('Identity zone authority must bind loopback');
  if (!Number.isInteger(port) || port < 0 || port > 65535) throw new TypeError('Invalid port');
  const authority = createAuthority(options);
  try {
    await new Promise((resolve, reject) => {
      const onError = error => reject(error);
      authority.server.once('error', onError);
      authority.server.listen(port, host, () => { authority.server.off('error', onError); resolve(); });
    });
  } catch (error) { await authority.close(); throw error; }
  const bound = authority.server.address().port;
  return {...authority, port:bound, endpoint:`ws://${host === '::1' ? '[::1]' : host}:${bound}/native-zones`};
}

export {IDENTITY_ZONE_MAP_ID, IDENTITY_ZONE_MODE, identityZoneAllowed, identityZoneEntry,
  createIdentityZoneMatch, validateIdentityZoneConfig};
