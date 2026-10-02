// Test-only capability and exact-byte admission. Never imported by public code.
import assert from 'node:assert/strict';
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {canonical,worldEntry as publicEntry} from '../../port/multiplayer-worlds/catalog.mjs';
export const ROOT=fileURLToPath(new URL('../../',import.meta.url));
export const CANDIDATES=Object.freeze({
 'vesper-viaduct':['deathmatch','teamdeathmatch','ctf','domination','koth','uplink'],
 'abyssal-pressureworks':['deathmatch','teamdeathmatch','ctf','koth','domination','holdout'],
 'stormglass-causeway':['puma-race'],
});
export const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
export function authorize({id,mode,enabled=false,expectedSha},bytes){
 assert.equal(enabled,true,'Explicit private admission required');
 assert.ok(Object.hasOwn(CANDIDATES,id)&&CANDIDATES[id].includes(mode),'Unauthorized candidate pair');
 assert.equal(sha(bytes),expectedSha,'Candidate byte identity mismatch');
 const data=JSON.parse(bytes);
 assert.equal(data.schemaVersion,1);assert.equal(data.id,id);assert.equal(data.arena.id,id);
 assert.equal(data.name,data.arena.name);assert.deepEqual(data.arena.modeBindings,{});
 assert.deepEqual(data.arena.candidateModes,CANDIDATES[id]);
 assert.equal(sha(canonical(data.arena)),data.geometryHash,'Candidate geometry mismatch');
 assert.throws(()=>publicEntry(id,mode),'Public candidate admission must remain closed');
 return data;
}
export function identity(id,mode){
 const bytes=readFileSync(resolve(ROOT,`godot/multiplayer_worlds/generated/${id}.json`));
 const request={id,mode,enabled:true,expectedSha:sha(bytes)};
 return {...request,data:authorize(request,bytes)};
}

// Materialize only transport/Match derivatives, rewriting their static import
// edges to absolute original modules or private peers. No gameplay substitutions.
// Catalog injection uses the same pre-constructor arena seam as production.
export function prepare(directory,request){
 const path=resolve(ROOT,`godot/multiplayer_worlds/generated/${request.id}.json`);
 authorize(request,readFileSync(path));
 mkdirSync(directory,{recursive:true});
 const sources=['port/multiplayer-worlds/catalog.mjs','port/multiplayer-worlds/match.mjs',
  ...['core','payload','room','rooms','game-server'].map(n=>`port/multiplayer-worlds/derived/${n}.mjs`)];
 const destinations=new Map(sources.map(p=>[resolve(ROOT,p),pathToFileURL(resolve(directory,p.split('/').at(-1))).href]));
 const records={};
 for(const relative of sources){
  const original=resolve(ROOT,relative),bytes=readFileSync(original,'utf8');records[relative]=sha(bytes);
  let text=bytes.replace(/(from\s*|import\s*)(['"])(\.[^'"]+)\2/g,(_,prefix,quote,spec)=>{
   const target=resolve(dirname(original),spec);return prefix+quote+(destinations.get(target)??pathToFileURL(target).href)+quote;
  });
  if(relative.endsWith('/catalog.mjs')){
   // Keep full production validation functions; extend only this private table.
   const anchor='export const WORLDS = Object.freeze({';
   assert.equal(text.split(anchor).length,2,'Catalog seam drift');
   text=text.replace(anchor,anchor+`\n${JSON.stringify(request.id)}:Object.freeze({name:${JSON.stringify(request.data?.name??JSON.parse(readFileSync(path)).name)},modes:Object.freeze([${JSON.stringify(request.mode)}])}),`);
   const url='new URL(`../../godot/multiplayer_worlds/generated/${id}.json`,import.meta.url)';
   assert.ok(text.includes(url));
   text=text.replace(url,`new URL(${JSON.stringify(pathToFileURL(resolve(ROOT,'godot/multiplayer_worlds/generated')).href+'/')}+id+'.json')`);
   // Exact identity checked at module load AND every candidate read.
   const guard=`if(id===${JSON.stringify(request.id)}&&createHash('sha256').update(readFileSync(${JSON.stringify(path)})).digest('hex')!==${JSON.stringify(request.expectedSha)})throw Error('Candidate identity changed');`;
   text=text.replace('export function readWorld(id){','export function readWorld(id){'+guard);
  }
  writeFileSync(fileURLToPath(destinations.get(original)),text);
 }
 writeFileSync(resolve(directory,'derivation.json'),JSON.stringify({request:{...request,data:undefined},sources:records,policy:'only static import edges and private catalog admission; exact production validation and simulation'},null,2));
 return {server:resolve(directory,'game-server.mjs'),records};
}
