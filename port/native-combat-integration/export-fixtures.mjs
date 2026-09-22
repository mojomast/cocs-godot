// Actual source fire/snapshot and rayWorld oracle, with explicit test actor poses.
// This is deterministic contract evidence, separate from the live OS-input review.
import {readFileSync, writeFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {Match, rayWorld, eye} from '../../game/core.mjs';
import {getMap} from '../../game/maps.mjs';
import {EventCursor} from '../native-arenas/event-cursor.mjs';
const root = new URL('../../godot/tests/combat_integration/', import.meta.url);
let seed = 18317;
const random = () => ((seed = (Math.imul(seed, 1664525)+1013904223) >>> 0)/4294967296);
const manifest = JSON.parse(readFileSync(new URL('../../godot/content/generated/manifest.json', import.meta.url)));
const rays = [];
for (const {id} of manifest.maps) {
  const map = getMap(id), b = map.bounds;
  const cases = [];
  for (let i=0;i<80;i++) {
    const from = {x:b.minX+random()*(b.maxX-b.minX), y:random()*20+.05, z:b.minZ+random()*(b.maxZ-b.minZ)};
    const to = {x:from.x+(random()-.5)*70, y:from.y+(random()-.6)*25, z:from.z+(random()-.5)*70};
    const length = Math.hypot(to.x-from.x,to.y-from.y,to.z-from.z);
    const direction = Object.fromEntries(['x','y','z'].map(k=>[k,(to[k]-from[k])/length]));
    const distance = rayWorld(from,direction,length,map);
    // Analytic floor uses a .00125m refinement; allow only its documented tolerance.
    cases.push({from,to,blocked:distance<length-.01,distance,length});
  }
  rays.push({id,cases});
}
const m = new Match('chatgpt','openclaw',random,'meridian-exchange',{botCount:1,skipNav:true});
const [a,b] = m.actors;
const cursor = new EventCursor();
cursor.take(m);
const frames=[];
for(let weapon=0;weapon<10;weapon++) {
  Object.assign(a,{x:0,y:25,z:10,yaw:0,pitch:0,weapon,health:100,dead:0,armor:0,protection:0,shotWait:0,weaponSwitch:0,reloading:false,charge:1,chargeAt:m.time});
  a.ammo.fill(100);
  Object.assign(b,{x:0,y:25,z:-2,health:100,dead:0,armor:50,protection:0});
  m.time+=1;
  a.chargeAt=m.time;
  m.rockets=[];
  m.fire(a);
  const events=cursor.take(m);
  assert(events.some(e=>['shot','launch'].includes(e.type)),`source weapon ${weapon} fired`);
  for(const event of events.filter(e=>e.type==='launch')) {
    const id=event.projectile??event.sourceId-1;
    assert(m.rockets.some(r=>r.id===id&&r.owner===event.actor&&r.weapon===event.weapon));
  }
  frames.push({camera:eye(a),state:m.snapshot(),events});
}
// Near-wall authority evidence: no damage when eye->muzzle crosses a block.
const wall=m.arena.blocks.find(b=>b.h>3&&b.w>2&&b.d>2);
Object.assign(a,{x:wall.x,y:0,z:wall.z+wall.d/2+.05,weapon:0,shotWait:0,chargeAt:-1,charge:0});
Object.assign(b,{x:wall.x,y:0,z:wall.z-wall.d/2-2,health:100,armor:0,protection:0});
m.time+=1;
const before=b.health;
m.fire(a);
const nearWall={camera:eye(a),state:m.snapshot(),events:cursor.take(m),healthBefore:before,healthAfter:b.health};
assert.equal(before,b.health);
assert(!nearWall.events.some(e=>e.type==='damage'));
writeFileSync(new URL('source.json',root),JSON.stringify({provenance:'Actual Match.fire/Match.snapshot and rayWorld; explicit deterministic test poses, not a live recording',rays,frames,nearWall})+'\n');
console.log(`SOURCE_INTEGRATION_FIXTURES maps=${rays.length} rays=${rays.length*80} weapons=${frames.length} wallDamage=0`);
