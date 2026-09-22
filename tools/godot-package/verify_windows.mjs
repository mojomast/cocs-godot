// Run on an actual Windows host against a fresh extracted release, not a stub.
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
assert.equal(process.platform, 'win32', 'Native Windows runner required');
await mkdir(output, {recursive:true});
const report = {platform:process.platform, status:'running', cases:[], graphical:false};
const sandbox = await mkdtemp(join(tmpdir(), 'cocs windows smoke '));
const env = {...process.env, TEMP:sandbox, TMP:sandbox, APPDATA:join(sandbox,'roaming'), LOCALAPPDATA:join(sandbox,'local')};
await mkdir(env.APPDATA); await mkdir(env.LOCALAPPDATA);
const sha = data => createHash('sha256').update(data).digest('hex');
async function closed(port) {
  return new Promise((resolve, reject) => {
    const socket = createConnection({host:'127.0.0.1',port});
    socket.setTimeout(3000, () => { socket.destroy(); reject(Error('Port check timeout')); });
    socket.once('connect', () => { socket.destroy(); resolve(false); });
    socket.once('error', error => error.code === 'ECONNREFUSED' ? resolve(true) : reject(error));
  });
}
try {
  const manifest = JSON.parse(await readFile(join(root,'manifest.json')));
  assert.equal(manifest.target, 'windows');
  assert.equal(manifest.operator_models, 'candidate');
  assert.ok(manifest.staged_native_overrides['world/presentation.gd']);
  for (const [name, expected] of Object.entries(manifest.files)) {
    assert.equal(sha(await readFile(join(root,name))), expected, name);
  }
  report.manifest_sha256 = sha(await readFile(join(root,'manifest.json')));
  report.port_commit = manifest.port_commit;
  report.files_verified = Object.keys(manifest.files).length;
  const node = join(root,'node.exe');
  assert.equal((await exec(node,['--version'])).stdout.trim(), 'v'+manifest.bundled_node.version);
  assert.equal((await exec(join(root,'cocs.exe'),['--headless','--version'])).stdout.trim(), manifest.godot_version);
  for (const map of ['meridian-exchange','verdant-reliquary','ember-crucible']) {
    // cmd.exe exercises the actual double-click entry point and path quoting.
    let stdout = '', stderr = '';
    try {
      ({stdout,stderr} = await exec(process.env.ComSpec || 'cmd.exe', ['/d','/s','/c',`""${join(root,'Play.cmd')}" --smoke --map=${map}"`], {cwd:sandbox, env, timeout:45000, maxBuffer:4*1024*1024}));
    } catch (error) {
      await writeFile(join(output,map+'.log'), (error.stdout || '')+(error.stderr || '')+'\n'+error.message);
      throw error;
    }
    await writeFile(join(output,map+'.log'), stdout+stderr);
    assert.doesNotMatch(stdout+stderr, /SCRIPT ERROR|ERROR:|Assertion failed/);
    assert.match(stdout, /PORT_SESSION_SMOKE_OK actors=3/);
    assert.match(stdout, /PORT_OPERATOR_MODEL res:\/\/player_models\/candidate.gd/);
    assert.match(stdout, /PACKAGE_STOPPED/);
    const ready = JSON.parse(stdout.split(/\r?\n/).find(l=>l.startsWith('PACKAGE_SERVER_READY ')).slice(21));
    const native = JSON.parse(stdout.split(/\r?\n/).find(l=>l.startsWith('PACKAGE_NATIVE_STARTED ')).slice(23));
    assert.ok(await closed(ready.port), 'Owned authority listener closed');
    assert.throws(()=>process.kill(native.pid,0), 'Native process exited');
    assert.equal((await readdir(sandbox)).filter(n=>n.startsWith('cocs-native-')).length,0);
    report.cases.push({map,passed:true,port:ready.port,native_pid:native.pid,cleanup:true});
  }
  // The preview resource must also resolve in the exported PCK without a project.
  const preview = await exec(join(root,'cocs.exe'), ['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--quit-after','10','res://player_models/preview.tscn'], {cwd:sandbox,env,timeout:30000});
  await writeFile(join(output,'preview.log'),preview.stdout+preview.stderr);
  assert.doesNotMatch(preview.stdout+preview.stderr,/SCRIPT ERROR|ERROR:/);
  report.preview_load = true;
  report.status = 'passed';
} catch (error) {
  report.status = 'failed'; report.error = error.stack; process.exitCode = 1;
} finally {
  await writeFile(join(output,'result.json'),JSON.stringify(report,null,2)+'\n');
  await rm(sandbox,{recursive:true,force:true,maxRetries:5,retryDelay:100});
}
console.log(JSON.stringify(report,null,2));
