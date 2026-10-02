import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {EventEmitter} from 'node:events';
import {KINDS,MAP,MODE,ROUND_SECONDS,validateCommand,walk,drive,look,signedSpeed,assertRole,assertObservation,assertCase,assertEventPosition} from '../../../tools/godot-vehicle-assets/journey-contract.mjs';
import {options,assetInputs} from '../../../tools/godot-vehicle-assets/journey.mjs';
import {controller} from '../../../tools/asset-production/candidate-guidance.mjs';
import {observeChild,shutdownPeers} from '../../../tools/asset-production/process-evidence.mjs';
const root=new URL('../../../',import.meta.url),text=p=>readFileSync(new URL(p,root),'utf8');
const close=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} ~= ${b}`);

test('plan/import are inert; production route is accepted Sunscar and assets mandatory',()=>{
  const p=options(['--plan']);assert.equal(p.plan,true);assert.equal(p.granted,false);
  assert.deepEqual(p.kinds,['puma','titan','scout']);assert.equal(p.map,MAP);assert.equal(p.mode,MODE);assert.equal(p.roundSeconds,ROUND_SECONDS);assert.equal(p.requireAssets,true);
  assert.throws(()=>options(['--kind=hornet']));assert.throws(()=>options(['--allow-fallback']));
  assert.throws(()=>assetInputs('/path-that-cannot-contain-vehicle-assets'),'missing generated GLBs fail closed');
  const map=text('game/destination-objective-maps.mjs');assert.match(map,/sunscar-convoy/);
  for(const kind of KINDS)assert.ok(map.includes(`['${kind}',`),'real source fleet slot '+kind);
  assert.match(text('godot/combined_arms/demo.gd'),/map_id != "sunscar-convoy"/);
});
test('only finite physical native stimuli enter the fixture command channel',()=>{
  validateCommand({id:1,stage:'drive',keys:['W','SHIFT'],yaw:-Math.PI/2,pitch:0,fire:false});
  for(const change of [{keys:['steer']},{keys:['W','W']},{yaw:NaN},{pitch:2},{health:10},{x:3},{score:2},{position:{x:0}},{packet:{fire:true}},{id:0},{quit:1}])assert.throws(()=>validateCommand({id:1,stage:'negative',keys:[],...change}));
});
test('navigation guidance uses ordinary facing/movement with no input teleport',()=>{
  const a={id:0,x:0,y:0,z:0,health:100,deaths:0,eyeHeight:1.45};
  const before=JSON.stringify(a),cmd=walk(a,{x:8,y:0,z:0});assert.deepEqual(cmd.keys,['W']);close(cmd.yaw,-Math.PI/2);
  assert.deepEqual(walk(a,{x:.1,z:0}).keys,[]);close(look(a,{x:0,y:0,z:10},1.45).pitch,0);
  const graph={nav:[{x:0,z:0},{x:3,z:0},{x:6,z:0}],edges:[[1],[0,2],[1]]};
  const input=controller()(graph,a,{x:7,z:0},'route');assert.equal(input.x,1);assert.equal(input.z,0);
  assert.equal(JSON.stringify(a),before);assert.ok(!('position' in input));
});
test('native W/S drive orientation and signed roll speed retain source axes',()=>{
  for(const heading of [0,Math.PI/2,-.8]){
    const v={heading,velocity:{x:Math.sin(heading)*4,z:Math.cos(heading)*4}};
    const input=drive(v,['W']);close(-Math.sin(input.yaw),Math.sin(heading));close(-Math.cos(input.yaw),Math.cos(heading));close(signedSpeed(v),4);
    v.velocity.x*=-1;v.velocity.z*=-1;close(signedSpeed(v),-4);
  }
  assert.match(text('godot/sports/controls.gd'),/-sin\(yaw\)\*throttle-cos\(yaw\)\*steer/);
  assert.match(text('godot/combined_arms/controls.gd'),/if driving: cancel_aim/);
});
function sample(kind='puma'){
  const v={id:'source-car',kind,x:3,y:0,z:6,health:100,respawnTimer:0,driver:0,gunner:1,passengers:[2]};
  const actors=[{id:0,team:0,vehicleId:v.id,vehicleSeat:'driver'},{id:1,team:1,vehicleId:v.id,vehicleSeat:'gunner'},{id:2,team:0,vehicleId:v.id,vehicleSeat:'passenger'}];
  const state={time:9,actors,vehicles:[v]},attachments=kind==='titan'?18:6;
  const report={requireAssets:true,sourceTime:9,phase:'active',seq:4,ack:2,failures:[],actor:actors[0],fleet:[{id:v.id,kind,authored:kind,attachments,lods:attachments*3,assetIdentity:true,muzzleMatch:true,visible:true,position:[3,0,6],team:0,channelsOwned:true,materialsIsolated:true}]};
  return {state,report};
}
for(const kind of KINDS)test(`${kind}: actual-recipient observation contract rejects wrong assets, ownership, transforms and visibility`,()=>{
  const {state,report}=sample(kind);assertObservation(report,state);
  for(const change of [{authored:''},{kind:'hornet'},{lods:1},{assetIdentity:false},{muzzleMatch:false},{visible:false},{position:[4,0,6]},{team:1},{channelsOwned:false},{materialsIsolated:false}]){
    const bad=structuredClone(report);Object.assign(bad.fleet[0],change);assert.throws(()=>assertObservation(bad,state));
  }
  for(const change of [{requireAssets:false},{sourceTime:8},{failures:['native']},{fleet:[]}])assert.throws(()=>assertObservation({...report,...change},state));
  assert.throws(()=>assertObservation(report,state,{requireAssets:false}));
});
test('seat ownership is reciprocal and does not invent a Scout gunner',()=>{
  const {state}=sample();for(const [id,seat] of [[0,'driver'],[1,'gunner'],[2,'passenger']])assertRole(state,id,'source-car',seat);
  state.vehicles[0].passengers=[];assert.throws(()=>assertRole(state,2,'source-car','passenger'));
  const p={kind:'scout',gunnerFire:false};for(const key of ['driver','drive','bend','reverse','driverFire','teamSwapWet','passengerFire','damage','repair','wreck','respawn','reset','resetCleanup','nativeAssets','wireInputs'])p[key]=true;
  assertCase(p,'scout');assert.throws(()=>assertCase({...p,gunnerFire:true},'scout'));assert.throws(()=>assertCase({...p,resetCleanup:false},'scout'));
});
test('repair/wreck effects require finite source-position events',()=>{
  const vehicle={position:{x:1,y:0,z:2}};
  assertEventPosition({type:'vehicle-repair',x:1,y:0,z:2},vehicle);assertEventPosition({type:'vehicle-destroyed',pos:{x:1,y:0,z:2}},vehicle);
  assert.throws(()=>assertEventPosition({type:'vehicle-repair',x:100,y:0,z:2},vehicle));assert.throws(()=>assertEventPosition({pos:{x:NaN,y:0,z:2}},vehicle));
});
test('fixture drives the production native input path and has no source staging API',()=>{
  const runner=text('tools/godot-vehicle-assets/journey.mjs'),native=text('godot/tests/vehicle_assets/journey.gd');
  assert.match(native,/extends "res:\/\/combined_arms\/demo.gd"/);assert.match(native,/Input.parse_input_event\(event\)/);
  assert.doesNotMatch(native,/net\.send_input\(/,'fixture cannot bypass production controls');
  assert.doesNotMatch(runner,/\bm\.(?:step|spawn|damageVehicle|releaseVehicle|enterVehicle|driveVehicle)\s*\(/);
  assert.doesNotMatch(runner,/(?:actor\([^)]*\)|vehicle\(\))\.(?:health|position|score|x|y|z)\s*=(?!=)/);
  assert.match(runner,/await shutdownPeers/);assert.ok(runner.indexOf('await shutdownPeers')<runner.indexOf("writeFileSync(join(out,p.role+'.log')"));
  assert.match(runner,/if\(!result.success\)break/);assert.match(native,/stage_name == suppressed_stage/,'seat changes cannot reissue held E');
  assert.match(native,/child.mesh == asset_meshes/,'actual imported mesh identities, not names alone');
  assert.match(native,/channels\(binding.prior\) == binding.channels/);
});
test('owned-child final stderr is assessed after close; no subprocess is launched',async()=>{
  const child=new EventEmitter();child.pid=123;child.stdout=new EventEmitter();child.stderr=new EventEmitter();child.kill=()=>assert.fail('clean fake child never force killed');
  const peer=observeChild(child,'fake-source-only');
  const result=await shutdownPeers([peer],()=>{
    queueMicrotask(()=>{child.stdout.emit('data','CANDIDATE_TEARDOWN_READY {}\n');child.stderr.emit('data','ERROR: late teardown resource failure\n');child.emit('close',0,null);});
  });
  assert.equal(result[0].clean,false);assert.ok(result[0].failures.includes('native-log-error-or-leak'));assert.ok(peer.closed);assert.ok(peer.log.includes('late teardown'));
});
