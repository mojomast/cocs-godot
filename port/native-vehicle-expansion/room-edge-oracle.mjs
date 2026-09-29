// CONTROLLED SOURCE-ONLY ROOM FIXTURE, not native/websocket evidence. Actor 0
// is positioned beside Hornet so this checks Room's ordinary input-edge
// translation without claiming a naturally navigated aircraft approach.
import assert from 'node:assert/strict';
import {Room} from '../../server/room.mjs';
import {RULES} from '../../game/data.mjs';

const room=new Room('arranged-hornet',()=>0.5,{warmupSeconds:0});
room.join(1,'Hornet fixture');
room.host(1,{mode:'combined-arms',botCount:0},'sunscar-convoy');
room.start(1);
assert.equal(room.match.config.mode,'combined-arms');
const vehicle=room.match.vehicles.find(v=>v.kind==='hornet');
assert(vehicle);
// Source-authored spawn collides in this map; arrange an open test position.
Object.assign(vehicle.position,{x:-60,y:2,z:30});
const actor=room.match.actors[0];
Object.assign(actor,{x:vehicle.position.x,y:vehicle.position.y,z:vehicle.position.z});
assert(room.match.enterVehicle(actor));
assert.equal(actor.vehicleSeat,'driver');
const altitudeBefore=vehicle.position.y;
const accepted=[];
const sourceStep=room.match.step;
room.match.step=function(dt,values){accepted.push(values.inputs?.[0]?.jump===true);return sourceStep.call(this,dt,values);};
for(let seq=1;seq<=28;seq++) {
  room.input(1,{seq,input:{x:0,z:0,yaw:actor.yaw,jump:true}});
  room.tick(RULES.dt);
}
assert.equal(accepted.filter(Boolean).length,1,'one held press must make one accepted climb edge');
const altitudeAfter=vehicle.position.y;
assert(Number.isFinite(altitudeAfter) && altitudeAfter>altitudeBefore,'Hornet source ascent did not occur');
room.input(1,{seq:29,input:{jump:false,yaw:actor.yaw}});room.tick(RULES.dt);
room.input(1,{seq:30,input:{jump:true,yaw:actor.yaw}});room.tick(RULES.dt);
assert.equal(accepted.filter(Boolean).length,2,'fresh release and press must make second accepted edge');
console.log('VEHICLE_ROOM_EDGE_ORACLE '+JSON.stringify({classification:'arranged direct Room fixture, no socket/native client',
  vehicle:vehicle.id,actor:actor.id,controlledVehiclePosition:[-60,2,30],altitudeBefore,altitudeAfter,acceptedClimbEdges:2}));
