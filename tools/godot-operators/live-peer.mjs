// Real production-protocol remote peers for the source-operator live session.
// Both join the default local room and send ordinary input frames forever:
// continuous walking, rocket fire against a finite magazine, and explicit reload
// edges. The authority stays authoritative; nothing is written into its state.
// The host peer owns the match config and the round restart; the guest peer is
// simply a second remote human actor.
import {writeFileSync} from 'node:fs';
const [readyPath, url, role = 'host'] = process.argv.slice(2);
const name = role === 'host' ? 'SourcePeerHost' : 'SourcePeerGuest';
const ws = new WebSocket(url);
let peerId = null;
let seq = 0;
let guestSeen = false;
let startSent = false;
let restartSent = false;
let started = false;
const t0 = Date.now();
let lastLog = 0;

function send(frame) { if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(frame)); }
function log(line) { console.log(line); }

ws.onopen = () => send({type: 'join', name, character: role === 'host' ? 'gemini' : 'mistral', harness: 'cline', v: 3, delta: 0});
ws.onmessage = event => {
  const m = JSON.parse(event.data);
  if (m.type === 'welcome') {
    peerId = m.peerId;
    if (role === 'host') send({type: 'host', mapId: 'meridian-exchange', config: {mode: 'deathmatch', botCount: 2, timeLimit: 60, fragLimit: 100, difficulty: 'easy', startingWeapon: 1}});
    writeFileSync(readyPath, JSON.stringify({peerId, roomId: m.roomId, host: m.host === true, role}));
    log('PEER_READY role=' + role + ' room=' + m.roomId + ' peer=' + peerId + ' host=' + m.host);
  } else if (m.type === 'lobby') {
    const guests = (m.players || []).filter(player => player.peerId !== peerId && player.connected !== false && player.spectate !== true);
    if (!guestSeen && guests.length >= 2) { guestSeen = true; log('PEER_GUESTS_SEEN ' + guests.map(player => player.peerId).join(',')); }
    if (guestSeen && !startSent && m.hostId === peerId) { startSent = true; send({type: 'start'}); log('PEER_START_SENT'); }
  } else if (m.type === 'snapshot') {
    started = true;
    const me = m.state.actors.find(actor => actor.name === name);
    if (me && Date.now() - lastLog > 5000) {
      lastLog = Date.now();
      log('PEER_STATE role=' + role + ' id=' + me.id + ' t=' + m.state.time.toFixed(0) + ' reloading=' + me.reloading + ' ammo=' + me.ammo[me.weapon] + ' shots=' + me.shots + ' x=' + me.x.toFixed(1) + ' z=' + me.z.toFixed(1));
    }
  } else if (m.type === 'results') {
    if (role === 'host' && !restartSent) { restartSent = true; setTimeout(() => { send({type: 'start'}); log('PEER_RESTART_SENT'); }, 400); }
  } else if (m.type === 'error') {
    log('PEER_ERROR ' + m.message);
  }
};
// 33ms cadence mirrors the shipped demo client; every frame is a normal input.
const timer = setInterval(() => {
  if (ws.readyState !== WebSocket.OPEN) return;
  const elapsed = (Date.now() - t0) / 1000;
  const input = {x: Math.sin(elapsed * 0.9 + (role === 'host' ? 0 : 2)) * 0.8, z: Math.cos(elapsed * 0.7 + (role === 'host' ? 0 : 2)) * 0.8, yaw: (elapsed * 0.45) % (Math.PI * 2), fire: true};
  const cycle = elapsed % 14;
  if (cycle > 12.6 && cycle < 13) input.reload = true;
  send({type: 'input', seq: ++seq, input});
}, 33);
setTimeout(() => { log('PEER_EXIT role=' + role); clearInterval(timer); ws.close(); process.exit(0); }, 110000);
