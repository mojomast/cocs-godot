// SYNTHETIC authority and native-process fixtures. These prove launcher ownership,
// argument routing and teardown, not native gameplay, protocol or rendering.
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {mkdtemp, mkdir, copyFile, writeFile, chmod, readdir, rm} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {promisify} from 'node:util';
import net from 'node:net';
const exec = promisify(execFile), repository = new URL('../../',import.meta.url);

const factory = `import http from 'node:http';
export async function createNativeArenaAuthority(options) {
 console.log('SYNTHETIC_FACTORY '+JSON.stringify(options));
 const scenario=process.env.SCENARIO;
 if(scenario==='factory-failure')throw Error('synthetic construction failure');
 const server=http.createServer((req,res)=>{
  const status={service:'synthetic-native-arena',localOnly:true,port:server.address().port};
  if(scenario==='wrong-local')status.localOnly=false;
  if(scenario==='wrong-port')status.port++;
  if(scenario==='health-failure')res.statusCode=503;
  res.end(JSON.stringify(status));
 });
 const result={server,wss:{clients:new Set()},async close(){
  server.closeAllConnections();if(server.listening)await new Promise(r=>server.close(r));
  console.log('SYNTHETIC_CLOSED');
 }};
 server.on('listening',()=>{console.log('SYNTHETIC_PORT '+server.address().port);if(scenario==='server-failure')setTimeout(()=>server.emit('error',Error('synthetic runtime failure')),500);});
 if(scenario==='listen-failure'){server.listen=()=>queueMicrotask(()=>server.emit('error',Error('synthetic listen failure')));return result;}
 if(scenario==='unstarted')return result;
 await new Promise(r=>server.listen(options.port,options.host,r));
 result.endpoint='ws://127.0.0.1:'+server.address().port;
 if(scenario==='external-endpoint')result.endpoint='ws://example.invalid:12345';
 if(scenario==='endpoint-only'){delete result.server;delete result.wss;}
 return result;
}`;

export const scenarios = ['exit','smoke','unstarted','endpoint-only','native-failure','native-crash','missing-native',
  'spawn-failure','interrupt','terminate','uncooperative','server-failure','listen-failure','factory-failure',
  'wrong-local','wrong-port','health-failure','external-endpoint','bad-args','native-only'];

export async function verifyOwnership(kind, scenario, map = 'prism-foundry') {
  const root = await mkdtemp(join(tmpdir(),'native arena ownership synthetic '));
  const processes = new Set();
  try {
    const put = async (path,text) => {await mkdir(dirname(join(root,path)),{recursive:true});await writeFile(join(root,path),text);};
    const copy = async (from,to) => {await mkdir(dirname(join(root,to)),{recursive:true});await copyFile(new URL(from,repository),join(root,to));};
    const native = join(root,'cocs.x86_64');
    await put('cocs.x86_64',`#!${process.execPath}
const s=process.env.SCENARIO;
if(process.argv.includes('--version')){
 console.log('synthetic-pinned');if(s==='spawn-failure')require('node:fs').unlinkSync(__filename);
}else{
 console.log('SYNTHETIC_NATIVE '+JSON.stringify({pid:process.pid,args:process.argv.slice(2),cwd:process.cwd(),xdg:['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'].map(k=>process.env[k])}));
 if(s==='native-crash')process.kill(process.pid,'SIGKILL');
 else if(['interrupt','terminate','uncooperative','server-failure','smoke-timeout'].includes(s)){
  setInterval(()=>{},1000);
  if(s==='uncooperative')process.on('SIGTERM',()=>console.log('SYNTHETIC_IGNORED_SIGTERM'));
  if(['interrupt','terminate','uncooperative'].includes(s))setTimeout(()=>process.kill(process.ppid,s==='interrupt'?'SIGINT':'SIGTERM'),100);
 }else process.exitCode=s==='native-failure'?17:0;
}
`);
    await chmod(native,0o755);
    const forbidden = "throw Error('UNEXPECTED_AUTHORITY_IMPORT');";
    const adapter = ['bad-args','native-only'].includes(scenario) ? forbidden : factory;
    let script;
    if (kind === 'package') {
      for (const name of ['run.mjs','options.mjs','endpoint.mjs']) await copy('tools/godot-package/'+name,name);
      await copy('port/contracts/map-selection.json','catalog.json');
      await put('runtime/server/game-server.mjs',forbidden);
      await put('runtime/port/native-horde/authority.mjs',forbidden);
      await put('runtime/port/native-arenas/authority.mjs',adapter);
      await put('cocs.pck','SYNTHETIC pack placeholder');
      await mkdir(join(root,'unrelated caller'));
      if (scenario === 'spawn-failure') await chmod(native,0o644);
      script = join(root,'run.mjs');
    } else {
      for (const name of ['launch.mjs','launch_options.mjs']) await copy('tools/godot-dev/'+name,'tools/godot-dev/'+name);
      await copy('tools/godot-package/endpoint.mjs','tools/godot-package/endpoint.mjs');
      await copy('port/contracts/map-selection.json','port/contracts/map-selection.json');
      await put('port/contracts/source-lock.json',JSON.stringify({godot_version:'synthetic-pinned'}));
      await put('tools/godot-export/semantic.mjs','export function verifySource(){}');
      await put('server/game-server.mjs',forbidden);
      await put('port/native-horde/authority.mjs',forbidden);
      await put('port/native-arenas/authority.mjs',adapter);
      script = join(root,'tools/godot-dev/launch.mjs');
    }
    if (scenario === 'missing-native') await rm(native);
    const args = scenario === 'native-only' ? ['--experience=aurora-basin'] : ['--experience=native-dm',`--map=${map}`,'--bots=0','--round-seconds=60'];
    if (['smoke','smoke-timeout'].includes(scenario)) args.push('--smoke');
    if (scenario === 'bad-args') args.push('--endpoint=ws://127.0.0.1:12345');
    let result;
    try {
      result = await exec(process.execPath,[script,...args],{cwd:kind==='package'?join(root,'unrelated caller'):root,
        env:{...process.env,PORT:'invalid-native-dm-must-use-port-zero',TMPDIR:root,GODOT_BIN:native,SCENARIO:scenario},timeout:30000});
      result.code = 0;
    } catch (error) {result = error;}
    const text = result.stdout + result.stderr;
    const line = result.stdout.split('\n').find(l=>l.startsWith('SYNTHETIC_NATIVE '));
    const child = line ? JSON.parse(line.slice('SYNTHETIC_NATIVE '.length)) : null;
    if (child) processes.add(child.pid);
    const expected = ['exit','smoke','unstarted','endpoint-only','native-only'].includes(scenario) ? 0 : scenario==='native-failure' ? 17 : scenario==='interrupt' ? 130 : ['terminate','uncooperative'].includes(scenario) ? 143 : 1;
    assert.equal(result.code,expected,text);
    assert.doesNotMatch(text,/UNEXPECTED_AUTHORITY_IMPORT/);
    const constructed = !['bad-args','native-only'].includes(scenario) && !(kind==='dev'&&scenario==='missing-native');
    const factoryLine = result.stdout.split('\n').find(l=>l.startsWith('SYNTHETIC_FACTORY '));
    assert.equal(!!factoryLine,constructed,text);
    if (constructed) assert.deepEqual(JSON.parse(factoryLine.slice('SYNTHETIC_FACTORY '.length)),{port:0,host:'127.0.0.1',mapId:map,mode:'deathmatch',bots:0,roundSeconds:60});
    assert.equal(result.stdout.includes('SYNTHETIC_CLOSED'),constructed&&scenario!=='factory-failure',text);
    const started = ['exit','smoke','smoke-timeout','unstarted','endpoint-only','native-failure','native-crash','interrupt','terminate','uncooperative','server-failure','native-only'].includes(scenario);
    assert.equal(!!child,started,text);
    if (child) {
      assert.equal(child.cwd,root);
      const smoke = ['smoke','smoke-timeout'].includes(scenario);
      const engine = smoke ? ['--headless','--audio-driver','Dummy'] : [];
      const port = Number(result.stdout.match(/SYNTHETIC_PORT (\d+)/)?.[1]);
      const scene = scenario==='native-only' ? 'res://aurora_basin/demo.tscn' : 'res://native_arenas/demo.tscn';
      const prefix = kind==='package' ? [...engine,'--main-pack',join(root,'cocs.pck'),scene,'--'] : [...engine,'--path','godot',scene,'--'];
      assert.deepEqual(child.args,[...prefix,...(scenario==='native-only'?[]:[`--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,'--mode=deathmatch','--bots=0','--round-seconds=60',...(smoke?['--smoke']:[])])]);
      assert.equal(new Set(child.xdg).size,3);
      for (const path of child.xdg) {assert.equal(dirname(dirname(path)),root);await assert.rejects(readdir(path),{code:'ENOENT'});}
      assert.throws(()=>process.kill(child.pid,0),{code:'ESRCH'},'Native child survived');
      processes.delete(child.pid);
    }
    if (scenario==='uncooperative') assert.match(text,/SYNTHETIC_IGNORED_SIGTERM/);
    if (scenario==='smoke-timeout') assert.match(text,/Native DM smoke exceeded 20 seconds/);
    const port = Number(result.stdout.match(/SYNTHETIC_PORT (\d+)/)?.[1]);
    if (port) await new Promise((resolve,reject)=>{const socket=net.connect(port,'127.0.0.1');socket.once('connect',()=>{socket.destroy();reject(Error('Owned listener survived'));});socket.once('error',resolve);});
    assert.deepEqual((await readdir(root)).filter(n=>n.startsWith('cocs-native-')),[]);
  } finally {
    for (const pid of processes) try {process.kill(pid,'SIGKILL');} catch (error) {if(error.code!=='ESRCH')throw error;}
    await rm(root,{recursive:true,force:true,maxRetries:5,retryDelay:100});
  }
}
