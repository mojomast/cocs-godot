// Pure input/report contracts. Importing this module never constructs a match.
import assert from 'node:assert/strict';
export const KINDS=Object.freeze(['puma','titan','scout']);
export const MAP='sunscar-convoy', MODE='combined-arms';
export const ROUND_SECONDS=300;
export const KEYS=Object.freeze(['W','A','S','D','SHIFT','SPACE','E','R','ENTER','ESCAPE']);
export const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
export const wrap=a=>Math.atan2(Math.sin(a),Math.cos(a));
export const neutral=()=>({keys:[],fire:false});
export function look(a,b,height=.35){
  return {yaw:Math.atan2(a.x-b.x,a.z-b.z),pitch:Math.atan2((b.y??0)+height-(a.y+(a.eyeHeight??1.45)),distance(a,b))};
}
export function walk(a,b){return distance(a,b)>.45?{keys:['W'],...look(a,b,1.45)}:neutral();}
export function drive(v,keys){return {keys,yaw:v.heading-Math.PI,pitch:0};}
export function signedSpeed(v){return v.velocity.x*Math.sin(v.heading)+v.velocity.z*Math.cos(v.heading);}
export function validateCommand(c){
  assert.ok(c&&typeof c==='object');assert.ok(Number.isSafeInteger(c.id)&&c.id>0);
  assert.ok(typeof c.stage==='string'&&c.stage.length<=96);
  assert.ok(Array.isArray(c.keys)&&c.keys.every(k=>KEYS.includes(k))&&new Set(c.keys).size===c.keys.length);
  for(const k of ['yaw','pitch'])if(k in c)assert.ok(Number.isFinite(c[k]));
  if('pitch' in c)assert.ok(Math.abs(c.pitch)<=1.55);
  for(const k of ['fire','quit','wet'])if(k in c)assert.equal(typeof c[k],'boolean');
  assert.ok(Object.keys(c).every(k=>['id','stage','keys','fire','yaw','pitch','quit','wet'].includes(k)),'no authority/packet mutation command');
  return c;
}
export function assertRole(state,actorId,vehicleId,seat){
  const a=state.actors.find(a=>a.id===actorId),v=state.vehicles.find(v=>v.id===vehicleId);
  assert.ok(a&&v);assert.equal(a.vehicleId,vehicleId);assert.equal(a.vehicleSeat,seat);
  if(seat==='passenger')assert.ok(v.passengers.includes(actorId));else assert.equal(v[seat],actorId);
}
// Read-only native report vs the exact recipient source snapshot (same round).
export function assertObservation(report,state,{requireAssets=true}={}){
  assert.equal(requireAssets,true,'production journey may not admit fallback');
  assert.equal(report.requireAssets,true);assert.equal(report.sourceTime,state.time);
  assert.equal(report.phase,'active');assert.ok(Number.isInteger(report.seq)&&report.seq>=0);
  assert.ok(report.ack>=0);assert.equal(report.failures.length,0);
  const selected=state.vehicles.filter(v=>KINDS.includes(v.kind));
  assert.equal(report.fleet.length,selected.length);
  for(const actual of report.fleet){
    const source=selected.find(v=>v.id===actual.id);assert.ok(source,'exact source fleet identity');
    assert.equal(actual.kind,source.kind);assert.equal(actual.authored,source.kind);
    assert.equal(actual.attachments,source.kind==='titan'?18:6);
    assert.equal(actual.lods,actual.attachments*3);
    assert.equal(actual.assetIdentity,true);assert.equal(actual.muzzleMatch,true);
    assert.equal(actual.visible,source.health>0&&source.respawnTimer<=0);
    for(const [i,key] of ['x','y','z'].entries())assert.ok(Math.abs(actual.position[i]-source[key])<.0001);
    assert.equal(actual.team,state.actors.find(a=>a.id===source.driver)?.team??-1);
    assert.equal(actual.channelsOwned,true);assert.equal(actual.materialsIsolated,true);
  }
  if(report.actor?.vehicleId!=null)assertRole(state,report.actor.id,report.actor.vehicleId,report.actor.vehicleSeat);
  return true;
}
export function assertEventPosition(event,v){
  const p=event.pos??event;
  for(const key of ['x','y','z'])assert.ok(Number.isFinite(p[key])&&Math.abs(p[key]-v.position[key])<.15,`source-position ${event.type}/${key}`);
}
export function assertCase(proof,kind){
  assert.equal(proof.kind,kind);
  for(const key of ['driver','drive','bend','reverse','driverFire','teamSwapWet','passengerFire','damage','repair','wreck','respawn','reset','resetCleanup','nativeAssets','wireInputs'])assert.equal(proof[key],true,`missing ${kind}/${key}`);
  assert.equal(proof.gunnerFire,kind!=='scout','Scout has no gunner seat');
}
