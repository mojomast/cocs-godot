import {execFileSync} from 'node:child_process';
import {readFile,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {root,sha256,verifyFrames} from './contracts.mjs';
import {productionProof,readProof,artifacts,digestFile} from './proof.mjs';

export async function ledgerIdentity(path) {
  return JSON.parse(execFileSync('python3',['-B',join(root,'tools/release/cinematic-v3/identity.py'),path],{cwd:root,encoding:'utf8',timeout:120000,maxBuffer:8*1024*1024}));
}
export async function checkBoundIdentity(p) {
  if(p.finishIdentity&&JSON.stringify(await ledgerIdentity(p.finishLedger))!==JSON.stringify(p.finishIdentity))throw Error('Capture belongs to another final input identity');
}
export async function closeReceipt(out,p) {
  if(!p.finishIdentity||!p.finishLedger)throw Error('No execution-time final ledger binding; historical captures cannot be re-stamped');
  await checkBoundIdentity(p);
  await productionProof(out,p);
  const installed=await readProof(join(out,'menu-installed','receipt.json'),'native-menu');
  if(!installed.installed||installed.installedSHA256!==await digestFile(join(root,'godot/ui/attract/demo.json'))||installed.manifestSHA256!==p.manifestSHA256)throw Error('Actual installed-menu identity proof required');
  const paths={plan:join(out,'plan.json'),installed:join(out,'menu-installed/receipt.json'),candidate:join(out,'attract-candidate.json'),edit:join(out,'edit/production-proof.json')};
  for(const s of p.shots){await verifyFrames(join(out,s.id),s,p.fps);paths[s.id]=join(out,s.id,'capture-receipt.json');}
  const executionPath=join(out,'native-execution.json');
  await writeFile(executionPath,JSON.stringify({status:'passed',executed:true,checks:p.shots.map(s=>({shot:s.id,frames:s.seconds*p.fps,passed:true})).concat([{installedMenu:true,passed:true},{encodedMaster:true,passed:true}]),failures:[]},null,2),{flag:'wx'});
  paths.execution=executionPath;
  const evidence=await artifacts(paths);
  for(const [name,path]of Object.entries(paths)){
    if(!path.endsWith('receipt.json')&&!path.endsWith('production-proof.json'))continue;
    const proof=JSON.parse(await readFile(path));
    for(const [key,value]of Object.entries(proof.artifacts??{}))evidence[`${name}/${key}`]=value;
  }
  const report={gate:'menu-trailer-native-production',owner:'Cinematic production',resource_class:'engine',evidence_kind:'native-cinematic-and-menu-production',
    input_identity:p.finishIdentity,status:'passed',executed:true,units:{'v3-native-shots':'passed','v3-encoded-master':'passed','installed-live-menu':'passed'},
    execution_report:'execution',artifacts:evidence};
  const file=join(out,'owner-closure.json'),bytes=JSON.stringify(report,null,2)+'\n';await writeFile(file,bytes,{flag:'wx'});
  await writeFile(join(out,'owner-reference.json'),JSON.stringify({gate:report.gate,adapter:'owner-closure',report:{path:file,sha256:sha256(bytes)}},null,2),{flag:'wx'});
  // Human watch/listening has its own manual gate; this cannot manufacture it.
  console.log('NATIVE_OWNER_CLOSURE',file);
}
