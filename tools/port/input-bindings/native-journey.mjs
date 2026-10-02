// Explicitly queued for the parent's exclusive engine slot. Never run as part of
// the source oracle. This runner observes normal authority, with no actor writes.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {mkdirSync, writeFileSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {createGameServer} from '../../../server/game-server.mjs';

assert(process.argv.includes('--engine-granted'), 'parent must explicitly grant the exclusive engine slot');
const binary = process.env.GODOT_BIN;
assert(binary, 'GODOT_BIN must identify the pinned Godot');
const compact = process.argv.includes('--compact');
const out = resolve(process.env.EVIDENCE_DIR ?? `/tmp/opencode/input-bindings-${Date.now()}`);
mkdirSync(out, {recursive:true});
const game = createGameServer({historyPath:null, progressionPath:null});
const wire = [], events = [], stages = [];
let silence = false, start = 0, eventStart = 0;
game.wss.on('connection', socket => {
  socket.on('message', raw => { const f = JSON.parse(raw); if (f.type === 'input') wire.push(f); });
  const send = socket.send;
  socket.send = function(raw, ...rest) {
    const f = JSON.parse(String(raw));
	if (f.type === 'events') events.push(...(f.items ?? []));
    if (silence && ['snapshot','events'].includes(f.type)) return;
    return send.call(this, raw, ...rest);
  };
});
await new Promise(r => game.server.listen(0, '127.0.0.1', r));
const fields = ['x','z','fire','ads','jump','sprint','crouch','power','melee','grenade','mobility','interact','reload','altFire'];
const control = createServer((req, res) => {
  try {
    const stage = req.url.slice(1);
    if (stage.endsWith('-start')) { start = wire.length; eventStart = events.length; }
    else if (stage.endsWith('-end')) {
      const packets = wire.slice(start);
      assert(packets.length >= 3, 'several real sampled wire packets');
      const counts = Object.fromEntries(fields.map(k => [k, packets.filter(f => Boolean(f.input[k])).length]));
      if (stage === 'new-end') {
        assert.equal(counts.power, 1, 'remapped power queues exactly once while held');
        assert.equal(counts.melee, 1, 'remapped melee queues exactly once while held');
        for (const k of ['fire','mobility','crouch']) assert(counts[k] > 2, 'held samples '+k);
        assert(counts.x + counts.z > 2, 'mapped held movement samples');
        const effects = events.slice(eventStart).filter(e => e.actor === 0);
        for (const type of ['power','melee']) assert.equal(effects.filter(e => e.type === type).length, 1, 'actual source effect exactly once: '+type);
      } else assert(Object.values(counts).every(n => n === 0), 'old keys / boundary cannot replay '+JSON.stringify(counts));
      stages.push({stage, packets:packets.length, counts, authorityEvents:events.slice(eventStart)});
    } else if (stage === 'silence' || stage === 'resume') silence = stage === 'silence';
    else throw Error('unknown stage '+stage);
    res.end('ok');
  } catch (error) {
    stages.push({stage:req.url, error:String(error)});
    res.statusCode = 500;
    res.end(String(error));
  }
});
await new Promise(r => control.listen(0, '127.0.0.1', r));
const args = ['-a', binary, '--audio-driver','Dummy','--path',resolve('godot'),'--script','res://tests/input_bindings/native_journey.gd','--',
  `--bindings-out=${out}`,`--bindings-control=http://127.0.0.1:${control.address().port}`,`--endpoint=ws://127.0.0.1:${game.server.address().port}`,
  '--map=meridian-exchange','--mode=deathmatch','--bots=0','--operator=chatgpt','--harness=codex','--native-trace'];
if (compact) args.push('--bindings-compact');
const child = spawn('xvfb-run', args, {detached:true, env:{...process.env, LP_NUM_THREADS:'1', LIBGL_ALWAYS_SOFTWARE:'1',
  COCS_SETTINGS_PATH:resolve(out,'settings.json'), COCS_BINDINGS_PATH:resolve(out,'bindings.json')}, stdio:['ignore','pipe','pipe']});
let log = '', killTimer;
const stop = signal => { try { process.kill(-child.pid, signal); } catch {} };
for (const stream of [child.stdout, child.stderr]) stream.on('data', chunk => { log += chunk; });
const timeout = setTimeout(() => { stop('SIGTERM'); killTimer = setTimeout(() => stop('SIGKILL'), 5000); }, 80000);
try {
  const code = await new Promise((r,j) => { child.on('error', j); child.on('close', r); });
  assert.equal(code, 0, 'native exit; inspect '+out);
  assert(!/SCRIPT ERROR|Parse Error|^ERROR:/m.test(log), 'native diagnostic error; inspect '+out);
  assert.equal(JSON.parse(readFileSync(resolve(out,'native.json'))).failures.length, 0);
  assert(stages.some(s => s.stage === 'new-end') && !stages.some(s => s.error), 'source wire contracts');
  console.log('INPUT_BINDINGS_NATIVE_PASS', compact ? 'compact/UI150' : 'wide/UI100', out);
} finally {
  clearTimeout(timeout); clearTimeout(killTimer); stop('SIGTERM');
  writeFileSync(resolve(out,'native.log'), log);
  writeFileSync(resolve(out,'wire.json'), JSON.stringify(wire, null, 2));
  writeFileSync(resolve(out,'stages.json'), JSON.stringify(stages, null, 2));
  for (const socket of game.wss.clients) socket.terminate();
  await game.close();
  await new Promise(r => control.close(r));
  writeFileSync(resolve(out,'teardown.json'), JSON.stringify({pid:child.pid,exitCode:child.exitCode,signalCode:child.signalCode}));
}
