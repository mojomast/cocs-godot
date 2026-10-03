// Focused non-final Windows launch gate. The broader suite remains independently reported.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {verifyFinal} from './verify_final.mjs';
import {waitExit,forceStop} from './verify_expansion.mjs';

assert.equal(process.platform,'win32','Actual Windows required');
const root=resolve(process.argv[2]),out=resolve(process.argv[3]);
mkdirSync(out,{recursive:true});
const manifest=JSON.parse(readFileSync(join(root,'manifest.json')));
assert.equal(manifest.target,'windows');assert.equal(manifest.build_channel,'preview');
const sandbox=mkdtempSync(join(tmpdir(),'cocs focused preview '));
const env={...process.env,HOME:sandbox,USERPROFILE:sandbox,APPDATA:join(sandbox,'roaming'),LOCALAPPDATA:join(sandbox,'local')};
mkdirSync(env.APPDATA);mkdirSync(env.LOCALAPPDATA);
delete env.NODE_OPTIONS;delete env.NODE_PATH;delete env.COCS_SOURCE_DERIVATIVE;
const report={status:'running',platform:process.platform,port_commit:manifest.port_commit,
  scope:'Extracted PCK resources and graphical Home/Fighting AI/local/training/vehicle startup; public setup calls, not full input journeys or broad mode acceptance',cases:[]};
const probe=fileURLToPath(new URL('../../godot/tests/preview_package.gd',import.meta.url));
async function launch(name,args,markers){
  let log='',child;
  try{
    child=spawn(join(root,'cocs.exe'),['--rendering-method','gl_compatibility','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script',probe,'--',`--preview-output=${out}`,...args],{cwd:sandbox,env,stdio:['ignore','pipe','pipe']});
    child.stdout.on('data',b=>{log+=b});child.stderr.on('data',b=>{log+=b});
    await new Promise((ok,fail)=>{child.once('spawn',ok);child.once('error',fail)});
    assert.deepEqual(await waitExit(child,120000),{code:0,signal:null});
    for(const marker of markers)assert.ok(log.includes(marker),`Missing ${marker}`);
    assert.doesNotMatch(log,/SCRIPT ERROR|ERROR:|PREVIEW_PACKAGE_FAILED|ObjectDB instances leaked|resources still in use/);
    report.cases.push({name,passed:true,exit:0});
  }finally{
    if(child)await forceStop(child);
    writeFileSync(join(out,name+'.log'),log);
  }
}
try{
  report.resources=await verifyFinal(root,join(out,'final'));
  await launch('fighting',['--preview-case=fighting'],['PREVIEW_FIGHTING_OK mode=ai','PREVIEW_FIGHTING_OK mode=local','PREVIEW_FIGHTING_OK mode=training','PREVIEW_PACKAGE_GUI_OK']);
  const {createGameServer}=await import(pathToFileURL(join(root,'runtime/port/pass-two/modes/challenge-authority.mjs')));
  const game=await createGameServer({});
  try{
    await new Promise((ok,fail)=>{game.server.once('error',fail);game.server.listen(0,'127.0.0.1',ok)});
    await launch('vehicle',['--preview-case=vehicle','--map=sunscar-convoy',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--bots=0'],['PREVIEW_PACKAGE_VEHICLE_OK phase=active']);
  }finally{
    for(const socket of game.wss?.clients??[])socket.terminate();
    game.server.closeAllConnections?.();
    await new Promise(ok=>game.server.close(ok));
    await game.close?.();
    assert.equal(game.server.listening,false);
  }
  report.status='passed';
}catch(error){report.status='failed';report.error=error.stack;process.exitCode=1}
finally{
  writeFileSync(join(out,'preview-result.json'),JSON.stringify(report,null,2)+'\n');
  rmSync(sandbox,{recursive:true,force:true,maxRetries:5,retryDelay:100});
}
console.log(JSON.stringify(report,null,2));
