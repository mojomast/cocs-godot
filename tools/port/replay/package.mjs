// Parent package hook. Copies only this presentation helper and the unchanged
// source demo module into a fresh external runtime; never overwrites an artifact.
import {mkdirSync,copyFileSync,existsSync,writeFileSync,readFileSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {verifySourceModule} from './adapter.mjs';
const root=fileURLToPath(new URL('../../../',import.meta.url));
const output=resolve(process.argv[2]??'');
if(!process.argv[2]||existsSync(output)) throw Error('Pass a fresh replay-runtime output directory');
verifySourceModule();
const files=['game/demo.mjs','godot/replay/admission.json','tools/port/replay/adapter.mjs','tools/port/replay/service.mjs'];
const hashes={};
for(const path of files) {
  const target=resolve(output,path);mkdirSync(dirname(target),{recursive:true});copyFileSync(resolve(root,path),target);
  hashes[path]=createHash('sha256').update(readFileSync(target)).digest('hex');
}
writeFileSync(resolve(output,'manifest.json'),JSON.stringify({version:1,kind:'read-only-source-demo-adapter',files:hashes},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,files:files.length,sourceModuleVerified:true}));
