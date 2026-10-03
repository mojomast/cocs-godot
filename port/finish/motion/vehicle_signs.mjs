import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {controlsFromState} from '../../../game/input.mjs';
import {createVehicle,stepVehicle} from '../../../game/vehicles.mjs';

// Evaluate the checked-in adapter expressions, rather than reproducing their
// signs in this oracle. The expected world axes come from the actual web input.
const sports=readFileSync(new URL('../../../godot/sports/controls.gd',import.meta.url),'utf8');
const session=readFileSync(new URL('../../../godot/world/session.gd',import.meta.url),'utf8');
const expressions=[
  sports.match(/return \{"x":([^,]+),\s*"z":([^,]+),"yaw":yaw/),
  [null,...session.match(/var axes := Vector2\(([^\n]+)\)/)?.[1].split(', ')]
];
for(const result of expressions)assert.ok(result,'native vehicle projection found');
const project=expressions.map(([,x,z])=>{
  const compile=expression=>Function('yaw','throttle','steer','sin','cos',`return ${expression};`);
  const fx=compile(x),fz=compile(z);
  return (yaw,throttle,steer)=>({x:fx(yaw,throttle,steer,Math.sin,Math.cos),z:fz(yaw,throttle,steer,Math.sin,Math.cos)});
});
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-9,`${a} != ${b}`);
for(const heading of [0,Math.PI/2,Math.PI,-Math.PI/2]){
  const yaw=heading-Math.PI;
  for(const [name,keys,throttle,steer] of [
    ['W',['KeyW'],1,0],['S',['KeyS'],-1,0],
    ['A',['KeyA'],0,-1],['D',['KeyD'],0,1],
    ['W+D',['KeyW','KeyD'],1,1],['S+A',['KeyS','KeyA'],-1,-1]
  ]){
    const source=controlsFromState({yaw,keys:new Set(keys)});
    for(const [index,native] of project.entries()){
      const actual=native(yaw,throttle,steer);
      near(actual.x,source.x);near(actual.z,source.z);
      // Source race/soccer: projection onto negative actor forward/right.
      const sourceThrottle=-actual.x*Math.sin(yaw)-actual.z*Math.cos(yaw);
      const sourceSteer=-actual.x*Math.cos(yaw)+actual.z*Math.sin(yaw);
      near(sourceThrottle,throttle);near(sourceSteer,-steer);
      assert.ok(Number.isFinite(actual.x+actual.z),`${name} ${heading} adapter ${index}`);
    }
  }
}
const yaw=-Math.PI;
const d=controlsFromState({yaw,keys:new Set(['KeyD'])});
near(d.x,-1); // Looking +Z, camera right is -X in Godot/Three.
const vehicle=createVehicle();
const steer=-d.x*Math.cos(yaw)+d.z*Math.sin(yaw);
stepVehicle(vehicle,{throttle:0,steer},1/60);
assert.ok(steer<0&&vehicle.heading<0,'D decreases source heading and points the nose screen-right');
console.log('VEHICLE_SIGNS source web input/native sports+session/race+soccer projection/vehicle turn OK');
