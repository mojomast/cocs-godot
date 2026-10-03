import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {productionResources,REQUIREMENTS,REQUIRED_UNITS} from './production_resources.mjs';
import {J_PRODUCER,J_PRODUCER_SHA,J_BASE,J_RUNTIME_ADVANCES,RACE_RUNTIME_ADVANCES,MELEE_ADDED,stormglassRuntimePolicy,STORMGLASS_GLB,STORMGLASS_INVENTORY,stormglassImportPaths,verifyStormglassImports} from './stormglass_imports.mjs';
import {WORLDS,worldEntry,readWorld} from '../../port/multiplayer-worlds/catalog.mjs';
import {CANDIDATES,identity} from '../asset-production/candidate-admission.mjs';
const read=p=>readFileSync(p),hash=b=>createHash('sha256').update(b).digest('hex');
const path='tools/godot-package/production_receipts/stormglass-causeway.json';
const options={read,has:existsSync,worldIds:Object.keys(WORLDS),strict:true};
function forged(id,mutate){
 const p=`tools/godot-package/production_receipts/${id}.json`,r=JSON.parse(read(p)),req=JSON.parse(read(REQUIREMENTS));mutate(r);const bytes=Buffer.from(JSON.stringify(r));req.units[id].promotion.sha256=hash(bytes);
 return ()=>productionResources({...options,read:x=>x===p?bytes:x===REQUIREMENTS?Buffer.from(JSON.stringify(req)):read(x)});
}
test('seven exact asset closures pass strict inventory; only one public Stormglass pair is registered',()=>{
 const result=productionResources(options);assert.deepEqual(result.pending,[]);
 assert.equal(Object.keys(result.units).length,7);assert.equal(result.units['stormglass-causeway'].expected.packageInputs.length,315);
 for(const id of REQUIRED_UNITS)for(const p of [...Object.keys(MELEE_ADDED),'godot/replay/stage.gd','godot/audio/playback_cleanup.gd'])assert.ok(result.units[id].expected.packageInputs.includes(p),id+': '+p);
 assert.deepEqual(WORLDS['stormglass-causeway'].modes,['puma-race']);assert.deepEqual(CANDIDATES['stormglass-causeway'],['puma-race']);
 assert.equal(Object.keys(WORLDS).length,13);assert.equal(Object.values(WORLDS).reduce((n,w)=>n+w.modes.length,0),73);
 assert.match(read('godot/multiplayer_worlds/catalog.gd').toString(),/"stormglass-causeway": \["puma-race"\]/);
 assert.equal(readWorld('stormglass-causeway').id,'stormglass-causeway');assert.doesNotThrow(()=>worldEntry('stormglass-causeway','puma-race'));
 for(const mode of ['puma-soccer','deathmatch','ctf','combined-arms'])assert.throws(()=>worldEntry('stormglass-causeway',mode));
 assert.throws(()=>identity('stormglass-causeway','puma-race'));
 assert.equal(Object.values(CANDIDATES).flat().length,13,'Historical candidate queue retained');
});
test('all J bytes equal the received commit; original receipt accepted/pending/native identities stay historical',()=>{
 const inventory=JSON.parse(read(STORMGLASS_INVENTORY)),r=JSON.parse(read(path)),original=JSON.parse(read(J_PRODUCER));
 assert.equal(hash(read(J_PRODUCER)),J_PRODUCER_SHA);
 for(const row of inventory.files)assert.equal(hash(execFileSync('git',['show',`9746a9e2:${row.path}`],{maxBuffer:128*1024*1024})),row.sha256);
 for(const [k,v]of Object.entries(original))assert.deepEqual(r[k],v);
 assert.equal(r.accepted,false);assert.equal(r.integrationReview.drivableReliefMetres,0);assert.equal(r.integrationReview.sharedProductionFeatureAcceptance,false);
 assert.equal(r.sourceFingerprint,'dd0f4fbea323ba8fa8ad4b7bf578c980c737495188f941fc8aa0b983dfd39d1c');
 for(const [p,c]of Object.entries(J_RUNTIME_ADVANCES)){assert.equal(r.nativeRuntimeHooks[p],c.before);assert.equal(r.runtimeHooks[p],stormglassRuntimePolicy(r.unit)[p].after);}
 assert.equal(execFileSync('git',['diff','38dfb3bd','--','game/','server/','port/multiplayer-worlds/derived/','port/multiplayer-worlds/wall_candidates.mjs','godot/sports/','godot/first_person/','tools/godot-multiplayer/new-maps/stormglass-causeway/','port/expansion-four/stormglass/'],{encoding:'utf8'}),'');
});
test('missing actual PNG or either sidecar type fails closed without reconstruction',()=>{
 const imports=stormglassImportPaths();assert.equal(imports.filter(p=>p.endsWith('.png')).length,11);assert.equal(imports.filter(p=>p.endsWith('.import')).length,12);
 for(const p of [imports.find(p=>p.endsWith('.png')),imports.find(p=>p.endsWith('.png.import')),STORMGLASS_GLB+'.import'])assert.throws(()=>productionResources({...options,has:x=>x!==p&&existsSync(x)}),/Required final production units remain pending/);
});
test('changed PNG, GLB/import policies and native process evidence cannot pass exact closure',()=>{
 for(const p of [stormglassImportPaths().find(p=>p.endsWith('.png')),STORMGLASS_GLB,STORMGLASS_GLB+'.import',J_BASE+'summary.json'])assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\nforged')]):read(x)}),/hash mismatch/);
 const r=JSON.parse(read(path));assert.throws(()=>verifyStormglassImports(p=>p===STORMGLASS_GLB+'.import'?Buffer.from(read(p).toString().replace('meshes/generate_lods=true','meshes/generate_lods=false')):read(p),r),/J (byte size|content hash)/);
});
test('forged original producer/native identity and skipped or rewritten runtime history fail',()=>{
 assert.throws(forged('stormglass-causeway',r=>r.accepted=true),/Original J field changed/);
 assert.throws(forged('stormglass-causeway',r=>r.pending=[]),/Original J field changed/);
 assert.throws(forged('stormglass-causeway',r=>r.nativeRuntimeHooks['godot/sports/chase.gd']='0'.repeat(64)),/Original J native runtime hooks/);
 assert.throws(forged('stormglass-causeway',r=>r.sourceFingerprint='0'.repeat(64)),/source fingerprint/);
 assert.throws(forged('stormglass-causeway',r=>r.stormglassPackageVerifierAdvance.runtimeChanged['godot/sports/chase.gd'].before='0'.repeat(64)),/Unreviewed Stormglass runtime advance/);
 assert.throws(forged('parallax-interiors',r=>delete r.stormglassPackageVerifierAdvance.runtimeChanged['godot/multiplayer_worlds/catalog.gd']),/Unreviewed Stormglass runtime advance/);
 assert.throws(forged('stormglass-causeway',r=>r.integrationReview.publicModes.push('puma-soccer')));
 assert.throws(forged('stormglass-causeway',r=>delete r.packageInputs[stormglassImportPaths()[0]]),/Incomplete production packageInputs/);
});
test('all six preceding receipt histories are unchanged and each new transaction binds exact previous bytes',()=>{
 for(const id of REQUIRED_UNITS.filter(id=>id!=='stormglass-causeway')){
  const p=`tools/godot-package/production_receipts/${id}.json`,bytes=execFileSync('git',['show',`38dfb3bd:${p}`]),old=JSON.parse(bytes),now=JSON.parse(read(p));
  for(const [k,v]of Object.entries(old))if(!['packageInputs','runtimeHooks'].includes(k))assert.deepEqual(now[k],v,id+': '+k);
  assert.equal(now.stormglassPackageVerifierAdvance.previousReceipt.sha256,hash(bytes));
 }
});
test('race and melee source steps cannot be skipped, restamped or replaced by later source',()=>{
 assert.throws(forged('vehicles',r=>delete r.stormglassPackageVerifierAdvance.runtimeChanged['godot/vehicle_assets/attachment.gd']),/Unreviewed Stormglass runtime advance/);
 assert.throws(forged('robots',r=>r.stormglassPackageVerifierAdvance.raceSourceAdvance.changed['godot/sports/hud.gd'].before='0'.repeat(64)),/Exact reviewed race source history/);
 assert.throws(forged('scenery',r=>r.stormglassPackageVerifierAdvance.meleeSourceAdvance.to='future'),/Exact reviewed melee source history/);
 assert.throws(forged('stormglass-causeway',r=>delete r.stormglassPackageVerifierAdvance.nativeToFeatureAdvance),/J native-to-feature history/);
 for(const p of [...Object.keys(MELEE_ADDED),'godot/vehicle_assets/attachment.gd'])assert.throws(()=>productionResources({...options,read:x=>x===p?Buffer.concat([read(x),Buffer.from('\n# future')]):read(x)}),/content hash mismatch/);
 const r=JSON.parse(read('tools/godot-package/production_receipts/vehicles.json'));
 assert.deepEqual(r.stormglassPackageVerifierAdvance.runtimeChanged['godot/vehicle_assets/attachment.gd'],RACE_RUNTIME_ADVANCES['godot/vehicle_assets/attachment.gd']);
});
