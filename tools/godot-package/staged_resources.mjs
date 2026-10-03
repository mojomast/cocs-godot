// Exclusion of candidate artifacts is neither art approval nor runtime promotion.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
export const STAGED_REVIEW='7ae3f2f54cd1d0764274d5c014eeb937e161af29';
export const STAGED_CANDIDATE='4a2f120158040bdd0a894132d09eb8d6eea379aa';
export const STAGED_MANIFEST='tools/godot-multiplayer/new-maps/gravemill-foundry/revision5/evidence/final-manifest.json';
export const STAGED_MANIFEST_SHA='03c5a898d819363ebd56614bc7f7ba0c6337250563457d4ce5b52ac9b5e1d6c5';
export const STAGED_ENTRIES=Object.freeze([
 Object.freeze({id:'foundry-r5',activation:STAGED_REVIEW,candidate:STAGED_CANDIDATE,manifest:STAGED_MANIFEST,sha256:STAGED_MANIFEST_SHA,count:63,status:'staged-not-runtime-promoted'}),
 Object.freeze({id:'foundry-r6',activation:'fceaac00b3b74a0272294a9470ab30ae7e5c4846',candidate:'fceaac00b3b74a0272294a9470ab30ae7e5c4846',source:'b5dfe08e36abf0c125c6a05abaf8cd28dce39184',manifest:'tools/godot-multiplayer/new-maps/gravemill-foundry/revision6/evidence/W/final-manifest.json',sha256:'234cdbe8118cddf0d10b605e4eebd1fb512ddad73f35fcc9bde745715f5766fc',count:74,status:'unpromoted-artifact-review-pending'}),
]);
const hash=b=>createHash('sha256').update(b).digest('hex');
export const nativeCandidate=p=>p.startsWith('godot/')&&!['godot/tests/','godot/content/','godot/.godot/'].some(prefix=>p.startsWith(prefix))&&!['godot/.gitignore','godot/export_presets.cfg'].includes(p);
export function stagedResources({paths,read,required}){
 const files={},entries=[],ids=required===true?['foundry-r5']:required||[];
 assert.ok(Array.isArray(ids)&&new Set(ids).size===ids.length&&ids.every(id=>STAGED_ENTRIES.some(e=>e.id===id)),'Unknown staged policy entry');
 for(const entry of STAGED_ENTRIES.filter(e=>ids.includes(e.id))){
  const b=read(entry.manifest);assert.equal(hash(b),entry.sha256,`Exact ${entry.id==='foundry-r5'?'R5':'R6'} staged manifest`);
  const selected=Object.entries(JSON.parse(b).files).filter(([p])=>nativeCandidate(p));
  assert.equal(selected.length,entry.count,'Exact '+entry.id+' non-test scope');
  for(const [p,r]of selected){
   assert.ok(!Object.hasOwn(files,p),'Overlapping staged inventories: '+p);files[p]=r;
   assert.ok(paths.includes(p),'Missing staged resource: '+p);
   const b=read(p);assert.equal(b.length,r.bytes,'Staged byte length: '+p);assert.equal(hash(b),r.sha256,'Staged hash: '+p);
  }
  entries.push({...entry,paths:selected.map(([p])=>p)});
 }
 const candidates=paths.filter(nativeCandidate);
 // Reserve revision namespaces for explicit review. Unknown entries fail,
 // rather than becoming either silently excluded or implicitly shipped.
 for(const p of candidates)if(p.includes('/revisions/'))assert.ok(Object.hasOwn(files,p),'Unreviewed staged revision: '+p);
 const nativeFiles=candidates.filter(p=>!Object.hasOwn(files,p));
 rejectStagedReferences(nativeFiles,read,files);
 return {status:'staged-not-runtime-promoted',entries,files,nativeFiles,excludePaths:Object.keys(files).map(p=>p.slice(6)).sort(),provenance:entries.map(e=>e.manifest)};
}
export function rejectStagedReferences(paths,read,files){
 const needles=Object.keys(files).map(p=>p.slice(p.lastIndexOf('/')+1));
 const uids=Object.keys(files).filter(p=>p.endsWith('.import')).flatMap(p=>[...read(p).toString().matchAll(/uid="(uid:\/\/[^\"]+)"/g)].map(m=>m[1]));
 for(const p of paths){
  if(!/\.(mjs|gd|gdshader|gdshaderinc|tscn|tres|json|godot|import|cfg)$/.test(p))continue;
  const text=read(p).toString();
  assert.ok(!text.includes('/revisions/')&&!needles.some(n=>text.includes(n))&&!uids.some(n=>text.includes(n)),'Production reference to staged revision: '+p);
 }
}
export function rejectStagedInputs(paths,policy){
 for(const p of paths)assert.ok(!Object.hasOwn(policy.files,p.replace(/^runtime\//,'')),'Staged resource in runtime/raw/export inputs: '+p);
}
export function gitStagedResources(repo,commit,{working=false,consumers=[]}={}){
 const git=(...args)=>execFileSync('git',args,{cwd:repo,maxBuffer:128*1024*1024,stdio:['ignore','pipe','pipe']});
 const required=STAGED_ENTRIES.filter(e=>{try{return git('merge-base',e.activation,commit).toString().trim()===e.activation;}catch{return false;}}).map(e=>e.id);
 const paths=git('ls-tree','-r','--name-only','-z',commit,'--','godot').toString().split('\0').filter(Boolean);
 if(working){
  for(const p of git('ls-files','--cached','-z','--','godot').toString().split('\0'))if(p&&!paths.includes(p))paths.push(p);
  for(const p of git('ls-files','--others','--exclude-standard','-z','--','godot').toString().split('\0'))if(p.includes('/revisions/')&&!paths.includes(p))paths.push(p);
 }
 const cache=new Map(),read=p=>{if(!cache.has(p))cache.set(p,working?readFileSync(join(repo,p)):git('show',`${commit}:${p}`));return cache.get(p);};
 const policy=stagedResources({paths,read,required});
 rejectStagedReferences(consumers,read,policy.files);return policy;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const closure=process.argv[4]?JSON.parse(readFileSync(process.argv[4])):{};
 const consumers=[...Object.keys(closure.modules??{}),...Object.keys(closure.adapterModules??{}),...Object.entries(closure).filter(([k])=>k.endsWith('Files')).flatMap(([,v])=>v)];
 console.log(JSON.stringify(gitStagedResources(process.argv[2],process.argv[3],{working:true,consumers})));
}
