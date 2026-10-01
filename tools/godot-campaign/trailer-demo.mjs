#!/usr/bin/env node
// Export production replay states, not pixels, for the live Godot menu viewport.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createInterface} from 'node:readline';
import {createReadStream} from 'node:fs';
import {resolve,dirname,join} from 'node:path';
import {execFileSync} from 'node:child_process';
const arg=k=>process.argv.find(v=>v.startsWith(`--${k}=`))?.slice(k.length+3);
if(!arg('evidence'))throw Error('--evidence is required');
const base=resolve(arg('evidence')), output=resolve(arg('output')||'godot/ui/attract/demo.json');
const clips=[], audit=[];
for(const id of ['forest','mara','patch','fire']){
 const receipt=JSON.parse(await readFile(join(base,id,'receipt.json'),'utf8'));
 const lines=createInterface({input:createReadStream(join(base,id,'replay.jsonl')),crlfDelay:Infinity});
 let header, group=[], totalEvents=0;const frames=[];
 function retain(){
  const last=group.at(-1),events=group.flatMap(r=>r.events);totalEvents+=events.length;
  frames.push({t:group[0].frame/24,state:{time:last.state.time,actors:last.state.actors,campaign:last.state.campaign},events});group=[];
 }
 for await(const line of lines){
  if(!header){header=JSON.parse(line);continue;}
  group.push(JSON.parse(line));if(group.length===2)retain();
 }
 if(group.length)retain();
 if(frames.length!==header.shot.seconds*12)throw Error(`${id}: incorrect replay length`);
 if(id==='patch'&&!frames.some(f=>f.state.campaign.story.pets>0))throw Error('Accepted pet missing');
 if(id==='fire'&&!frames.some(f=>f.events.some(e=>e.type==='damage'&&e.source===0)))throw Error('Actual player damage missing');
 clips.push({id,map:header.shot.map,kind:header.shot.kind,camera:'orbit',duration:header.shot.seconds,focus:header.focus,frames});
 audit.push({id,sourceSHA256:receipt.sha256,frames:frames.length,events:totalEvents,petReceipts:receipt.interactions});
}
const data={version:1,fps:12,provenance:{scripted:true,authorityRevision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),description:'Production-authority fixed-step replay; camera/placement/AI staged. No live authority or gameplay inputs in menu.'},clips};
const bytes=JSON.stringify(data);
if(Buffer.byteLength(bytes)>4*1024*1024)throw Error('Menu replay exceeds 4 MiB budget');
await mkdir(dirname(output),{recursive:true});await writeFile(output,bytes+'\n');
await writeFile(join(base,'demo-export-audit.json'),JSON.stringify({bytes:Buffer.byteLength(bytes),clips:audit},null,2));
console.log('TRAILER_DEMO_EXPORTED',output,Buffer.byteLength(bytes));
