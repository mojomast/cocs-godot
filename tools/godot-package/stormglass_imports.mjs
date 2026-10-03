import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
export const STORMGLASS_GLB='godot/multiplayer_worlds/art/worlds/stormglass-causeway.glb';
export const STORMGLASS_INVENTORY='tools/godot-package/stormglass_j_inventory.json';
export const J_BASE='port/expansion-four/stormglass/evidence/production-j/';
export const J_PRODUCER=J_BASE+'generic-receipt.json';
export const J_PRODUCER_SHA='df3ec7f7a5b2ab0b76701ad9ee777eeeb934f64fdbca984a76262b1ab91697b3';
export const J_STAGES=[
 ['20261003T054201.375093Z-build','build'],
 ['20261003T054210.294563Z-import','import'],
 ['20261003T054509.988544Z-reopen-original','reopen-original'],
 ['20261003T054515.058809Z-reopen','independent-reopen'],
 ['20261003T055018.455696Z-native','native'],
];
export const J_RUNS=['2026-10-03T05-59-03.606Z-stormglass-causeway-puma-race','2026-10-03T06-00-57.076Z-stormglass-causeway-puma-race'];
export const STORMGLASS_EVIDENCE=[STORMGLASS_INVENTORY,...['generic-receipt.json','summary.json','release-j.json','art-audit.json'].map(p=>J_BASE+p),
 ...J_STAGES.flatMap(([dir,name])=>[`${name}-process.json`,`${name}.log`].map(p=>J_BASE+'stages/'+dir+'/'+p)),
 ...J_RUNS.flatMap(dir=>['outcome.json','teardown.json'].map(p=>J_BASE+'runs/'+dir+'/'+p)),
 'port/expansion-four/stormglass/PAIR-PROPOSAL-J.json','tools/godot-multiplayer/new-maps/stormglass-causeway/export-report.json'];
export const STORMGLASS_SUPPORTING_RUNTIME={
 'godot/multiplayer_worlds/catalog.gd':{before:'65a0b3f6fb962eec1cf0b2c0c42a9bfd27713cc850f799e5ab1cc7c72d0cc53a',after:'c902cb9c083772c3ad3c75fdc1f8e3a5f1c4e226f54aafb67b7b32c19c76e61d'},
};
// J actually exercised the old camera/control/HUD sources; current source was
// parent-reviewed in a5c26f25, with native feature gates still pending.
export const J_RUNTIME_ADVANCES={
 'godot/multiplayer_worlds/sports_demo.gd':{before:'78b86c3874bbc7e91069ac6c8d65fb9468fecbfcf7cbe34f63fcbdd8c13232b9',after:'f6a121b02b8b1776d59140120651abf6c35da4b25453c73618bf55a0f307930b'},
 'godot/sports/chase.gd':{before:'57b92456b701f39f75e84864eedc03809238adbe849f0675240abdf03a5f3abc',after:'c589874c000503647a79fc435b3715fffe6027ab0fc89744975f68900e69ef17'},
 'godot/sports/controls.gd':{before:'6c55e17862ce148b23998a7725d848d2f3744af4342217108f81105373a21822',after:'3401604703866777ad2875260b4c918ed5faa15881593bcf9849b797c315c7c2'},
 'godot/sports/hud.gd':{before:'08ffcb18b690917ae0740d3fb2dc91a9c13c04f5f9c8aa9aa05924407ff02250',after:'be4daecdd6c92711c88be8a7a5d0a198bbd8cc7200aadc61371e2fda4e8f1a16'},
};
export const RACE_RUNTIME_ADVANCES={
 'godot/multiplayer_worlds/sports_demo.gd':{before:'f6a121b02b8b1776d59140120651abf6c35da4b25453c73618bf55a0f307930b',after:'928cab00e03bafd6088b16734833b8f1c4cea6b341353235d63f7c1f04d187c8'},
 'godot/sports/av_lifecycle.gd':{before:'a266a96e3bf7c5d186cd279ba9a0b619fb5f0c5fcd26a941ee1b251e43b1a64c',after:'9811ae6751579d3ce80a54f15a1889c2eccba3e7f724610b89a66c2f5fdbbbb5'},
 'godot/sports/demo.gd':{before:'dc030049e3f49d6756aef76c77f5cc1dc3f52deb9a7c9b1a26b8d02113e00102',after:'c9f6ab3962ca0dcf184b5c1801c938065a5339e64cf87a1ff4c0dc2031abb01b'},
 'godot/sports/hud.gd':{before:'be4daecdd6c92711c88be8a7a5d0a198bbd8cc7200aadc61371e2fda4e8f1a16',after:'eaa003b9b5cc473a424cf6338523593d1d082ef58a6b6947264a6b126eff1e0e'},
 'godot/vehicle_assets/attachment.gd':{before:'13fc00ebd1d5495769df1d120329e5462724cf09487697a6258f92a1545f3a63',after:'89a11d2c2987b5be14f8d6458079cd27dc16f461b1530ce66d6ac9e3b4e66f21'},
};
export const MELEE_RUNTIME_ADVANCES={
 'godot/replay/stage.gd':{before:'e7d1cb41c1732bcae132f9ab05d9e078fc9d47e2c255e22fd4028165b9d5d05c',after:'9d80c822737534c7606981a0d63f8676a2cc853810c8cfb1699b6519af141cc0'},
 'godot/source_operators/locomotion.gd':{before:'584a0c23611962fff1b1c1a511a640ec26227a17bcd2639c305637fb007545dd',after:'d6d756911e9a273c7dbb3e88b88e79d67234fa0a6166c59dc2dfa6ca9e9ae0e3'},
 'godot/source_operators/operator_visual.gd':{before:'a5d6bc153cd99e3928b43dfe6d98023445ad3d23d6e4a3cf238c64f19f3e93ee',after:'8af316a41810cd86a70cb8a00741c8ae4ceaae73eb579fc157d3a09b76ecd92a'},
 'godot/world/presentation.gd':{before:'b7dbd839627526bff16d55b31c92face8fcf3d248302210b0cfc805693ea4892',after:'c464a7f383322f17b201e6922571173188480548f60d7505aa958ad1f455d21b'},
 'godot/world/session.gd':{before:'7c49f5ca4c347617aa9fe8dafd1c45887578fa001cfa8ba9c6398f06d7a96067',after:'32ff87d491dad9f47d555fa3eec701fbfbbfa47608075ebbc2796b5c291b549c'},
};
export const MELEE_ADDED={
 'godot/source_operators/melee_events.gd':'427cbf26efb0b289afc4b595e1be1904f470db869d632bca02ec25887dfe2e4f',
 'godot/source_operators/melee_pose.gd':'1cfce0989b5cdb64c9df9193050f37ecb7502b59cb7c62113d8089b1cd37e3e9',
};
export function stormglassRuntimePolicy(unit){
 if(unit==='parallax-interiors')return STORMGLASS_SUPPORTING_RUNTIME;
 if(unit==='vehicles')return {'godot/vehicle_assets/attachment.gd':RACE_RUNTIME_ADVANCES['godot/vehicle_assets/attachment.gd']};
 if(unit!=='stormglass-causeway')return {};
 const result=structuredClone(J_RUNTIME_ADVANCES);
 for(const p of ['godot/multiplayer_worlds/sports_demo.gd','godot/sports/hud.gd','godot/vehicle_assets/attachment.gd']){
  const step=RACE_RUNTIME_ADVANCES[p];
  if(result[p]){assert.equal(result[p].after,step.before,'J to feature to race source chain');result[p].after=step.after;}
  else result[p]=step;
 }
 return result;
}
const hash=b=>createHash('sha256').update(b).digest('hex');
const names=['MothLocal_asphalt','MothLocal_brick','MothLocal_concrete','MothLocal_salt','MothLocal_steel','MothLocal_teal',...['asphalt','brick','concrete','salt','steel'].map(n=>'MothLocalNormal_'+n)];
export function stormglassImportPaths(){return [STORMGLASS_GLB+'.import',...names.flatMap(n=>{const p=STORMGLASS_GLB.replace(/\.glb$/,'_'+n+'.png');return [p,p+'.import'];})];}
export function verifyStormglassAdvance(receipt){
 const r=receipt.stormglassPackageVerifierAdvance;
 assert.equal(r?.review.foundation,'38dfb3bd');
 assert.equal(r.review.scope,'supporting package dependency reconciliation only; native feature checks pending');
 assert.equal(r.review.nativeFeatureChecks,'pending');
 assert.deepEqual(r.raceSourceAdvance,{from:'9746a9e2',to:'4cc0292d',changed:RACE_RUNTIME_ADVANCES},'Exact reviewed race source history');
 assert.deepEqual(r.meleeSourceAdvance,{from:'4cc0292d',to:'38dfb3bd',changed:MELEE_RUNTIME_ADVANCES,added:MELEE_ADDED},'Exact reviewed melee source history');
 for(const [p,c]of Object.entries({...RACE_RUNTIME_ADVANCES,...MELEE_RUNTIME_ADVANCES}))assert.equal(receipt.packageInputs[p],c.after,'Current supporting feature identity: '+p);
 for(const [p,sha]of Object.entries(MELEE_ADDED))assert.equal(receipt.packageInputs[p],sha,'New melee preload identity: '+p);
 assert.deepEqual(r.nativeToFeatureAdvance,receipt.unit==='stormglass-causeway'?{to:'a5c26f25',changed:J_RUNTIME_ADVANCES}:null,'J native-to-feature history');
 const policy=stormglassRuntimePolicy(receipt.unit);
 assert.deepEqual(r.runtimeChanged,policy,'Unreviewed Stormglass runtime advance');
 for(const [p,c]of Object.entries(policy))assert.equal(receipt.runtimeHooks[p],c.after,'Stormglass current hook identity');
}
export function verifyStormglassImports(read,receipt){
 assert.equal(hash(read(STORMGLASS_INVENTORY)),'edb811fd503d343314f6fad4bb469a0e73195f643d7d3af34684598712190fb4','Exact received J inventory identity');
 const inventory=JSON.parse(read(STORMGLASS_INVENTORY));
 assert.equal(inventory.foundation,'9746a9e2');
 assert.deepEqual(inventory.files.map(r=>r.path).sort(),[STORMGLASS_GLB,...stormglassImportPaths(),...STORMGLASS_EVIDENCE.filter(p=>p!==STORMGLASS_INVENTORY),'tools/godot-multiplayer/new-maps/stormglass-causeway/architecture.py'].sort(),'Exact J inventory');
 for(const row of inventory.files){const bytes=read(row.path);assert.equal(bytes.length,row.bytes,'J byte size: '+row.path);assert.equal(hash(bytes),row.sha256,'J content hash: '+row.path);}
 assert.equal(hash(read(J_PRODUCER)),J_PRODUCER_SHA,'Original J producer identity');
 const original=JSON.parse(read(J_PRODUCER));
 for(const [key,value]of Object.entries(original))assert.deepEqual(receipt[key],value,'Original J field changed: '+key);
 const bytes=read(STORMGLASS_GLB),size=bytes.readUInt32LE(12),doc=JSON.parse(bytes.subarray(20,20+size)),bin=bytes.subarray(size+28);
 assert.deepEqual(doc.images.map(i=>i.name).sort(),[...names].sort());
 for(const image of doc.images){
  assert.equal(image.mimeType,'image/png');assert.equal(image.uri,undefined);
  const view=doc.bufferViews[image.bufferView];assert.equal(view.buffer,0);
  const data=read(STORMGLASS_GLB.replace(/\.glb$/,'_'+image.name+'.png'));
  assert.deepEqual(data,bin.subarray(view.byteOffset??0,(view.byteOffset??0)+view.byteLength),'J embedded/extracted image identity');
  assert.equal(data.subarray(0,8).toString('hex'),'89504e470d0a1a0a');assert.equal(data.toString('ascii',12,16),'IHDR');
 }
 for(const source of [STORMGLASS_GLB,...stormglassImportPaths()].filter(p=>!p.endsWith('.import'))){
  const text=read(source+'.import').toString(),scene=source===STORMGLASS_GLB;
  const line=s=>assert.ok(text.split('\n').includes(s),'J import policy: '+source+' '+s);
  line(`source_file="res://${source.slice(6)}"`);line(`importer="${scene?'scene':'texture'}"`);
  for(const p of scene?['meshes/ensure_tangents=true','meshes/generate_lods=true','meshes/force_disable_compression=false','gltf/embedded_image_handling=1']:['compress/mode=0','compress/normal_map=0','process/normal_map_invert_y=false','process/size_limit=0'])line(p);
 }
 const summary=JSON.parse(read(J_BASE+'summary.json'));
 assert.deepEqual(receipt.nativeRuntimeHooks,Object.fromEntries(Object.entries(summary.runtimeAndFixtureHashes).filter(([p])=>p.startsWith('godot/')&&!p.startsWith('godot/tests/')&&p.endsWith('.gd'))),'Original J native runtime hooks');
 assert.deepEqual(Object.keys(receipt.runtimeHooks).sort(),Object.keys(receipt.nativeRuntimeHooks).sort(),'Exact J activation hooks');
 for(const [p,sha]of Object.entries(receipt.nativeRuntimeHooks))assert.equal(receipt.runtimeHooks[p],stormglassRuntimePolicy(receipt.unit)[p]?.after??sha,'J runtime chain');
 for(const [p,c]of Object.entries(J_RUNTIME_ADVANCES))assert.equal(c.before,summary.runtimeAndFixtureHashes[p],'J original runtime identity');
 assert.equal(hash(read('tools/godot-multiplayer/new-maps/stormglass-causeway/architecture.py')),summary.runtimeAndFixtureHashes['tools/godot-multiplayer/new-maps/stormglass-causeway/architecture.py']);
 for(const [dir,name]of J_STAGES)assert.equal(JSON.parse(read(J_BASE+'stages/'+dir+'/'+name+'-process.json')).exitCode,0);
 const release=JSON.parse(read(J_BASE+'release-j.json'));assert.equal(release.released,true);assert.equal(release.ownedGroups.length,19);assert.equal(release.audits.length,3);for(const a of release.audits)assert.deepEqual(a.ownedProcesses,[]);
 for(const id of J_RUNS){const run=summary.runs.find(r=>r.id===id);assert.equal(run.success,true);assert.equal(run.processFailed,false);assert.equal(run.respawn.restartObserved,true);}
 assert.deepEqual(receipt.integrationReview.publicModes,['puma-race']);
 assert.equal(receipt.integrationReview.drivableReliefMetres,0);
 assert.equal(receipt.integrationReview.sharedProductionFeatureAcceptance,false);
}
