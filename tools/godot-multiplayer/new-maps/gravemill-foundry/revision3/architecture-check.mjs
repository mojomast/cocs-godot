import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {recipe} from './recipe.mjs';
import {canonical} from '../../../../../port/multiplayer-worlds/catalog.mjs';
import {floorAt,moveActor,visible,rayWorld} from '../../../../../game/core.mjs';
const arena=recipe(),p=(x,q,y)=>({x,y,z:q+.14*x}),results=[];
// Exercise NEW solid walls from both sides using continuous source movement.
for(const [label,x,q,axis] of [['crusher-front',-66,-52,'z'],['assay-partition',57,29,'x'],['transfer-south',0,-77.81,'z']])for(const sign of [-1,1]){
 const start=p(x,q,floorAt(x,q+.14*x,arena));start[axis]+=sign*2;
 const actor={...start,vx:0,vy:0,vz:0,grounded:true,health:100,character:'chatgpt',harness:'openclaw',powerups:{}};
 for(let i=0;i<100;i++)moveActor(actor,{[axis]:-sign},.025,arena);
 assert.ok((actor[axis]-p(x,q,0)[axis])*sign>0,label+' wall leaked');
 assert.ok(!visible({...start,y:start.y+1.45},{...p(x,q,start.y+1.45),[axis]:p(x,q,0)[axis]-sign*2},arena),label+' ray leaked');
 results.push({label,side:sign,actorStopped:true,rayBlocked:true});
}
for(const [label,x,q,y,expected] of [['crusher-roof',-90,-38,1.5,30],['transfer-roof',10,-64,1.5,24],['assay-roof',66,36,13.5,20],['cooling-roof',-66,36,13.5,15]]){
 const hit=rayWorld(p(x,q,y),{x:0,y:1,z:0},40,arena);assert.ok(hit<expected,label);results.push({label,hit});
}
assert.ok(visible(p(48,30,14.5),p(48,34,14.5),arena),'inspection aperture blocked');
assert.ok(!visible(p(48,30,17),p(48,34,17),arena),'inspection lintel leaked');
const receipt={status:'source-only-native-pending',geometryHash:createHash('sha256').update(canonical(arena)).digest('hex'),results};
fs.writeFileSync(new URL('architecture-validation.json',import.meta.url),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify(receipt));
