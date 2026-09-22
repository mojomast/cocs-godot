// Private arranged render fixture. Unmodified source methods author every
// collection event, health/ammo award, wait clock and respawn snapshot.
import assert from 'node:assert/strict';
import {mkdirSync, writeFileSync} from 'node:fs';
import {Match} from '../../game/core.mjs';
import {POWERUPS, ECONOMY_PICKUPS} from '../../game/data.mjs';
import {pickupWeapon} from '../../game/maps.mjs';

const weapons=['rocket','rail','scatter','plasma','grenade','shock','flak','marksman','smg'];
assert.deepEqual(weapons.map(pickupWeapon),[1,2,3,4,5,6,7,8,9]);
const kinds=['health','armor','ammo','rocket','megahealth',...weapons.slice(1),...POWERUPS.map(p=>p.id),...ECONOMY_PICKUPS.map(p=>p.id)];
const match=new Match('chatgpt','openclaw',()=>.37,'meridian-exchange',{mode:'deathmatch',botCount:0});
const actor=match.actors[0];
// Test-only placement, not a modified map or a live multiplayer recording.
match.pickups=kinds.map((kind,id)=>({id,kind,x:(id%5-2)*1.3,y:0,z:-Math.floor(id/5)*2,wait:0,...(kind==='ammo'?{weapon:'rail'}:{})}));
Object.assign(actor,{x:100,y:0,z:100,health:20,armor:0,protection:0});
const clone=x=>JSON.parse(JSON.stringify(x));
const frames=[];
const take=label=>frames.push({label,state:clone(match.snapshot()),events:clone(match.events)});
take('available');
assert(match.collect(actor,match.pickups[0]));
assert.equal(actor.health,55);
take('health-collected');
for(const p of match.pickups.slice(1)) {
  actor.health=20; actor.armor=0; actor.ammo.fill(0);
  assert(match.collect(actor,p),`collect ${p.kind}`);
}
take('all-unavailable');
assert(frames.at(-1).state.pickups.every(p=>p.wait>0));
for(let tick=0;tick<901;tick++) match.step(1/60);
take('source-respawn');
assert(frames.at(-1).state.pickups.every(p=>p.wait===0));
assert(frames[1].events.some(e=>e.type==='pickup'&&e.kind==='health'));
const out=new URL('../../godot/tests/combat_pickup_assets/source.json',import.meta.url);
mkdirSync(new URL('.',out),{recursive:true});
writeFileSync(out,JSON.stringify({provenance:'Arranged private Match fixture; actual source collect/step/snapshot/events. Not natural multiplayer play.',kinds,frames},null,2)+'\n');
console.log(`PICKUP_SOURCE_OK kinds=${kinds.length} actual_collect=${match.stats.pickups} health_award=35 respawn_ticks=901`);
