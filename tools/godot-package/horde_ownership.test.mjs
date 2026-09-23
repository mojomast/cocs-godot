// SYNTHETIC process/factory fixtures: lifecycle and routing evidence only.
// No fixture here is evidence of Horde gameplay or real native rendering.
import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, mkdir, copyFile, writeFile, chmod, readdir, rm} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import net from 'node:net';
const exec=promisify(execFile), here=import.meta.dirname;
const factory=`import http from 'node:http';
export function createAuthority(options){
 console.log('SYNTHETIC_FACTORY '+JSON.stringify(options));
 const scenario=process.env.SCENARIO;
 if(scenario==='factory-failure')throw Error('synthetic construction failure');
 const server=http.createServer((req,res)=>{
  const status={service:'cocs-local-horde',transport:1,localOnly:true,port:server.address().port};
  if(scenario==='wrong-service')status.service='token-arena-game-server';
  if(scenario==='wrong-transport')status.transport=2;
  if(scenario==='string-transport')status.transport='1';
  if(scenario==='wrong-local')status.localOnly=false;
  if(scenario==='wrong-port')status.port++;
  res.end(JSON.stringify(status));
 });
 server.on('listening',()=>{console.log('SYNTHETIC_PORT '+server.address().port);if(scenario==='server-failure')setTimeout(()=>server.emit('error',Error('synthetic runtime failure')),300);});
 if(scenario==='listen-failure')server.listen=()=>queueMicrotask(()=>server.emit('error',Error('synthetic listen failure')));
 return {server,wss:{clients:new Set()},async close(){server.closeAllConnections();if(server.listening)await new Promise(r=>server.close(r));console.log('SYNTHETIC_CLOSED');}};
}`;
for(const kind of ['package','dev'])for(const scenario of ['exit','native-failure','native-crash','missing-native','interrupt','terminate','server-failure','listen-failure','factory-failure','wrong-service','wrong-transport','string-transport','wrong-local','wrong-port','bad-args']){
 test(`${kind} Horde synthetic factory: ${scenario}`,async()=>{
  const root=await mkdtemp(join(tmpdir(),'horde-owner-synthetic-'));
  // Shebanged cocs.x86_64 Node stub: the nearest package.json decides its
  // loader, so an ambient {"type":"module"} above tmpdir() (shared TMPDIR) would
  // force ESM and kill it with ERR_UNKNOWN_FILE_EXTENSION. Pin CJS explicitly.
  await writeFile(join(root, 'package.json'), '{"type":"commonjs"}\n');
  try{
   const put=async(path,text)=>{await mkdir(dirname(join(root,path)),{recursive:true});await writeFile(join(root,path),text);};
   const copy=async(from,to)=>{await mkdir(dirname(join(root,to)),{recursive:true});await copyFile(join(here,from),join(root,to));};
   const native=join(root,'cocs.x86_64');
   await put('cocs.x86_64',`#!${process.execPath}\nif(process.argv.includes('--version'))console.log('synthetic-pinned');else{console.log('SYNTHETIC_NATIVE '+JSON.stringify(process.argv.slice(2)));const s=process.env.SCENARIO;if(s==='native-crash')process.kill(process.pid,'SIGKILL');else if(['interrupt','terminate','server-failure'].includes(s)){setInterval(()=>{},1000);if(s!=='server-failure')setTimeout(()=>process.kill(process.ppid,s==='interrupt'?'SIGINT':'SIGTERM'),100);}else process.exitCode=s==='native-failure'?17:0;}\n`);
   await chmod(native,0o755);
   let script;
   const ordinary="export function createGameServer(){throw Error('Wrong public factory');}";
   if(kind==='package'){
    for(const name of ['run.mjs','options.mjs','endpoint.mjs'])await copy(name,name);
    await copy('../../port/contracts/map-selection.json','catalog.json');
    await put('runtime/server/game-server.mjs',ordinary);
    await put('runtime/port/native-horde/authority.mjs',scenario==='bad-args'?"throw Error('Premature adapter import');":factory);
    script=join(root,'run.mjs');
   }else{
    for(const name of ['launch.mjs','launch_options.mjs'])await copy('../godot-dev/'+name,'tools/godot-dev/'+name);
    await copy('endpoint.mjs','tools/godot-package/endpoint.mjs');
    await copy('../../port/contracts/map-selection.json','port/contracts/map-selection.json');
    await put('port/contracts/source-lock.json',JSON.stringify({godot_version:'synthetic-pinned'}));
    await put('tools/godot-export/semantic.mjs','export function verifySource(){}');
    await put('server/game-server.mjs',ordinary);
    await put('port/native-horde/authority.mjs',scenario==='bad-args'?"throw Error('Premature adapter import');":factory);
    script=join(root,'tools/godot-dev/launch.mjs');
   }
   if(scenario==='missing-native')await rm(native);
   let result;
   try{result=await exec(process.execPath,[script,'--experience=horde',...(scenario==='bad-args'?['--waves=0']:[])],{cwd:root,env:{...process.env,PORT:'0',TMPDIR:root,GODOT_BIN:native,SCENARIO:scenario},timeout:12000});result.code=0;}catch(error){result=error;}
   const expected=scenario==='exit'?0:scenario==='native-failure'?17:scenario==='interrupt'?130:scenario==='terminate'?143:1;
   assert.equal(result.code,expected,result.stdout+result.stderr);
   assert.doesNotMatch(result.stdout+result.stderr,/Wrong public factory|Premature adapter import/);
   const constructed=!['bad-args'].includes(scenario)&&!(kind==='dev'&&scenario==='missing-native');
   assert.equal(result.stdout.includes('SYNTHETIC_FACTORY {}'),constructed);
   assert.equal(result.stdout.includes('SYNTHETIC_CLOSED'),constructed&&scenario!=='factory-failure');
   const nativeStarted=['exit','native-failure','native-crash','interrupt','terminate','server-failure'].includes(scenario);
   assert.equal(result.stdout.includes('SYNTHETIC_NATIVE '),nativeStarted);
   if(nativeStarted){
    const argv=JSON.parse(result.stdout.split('\n').find(l=>l.startsWith('SYNTHETIC_NATIVE ')).slice(17));
    assert.ok(argv.includes('res://horde/demo.tscn'));assert.ok(argv.includes('--mode=horde'));
    assert.ok(!argv.some(a=>a.startsWith('--waves')));
   }
   const port=Number(result.stdout.match(/SYNTHETIC_PORT (\d+)/)?.[1]);
   if(port)await new Promise((resolve,reject)=>{const socket=net.connect(port,'127.0.0.1');socket.on('connect',()=>{socket.destroy();reject(Error('Listener survived'));});socket.on('error',resolve);});
   if(kind==='package')assert.deepEqual((await readdir(root)).filter(n=>n.startsWith('cocs-native-')),[]);
  }finally{await rm(root,{recursive:true,force:true});}
 });
}
