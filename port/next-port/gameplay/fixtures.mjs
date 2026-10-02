// Controlled source fixtures, deliberately separate from live wire journeys.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {Match} from '../../../game/core.mjs';
import {CHARACTERS} from '../../../game/data.mjs';
import {createMovementState,stepMovement,movementSnapshot} from '../../../game/movement.mjs';
const states=[];
for(const {id} of CHARACTERS){
 const m=new Match(id,id==='claude'?'claudecode':'codex',()=>.5,'exchange',{botCount:0,skipNav:true});
 const a=m.actors[0];a.health=40;a.protection=0;
 m.step(1/60,{power:true});
 assert.equal(m.events.filter(e=>e.type==='power').length,1,id);
 assert.equal(a.cooldown,id==='claude'?10:16,id+' exact accepted cooldown');
 if(id!=='claude')assert.equal(a.health,85,id+' source Recompile heal');
 const previous=m.stats.powers;m.step(1/60,{power:true});assert.equal(m.stats.powers,previous,id+' cooldown refusal');
 states.push({operator:id,state:m.snapshot()});
}
const movement=createMovementState({character:'qwen',harness:'codex'});
const frame=stepMovement(movement,{mobility:true},{dt:1/60,x:0,y:0,z:0,eyeHeight:1.45,grounded:true,yaw:0,pitch:0,floorAt:()=>0,obstructed:()=>false,bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100},castRay:()=>({x:0,y:3,z:-8,distance:8})});
assert.ok(frame.events.some(e=>e.type==='rope-place'));
assert.equal(movement.charges,0);assert.equal(movement.cooldown,10);
const rope={actors:[{id:0,character:'qwen',harness:'codex',health:100,x:0,y:0,z:0,eyeHeight:1.45,vehicleId:null,movement:movementSnapshot(movement)}]};
const path=new URL('../../../godot/tests/player_gameplay/fixtures.json',import.meta.url);
const bytes=JSON.stringify({label:'CONTROLLED SOURCE FIXTURES, NOT LIVE INPUT PROOF',states,rope},null,2)+'\n';
if(process.argv.includes('--check'))assert.equal(readFileSync(path,'utf8'),bytes,'Player gameplay fixtures differ from source');
else writeFileSync(path,bytes);
console.log('SOURCE_FIXTURES_OK nine powers, exact heal, cooldown refusals, rope placement charge/cooldown');
