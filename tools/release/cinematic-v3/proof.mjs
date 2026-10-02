import {readFile,lstat,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {createReadStream} from 'node:fs';
import {verifyFrames} from './contracts.mjs';
export async function digestFile(path) {
  const info=await lstat(path);if(!info.isFile()||info.isSymbolicLink())throw Error(`Expected regular evidence file: ${path}`);
  const hash=createHash('sha256');for await(const chunk of createReadStream(path))hash.update(chunk);return hash.digest('hex');
}
export async function artifacts(paths) {
  const result={};for(const [key,path]of Object.entries(paths))result[key]={path:resolve(path),sha256:await digestFile(path)};return result;
}
export async function verifyArtifacts(records) {
  if(!records||!Object.keys(records).length)throw Error('Missing execution-time artifact inventory');
  for(const row of Object.values(records))if(!row.path||await digestFile(row.path)!==row.sha256)throw Error('Execution artifact identity mismatch');
}
export async function writeProof(path,value,paths) {
  const record={...value,artifacts:await artifacts(paths)};
  await writeFile(path,JSON.stringify(record,null,2)+'\n',{flag:'wx'});return record;
}
export async function readProof(path,kind) {
  const proof=JSON.parse(await readFile(path));
  if(proof.kind!==kind||proof.executed!==true||proof.status!=='passed')throw Error('Missing actual executed production proof');
  await verifyArtifacts(proof.artifacts);return proof;
}
export async function productionProof(out,p) {
  for(const shot of p.shots){const proof=await readProof(join(out,shot.id,'capture-receipt.json'),'native-shot');
    if(proof.inputSHA256!==p.inputSHA256||proof.manifestSHA256!==p.manifestSHA256||proof.assetSHA256!==p.assets.sha256||proof.frames!==shot.seconds*p.fps)throw Error('Shot capture identity mismatch');
    await verifyFrames(join(out,shot.id),shot,p.fps,p.inputSHA256);
    for(const name of ['godot.log','godot.log.process.json','cadence.jsonl','replay.jsonl','invocation.json','asset-inputs.json'])if(!proof.artifacts[name])throw Error('Missing original capture execution artifact');
    const execution=JSON.parse(await readFile(join(out,shot.id,'godot.log.process.json')));
    if(execution.status!=='passed'||execution.code!==0||execution.descendantsAfterParentExit||execution.reason)throw Error('Native execution did not exit cleanly');
    const log=await readFile(join(out,shot.id,'godot.log'),'utf8');
    if(!log.includes(`CINEMATIC_V3_OK ${shot.id} frames=${shot.seconds*p.fps}`)||/SCRIPT ERROR|^ERROR:|resources still in use|ObjectDB instances leaked/m.test(log))throw Error('Native capture did not close cleanly');}
  const menu=await readProof(join(out,'menu-native','receipt.json'),'native-menu');
  if(menu.inputSHA256!==p.inputSHA256||menu.manifestSHA256!==p.manifestSHA256||menu.assetSHA256!==p.assets.sha256)throw Error('Menu capture identity mismatch');
  const edit=await readProof(join(out,'edit','production-proof.json'),'encoded-master');
  if(edit.inputSHA256!==p.inputSHA256||edit.manifestSHA256!==p.manifestSHA256||edit.assetSHA256!==p.assets.sha256)throw Error('Edit identity mismatch');
  return {menu,edit};
}
