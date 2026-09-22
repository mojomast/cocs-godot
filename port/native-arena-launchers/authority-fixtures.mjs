// Real delivered authority + source Match on explicitly synthetic geometry.
// The native executable is a protocol-driving process fixture, not Godot evidence.
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {mkdtemp, mkdir, copyFile, writeFile, chmod, readFile, readdir, rm} from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {promisify} from 'node:util';
import net from 'node:net';
import {createNativeArenaAuthority} from '../native-arenas/authority.mjs';
import {syntheticArena} from '../native-arenas/tests/fixtures.mjs';

const exec = promisify(execFile), repository = new URL('../../', import.meta.url);

export async function verifyFactoryBounds() {
  for (const bots of [0, 8]) await assert.rejects(createNativeArenaAuthority({port:0, host:'127.0.0.1',
    bots, arenaData:syntheticArena()}), /botCount must be 1\.\.7/);
}

export async function verifyActualFactory(kind, bots) {
  const root = await mkdtemp('/tmp/opencode/native-arena-factory-');
  // The synthetic engine below is a shebanged Node script named cocs.x86_64.
  // Node resolves the NEAREST package.json for it: an ambient
  // {"type":"module"} anywhere above tmpdir() (a shared TMPDIR) forces ESM and
  // kills it with ERR_UNKNOWN_FILE_EXTENSION. Pin CJS so the fixture owns its
  // loader regardless of the environment the gates run in.
  await writeFile(join(root, 'package.json'), '{"type":"commonjs"}\n');
  const seconds = bots === 7 ? 300 : 60, valid = bots >= 1 && bots <= 7;
  try {
    const put = async (path, text) => {await mkdir(dirname(join(root,path)), {recursive:true}); await writeFile(join(root,path),text);};
    const copy = async (from, to) => {await mkdir(dirname(join(root,to)), {recursive:true}); await copyFile(new URL(from,repository),join(root,to));};
    const lock = JSON.parse(await readFile(new URL('port/contracts/source-lock.json',repository)));
    const adapter = `import {createNativeArenaAuthority as create} from ${JSON.stringify(new URL('../native-arenas/authority.mjs',import.meta.url).href)};
import {syntheticArena} from ${JSON.stringify(new URL('../native-arenas/tests/fixtures.mjs',import.meta.url).href)};
export async function createNativeArenaAuthority(options) {
 console.log('ACTUAL_FACTORY '+JSON.stringify(options));
 const authority=await create({...options,arenaData:syntheticArena(options.mapId)});
 console.log('ACTUAL_ENDPOINT '+authority.endpoint);
 return {...authority, async close(){await authority.close();console.log('ACTUAL_CLOSED');}};
}`;
    await put('cocs.x86_64', `#!${process.execPath}
const assert=require('node:assert/strict');
if(process.argv.includes('--version'))console.log(${JSON.stringify(lock.godot_version)});
else {
 const args=process.argv.slice(process.argv.indexOf('--')+1);
 const value=key=>args.find(a=>a.startsWith('--'+key+'=')).split('=')[1];
 const endpoint=value('endpoint'), bots=Number(value('bots')), seconds=Number(value('round-seconds'));
 console.log('PROTOCOL_PROCESS '+JSON.stringify({pid:process.pid,args,xdg:['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'].map(k=>process.env[k])}));
 assert.equal(endpoint,'ws://127.0.0.1:'+new URL(endpoint).port+'/native-arenas');
 const ws=new WebSocket(endpoint);
 const timer=setTimeout(()=>{console.error('Actual authority fixture timed out');process.exit(1);},7000);
 let started=false;
 const config={mode:'deathmatch',botCount:bots,timeLimit:seconds,fragLimit:50};
 const send=frame=>ws.send(JSON.stringify(frame));
 ws.addEventListener('open',()=>send({type:'create',v:3,delta:0,nativeArenaInput:1,playerName:'Factory fixture'}));
 ws.addEventListener('error',()=>process.exit(1));
 ws.addEventListener('message',event=>{
  const f=JSON.parse(event.data);
  if(f.type==='error')throw Error(f.message);
  if(f.type==='lobby'){
   if(f.config===null)send({type:'host',mapId:value('map'),config});
   else {for(const [k,v] of Object.entries(config))assert.equal(f.config[k],v);send({type:'start'});}
  }
  if(f.type==='start'){assert.ok(f.inputEpoch>0);assert.match(f.geometryHash,/^[a-f0-9]{64}$/);started=true;}
  if(f.type==='snapshot'){
   assert.ok(started);assert.equal(f.state.actors.length,bots+1);assert.equal(f.state.mapId,value('map'));
   for(const [k,v] of Object.entries(config))assert.equal(f.state.config[k],v);
   console.log('ACTUAL_MATCH '+JSON.stringify({bots,seconds,actors:f.state.actors.length,inputEpoch:f.inputEpoch,map:f.state.mapId}));
   clearTimeout(timer);ws.close();
  }
 });
}
`);
    await chmod(join(root,'cocs.x86_64'),0o755);
    const forbidden = "throw Error('UNEXPECTED_AUTHORITY_IMPORT');";
    let script;
    if (kind === 'package') {
      for (const name of ['run.mjs','options.mjs','endpoint.mjs']) await copy('tools/godot-package/'+name,name);
      await copy('port/contracts/map-selection.json','catalog.json');
      await put('runtime/port/native-arenas/authority.mjs',adapter);
      await put('runtime/server/game-server.mjs',forbidden);
      await put('runtime/port/native-horde/authority.mjs',forbidden);
      await put('cocs.pck','SYNTHETIC native process fixture');
      script = join(root,'run.mjs');
    } else {
      for (const name of ['launch.mjs','launch_options.mjs']) await copy('tools/godot-dev/'+name,'tools/godot-dev/'+name);
      await copy('tools/godot-package/endpoint.mjs','tools/godot-package/endpoint.mjs');
      await copy('port/contracts/map-selection.json','port/contracts/map-selection.json');
      await put('port/contracts/source-lock.json',JSON.stringify(lock));
      await put('tools/godot-export/semantic.mjs','export function verifySource(){} // fixture checkout');
      await put('port/native-arenas/authority.mjs',adapter);
      await put('server/game-server.mjs',forbidden);
      await put('port/native-horde/authority.mjs',forbidden);
      script = join(root,'tools/godot-dev/launch.mjs');
    }
    let result;
    try {
      result = await exec(process.execPath,[script,'--experience=native-dm','--map=prism-foundry',`--bots=${bots}`,`--round-seconds=${seconds}`],
        {cwd:root,env:{...process.env,GODOT_BIN:join(root,'cocs.x86_64'),TMPDIR:root,PORT:'must-use-private-port-zero'},timeout:15000});
      result.code = 0;
    } catch (error) { result = error; }
    const text = result.stdout + result.stderr;
    assert.equal(result.code,valid ? 0 : 1,text);
    assert.doesNotMatch(text,/UNEXPECTED_AUTHORITY_IMPORT/);
    assert.equal(text.includes('ACTUAL_FACTORY '),valid,text);
    assert.equal(text.includes('ACTUAL_CLOSED'),valid,text);
    if (valid) {
      const record = prefix => JSON.parse(result.stdout.split('\n').find(line=>line.startsWith(prefix)).slice(prefix.length));
      assert.deepEqual(record('ACTUAL_FACTORY '),{port:0,host:'127.0.0.1',mapId:'prism-foundry',mode:'deathmatch',bots,roundSeconds:seconds});
      assert.deepEqual(record('ACTUAL_MATCH '),{bots,seconds,actors:bots+1,inputEpoch:1,map:'prism-foundry'});
      const child = record('PROTOCOL_PROCESS ');
      assert.throws(()=>process.kill(child.pid,0),{code:'ESRCH'},'Protocol-driving process survived');
      for (const path of child.xdg) await assert.rejects(readdir(path),{code:'ENOENT'});
      const port = Number(text.match(/ACTUAL_ENDPOINT ws:\/\/127\.0\.0\.1:(\d+)\/native-arenas/)[1]);
      await new Promise((resolve,reject)=>{const socket=net.connect(port,'127.0.0.1');socket.once('connect',()=>{socket.destroy();reject(Error('Actual listener survived'));});socket.once('error',resolve);});
    } else assert.match(text,/--bots must be 1\.\.7/);
    assert.deepEqual((await readdir(root)).filter(name=>name.startsWith('cocs-native-')),[]);
  } finally {
    await rm(root,{recursive:true,force:true,maxRetries:5,retryDelay:100});
  }
}
