import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {validate} from './validate.mjs';
const evidence=new URL('./evidence/',import.meta.url);
const accepted={'tidal-citadel':'c45137f0-884e-433e-9d22-01f6be647ce6','sunscar-convoy':'38216605-573c-47cf-a23a-18499282579c'};
function fixture(map){
 const dir=new URL(accepted[map]+'/',evidence);
 assert.equal(JSON.parse(readFileSync(new URL('summary.json',dir))).exit,0,'Successful archived fixture required for '+map);
 const read=name=>gunzipSync(readFileSync(new URL(name+'.gz',dir))).toString();
 return{wire:read('wire.jsonl').trim().split('\n').map(JSON.parse),stdout:read('native.stdout.log'),map,seconds:JSON.parse(readFileSync(new URL('summary.json',dir))).seconds};
}
const run=f=>validate(f.wire,f.stdout,f.map,f.seconds);
for(const map of ['tidal-citadel','sunscar-convoy'])test('replay genuine '+map,()=>assert.equal(run(fixture(map)).status,'PASS'));
function reject(name,mutate,map='tidal-citadel'){
 test('tampered fixture rejected: '+name,()=>{const f=fixture(map);mutate(f);assert.throws(()=>run(f));});
}
reject('missing source return',f=>{for(const row of f.wire)if(row.type==='events')row.items=row.items.filter(e=>e.type!=='flag-return');});
reject('forced early result',f=>{f.wire.find(r=>r.connection===0&&r.type==='results').state.time=1;});
reject('accelerated wall time',f=>{const start=f.wire.find(r=>r.connection===0&&r.type==='start');f.wire.find(r=>r.connection===0&&r.type==='results').wall=start.wall+1000;});
reject('stale dynamic marker after restart',f=>{f.stdout=f.stdout.split('\n').map(l=>{if(!l.startsWith('PROGRESSION_BOUNDARY '))return l;const r=JSON.parse(l.slice(21));if(r.event==='start'&&r.round===2)r.dynamic=['flag_1'];return 'PROGRESSION_BOUNDARY '+JSON.stringify(r);}).join('\n');});
reject('duplicate completion marker',f=>{f.stdout+='\n'+f.stdout.split('\n').find(l=>l.startsWith('PROGRESSION_DONE '));});
reject('wrong rendered height',f=>{let changed=false;f.stdout=f.stdout.split('\n').map(l=>{if(changed||!l.startsWith('OBJECTIVE_NATIVE '))return l;const r=JSON.parse(l.slice(17));r.rendered.flag_0.y+=3;changed=true;return 'OBJECTIVE_NATIVE '+JSON.stringify(r);}).join('\n');});
reject('contest without opposing occupant',f=>{for(const r of f.wire)if(r.type==='snapshot'&&r.state.objectives?.payload?.contested)r.state.actors=r.state.actors.filter(a=>a.team===0);},'sunscar-convoy');
reject('old cart progress on new round',f=>{f.wire.find(r=>r.connection===0&&r.type==='snapshot'&&r.round===2).state.objectives.payload.distance=99;},'sunscar-convoy');
