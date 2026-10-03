// Fresh, explicitly reviewed generation intent for checkerboard-dominated xy
// results. Originals remain immutable in provider/raw and candidate/.
import fs from 'node:fs';
const root=new URL('./',import.meta.url),file=new URL('refined.json',root);
if(fs.existsSync(file))throw new Error('Refinement already prepared; reuse its journal/IDs');
const jobs=['live.json','supplemental.json'].flatMap(p=>JSON.parse(fs.readFileSync(new URL(p,root))).jobs).filter(j=>j.params.style==='xy').map(j=>({id:`${j.id}-x-refined`,engine:j.engine,credits:1,raw:`${j.id}-x-refined`,params:{...j.params,style:'x',strength:.085},bake:{type:'raw-grid',name:j.id}}));
fs.writeFileSync(file,JSON.stringify({version:1,contractSnapshot:'contracts/engines.json',jobs,emitters:[]})+'\n');
console.log(`Prepared ${jobs.length} structure-preserving x-only refinements, 1 estimated credit each.`);
