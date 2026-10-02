// Additive extracted-package feature checks. Native execution requires the
// platform's own engine; --replay-only performs the read-only Node helper check.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {readFileSync,writeFileSync,mkdtempSync,mkdirSync,existsSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
import {REPLAY_FILES,REPLAY_KIND} from './replay_runtime.mjs';
import {forceStop,waitExit} from './verify_expansion.mjs';
const sha=path=>createHash('sha256').update(readFileSync(path)).digest('hex');
export async function verifyReplayExtracted(root,output,{node=process.platform==='win32'?join(root,'node.exe'):process.execPath}={}) {
  root=resolve(root);mkdirSync(output,{recursive:true});
  const sandbox=mkdtempSync(join(tmpdir(),'cocs replay fresh cwd '));
  let child,log='';
  const report={status:'running',scope:'extracted read-only replay helper; no engine or authority',cwd:sandbox};
  try {
    const runtime=join(root,'replay-runtime');
    const own=JSON.parse(readFileSync(join(runtime,'manifest.json'),'utf8'));
    assert.equal(own.kind,REPLAY_KIND);assert.equal(own.version,1);
    assert.deepEqual(Object.keys(own.files).sort(),[...REPLAY_FILES].sort());
    for(const path of REPLAY_FILES) assert.equal(sha(join(runtime,path)),own.files[path],`Replay hash mismatch: ${path}`);
    const token=randomBytes(32).toString('hex'),ready=join(sandbox,'ready.json');
    const env={...process.env};delete env.NODE_PATH;delete env.NODE_OPTIONS;
    child=spawn(node,[join(runtime,'tools/port/replay/service.mjs'),join(sandbox,'library'),ready,token],{cwd:sandbox,env,stdio:['ignore','pipe','pipe'],windowsHide:true});
    child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
    await new Promise((ok,fail)=>{child.once('spawn',ok);child.once('error',fail);});
    const until=Date.now()+8000;
    while(!existsSync(ready)&&Date.now()<until&&child.exitCode===null)await new Promise(ok=>setTimeout(ok,20));
    assert.ok(existsSync(ready),`Replay helper failed to start: ${log}`);
    const {port}=JSON.parse(readFileSync(ready));assert.ok(Number.isInteger(port)&&port>0&&port<65536);
    const request=async(body,authorization=token)=>fetch(`http://127.0.0.1:${port}/replay`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${authorization}`},body:JSON.stringify(body),signal:AbortSignal.timeout(5000)});
    assert.equal((await request({op:'ping'},'bad')).status,403);
    assert.deepEqual(await (await request({op:'ping'})).json(),{ok:true,alive:true});
    assert.deepEqual(await (await request({op:'list'})).json(),{ok:true,clips:[]});
    assert.equal((await (await request({op:'record',mapId:'tern-archipelago',mode:'cocs',role:'player'})).json()).ok,false);
    report.status='passed';report.port=port;report.files=REPLAY_FILES.length;
  } catch(error) {report.status='failed';report.error=error.stack;throw error;}
  finally {
    if(child)await forceStop(child);
    writeFileSync(join(output,'replay-helper.log'),log);
    writeFileSync(join(output,'replay-result.json'),JSON.stringify(report,null,2)+'\n');
    rmSync(sandbox,{recursive:true,force:true});
  }
  return report;
}
export async function verifyFeatures(root,output,{replayOnly=false}={}) {
  root=resolve(root);output=resolve(output);mkdirSync(output,{recursive:true});
  const manifest=JSON.parse(readFileSync(join(root,'manifest.json'),'utf8'));
  assert.equal(manifest.target,process.platform==='win32'?'windows':'linux','Feature execution requires the matching platform');
  const report={scope:'additive extracted feature resource/helper checks',status:'running'};
  if(Object.keys(manifest.replay_runtime_sha256??{}).length)report.replay=await verifyReplayExtracted(root,output);
  if(!replayOnly) {
    const list=join(output,'feature-resources.json');
    writeFileSync(list,JSON.stringify(manifest.feature_resource_sha256??{}));
    const sandbox=mkdtempSync(join(tmpdir(),'cocs features fresh cwd '));
    let child,log='';
    try {
      child=spawn(join(root,process.platform==='win32'?'cocs.exe':'cocs.x86_64'),['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script',fileURLToPath(new URL('../../godot/tests/package_features.gd',import.meta.url)),'--',`--feature-list=${list}`],{cwd:sandbox,env:{...process.env,HOME:sandbox,USERPROFILE:sandbox,XDG_DATA_HOME:sandbox,APPDATA:sandbox,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe'],windowsHide:true});
      child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
      await new Promise((ok,fail)=>{child.once('spawn',ok);child.once('error',fail);});
      assert.deepEqual(await waitExit(child,30000),{code:0,signal:null});
      assert.match(log,/PACKAGE_FEATURE_RESOURCES_OK/);assert.doesNotMatch(log,/SCRIPT ERROR|ERROR:/);
      report.native='passed';
    } finally {if(child)await forceStop(child);writeFileSync(join(output,'feature-native.log'),log);rmSync(sandbox,{recursive:true,force:true});}
  }
  report.status='passed';writeFileSync(join(output,'feature-result.json'),JSON.stringify(report,null,2)+'\n');return report;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  if(!process.argv[2]||!process.argv[3])throw Error('Usage: verify_features.mjs PACKAGE EVIDENCE [--replay-only]');
  console.log(JSON.stringify(await verifyFeatures(process.argv[2],process.argv[3],{replayOnly:process.argv.includes('--replay-only')}),null,2));
}
