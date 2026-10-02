// Source-only extraction/check. No engine, renderer or authority mutation.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {spectateActor, nextSpectateTarget, assistCredit} from '../../game/hud.mjs';
import {filterCocsSnapshot, cocsEventVisible, COCS_PUBLIC_EVENTS} from '../../game/cocs-intel.mjs';
import {integrateFreeMove} from '../../game/camera-modes.mjs';
const actors = [{id:0,name:'Alpha',team:0,health:100,x:1,y:2,z:3,req:777,reqBuff:{secret:'PRIVATE'},weapon:4,cooldown:99}, {id:1,name:'Beta',team:1,health:50,x:4,y:5,z:6}, {id:'named',name:'String ID',health:0,x:7,y:8,z:9}];
const selection=[];
for(const roster of [[], actors, [...actors].reverse(), actors.map(a=>({...a,health:0})), actors.filter(a=>a.id!==0), [{id:'one',health:100},{id:'two',health:100}]]) {
  for(const target of [null,0,1,'named','one','two','0',99]) {
    selection.push({actors:roster,target,expected:spectateActor(roster,target)?.id??null,next:nextSpectateTarget(roster,target),previous:nextSpectateTarget(roster,target,-1)});
  }
}
const assist=[];
for(const victim of [0,'0',1,'named',null]) for(const time of [9,10,14.999,15,15.001,20]) {
  const marks={'0':10,named:10};
  assist.push({marks,victim,time,expected:assistCredit(marks,victim,time)});
}
const types=[...COCS_PUBLIC_EVENTS,'cocs-order','cocs-scan','cocs-role','cocs-buy','cocs-unknown','death','damage'];
const visibility=types.flatMap(type=>[0,1,null].map(team=>({event:{type,team:0,actor:0,text:'PRIVATE'},team,expected:cocsEventVisible({type,team:0,actor:0,text:'PRIVATE'},team)})));
const full={time:10,actors,cocs:{intel:{0:{secret:'RED'},1:{secret:'BLUE'}},contacts:{0:[],1:[]},req:[{id:0,amount:777}],cards:[{team:0,text:'PRIVATE'}],scores:{0:2,1:3}}};
const publicSnapshot=filterCocsSnapshot(full,null);
assert(!JSON.stringify(publicSnapshot).includes('PRIVATE'));
assert.deepEqual(publicSnapshot.cocs.intel,{});
const motion=[];
for(const dt of [0,1/144,1/30,.1,.5]) for(const boost of [false,true]) for(const input of [{forward:1,right:0,up:0},{forward:1,right:1,up:1},{forward:0,right:0,up:0},{forward:0,right:0,up:-1}]) {
  const pose={x:1,y:.4,z:3,yaw:.7,pitch:.4},velocity={x:2,y:-1,z:3};
  const initial={pose:{...pose},velocity:{...velocity},input:{...input,boost},dt};
  integrateFreeMove(pose,velocity,initial.input,dt);
  motion.push({...initial,expected:{pose,velocity}});
}
const provenance=Object.fromEntries(['game/hud.mjs','game/cocs-intel.mjs','game/camera-modes.mjs','app/page.tsx','game/view.mjs'].map(path=>[path,crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')]));
const outputs={'godot/experience/public_event_types.json':COCS_PUBLIC_EVENTS,'godot/tests/experience/spectator_fixture.json':{provenance,selection,assist,visibility,publicSnapshot,motion}};
for(const [path,value] of Object.entries(outputs)) {
  const bytes=JSON.stringify(value,null,2)+'\n';
  if(process.argv.includes('--check')) assert.equal(fs.readFileSync(path,'utf8'),bytes,path);
  else fs.writeFileSync(path,bytes);
}
console.log(`SPECTATOR_SOURCE_OK ${selection.length} target vectors, ${assist.length} assist boundaries, ${visibility.length} visibility contexts, ${motion.length} free-motion vectors; public snapshot redaction verified`);
