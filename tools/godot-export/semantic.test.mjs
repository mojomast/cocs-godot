import test from 'node:test';
import assert from 'node:assert/strict';
import {strictData,normalizeMap,validateSelection,verifySource,build} from './semantic.mjs';
import {DESTINATION_MAPS} from '../../game/destination-maps.mjs';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
test('strict serializer rejects silent JSON losses',()=>{
 const cycle={};cycle.self=cycle;
 for(const value of [undefined,()=>1,NaN,Infinity,new Float32Array([1]),new Map(),cycle,[,],{x:undefined},{x:1n}])assert.throws(()=>strictData(value));
 assert.deepEqual(strictData({z:null,a:[true,3]}),{a:[true,3],z:null});
});
test('allowlist fails closed',()=>{
 const source_commit='a'.repeat(40),lock={source_commit,map_ids:['one']},selection={source_commit,maps:[{id:'one'}]};
 validateSelection(lock,selection,[{id:'one'}]);
 for(const bad of [{...lock,source_commit:null},{...lock,map_ids:[]},{...lock,map_ids:['one','one']}])assert.throws(()=>validateSelection(bad,selection));
 assert.throws(()=>validateSelection(lock,selection,[]));
 assert.throws(()=>validateSelection(lock,{...selection,source_commit:'b'.repeat(40)},[{id:'one'}]));
});
test('selected maps preserve every root field and resolve callable terrain',()=>{
 for(const map of DESTINATION_MAPS){const out=normalizeMap(map).source_map;assert.deepEqual(Object.keys(out).sort(),Object.keys(map).sort());assert.deepEqual(out.spawns,map.spawns);assert.deepEqual(out.blocks,map.blocks);if(map.terrain){assert.ok(out.terrain.support_triangles.length);assert.ok(!('height' in out.terrain));}}
});
test('two point walls survive despite no wall triangles',()=>{
 const t={surfaces:[],walls:[{a:[0,0,0],b:[1,2,0]}]};const out=normalizeMap({terrain:t});assert.equal(out.source_map.terrain.wall_triangles.length,0);assert.equal(out.source_map.terrain.wall_segments.length,1);
});
test('two clean builds have identical manifests and asset hashes',()=>{
 const lock=JSON.parse(readFileSync(new URL('../../port/contracts/source-lock.json',import.meta.url)));
 const derivative=JSON.parse(readFileSync(new URL('../../port/contracts/lattice-catalog-derivative.json',import.meta.url)));
 assert.throws(()=>verifySource(lock),/Locked source differs/, 'the original pinned export remains strict');
 verifySource(lock,derivative);
 assert.throws(()=>verifySource(lock,{...derivative,runtime_files:{...derivative.runtime_files,'game/cocs.mjs':'0'.repeat(64)}}),/byte mismatch/);
 const temp=mkdtempSync(join(tmpdir(),'cocs-export-'));
 const previous=process.env.COCS_SOURCE_DERIVATIVE;
 try{process.env.COCS_SOURCE_DERIVATIVE=new URL('../../port/contracts/lattice-catalog-derivative.json',import.meta.url).pathname;const a=build(join(temp,'a'));const b=build(join(temp,'b'));assert.deepEqual(a,b);assert.equal(a.source_derivative_commit,derivative.derivative_commit);assert.equal(a.maps.length,9);for(const entry of a.maps)assert.deepEqual(readFileSync(join(temp,'a',entry.path)),readFileSync(join(temp,'b',entry.path)));}finally{if(previous===undefined)delete process.env.COCS_SOURCE_DERIVATIVE;else process.env.COCS_SOURCE_DERIVATIVE=previous;rmSync(temp,{recursive:true});}
});
