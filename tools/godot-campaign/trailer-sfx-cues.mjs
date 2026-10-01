#!/usr/bin/env node
import {readFile,writeFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const evidence=process.argv.find(a=>a.startsWith('--evidence='))?.slice(11);
if(!evidence)throw Error('--evidence required');
const out=resolve(evidence),m=JSON.parse(await readFile(new URL('./trailer.json',import.meta.url),'utf8'));
let start=0;const cues=[];
for(const shot of m.shots){
 const lines=(await readFile(join(out,shot.id,'replay.jsonl'),'utf8')).trim().split('\n').slice(1);
 let shots=0,hits=0;
 for(const line of lines){const r=JSON.parse(line);for(const event of r.events){
  const at=start+r.frame/24;
  const cue=(name,gainDB,offset=0)=>cues.push({path:join(out,'sfx',name+'.wav'),at:Math.max(0,at+offset),gainDB,shot:shot.id,eventId:event.id,eventType:event.type});
  if(['fire','robots'].includes(shot.id)&&event.type==='shot'&&event.actor===0){
   shots++;if(shots<=6||shots%4===0)cue('pulse-shot',shot.id==='fire'?-13:-19);
  }
  if(shot.id==='fire'&&event.type==='damage'&&event.source===0){hits++;if(hits%3===1)cue('pulse-hit',-19);}
  if(shot.id==='kick'&&event.type==='melee'&&event.actor===0){cue('melee-whoosh',-11,-.04);if(event.outcome==='hit')cue('melee-impact',-8);}
  if(shot.id==='danger'&&event.type==='enemy-artillery')cue('explosion',-12);
 }}
 start+=shot.seconds;
}
await writeFile(join(out,'sfx-cues.json'),JSON.stringify(cues,null,2));
console.log('TRAILER_SFX_CUES',cues.length);
