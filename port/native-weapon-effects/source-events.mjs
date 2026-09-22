// Read-only source simulation probe. Writes only this lane's supplied output.
import { Match } from '../../game/core.mjs';
import { WEAPONS } from '../../game/data.mjs';
import { writeFileSync } from 'node:fs';
const records = [];
for (const weapon of [0,9]) {
  const match = new Match('chatgpt','openclaw',()=>0.5,'exchange',{mode:'deathmatch',botCount:0,humanCount:1});
  match.arena = {blocks:[],bounds:{minX:-100,maxX:100,minZ:-100,maxZ:100}};
  match.pickups=[]; match.vehicles=[];
  const actor=match.actors[0];
  Object.assign(actor,{x:0,y:0,z:4,yaw:0,pitch:0,eyeHeight:1.6,weapon,health:100,armor:0,protection:0,shotWait:0,reloading:false,weaponSwitch:0});
  actor.ammo[weapon]=100;
  match.events=[];
  for(let frame=0;frame<120;frame++) {
    match.fire(actor);
    match.step(1/60);
  }
  const events=match.events.filter(e=>e.type==='shot'&&e.weapon===weapon);
  records.push({weapon,interval:WEAPONS[weapon].interval,events,actor:{id:actor.id,health:actor.health,weapon},label:'Real Match.fire + Match.step at 60 Hz for two seconds; no fabricated wire events'});
}
writeFileSync(process.argv[2] ?? new URL('./source-events.json',import.meta.url),JSON.stringify(records,null,2)+'\n');
console.log(records.map(r=>({weapon:r.weapon,shots:r.events.length,interval:r.interval,first:r.events[0]?.time,last:r.events.at(-1)?.time})));
