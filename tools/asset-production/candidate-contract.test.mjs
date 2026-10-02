import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {execFileSync} from 'node:child_process';
import {ROOT,CANDIDATES,identity,authorize,prepare,sha} from './candidate-admission.mjs';
import {worldEntry} from '../../port/multiplayer-worlds/catalog.mjs';
import {assertOutcome,controller} from './candidate-guidance.mjs';
import {validateSurface} from './material-validation.mjs';

test('all 6/6/1 candidates refuse public/unauthorized admission and byte/geometry identity substitution',()=>{
 assert.deepEqual(Object.values(CANDIDATES).map(a=>a.length),[6,6,1]);
 for(const [id,modes] of Object.entries(CANDIDATES))for(const mode of modes){
  const request=identity(id,mode),bytes=readFileSync(resolve(ROOT,`godot/multiplayer_worlds/generated/${id}.json`));
  assert.throws(()=>worldEntry(id,mode));
  assert.throws(()=>authorize({...request,enabled:false},bytes));
  assert.throws(()=>authorize({...request,mode:'payload'},bytes));
  assert.throws(()=>authorize({...request,expectedSha:'0'.repeat(64)},bytes));
  const wrong=structuredClone(request.data);wrong.arena.id='accepted-map';
  const changed=JSON.stringify(wrong);assert.throws(()=>authorize({...request,expectedSha:sha(changed)},changed));
  wrong.arena.id=id;wrong.geometryHash='0'.repeat(64);
  const bad=JSON.stringify(wrong);assert.throws(()=>authorize({...request,expectedSha:sha(bad)},bad));
 }
});
test('private derivatives resolve production dependencies without changing authority bodies; no server is run',()=>{
 const dir=mkdtempSync('/tmp/opencode/candidate-source-');
 try{
  const request=identity('stormglass-causeway','puma-race');prepare(dir,request);
  for(const name of ['core','payload','room','rooms','game-server','match']){
   const relative=['match'].includes(name)?`port/multiplayer-worlds/${name}.mjs`:`port/multiplayer-worlds/derived/${name}.mjs`;
   const strip=s=>s.replace(/(from\s*|import\s*)(['"])[^'"]+\2/g,'$1"IMPORT"');
   assert.equal(strip(readFileSync(resolve(dir,name+'.mjs'),'utf8')),strip(readFileSync(resolve(ROOT,relative),'utf8')));
   execFileSync(process.execPath,['--check',resolve(dir,name+'.mjs')],{timeout:10000});
  }
  const catalog=readFileSync(resolve(dir,'catalog.mjs'),'utf8');
  assert.ok(catalog.includes('/generated/"+id'));assert.ok(catalog.includes(request.expectedSha));
  assert.ok(catalog.includes('Candidate identity changed'));
 }finally{rmSync(dir,{recursive:true,force:true});}
});
test('win gate rejects timeouts, missing respawn and wrong winners on passive snapshots',()=>{
 const a={id:0,name:'host',team:0,frags:3,scoreStats:{captures:1,objectiveTime:2}},state={winner:0,overReason:'objective',leaders:['host']};
 const m={actors:[a],over:true,config:{fragLimit:3},snapshot:()=>state,objectiveState:{winner:0}};
 for(const mode of CANDIDATES['abyssal-pressureworks']){
  state.overReason=['deathmatch','teamdeathmatch'].includes(mode)?'frag':mode==='ctf'?'capture':'objective';
  assert.doesNotThrow(()=>assertOutcome(m,mode,{dead:true,alive:true}));
  assert.throws(()=>assertOutcome(m,mode,{}));
 }
 state.overReason='time';assert.throws(()=>assertOutcome(m,'ctf',{dead:true,alive:true}));
 state.overReason='capture';state.winner=1;assert.throws(()=>assertOutcome(m,'ctf',{dead:true,alive:true}));
});
test('route guidance is read-only and refuses disconnected source paths',()=>{
 const a=Object.freeze({id:0,x:0,z:0,health:100,deaths:0});
 const m=Object.freeze({nav:[{x:0,z:0},{x:3,z:0}],edges:[[1],[0]]});
 assert.ok(controller()(m,a,{x:3,z:0},'route').x>0);
 assert.throws(()=>controller()({...m,edges:[[],[]]},a,{x:3,z:0},'bad'));
});
test('queue exposes exactly 13 bounded ordinary-native journeys with no public binding edits',()=>{
 const plan=JSON.parse(readFileSync(resolve(ROOT,'port/finish/ASSET_PRODUCTION.json')));
 for(const [id,modes] of Object.entries(CANDIDATES)){
  const jobs=plan.units.find(u=>u.id===id).commands.filter(c=>c.id.startsWith('hosted-'));
  assert.deepEqual(jobs.map(j=>j.id.slice(7)),modes);
  for(const job of jobs){assert.equal(job.argv[1],'tools/asset-production/candidate-hosted.mjs');assert.ok(job.timeoutSeconds>=900&&job.timeoutSeconds<=1800);}
 }
});
test('all actual builder palette names resolve refined roles and selective normals',()=>{
 const c=JSON.parse(execFileSync('python3',['tools/asset-production/material_contract.py'],{cwd:ROOT,encoding:'utf8',timeout:15000}));
 assert.equal(Object.keys(c.units).length,6);
 assert.equal(c.units.robots.switchyard_vertex_enamel.normalRequired,false);
 assert.equal(c.units.robots.switchyard_vertex_enamel.colorRequired,true);
 assert.equal(c.units.vehicles.lamp.role,'preserve');
 assert.equal(c.units.scenery.biome4_moss.normalRequired,false);
 assert.equal(c.units.scenery.biome4_bark.normalRequired,true);
 for(const [unit,names] of Object.entries(c.units))for(const [name,rule] of Object.entries(names)){
  const mat={name,pbrMetallicRoughness:{baseColorTexture:{index:0,texCoord:1}},extras:{moth_finish_revision:2,moth_family:rule.role,moth_resource_sha256:JSON.stringify(rule.sourceHashes),moth_baked_master_sha256:Object.values(c.master)[0]}};
  if(rule.normalRequired)mat.normalTexture={index:1,texCoord:1,scale:rule.normalStrength};
  const p={attributes:{POSITION:0,NORMAL:1,TEXCOORD_1:2,COLOR_0:3}};
  assert.doesNotThrow(()=>validateSurface(c,unit,mat,p));
  assert.throws(()=>validateSurface(c,unit,{...mat,name:'unreviewed'},p));
  if(rule.role==='preserve')continue;
  assert.throws(()=>validateSurface(c,unit,mat,{attributes:{NORMAL:1,COLOR_0:3}}));
  if(rule.normalRequired)assert.throws(()=>validateSurface(c,unit,{...mat,normalTexture:undefined},p));
  else assert.throws(()=>validateSurface(c,unit,{...mat,normalTexture:{index:1}},p));
  if(rule.colorRequired)assert.throws(()=>validateSurface(c,unit,mat,{attributes:{NORMAL:1,TEXCOORD_1:2}}));
  assert.throws(()=>validateSurface(c,unit,{...mat,extras:{...mat.extras,moth_resource_sha256:'{}'}},p));
 }
});
