// SYNTHETIC launcher fixtures only: no rendering, scene-resource or gameplay evidence.
// Every process, source-validation stub and filesystem fixture is test-local.
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {mkdtemp, mkdir, copyFile, writeFile, chmod, readdir, rm} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {promisify} from 'node:util';

const exec = promisify(execFile);
const repository = new URL('../../', import.meta.url);
export const nativeScenes = {
  showcase:'res://showcase/demo.tscn',
  'aurora-basin':'res://aurora_basin/demo.tscn',
  'cinder-array':'res://cinder_array/demo.tscn',
  'particle-lab':'res://particle_lab/demo.tscn',
  'shader-lab':'res://shader_lab/demo.tscn',
};
export const rejectedOptions = [
  ['--map=meridian-exchange'], ['--map=aurora-basin'], ['--map','showcase'],
  ['--mode=deathmatch'], ['--mode','exploration'],
  ['--endpoint=ws://127.0.0.1:12345'], ['--endpoint=wss://example.invalid'],
  ['--time-limit=60'], ['--round-target=1'], ['--play'], ['--setup'],
  ['--mute'], ['--debug-hud'], ['--native-trace'], ['--session-smoke'],
  ['--network-smoke'], ['--lifecycle-smoke'], ['--smoke','--setup'],
  ['--smoke','--smoke'], ['--smoke=true'], ['--smok'], ['--help'],
  ['--experience=showcase'], ['--experience','particle-lab'], ['--experience='],
  ['--source-match'], ['--waves=1'], ['--port=0'], ['--'], ['res://other.tscn'],
];

export async function verifyLifecycle(kind, experience, scenario = 'exit') {
  const root = await mkdtemp(join(tmpdir(), 'native graphics launcher stub '));
  // The synthetic engine below is a shebanged Node script named cocs.x86_64.
  // Node resolves the NEAREST package.json for it: an ambient
  // {"type":"module"} anywhere above tmpdir() (a shared TMPDIR) forces ESM and
  // kills it with ERR_UNKNOWN_FILE_EXTENSION. Pin CJS so the fixture owns its
  // loader regardless of the environment the gates run in.
  await writeFile(join(root, 'package.json'), '{"type":"commonjs"}\n');
  const processes = new Set();
  let result;
  try {
    const put = async (path, text) => {
      await mkdir(dirname(join(root,path)), {recursive:true});
      await writeFile(join(root,path), text);
    };
    const copy = async (from, to) => {
      await mkdir(dirname(join(root,to)), {recursive:true});
      await copyFile(new URL(from,repository), join(root,to));
    };
    // Guard even against a future direct listener bypassing the authority imports.
    await put('deny-listen.cjs', `const net = require('node:net');
net.Server.prototype.listen = function(){console.error('UNEXPECTED_LISTEN');throw Error('UNEXPECTED_LISTEN');};
`);
    const forbidden = "throw Error('UNEXPECTED_AUTHORITY_IMPORT');\n";
    const binary = join(root, 'cocs.x86_64');
    await put('cocs.x86_64', `#!${process.execPath}
// SYNTHETIC native-process stub, not a Godot executable.
const scenario=process.env.SCENARIO;
if(process.argv.includes('--version')){
 console.log(scenario==='wrong-version'?'wrong-version':'synthetic-pinned');
 if(scenario==='spawn-failure')require('node:fs').unlinkSync(__filename);
}else{
 console.log('STUB_NATIVE '+JSON.stringify({pid:process.pid,args:process.argv.slice(2),cwd:process.cwd(),xdg:['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'].map(k=>process.env[k])}));
 console.error('STUB_NATIVE_STDERR');
 if(scenario==='native-crash')process.kill(process.pid,'SIGKILL');
 else if(['interrupt','terminate','uncooperative'].includes(scenario)){
  if(scenario==='uncooperative')process.on('SIGTERM',()=>console.log('STUB_IGNORED_SIGTERM'));
  setInterval(()=>{},1000);
  setTimeout(()=>process.kill(process.ppid,scenario==='interrupt'?'SIGINT':'SIGTERM'),100);
 }else process.exitCode=scenario==='native-failure'?17:0;
}
`);
    await chmod(binary,0o755);
    let script;
    if (kind === 'package') {
      for (const name of ['run.mjs','options.mjs','endpoint.mjs']) await copy('tools/godot-package/'+name, name);
      await copy('port/contracts/map-selection.json','catalog.json');
      await put('runtime/server/game-server.mjs',forbidden);
      await put('runtime/port/native-horde/authority.mjs',forbidden);
      await put('cocs.pck','SYNTHETIC placeholder, not a runnable pack');
      await mkdir(join(root,'unrelated caller'));
      script = join(root,'run.mjs');
    } else {
      for (const name of ['launch.mjs','launch_options.mjs']) await copy('tools/godot-dev/'+name,'tools/godot-dev/'+name);
      await copy('tools/godot-package/endpoint.mjs','tools/godot-package/endpoint.mjs');
      await copy('port/contracts/map-selection.json','port/contracts/map-selection.json');
      await put('port/contracts/source-lock.json',JSON.stringify({godot_version:'synthetic-pinned'}));
      await put('tools/godot-export/semantic.mjs',`export function verifySource(){console.log('STUB_SOURCE_VALIDATED');if(process.env.SCENARIO==='invalid-lock')throw Error('SYNTHETIC_SOURCE_REJECTED');}`);
      await put('server/game-server.mjs',forbidden);
      await put('port/native-horde/authority.mjs',forbidden);
      script = join(root,'tools/godot-dev/launch.mjs');
    }
    if (scenario === 'missing-native') await rm(binary);
    const before = (await readdir(root)).sort();
    const args = [script, `--experience=${experience}`];
    if (scenario === 'smoke') args.push('--smoke');
    if (scenario === 'bad-args') args.push('--map=meridian-exchange');
    if (scenario === 'ambiguous-help') args.push('--help','--typo');
    try {
      result = await exec(process.execPath,args,{
        cwd:kind === 'package' ? join(root,'unrelated caller') : root,
        env:{...process.env, NODE_OPTIONS:`--require="${join(root,'deny-listen.cjs')}"`,
          TMPDIR:root, GODOT_BIN:binary, PORT:'invalid-native-route-must-ignore-port', SCENARIO:scenario},
        timeout:12000,
      });
      result.code = 0;
    } catch (error) { result = error; }
    const line = result.stdout.split('\n').find(line => line.startsWith('STUB_NATIVE '));
    const native = line ? JSON.parse(line.slice('STUB_NATIVE '.length)) : null;
    if (native) processes.add(native.pid);
    const started = ['exit','smoke','native-failure','native-crash','interrupt','terminate','uncooperative'].includes(scenario);
    const expected = ['exit','smoke'].includes(scenario) ? 0 : scenario === 'native-failure' ? 17
      : scenario === 'interrupt' ? 130 : ['terminate','uncooperative'].includes(scenario) ? 143 : 1;
    assert.equal(result.code,expected,result.stdout+result.stderr);
    assert.doesNotMatch(result.stdout+result.stderr,/UNEXPECTED_LISTEN|UNEXPECTED_AUTHORITY_IMPORT|PACKAGE_SERVER_READY|PACKAGE_EXTERNAL_AUTHORITY|Owned local server ready|Using existing authority/);
    assert.equal(!!native,started,result.stdout+result.stderr);
    if (native) {
      assert.match(result.stderr,/STUB_NATIVE_STDERR/);
      const engineArgs = scenario === 'smoke' ? ['--headless','--audio-driver','Dummy'] : [];
      const expectedArgs = kind === 'package'
        ? [...engineArgs,'--main-pack',join(root,'cocs.pck'),nativeScenes[experience],'--']
        : [...engineArgs,'--path','godot',nativeScenes[experience],'--'];
      if (scenario === 'smoke') expectedArgs.push('--smoke');
      assert.deepEqual(native.args,expectedArgs);
      assert.equal(native.cwd,root);
      const runtime = dirname(native.xdg[0]);
      assert.equal(dirname(runtime),root);
      assert.match(runtime,/cocs-native-/);
      assert.equal(new Set(native.xdg).size,3);
      for (const directory of native.xdg) assert.equal(dirname(directory),runtime);
      await assert.rejects(readdir(runtime),{code:'ENOENT'});
      assert.throws(()=>process.kill(native.pid,0),{code:'ESRCH'},'Native process survived launcher exit');
      processes.delete(native.pid);
    }
    if (scenario === 'uncooperative') assert.match(result.stdout,/STUB_IGNORED_SIGTERM/);
    const rejectedArgs = ['bad-args','ambiguous-help'].includes(scenario);
    if (kind === 'dev') assert.equal(result.stdout.includes('STUB_SOURCE_VALIDATED'),!rejectedArgs);
    if (kind === 'package' && !rejectedArgs) {
      assert.match(result.stdout,/PACKAGE_NATIVE_ONLY/);
      assert.match(result.stdout,/PACKAGE_STOPPED/);
    }
    const after = (await readdir(root)).sort();
    assert.deepEqual(after,scenario === 'spawn-failure' ? before.filter(name=>name!=='cocs.x86_64') : before);
  } finally {
    // On assertion failure, still reap any live fixture child before deleting its files.
    for (const pid of processes) {
      try { process.kill(pid,'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
    }
    await rm(root,{recursive:true,force:true,maxRetries:5,retryDelay:100});
  }
}
