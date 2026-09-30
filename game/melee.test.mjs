import test from 'node:test';
import assert from 'node:assert/strict';
import {Match,MELEE,meleeKnockback,obstructed} from './core.mjs';

const open=()=>{
 const m=new Match('chatgpt','openclaw',()=>.5,'exchange',{mode:'deathmatch',botCount:0,humanCount:2});
 m.arena={blocks:[],bounds:{minX:-1000,maxX:1000,minZ:-1000,maxZ:1000}};m.pickups=[];m.vehicles=[];
 const [a,b]=m.actors;
 Object.assign(a,{x:0,y:0,z:0,health:100,armor:0,protection:0,shotWait:0,weaponSwitch:0,melee:0,yaw:0,pitch:0,punchYaw:0,punchPitch:0});
 Object.assign(b,{x:0,y:0,z:-2,health:100,armor:0,protection:0});
 a.ammo[0]=Infinity;
 return {m,a,b};
};

test('melee damages a close target in front and reports the hit',()=>{
 const {m,a,b}=open();
 assert.equal(m.melee(a),true);
 assert.equal(b.health,100-MELEE.damage);
 const event=m.events.find(e=>e.type==='melee');
 assert.ok(event&&event.hit===b.id);
 assert.equal(event.outcome,'hit');
 assert.equal(event.damage,MELEE.damage);
 assert.equal(event.pos.z,0,'legacy pos remains kick origin');
 assert.ok(event.impact.z< -1 && event.impact.z> -2,'contact on target before shove, not attack origin');
 assert.equal(event.normal.z,1);
 assert.ok(b.z< -2 && b.z>= -2-MELEE.knockback-1e-6);
});

test('miss and invulnerable contact never knock back or claim damage',()=>{
 const {m,a,b}=open();
 b.protection=1;
 const before={x:b.x,y:b.y,z:b.z};
 m.melee(a);
 const event=m.events.find(e=>e.type==='melee');
 assert.equal(event.outcome,'blocked');assert.equal(event.target,b.id);
 assert.equal(event.hit,null);assert.equal(event.damage,0);assert.equal(b.health,100);
 assert.deepEqual({x:b.x,y:b.y,z:b.z},before);
 a.melee=0;b.protection=0;b.z=-20;
 m.melee(a);
 assert.equal(m.events.filter(e=>e.type==='melee').at(-1).outcome,'miss');
 assert.equal(b.z,-20);
});

test('shove preserves locomotion and stops before thin walls and arena bounds',()=>{
 const {m,a,b}=open();
 Object.assign(b,{vx:3,vy:0,vz:1,grounded:true});
 m.arena.blocks=[{x:0,z:-2.65,w:4,d:.05,h:3}];
 m.melee(a);
 assert.ok(b.z< -2 && b.z> -2.65);
 assert.equal(obstructed(b.x,b.y,b.z,undefined,m.arena),false);
 assert.deepEqual([b.vx,b.vy,b.vz],[3,0,1]);
 assert.equal(b.y,0);assert.equal(b.grounded,true);
 const arena={blocks:[],bounds:{minX:-2,maxX:2,minZ:-2.7,maxZ:2}};
 b.z=-2;meleeKnockback(b,{x:0,z:-1},arena,100);
 assert.ok(b.z> -2.7 && b.z>= -2-MELEE.knockback);
});

test('shove refuses void and steep ledges, and follows a shallow grounded step',()=>{
 const {b}=open();b.grounded=true;
 const arena={blocks:[],bounds:{minX:-10,maxX:10,minZ:-10,maxZ:10},surfaces:[{x:0,z:0,w:10,d:5,y:0}]};
 meleeKnockback(b,{x:0,z:-1},arena);
 assert.ok(b.z> -2.5,'grounded shove stops before unsupported edge');
 assert.equal(b.y,0);
 const steep={...arena,surfaces:[...arena.surfaces,{x:0,z:-5,w:10,d:5,y:-2}]};
 b.z=-2;meleeKnockback(b,{x:0,z:-1},steep);
 assert.ok(b.z> -2.5);assert.equal(b.y,0);
 const shallow={...arena,surfaces:[...arena.surfaces,{x:0,z:-5,w:10,d:5,y:.1}]};
 b.z=-2;meleeKnockback(b,{x:0,z:-1},shallow);
 assert.ok(b.z< -2.5);assert.equal(b.y,.1);
});

test('wall occlusion, dead actors, mounted actors and match end reject kick effects',()=>{
 const {m,a,b}=open();
 m.arena.blocks=[{x:0,z:-1,w:4,d:.1,h:3}];
 m.melee(a);assert.equal(b.health,100);assert.equal(b.z,-2);
 assert.equal(m.events.filter(e=>e.type==='melee').at(-1).outcome,'miss');
 a.melee=0;a.health=0;assert.equal(m.melee(a),false);
 a.health=100;a.vehicleId='mounted';assert.equal(m.melee(a),false);
 a.vehicleId=null;m.over=true;assert.equal(m.melee(a),false);
});

test('fresh presses at 0.3 seconds work; cooldown presses are discarded, not delayed',()=>{
 const {m,a,b}=open();b.z=-20;
 const step=melee=>m.step(.01,{inputs:{[a.id]:{melee}}});
 const count=()=>m.events.filter(e=>e.type==='melee'&&e.actor===a.id).length;
 step(true);assert.equal(count(),1);
 step(false);step(true); // refused early press
 for(let i=0;i<40;i++)step(true);
 assert.equal(count(),1,'a refused press is consumed even if held beyond cooldown');
 step(false);step(true);assert.equal(count(),2);
 for(let i=0;i<30;i++)step(false);
 step(true);assert.equal(count(),3,'rapid fresh press after short cooldown');
});

test('melee respects its cooldown',()=>{
 const {m,a,b}=open();
 assert.equal(m.melee(a),true);
 assert.equal(m.melee(a),false,'a second swing inside the cooldown is refused');
 assert.equal(b.health,100-MELEE.damage);
});

test('melee misses targets out of range or behind the attacker',()=>{
 const {m,a,b}=open();
 Object.assign(b,{z:-10,health:100});
 a.melee=0;
 assert.equal(m.melee(a),true);
 assert.equal(b.health,100,'out of range is a miss');
 Object.assign(b,{z:2,health:100});
 a.melee=0;
 assert.equal(m.melee(a),true);
 assert.equal(b.health,100,'behind the attacker is a miss');
 assert.ok(m.events.some(e=>e.type==='melee'&&e.hit===null));
});

test('melee never hits a teammate',()=>{
 const m=new Match('chatgpt','openclaw',()=>.5,'launchpad',{mode:'ctf',botCount:0,humanCount:2});
 m.arena={blocks:[],bounds:{minX:-1000,maxX:1000,minZ:-1000,maxZ:1000}};m.pickups=[];m.vehicles=[];
 const [a,b]=m.actors;
 a.team=0;b.team=0;
 Object.assign(a,{x:0,y:0,z:0,health:100,protection:0,melee:0,yaw:0,pitch:0});
 Object.assign(b,{x:0,y:0,z:-1.5,health:100,armor:0,protection:0});
 assert.equal(m.melee(a),true);
 assert.equal(b.health,100);
 assert.equal(b.z,-1.5,'teammates cannot be shoved');
});
