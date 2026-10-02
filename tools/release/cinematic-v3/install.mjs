import {readFile,writeFile,rename,unlink,mkdir} from 'node:fs/promises';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {root,sha256} from './contracts.mjs';
import {productionProof,writeProof,digestFile} from './proof.mjs';
const target=join(root,'godot/ui/attract/demo.json');
async function atomicReplace(path,bytes) {
  const temporary=path+`.cinematic-${randomBytes(8).toString('hex')}.tmp`;
  try{await writeFile(temporary,bytes,{flag:'wx'});await rename(temporary,path);}finally{await unlink(temporary).catch(e=>{if(e.code!=='ENOENT')throw e;});}
}

// Low-level transaction is separately tested with a disposable target. The public
// CLI uses installMenu(), whose native/master/cadence checks run BEFORE any write.
export async function replaceMenuTransaction({out,path=target,candidate,expectedBefore,check}) {
  const before=await readFile(path),next=await readFile(candidate);
  if(sha256(before)!==expectedBefore)throw Error('Installed menu changed since source preparation');
  const directory=join(out,'installation');await mkdir(directory);
  const backup=join(directory,'preserved-before.json');await writeFile(backup,before,{flag:'wx'});
  const record={version:1,target:path,candidateSHA256:sha256(next),beforeSHA256:sha256(before),backup};
  await writeFile(join(directory,'transaction.json'),JSON.stringify(record,null,2),{flag:'wx'});
  try {
    await atomicReplace(path,next);
    await check();
    if(await digestFile(path)!==record.candidateSHA256)throw Error('Installed bytes changed during native check');
    return await writeProof(join(directory,'installed.json'),{kind:'menu-installation',status:'passed',executed:true,...record},
      {backup,transaction:join(directory,'transaction.json'),installed:path});
  } catch(error) {
    // Never overwrite unrelated concurrent work. Explicit rollback can diagnose it.
    if(await digestFile(path)===record.candidateSHA256)await atomicReplace(path,before);
    await writeFile(join(directory,'failure.json'),JSON.stringify({status:'failed',error:error.message,restoredSHA256:await digestFile(path)},null,2),{flag:'wx'});
    throw error;
  }
}
export async function installMenu(out,p,check) {
  if(p.finishIdentity)throw Error('Install before freezing the final ledger; do not change final capture identity');
  await productionProof(out,p);
  const expected=p.provenance.files['godot/ui/attract/demo.json'];
  if(!expected)throw Error('Source preparation did not bind preserved menu');
  return replaceMenuTransaction({out,candidate:join(out,'attract-candidate.json'),expectedBefore:expected,check});
}
export async function rollbackMenu(out) {
  const directory=join(out,'installation'),record=JSON.parse(await readFile(join(directory,'transaction.json')));
  if(record.target!==target)throw Error('Rollback target is not this checkout menu');
  const backup=await readFile(record.backup),current=await digestFile(target);
  if(sha256(backup)!==record.beforeSHA256)throw Error('Preserved menu backup identity mismatch');
  if(current!==record.beforeSHA256&&current!==record.candidateSHA256)throw Error('Rollback refuses unrelated changed menu');
  if(current!==record.beforeSHA256)await atomicReplace(target,backup);
  await writeFile(join(directory,`rollback-${Date.now()}.json`),JSON.stringify({status:'restored',sha256:await digestFile(target)},null,2),{flag:'wx'});
}
