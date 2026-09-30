// Owns a real loopback campaign authority and Godot child. No simulation mocks.
import {spawn} from 'node:child_process';
import {mkdtemp, mkdir, writeFile, rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import {createAuthority} from '../native-campaign/authority.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const maps = process.argv.slice(2);
if (!maps.length) maps.push('rootfall-verge');
const roster = ['rootfall-verge', 'siltwake-crossing', 'emberline-ascent', 'crown-array'];
if (maps.some(id => !roster.includes(id))) throw Error('Select campaign map IDs');
const godot = process.env.GODOT_BIN || 'godot';
const output = await mkdtemp('/tmp/opencode/campaign-smoke-');
console.log('CAMPAIGN_SMOKE_OUTPUT', output);
for (const mapId of maps) {
  let authority, child, timer, done;
  let log = '', hash = '', shots = 0, ack = 0, snapshots = 0, moved = false, initial;
  const observe = record => {
    if (record.direction !== 'out') return;
    const frame = record.frame;
    if (frame?.type === 'start') hash = frame.geometryHash;
    if (frame?.type !== 'snapshot') return;
    snapshots++;
    const actor = frame.state.actors.find(actor => actor.id === 0);
    if (!actor) return;
    initial ??= {x:actor.x, z:actor.z};
    moved ||= Math.hypot(actor.x-initial.x, actor.z-initial.z) > 0.5;
    shots = Math.max(shots, actor.shots ?? 0);
    ack = Math.max(ack, frame.acks?.[0] ?? 0);
  };
  try {
    authority = await createAuthority({mapId, difficulty:'easy', observe});
    await new Promise((resolve, reject) => {
      authority.server.once('error', reject);
      authority.server.listen(0, '127.0.0.1', resolve);
    });
    const endpoint = `ws://127.0.0.1:${authority.server.address().port}/native-campaign`;
    const env = {...process.env};
    for (const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
      env[key] = join(output, mapId, key);
      await mkdir(env[key], {recursive:true});
    }
    done = new Promise((resolve, reject) => {
      child = spawn(godot, ['--headless','--audio-driver','Dummy','--path','godot',
        'res://campaign/demo.tscn','--',`--map=${mapId}`,'--mode=campaign',
        `--endpoint=${endpoint}`,'--difficulty=easy','--smoke','--mute'], {cwd:root,env,stdio:['ignore','pipe','pipe']});
      child.stdout.on('data', data => { log += data; });
      child.stderr.on('data', data => { log += data; });
      child.once('error', reject);
      child.once('exit', (code, signal) => resolve({code,signal}));
      timer = setTimeout(() => child.kill('SIGKILL'), 120000);
    });
    const result = await done;
    const line = log.split(/\r?\n/).find(line => line.startsWith('CAMPAIGN_SMOKE_OK '));
    const evidence = line ? JSON.parse(line.slice('CAMPAIGN_SMOKE_OK '.length)) : null;
    if (result.code !== 0 || !evidence || evidence.map !== mapId || !evidence.moved || !evidence.fired ||
        !evidence.firstPerson || evidence.robotsLoaded < 1 || evidence.acks <= 10 || evidence.combatShots < 1 ||
        !hash || evidence.geometryHash !== hash || shots < 1 || ack <= 10 || !moved || /SCRIPT ERROR|^ERROR:/m.test(log)) {
      throw Error(`Campaign real smoke failed ${mapId}: ${JSON.stringify(result)}\n${log.slice(-8000)}`);
    }
    await writeFile(join(output, `${mapId}.json`), JSON.stringify({evidence, authority:{hash,shots,ack,moved,snapshots}, renderedPerformanceAcceptance:false},null,2));
    console.log('CAMPAIGN_REAL_AUTHORITY_VERIFIED', mapId);
  } finally {
    clearTimeout(timer);
    if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    if (done) await done.catch(() => {});
    if (authority) await authority.close();
    await writeFile(join(output, `${mapId}.log`), log);
    await rm(join(output,mapId), {recursive:true,force:true});
  }
}
