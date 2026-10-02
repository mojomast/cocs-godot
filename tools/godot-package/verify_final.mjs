import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdirSync,mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {forceStop,waitExit} from './verify_expansion.mjs';
export async function verifyFinal(root,output) {
  root=resolve(root);output=resolve(output);mkdirSync(output,{recursive:true});
  const manifest=JSON.parse(readFileSync(join(root,'manifest.json')));
  assert.equal(manifest.target,process.platform==='win32'?'windows':'linux','Final native proof requires the target host');
  const list=join(output,'final-inventory.json');
  const resources=manifest.final_resource_sha256;
  assert.ok(resources&&Object.hasOwn(resources,'godot/fighting/data/roster.json'),'Final fighting closure missing');
  writeFileSync(list,JSON.stringify({resources,raw:manifest.raw_resource_sha256}));
  const sandbox=mkdtempSync(join(tmpdir(),'cocs final clean cwd '));
  const env={...process.env,HOME:sandbox,USERPROFILE:sandbox,APPDATA:join(sandbox,'roaming'),LOCALAPPDATA:join(sandbox,'local'),XDG_CONFIG_HOME:join(sandbox,'config'),XDG_DATA_HOME:join(sandbox,'data'),XDG_CACHE_HOME:join(sandbox,'cache'),LP_NUM_THREADS:'1'};
  for(const p of ['roaming','local','config','data','cache'])mkdirSync(join(sandbox,p));
  delete env.NODE_OPTIONS;delete env.NODE_PATH;delete env.COCS_SOURCE_DERIVATIVE;
  let child,log='';const report={status:'running',scope:'native extracted PCK raw bytes, nine imported rigs/finishes, Home Fighting training and Home return; not human/GPU/audio acceptance',cwd:sandbox};
  try {
    child=spawn(join(root,process.platform==='win32'?'cocs.exe':'cocs.x86_64'),['--headless','--audio-driver','Dummy','--main-pack',join(root,'cocs.pck'),'--script',fileURLToPath(new URL('./package_final.gd',import.meta.url)),'--',`--final-list=${list}`],{cwd:sandbox,env,stdio:['ignore','pipe','pipe'],windowsHide:true});
    child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
    await new Promise((ok,fail)=>{child.once('spawn',ok);child.once('error',fail);});
    assert.deepEqual(await waitExit(child,90000),{code:0,signal:null});
    assert.match(log,/PACKAGE_FINAL_OK operators=9 home_fighting=true training=true/);
    assert.doesNotMatch(log,/SCRIPT ERROR|ERROR:|PACKAGE_FINAL_FAILED/);
    report.status='passed';
  }catch(error){report.status='failed';report.error=error.stack;throw error;}
  finally {
    if(child)await forceStop(child);
    writeFileSync(join(output,'final-native.log'),log);
    writeFileSync(join(output,'final-result.json'),JSON.stringify(report,null,2)+'\n');
    rmSync(sandbox,{recursive:true,force:true});
  }
  return report;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(await verifyFinal(process.argv[2],process.argv[3]),null,2));
