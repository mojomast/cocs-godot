// Extracted-release startup/resource/wire verification; no checkout runtime imports.
// Usage: node verify_expansion.mjs /absolute/extracted/package /absolute/evidence
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {readFile,writeFile,mkdir,mkdtemp,rm,readdir} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createConnection} from 'node:net';
import {fileURLToPath} from 'node:url';
import {createInterface} from 'node:readline';

const IDS=['switchyard-ward','rainmarket-exchange','breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago'];
const HEX=/^[a-f0-9]{64}$/;
export function coverage(manifest, worlds) {
  const closure=manifest.server_closure;
  assert.ok(closure && Array.isArray(closure.worldDataFiles), 'Expansion manifest must declare worldDataFiles (no legacy fallback)');
  assert.deepEqual([...closure.worldDataFiles].sort(), IDS.map(id=>`godot/multiplayer_worlds/generated/${id}.json`).sort());
  assert.ok(closure.hordeDataFiles?.includes('godot/horde_maps/generated/blackwater-reclamation.json'), 'Blackwater runtime data absent');
  assert.deepEqual(Object.keys(worlds).sort(), [...IDS].sort(), 'Derive map options from packaged catalog');
  const pairs=Object.entries(worlds).flatMap(([map,entry])=>entry.modes.map(mode=>({map,mode})));
  assert.equal(pairs.length,43,'All packaged world mode pairs must be visited');
  for(const map of IDS) assert.ok(pairs.some(p=>p.map===map),`Uncovered ${map}`);
  for(const mode of ['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault','payload','combined-arms','puma-race','puma-soccer','cocs','cocs-coop'])
    assert.ok(pairs.some(p=>p.mode===mode),`Uncovered mode ${mode}`);
  return pairs;
}

async function authority(entry) {
  // This mode runs under packaged node.exe on Windows, system Node on Linux.
  // The sole dynamic import is an absolute file URL inside extracted runtime/.
  const {createGameServer,createAuthority}=await import(pathToFileURL(resolve(entry)).href);
  const game=createGameServer?createGameServer({historyPath:null,progressionPath:null}):createAuthority();
  await new Promise((ok,fail)=>{game.server.once('error',fail);game.server.listen(0,'127.0.0.1',ok);});
  console.log('EXPANSION_AUTHORITY_READY '+JSON.stringify({port:game.server.address().port,pid:process.pid}));
  // Windows child.kill('SIGTERM') is TerminateProcess, not a Node signal.
  // A line on the owned stdin pipe is an explicit, cross-platform handshake.
  const commands=createInterface({input:process.stdin});
  commands.once('line',line=>{
    if(line!=='STOP'){console.error('EXPANSION_AUTHORITY_FAILED unknown command');process.exitCode=2;commands.close();return;}
    game.close().then(()=>{
      console.log('EXPANSION_AUTHORITY_CLOSED');commands.close();
    }).catch(error=>{
      console.error('EXPANSION_AUTHORITY_FAILED '+error.stack);process.exitCode=1;commands.close();
    });
  });
}

async function closed(port) {
  return new Promise((ok,fail)=>{
    const socket=createConnection({host:'127.0.0.1',port});
    socket.setTimeout(2000,()=>{socket.destroy();fail(Error('Listener cleanup timed out'));});
    socket.once('connect',()=>{socket.destroy();ok(false);});
    socket.once('error',e=>e.code==='ECONNREFUSED'?ok(true):fail(e));
  });
}
export async function waitExit(child,ms) {
  if(child.exitCode!==null || child.signalCode!==null)return {code:child.exitCode,signal:child.signalCode};
  return new Promise((ok,fail)=>{
    const timeout=setTimeout(()=>{child.off('exit',exit);fail(Error(`Owned child ${child.pid} did not exit in ${ms}ms`));},ms);
    function exit(code,signal){clearTimeout(timeout);ok({code,signal});}
    child.once('exit',exit);
    // The exit may race registration after the initial check.
    if(child.exitCode!==null || child.signalCode!==null){clearTimeout(timeout);child.off('exit',exit);ok({code:child.exitCode,signal:child.signalCode});}
  });
}
export async function forceStop(child) {
  if(child.exitCode!==null || child.signalCode!==null)return;
  child.kill('SIGTERM');
  try{await waitExit(child,4000);}catch{
    child.kill('SIGKILL');await waitExit(child,4000);
  }
}
export async function gracefulAuthority(owned,ms=5000) {
  const {child,read}=owned;
  assert.ok(child.exitCode===null && child.signalCode===null,'Authority exited before shutdown request');
  child.stdin.write('STOP\n');
  const until=Date.now()+ms;
  while(Date.now()<until){
    if(read().includes('EXPANSION_AUTHORITY_CLOSED'))break;
    if(read().includes('EXPANSION_AUTHORITY_FAILED') || child.exitCode!==null || child.signalCode!==null)
      throw Error('Authority closed without acknowledgement: '+read().slice(-1200));
    await new Promise(ok=>setTimeout(ok,20));
  }
  assert.match(read(),/EXPANSION_AUTHORITY_CLOSED/,'Authority shutdown acknowledgment timed out');
  const exit=await waitExit(child,Math.max(1,until-Date.now()));
  assert.deepEqual(exit,{code:0,signal:null},'Authority did not exit normally after acknowledgment');
}
async function launch(exe,args,cwd,env) {
  const child=spawn(exe,args,{cwd,env,stdio:['pipe','pipe','pipe'],windowsHide:true});
  let text='';
  child.stdout.on('data',part=>{text+=String(part);});
  child.stderr.on('data',part=>{text+=String(part);});
  await new Promise((ok,fail)=>{child.once('spawn',ok);child.once('error',fail);});
  return {child,read:()=>text};
}
async function marker(process,prefix,ms) {
  const until=Date.now()+ms;
  while(Date.now()<until){
    const text=process.read();
    const line=text.split(/\r?\n/).find(row=>row.startsWith(prefix));
    if(line)return JSON.parse(line.slice(prefix.length));
    if(process.child.exitCode!==null || process.child.signalCode!==null)throw Error(`${prefix} missing; exited ${process.child.exitCode}/${process.child.signalCode}: ${text.slice(-2500)}`);
    await new Promise(ok=>setTimeout(ok,40));
  }
  throw Error(`${prefix} timeout: ${process.read().slice(-2500)}`);
}

export async function verify(root,output,{node=process.platform==='win32'?join(root,'node.exe'):process.execPath,
  engine=join(root,process.platform==='win32'?'cocs.exe':'cocs.x86_64'),
  probe=fileURLToPath(new URL('../../godot/tests/package_expansion.gd',import.meta.url))}={}) {
  root=resolve(root);output=resolve(output);
  await mkdir(output,{recursive:true});
  const sandbox=await mkdtemp(join(tmpdir(),'cocs expansion release '));
  const env={...process.env,TMP:sandbox,TEMP:sandbox,TMPDIR:sandbox,
    XDG_DATA_HOME:join(sandbox,'data'),XDG_CONFIG_HOME:join(sandbox,'config'),XDG_CACHE_HOME:join(sandbox,'cache'),
    APPDATA:join(sandbox,'roaming'),LOCALAPPDATA:join(sandbox,'local'),HOME:sandbox,USERPROFILE:sandbox,PWD:sandbox,
    PORT:'0',COCS_CAREER_ROOT:join(sandbox,'career')};
  delete env.NODE_PATH;delete env.NODE_OPTIONS;delete env.COCS_SOURCE_DERIVATIVE;
  for(const name of ['data','config','cache','roaming','local','career'])await mkdir(join(sandbox,name));
  const report={scope:'extracted release startup, resources and wire hash; not a full round',status:'running',cases:[],cwd:sandbox};
  let active=[];
  try{
    assert.notEqual(root,sandbox);
    const manifest=JSON.parse(await readFile(join(root,'manifest.json'),'utf8'));
    assert.equal(manifest.target,process.platform==='win32'?'windows':'linux');
    // Platform verifier already validates every manifest SHA and source closure.
    // Here every imported module and JSON comes ONLY from root/runtime.
    const catalog=await import(pathToFileURL(join(root,'runtime/port/multiplayer-worlds/catalog.mjs')).href);
    const pairs=coverage(manifest,catalog.WORLDS);
    const rows=[...pairs,{map:'blackwater-reclamation',mode:'horde'}];
    const blackwater=JSON.parse(await readFile(join(root,'runtime/godot/horde_maps/generated/blackwater-reclamation.json'),'utf8'));
    assert.match(blackwater.geometryHash,HEX);
    for(const [index,{map,mode}] of rows.entries()){
      const name=`${String(index+1).padStart(2,'0')}-${map}-${mode}`;
      const horde=mode==='horde';
      const data=horde?blackwater:catalog.readWorld(map);
      assert.match(data.geometryHash,HEX);
      if(mode==='puma-race')assert.equal(data.arena.race?.gates?.length,14,'Packaged Sirocco gate route');
      if(mode==='cocs'||mode==='cocs-coop')assert.equal(data.arena.nodes?.length,7,'Packaged Tern command nodes');
      const entry=join(root,horde?'runtime/port/native-horde/authority.mjs':'runtime/port/multiplayer-worlds/derived/game-server.mjs');
      let server,native,port;
      try{
        server=await launch(node,[fileURLToPath(import.meta.url),'--authority',entry],sandbox,env);active.push(server.child);
        const ready=await marker(server,'EXPANSION_AUTHORITY_READY ',15000);port=ready.port;
        const health=await (await fetch(`http://127.0.0.1:${port}/`,{signal:AbortSignal.timeout(5000)})).json();
        assert.equal(health.port,port);
        const args=['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script',probe,'--',
          `--endpoint=ws://127.0.0.1:${port}`,`--map=${map}`,`--mode=${mode}`,`--expect-hash=${data.geometryHash}`];
        // LATTICE normally waits for a human Enter at its session panel. Its
        // existing evidence switch requests that same start through the real
        // client after a configured roster, with no state or actor injection.
        if(mode==='cocs'||mode==='cocs-coop')args.push('--world-evidence');
        native=await launch(engine,args,sandbox,{...env,LP_NUM_THREADS:'1'});active.push(native.child);
        const proof=await marker(native,'EXPANSION_PRODUCT_READY ',55000);
        assert.equal(proof.scene,horde?'res://horde_maps/blackwater_demo.tscn':mode.startsWith('puma-')?'res://multiplayer_worlds/sports_demo.tscn':mode.startsWith('cocs')?'res://multiplayer_worlds/lattice_demo.tscn':'res://multiplayer_worlds/demo.tscn');
        assert.equal(proof.map,map);assert.equal(proof.mode,mode);assert.equal(proof.hash,data.geometryHash);
        assert.ok(proof.snapshots>=3 && proof.actors>0,'Native client received advancing state');
        if(horde){assert.equal(proof.blackwater,1);assert.ok(proof.robots.every(id=>['scrapper','skirmisher','sentinel','mortar','bulwark','warden'].includes(id)));}
        if(mode.startsWith('puma-'))assert.ok(proof.race,'Sports race state absent');
        const nativeExit=await waitExit(native.child,10000);
        assert.deepEqual(nativeExit,{code:0,signal:null},'Native probe did not exit normally');
        await gracefulAuthority(server);
        // Parse/errors can arrive after the ready marker, including teardown.
        assert.doesNotMatch(server.read()+native.read(),/SCRIPT ERROR|ERROR:|Assertion failed|EXPANSION_AUTHORITY_FAILED/);
        assert.ok(await closed(port),'Authority listener survived');
        report.cases.push({map,mode,hash:data.geometryHash,scene:proof.scene,actors:proof.actors,snapshots:proof.snapshots,robots:proof.robots,
          authority_pid:server.child.pid,native_pid:native.child.pid,port,native_exit:nativeExit.code,authority_exit:server.child.exitCode,listener_closed:true,cleanup:true});
      }catch(error){
        throw error;
      }finally{
        let teardownError;
        if(native)try{await forceStop(native.child);}catch(error){teardownError=error;}
        if(server && server.child.exitCode===null && server.child.signalCode===null){
          try{await gracefulAuthority(server);}catch(error){teardownError??=error;}
        }
        if(server)try{await forceStop(server.child);}catch(error){teardownError??=error;}
        await writeFile(join(output,name+'.log'),(server?.read()??'')+'\n'+(native?.read()??'')+(teardownError?'\n'+teardownError.stack:''));
        active=active.filter(child=>child!==native?.child && child!==server?.child);
        if(port)assert.ok(await closed(port),'Authority cleanup failed after case');
        if(teardownError)throw teardownError;
      }
    }
    report.status='passed';report.pairs=pairs.length;report.blackwater=true;
  }catch(error){report.status='failed';report.error=error.stack;throw error;}
  finally{
    for(const child of active)await forceStop(child);
    report.orphans=(await readdir(sandbox)).filter(x=>x.startsWith('cocs-native-'));
    if(report.orphans.length){report.status='failed';report.error='Owned native process directories survived: '+report.orphans.join(',');}
    await writeFile(join(output,'expansion-result.json'),JSON.stringify(report,null,2)+'\n');
    await rm(sandbox,{recursive:true,force:true,maxRetries:5,retryDelay:100});
    assert.equal(report.orphans.length,0,'Owned native process directories survived');
  }
  return report;
}

if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  if(process.argv[2]==='--authority') await authority(process.argv[3]);
  else {
    assert.ok(process.argv[2]&&process.argv[3],'Usage: verify_expansion.mjs EXTRACTED_PACKAGE OUTPUT');
    try{console.log(JSON.stringify(await verify(process.argv[2],process.argv[3]),null,2));}
    catch(error){console.error(error);process.exitCode=1;}
  }
}
