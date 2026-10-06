import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync,existsSync,renameSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {resolveReviewedDerivative} from '../godot-package/contact_derivative.mjs';
import {resolveActiveDerivative} from '../godot-dev/active_source.mjs';
import {verifyAuthoringResources} from '../godot-package/authoring_resources.mjs';
import {MAPS} from '../../game/maps.mjs';
import {terrainTriangles,terrainWallTriangles,terrainWallSegments} from '../../game/terrain.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
export function strictData(value,path='$',seen=new Set()) {
 if(value===null||typeof value==='string'||typeof value==='boolean')return value;
 if(typeof value==='number'){if(!Number.isFinite(value))throw Error(`${path}: nonfinite number`);return value;}
 if(typeof value!=='object')throw Error(`${path}: unsupported ${typeof value}`);
 if(seen.has(value))throw Error(`${path}: cycle`);
 if(!Array.isArray(value)&&Object.getPrototypeOf(value)!==Object.prototype&&Object.getPrototypeOf(value)!==null)throw Error(`${path}: nonplain object`);
 if(Object.getOwnPropertySymbols(value).length)throw Error(`${path}: symbol key`);
 seen.add(value);let out;
 if(Array.isArray(value)){out=[];for(let i=0;i<value.length;i++)out.push(strictData(value[i],`${path}[${i}]`,seen));}
 else {out={};for(const key of Object.keys(value).sort())out[key]=strictData(value[key],`${path}.${key}`,seen);}
 seen.delete(value);return out;
}
export function validateSelection(lock,selection,registry=MAPS) {
 if(!/^[0-9a-f]{40}$/.test(lock.source_commit??''))throw Error('source_commit must be pinned');
 if(!Array.isArray(lock.map_ids)||!lock.map_ids.length)throw Error('Empty map allowlist');
 if(new Set(lock.map_ids).size!==lock.map_ids.length)throw Error('Duplicate map IDs');
 if(selection.source_commit!==lock.source_commit)throw Error('Selection revision mismatch');
 if(JSON.stringify(selection.maps.map(m=>m.id))!==JSON.stringify(lock.map_ids))throw Error('Selection allowlist mismatch');
 for(const id of lock.map_ids)if(!registry.some(m=>m.id===id))throw Error(`Missing map ${id}`);
}
// terrain helpers deliberately expose optional material:undefined; omit ONLY this
// documented helper field. Source object undefined values remain hard failures.
const triangles=items=>items.map(({material,...rest})=>material===undefined?rest:{...rest,material});
export function normalizeMap(map) {
 const data={...map};
 // Authored structures use color:undefined to select renderer defaults. Record
 // these exact omissions, rather than silently dropping arbitrary undefined.
 const omitted_optional_fields=[];
 if(map.structures)data.structures=map.structures.map((s,i)=>{const out={...s};if(Object.hasOwn(out,'color')&&out.color===undefined){delete out.color;omitted_optional_fields.push(`structures[${i}].color`);}return out;});
 if(map.terrain){
  const {height,...terrain}=map.terrain;
  if(height!==undefined&&typeof height!=='function')throw Error('Unexpected terrain.height type');
  if(height&&!terrain.surfaces?.length)throw Error('Callable height lacks resolved surfaces');
  data.terrain={...terrain,support_triangles:triangles(terrainTriangles(map.terrain)),wall_triangles:triangles(terrainWallTriangles(map.terrain)),wall_segments:terrainWallSegments(map.terrain),height_policy:'triangulated_source_support_not_noise'};
 }
 return strictData({schema_version:1,omitted_optional_fields,source_map:data});
}
export function verifySource(lock,derivative=null,repositoryRoot=root) {
  const git=(...args)=>execFileSync('git',args,{cwd:repositoryRoot,encoding:'utf8'}).trim();
  derivative=resolveReviewedDerivative(derivative,p=>readFileSync(resolve(repositoryRoot,p)),(rev,p)=>execFileSync('git',['show',`${rev}:${p}`],{cwd:repositoryRoot}), (a,b)=>git('merge-base',a,b)===a);
  if(git('merge-base',lock.source_commit,'HEAD')!==lock.source_commit)throw Error('Checkout is not based on locked source');
  // Compare tracked source and dependency files to the lock, including unstaged edits.
  const tracked=git('ls-tree','-r','--name-only',lock.source_commit).split('\n').filter(p=>/^(game\/|server\/|assets\/|public\/|package.*json$)/.test(p));
  const changed=git('diff','--name-only',lock.source_commit,'--',...tracked).split('\n').filter(Boolean);
  // ls-tree/diff cannot see an index addition or an untracked runtime file.
  // Enumerate both index and visible working-tree candidates before deciding
  // whether strict mode or a derivative is eligible to build.
  const candidates=execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z','--',
    'game','server','assets','public',':(top,glob)package*.json'],{cwd:repositoryRoot,encoding:'utf8'}).split('\0').filter(Boolean);
  const added=[...new Set(candidates.filter(p=>!tracked.includes(p)&&!/^(game|server)\/.*\.test\.mjs$/.test(p)))].sort();
  const authoring=verifyAuthoringResources({read:p=>readFileSync(resolve(repositoryRoot,p)),isAncestor:(a,b)=>{
    try{return git('merge-base',a,b)===a;}catch{return false;}
  },sourceCommit:lock.source_commit,portCommit:git('rev-parse','HEAD'),added});
  const runtimeAdded=added.filter(p=>!Object.hasOwn(authoring,p));
  if(!derivative){if(changed.length||runtimeAdded.length)throw Error('Locked source differs from working tree');return;}
  if(derivative.schema_version!==1||derivative.source_commit!==lock.source_commit||!/^[0-9a-f]{40}$/.test(derivative.derivative_commit??'')||git('merge-base',derivative.derivative_commit,'HEAD')!==derivative.derivative_commit)throw Error('Invalid derivative source ancestry');
  const files=derivative.runtime_files;
  if(!files||typeof files!=='object'||Array.isArray(files)||!Object.keys(files).length)throw Error('Missing derivative runtime inventory');
  const actual=[...new Set([...changed,...runtimeAdded])].filter(p=>!/^(game|server)\/.*\.test\.mjs$/.test(p)).sort();
  const expected=Object.keys(files).sort();
  for(const p of expected)if(!/^(game|server)\/[a-z0-9-]+\.mjs$/.test(p)||! /^[0-9a-f]{64}$/.test(files[p]))throw Error(`Invalid derivative source entry: ${p}`);
  if(JSON.stringify(actual)!==JSON.stringify(expected))throw Error('Derivative source inventory differs from locked source');
  for(const p of expected){
   const committed=execFileSync('git',['show',`${derivative.derivative_commit}:${p}`],{cwd:repositoryRoot,stdio:['ignore','pipe','pipe']});
   const checksum=bytes=>createHash('sha256').update(bytes).digest('hex');
   if(checksum(committed)!==files[p]||checksum(readFileSync(resolve(repositoryRoot,p)))!==files[p])throw Error(`Derivative source byte mismatch: ${p}`);
  }
  return derivative;
}
export function build(output=resolve(root,'godot/content/generated')) {
  const lock=JSON.parse(readFileSync(resolve(root,'port/contracts/source-lock.json')));
  const selection=JSON.parse(readFileSync(resolve(root,'port/contracts/map-selection.json')));
  const derivative=resolveActiveDerivative(process.env.COCS_SOURCE_DERIVATIVE).contract;
  validateSelection(lock,selection);verifySource(lock,derivative);
 const stage=output+'.staging';if(existsSync(stage))throw Error('Staging output exists; inspect/remove before retry');
 mkdirSync(stage,{recursive:true});
  const manifest={schema_version:1,exporter_version:'0.1.0',source_commit:lock.source_commit,...(derivative?{source_derivative_commit:derivative.derivative_commit}:{}),godot_version:lock.godot_version,content_kind:'semantic-diagnostic',release_ready:false,coordinates:{units:'metres',up:'+Y',forward:'-Z',mirror:false},maps:[]};
 try {
  for(const id of lock.map_ids){
   const map=MAPS.find(m=>m.id===id);const text=JSON.stringify(normalizeMap(map))+'\n';
   mkdirSync(`${stage}/maps/${id}`,{recursive:true});writeFileSync(`${stage}/maps/${id}/map.json`,text);
   manifest.maps.push({id,name:map.name,modes:map.arena.play,path:`maps/${id}/map.json`,sha256:createHash('sha256').update(text).digest('hex'),bytes:Buffer.byteLength(text),world_glb:null,counts:Object.fromEntries(['blocks','spawns','pickups','navNodes','structures','props','vehicles','traversal'].map(k=>[k,map[k]?.length??0])),support_triangles:map.terrain?terrainTriangles(map.terrain).length:0});
  }
  writeFileSync(`${stage}/manifest.json`,JSON.stringify(manifest,null,2)+'\n');
  if(existsSync(output))rmSync(output,{recursive:true});renameSync(stage,output);
 }catch(error){rmSync(stage,{recursive:true,force:true});throw error;}
 console.log(`Exported ${manifest.maps.length} semantic maps; visual/release gate remains closed`);return manifest;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 if(process.argv.includes('--release'))throw Error('Release disabled: visual resources and gameplay acceptance outstanding');
 build(process.argv[2]?resolve(process.argv[2]):undefined);
}
