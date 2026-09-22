// Real source-Match authority + native scene smoke. Owns/cleans each listener and
// child; no pre-existing listener is reused. This does not accept rendered FPS.
import {spawn, execFileSync} from 'node:child_process';
import {mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {join, resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const evidence = fileURLToPath(new URL('./evidence/', import.meta.url));
const godot = process.env.GODOT_BIN || '/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const args = process.argv.slice(2), destinations = args.filter(arg => arg.startsWith('--output='));
if (destinations.length > 1 || destinations.some(arg => arg === '--output=')) throw Error('Use --output=<new-directory> once');
const selected = args.filter(arg => !arg.startsWith('--output='));
const maps = selected.length ? selected : ['prism-foundry', 'aurora-basin', 'cinder-array'];
if (new Set(maps).size !== maps.length || maps.some(map => !['prism-foundry','aurora-basin','cinder-array'].includes(map))) throw Error('Select unique native arena map IDs');
await mkdir(evidence, {recursive:true});
// Every invocation owns a fresh directory; old failures and screenshots survive.
const output = destinations.length ? resolve(destinations[0].slice('--output='.length)) : await mkdtemp(join(evidence,'live-'));
if (destinations.length) await mkdir(output); // EEXIST is intentional, never overwrite evidence.
console.log('NATIVE_DM_LIVE_OUTPUT', output);
const lock = JSON.parse(await readFile(new URL('../contracts/source-lock.json', import.meta.url)));
if (execFileSync(godot,['--version'],{encoding:'utf8'}).trim() !== lock.godot_version) throw Error('Godot version differs from pinned 4.5.2 lock');
const report = [];
for (const map of maps) {
  let actorShots = 0, publicSnapshots = 0, appliedInputs = 0, authorityHash = '';
  const lifecycle = [];
  let authority, child, childDone, timer, runtime, log = '', result;
  const started = performance.now();
  try {
    authority = await createNativeArenaAuthority({port:0, host:'127.0.0.1', mapId:map, bots:2, roundSeconds:60, observe(record) {
      if (record.direction === 'transport-error' || (['in','out'].includes(record.direction) && ['create','host','lobby','start','error'].includes(record.frame?.type))) {
        lifecycle.push({wallSeconds:(performance.now()-started)/1000, direction:record.direction,
          type:record.frame?.type, reason:record.reason, frame:record.frame});
      }
      if (record.direction !== 'out') return;
      if (record.frame.type === 'start') authorityHash = record.frame.geometryHash;
      if (record.frame.type === 'snapshot') {
        publicSnapshots++;
        actorShots = Math.max(actorShots, record.frame.state.actors.find(a => a.id === 0)?.shots ?? 0);
        appliedInputs = Math.max(appliedInputs, record.frame.acks[0] ?? 0);
      }
    }});
    runtime = await mkdtemp(join(tmpdir(),'native-dm-live-'));
    const env = {...process.env};
    for (const name of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {
      env[name] = join(runtime,name); await mkdir(env[name]);
    }
    childDone = new Promise((resolve, reject) => {
      child = spawn(godot, ['--headless', '--audio-driver', 'Dummy', '--path', 'godot', 'res://native_arenas/demo.tscn', '--',
        '--experience=native-dm', `--map=${map}`, '--mode=deathmatch', `--endpoint=${authority.endpoint}`,
        '--bots=2', '--round-seconds=60', '--smoke', '--mute'], {cwd:root, env, stdio:['ignore','pipe','pipe']});
      child.stdout.on('data', data => {log += data;});
      child.stderr.on('data', data => {log += data;});
      child.once('error', reject);
      child.once('exit', (code, signal) => resolve({code, signal}));
      timer = setTimeout(() => child.kill('SIGKILL'), 25000);
    });
    result = await childDone;
    const marker = log.split(/\r?\n/).find(line => line.startsWith('NATIVE_DM_SMOKE_OK '));
    const data = marker ? JSON.parse(marker.slice('NATIVE_DM_SMOKE_OK '.length)) : null;
    if (result.code !== 0 || !data || data.map !== map || !data.moved || !data.fired || !data.localAlive || data.actors !== 3 || data.geometryHash !== authorityHash || !authorityHash || data.acks <= 0 || actorShots <= 0 || appliedInputs <= 0 || /SCRIPT ERROR|^ERROR:/m.test(log)) {
      throw new Error(`Native smoke failed: ${map} ${JSON.stringify(result)}\n${log.slice(-6000)}`);
    }
    report.push({map, ...data, authorityPublicSnapshots:publicSnapshots, authorityActorShots:actorShots,
      authorityAppliedInputs:appliedInputs, lifecycle, wallSeconds:(performance.now()-started)/1000, evidence:'live-authority-headless', passed:true});
    console.log('NATIVE_DM_LIVE_VERIFIED', JSON.stringify(report.at(-1)));
  } catch (error) {
    log += `\nLIVE_SMOKE_FAILURE ${error.stack}\n`;
    report.push({map, passed:false, error:error.message, result:result ?? null,
      authorityPublicSnapshots:publicSnapshots, authorityActorShots:actorShots, authorityAppliedInputs:appliedInputs, lifecycle,
      wallSeconds:(performance.now()-started)/1000, evidence:'live-authority-headless'});
    console.error('NATIVE_DM_LIVE_FAILED', map, error.message);
    process.exitCode = 1;
  } finally {
    clearTimeout(timer);
    if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
    if (childDone) await childDone.catch(()=>{});
    if (authority) await authority.close();
    if (runtime) await rm(runtime,{recursive:true,force:true,maxRetries:5,retryDelay:100});
    await writeFile(`${output}/${map}-live-smoke.log`, log, {flag:'wx'});
  }
  if (process.exitCode) break;
}
await writeFile(`${output}/live-smoke.json`, JSON.stringify({renderedPerformanceAcceptance:false, runs:report}, null, 2) + '\n', {flag:'wx'});
