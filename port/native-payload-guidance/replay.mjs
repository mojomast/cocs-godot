// Actual historical states through the CURRENT renderer. Not fresh gameplay.
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {execFileSync} from 'node:child_process';
import {validate} from '../native-objective-completion/validate.mjs';
const archive='port/native-objective-completion/evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387/';
const wire=gunzipSync(readFileSync(archive+'wire.jsonl.gz')).toString().trim().split('\n').map(JSON.parse);
const stdout=gunzipSync(readFileSync(archive+'native.stdout.log.gz')).toString();
const samples=wire.filter(r=>r.connection===0&&r.type==='snapshot').map(r=>({key:`${r.round}:${r.seq}`,state:r.state}));
const tmp=mkdtempSync('/tmp/opencode/payload-guidance-replay-');
try{
 writeFileSync(tmp+'/states.json',JSON.stringify(samples));
 const text=execFileSync(process.env.GODOT_BIN,['--headless','--path','godot','--script','res://tests/objectives/guidance_replay.gd','--',tmp+'/states.json'],{encoding:'utf8',maxBuffer:32*1024*1024,timeout:60000});
 const models=new Map(text.split('\n').filter(x=>x.startsWith('GUIDANCE_REPLAY ')).map(x=>{const r=JSON.parse(x.slice(16));return [r.key,r];}));
 const changed=stdout.split('\n').map(line=>{
  for(const prefix of ['COMPLETION_HUD ','OBJECTIVE_NATIVE '])if(line.startsWith(prefix)){
   const r=JSON.parse(line.slice(prefix.length));const current=models.get(`${r.round}:${r.seq??r.snapshot_seq}`);
   if(!current)throw Error('Missing current-renderer sample');
   if(prefix==='COMPLETION_HUD ')r.model=current.model;
   else {r.rendered=current.rendered;r.hud=current.hud;}
   return prefix+JSON.stringify(r);
  }
  return line;
 }).join('\n');
 const result=validate(wire,changed,'sunscar-convoy',180);
 console.log(JSON.stringify({scope:'archived source sequence through current renderer; input/result witnesses historical',models:models.size,result},null,2));
}finally{rmSync(tmp,{recursive:true,force:true});}
