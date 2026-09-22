// Run on an actual Linux host against a fresh extracted release, not a stub.
// Mirrors tools/godot-package/verify_windows.mjs case for case; the Linux package
// takes Node.js >=22.13.0 as an external prerequisite instead of bundling it, and
// every entry point that Windows reaches through a .cmd reaches the same run.mjs here.
import assert from 'node:assert/strict';
import {readFile, writeFile, mkdir, mkdtemp, rm, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {join, resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {createConnection} from 'node:net';
const exec = promisify(execFile);
const root = resolve(process.argv[2]);
const output = resolve(process.argv[3]);
assert.equal(process.platform, 'linux', 'Native Linux runner required');
await mkdir(output, {recursive:true});
const report = {platform:process.platform, node:process.version, status:'running', cases:[], graphical:false};
const sandbox = await mkdtemp(join(tmpdir(), 'cocs linux smoke '));
const env = {...process.env, TMPDIR:sandbox, TMP:sandbox, XDG_DATA_HOME:join(sandbox,'data'),
  XDG_CONFIG_HOME:join(sandbox,'config'), XDG_CACHE_HOME:join(sandbox,'cache')};
for (const dir of [env.XDG_DATA_HOME, env.XDG_CONFIG_HOME, env.XDG_CACHE_HOME]) await mkdir(dir, {recursive:true});
const sha = data => createHash('sha256').update(data).digest('hex');
async function closed(port) {
  return new Promise((resolve, reject) => {
    const socket = createConnection({host:'127.0.0.1',port});
    socket.setTimeout(3000, () => { socket.destroy(); reject(Error('Port check timeout')); });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', error => error.code === 'ECONNREFUSED' ? resolve(true) : reject(error));
  });
}
// Both launcher classes are one run.mjs invocation; the Windows verifier reaches the
// same code through Play.cmd and the menu files.
async function runManager(args, name, timeout) {
  let result;
  try {
    result = await exec(process.execPath, [join(root,'run.mjs'), ...args], {cwd:sandbox, env, timeout, maxBuffer:8*1024*1024});
  } catch (error) {
    await writeFile(join(output, name+'.log'), (error.stdout || '')+(error.stderr || '')+'\n'+error.message);
    throw error;
  }
  await writeFile(join(output, name+'.log'), result.stdout+result.stderr);
  return result;
}
try {
  const manifest = JSON.parse(await readFile(join(root,'manifest.json')));
  assert.equal(manifest.target, 'linux');
  assert.equal(manifest.operator_models, 'source-operators');
  assert.deepEqual(manifest.staged_native_overrides, {});
  const [minimum] = /\d+\.\d+\.\d+/.exec(manifest.play_node.replace('>=', ''));
  const current = process.version.replace(/^v/, '').split('.').map(Number);
  const required = minimum.split('.').map(Number);
  assert.ok(current[0] > required[0] || (current[0] === required[0] && (current[1] > required[1]
    || (current[1] === required[1] && current[2] >= required[2]))), `Node >=${minimum} required, running ${process.version}`);
  for (const [name, expected] of Object.entries(manifest.files)) {
    assert.equal(sha(await readFile(join(root,name))), expected, name);
  }
  report.manifest_sha256 = sha(await readFile(join(root,'manifest.json')));
  report.port_commit = manifest.port_commit;
  report.files_verified = Object.keys(manifest.files).length;
  assert.equal((await exec(join(root,'cocs.x86_64'), ['--headless','--version'])).stdout.trim(), manifest.godot_version);
  for (const map of ['meridian-exchange','verdant-reliquary','ember-crucible']) {
    const result = await runManager(['--smoke', `--map=${map}`], 'source-'+map, 60000);
    const text = result.stdout+result.stderr;
    assert.doesNotMatch(text, /SCRIPT ERROR|ERROR:|Assertion failed/);
    assert.match(text, /PORT_SESSION_SMOKE_OK actors=3/);
    assert.match(text, /PORT_OPERATOR_MODEL res:\/\/source_operators\/operator_visual\.gd/);
    assert.match(text, /PACKAGE_STOPPED/);
    const ready = JSON.parse(result.stdout.split('\n').find(l=>l.startsWith('PACKAGE_SERVER_READY ')).slice(21));
    const native = JSON.parse(result.stdout.split('\n').find(l=>l.startsWith('PACKAGE_NATIVE_STARTED ')).slice(23));
    assert.ok(await closed(ready.port), 'Owned authority listener closed');
    assert.throws(()=>process.kill(native.pid,0), 'Native process exited');
    assert.equal((await readdir(sandbox)).filter(n=>n.startsWith('cocs-native-')).length,0);
    report.cases.push({map,passed:true,port:ready.port,native_pid:native.pid,cleanup:true});
  }
  // The preview resource must also resolve in the exported PCK without a project.
  const preview = await exec(join(root,'cocs.x86_64'), ['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--quit-after','10','res://player_models/preview.tscn'], {cwd:sandbox,env,timeout:30000});
  await writeFile(join(output,'preview.log'),preview.stdout+preview.stderr);
  assert.doesNotMatch(preview.stdout+preview.stderr,/SCRIPT ERROR|ERROR:/);
  report.preview_load = true;
  for (const map of ['prism-foundry','aurora-basin','cinder-array','lacuna-court','vermilion-fold','nacre-engine']) {
    const result = await runManager(['--experience=native-dm', `--map=${map}`, '--smoke'], 'native-dm-'+map, 60000);
    const text = result.stdout+result.stderr;
    assert.doesNotMatch(text, /SCRIPT ERROR|ERROR:|Assertion failed/);
    assert.match(text, /NATIVE_DM_SMOKE_OK/);
    assert.match(text, /PACKAGE_STOPPED/);
    const ready = JSON.parse(result.stdout.split('\n').find(line=>line.startsWith('PACKAGE_SERVER_READY ')).slice(21));
    const native = JSON.parse(result.stdout.split('\n').find(line=>line.startsWith('PACKAGE_NATIVE_STARTED ')).slice(23));
    assert.ok(await closed(ready.port), 'Native arena authority listener closed');
    assert.throws(()=>process.kill(native.pid,0), 'Native arena process exited');
    report.cases.push({experience:'native-dm',map,passed:true,port:ready.port,native_pid:native.pid,cleanup:true});
  }
  // The reviewed Domination route: its own authority modules, /native-zones route and
  // identity scene must all resolve inside the extracted package. The shared session
  // smoke driver ends the round once combat is live, before the zone scene's stricter
  // per-marker smoke gate, so the assertions here are the session markers plus the
  // authority's own identity echo.
  {
    const result = await runManager(['--experience=identity-zones', '--map=vermilion-fold', '--smoke'], 'identity-zones-vermilion-fold', 60000);
    const text = result.stdout+result.stderr;
    assert.doesNotMatch(text, /SCRIPT ERROR|ERROR:|Assertion failed/);
    assert.match(text, /PORT_SESSION_SMOKE_OK [^\n]*map=vermilion-fold [^\n]*mode=domination/);
    assert.match(text, /PACKAGE_STOPPED/);
    const ready = JSON.parse(result.stdout.split('\n').find(line=>line.startsWith('PACKAGE_SERVER_READY ')).slice(21));
    assert.equal(ready.mode, 'domination');
    assert.equal(ready.health?.service, 'cocs-native-identity-zones');
    assert.equal(ready.health?.mode, 'domination');
    assert.match(ready.health?.geometryHash ?? '', /^[0-9a-f]{64}$/);
    const native = JSON.parse(result.stdout.split('\n').find(line=>line.startsWith('PACKAGE_NATIVE_STARTED ')).slice(23));
    assert.ok(await closed(ready.port), 'Identity zone authority listener closed');
    assert.throws(()=>process.kill(native.pid,0), 'Identity zone process exited');
    report.cases.push({experience:'identity-zones',map:'vermilion-fold',mode:'domination',passed:true,
      port:ready.port,native_pid:native.pid,geometry_hash:ready.health.geometryHash,cleanup:true});
  }
  // The identity JSONs and the shared identity builder must resolve from the
  // exported PCK with no project directory present.
  const identityResources = await exec(join(root,'cocs.x86_64'), ['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script','res://native_arenas/package_inspect.gd'], {cwd:sandbox,env,timeout:60000});
  await writeFile(join(output,'identity-resources.log'),identityResources.stdout+identityResources.stderr);
  assert.doesNotMatch(identityResources.stdout+identityResources.stderr,/SCRIPT ERROR|ERROR:/);
  assert.match(identityResources.stdout,/SOURCE_OPERATOR_PACKAGE_OK /);
  assert.match(identityResources.stdout,/NATIVE_IDENTITY_PACKAGE_OK /);
  report.identity_resources = true;
  report.cases.push({experience:'native-dm-identity-resources',passed:true,pck:true});
  // Exercise the native graphics routes with no authority.
  for (const experience of ['showcase','aurora-basin','cinder-array','particle-lab','shader-lab']) {
    const result = await runManager([`--experience=${experience}`, '--smoke'], 'graphics-'+experience, 75000);
    const text = result.stdout+result.stderr;
    assert.doesNotMatch(text, /SCRIPT ERROR|ERROR:|Assertion failed/);
    assert.match(text, /PACKAGE_NATIVE_ONLY/);
    assert.doesNotMatch(text, /PACKAGE_SERVER_READY/);
    assert.match(text, /PACKAGE_STOPPED/);
    const started = JSON.parse(result.stdout.split('\n').find(l=>l.startsWith('PACKAGE_NATIVE_STARTED ')).slice(23));
    assert.throws(()=>process.kill(started.pid,0), 'Native-only process exited');
    report.cases.push({experience,passed:true,authority:false,native_pid:started.pid,cleanup:true});
  }
  const inspection = await exec(join(root,'cocs.x86_64'), ['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script',resolve('godot/tests/package_inspect.gd')], {cwd:sandbox,env,timeout:45000});
  await writeFile(join(output,'graphics-resources.log'),inspection.stdout+inspection.stderr);
  assert.doesNotMatch(inspection.stdout+inspection.stderr,/SCRIPT ERROR|ERROR:|Assertion failed/);
  assert.match(inspection.stdout,/PACKAGE_GRAPHICS_OK moth_planes=101 first_person_weapons=10/);
  report.graphics_resources = true;
  report.status = 'passed';
} catch (error) {
  report.status = 'failed'; report.error = error.stack; process.exitCode = 1;
} finally {
  await writeFile(join(output,'result.json'),JSON.stringify(report,null,2)+'\n');
  await rm(sandbox,{recursive:true,force:true,maxRetries:5,retryDelay:100});
}
console.log(JSON.stringify(report,null,2));
