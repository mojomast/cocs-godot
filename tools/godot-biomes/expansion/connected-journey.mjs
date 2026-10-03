// Grant-only driver. Authority is unmodified; observe() is a read-only witness.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {planJourney,sha} from './journey-plan.mjs';
import {createAuthority} from '../../../port/native-campaign/authority.mjs';
import {floorAt,obstructed} from '../../../port/native-campaign/core.generated.mjs';
assert.ok(process.argv.includes('--granted'),'Explicit scenery heavy grant required');
const root=fileURLToPath(new URL('../../../',import.meta.url));
const id=process.argv[2],catalog=JSON.parse(readFileSync(resolve(root,'godot/biomes/expansion/catalog.json')));
assert.equal(catalog.recipeSha256,sha(readFileSync(resolve(root,'tools/godot-biomes/expansion/meshes.json'))),'Stale scenery source geometry');
assert.ok(Object.hasOwn(catalog.chapters,id),'Choose one of four campaign chapters');
const raw=readFileSync(resolve(root,`godot/campaign/generated/${id}.json`)),data=JSON.parse(raw),plan=planJourney(data,catalog,raw);
const resources=Object.fromEntries(plan.assets.flatMap(id=>[0,1].map(lod=>{const p=`godot/biomes/expansion/art/${id}-${lod}.glb`;return [p,sha(readFileSync(resolve(root,p)))];})));
const output=resolve(process.env.SCENERY_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/connected',new Date().toISOString().replaceAll(':','-')+'-'+id);
mkdirSync(output,{recursive:true});writeFileSync(resolve(output,'plan.json'),JSON.stringify(plan));
let authority,child,timer,code=null,signal=null,log='',spawnError=null,failure=null,forced=false,closed=false,done;
let home,homeDone,homeTimer,homeClosed=false,homeLog='',homeCode=null,homeSignal=null,homeError=null,homeForced=false;
const witness={steps:0,fire:0,interact:0,ack:0,shots:0,workshops:[],snapshots:0,clearSamples:0,blockedSamples:0,trace:[],forbidden:[]};
const observe=e=>{
 if(e.direction==='in'&&['solo-cheat','campaign-action'].includes(e.frame.type))witness.forbidden.push(e.frame.type);
 if(e.direction==='step'){witness.steps++;if(e.controls.fire)witness.fire++;if(e.controls.interact)witness.interact++;}
 if(e.direction==='out'&&e.frame.type==='events')for(const event of e.frame.items){if(event.type==='shot'&&event.actor===0)witness.shots++;if(event.type==='campaign-interlude'&&event.completed)witness.workshops.push(event.sourceId);}
 if(e.direction==='out'&&e.frame.type==='snapshot'){
  witness.snapshots++;witness.ack=Math.max(witness.ack,e.frame.acks[0]);
  if(witness.snapshots%12===0){const a=e.frame.state.actors.find(a=>a.id===0),y=floorAt(a.x,a.z,data.arena);
   if(Number.isFinite(y)&&Math.abs(a.y-y)<.4&&!obstructed(a.x,a.y,a.z,.45,data.arena))witness.clearSamples++;else witness.blockedSamples++;
   witness.trace.push({time:e.frame.state.time,x:a.x,y:a.y,z:a.z,health:a.health,ack:e.frame.acks[0]});}
 }
};
try{
 authority=createAuthority({mapId:id,difficulty:'easy',random:()=>.5,observe});
 await new Promise((r,j)=>{authority.server.once('error',j);authority.server.listen(0,'127.0.0.1',r);});
 const godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
 const args=['--path',resolve(root,'godot'),'--audio-driver','Dummy','-s','res://tests/biome_assets/connected_journey.gd','--',`--map=${id}`,`--endpoint=ws://127.0.0.1:${authority.server.address().port}/native-campaign`,`--output=${output}`,`--journey-plan=${resolve(output,'plan.json')}`,...(process.argv.includes('--compact')?['--compact']:[])];
 child=spawn(godot,args,{cwd:root,env:{...process.env,LP_NUM_THREADS:'1',COCS_SETTINGS_PATH:resolve(output,'settings.json'),COCS_BINDINGS_PATH:resolve(output,'bindings.json')},stdio:['ignore','pipe','pipe']});
 child.on('error',e=>{spawnError=String(e);});
 for(const stream of [child.stdout,child.stderr])stream.on('data',b=>{log+=b;});
 done=new Promise(r=>child.on('close',(c,s)=>{closed=true;code=c;signal=s;r();}));
 timer=setTimeout(()=>{forced=true;child.kill('SIGKILL');},1100000);
 await done;clearTimeout(timer);
 assert.ok(!spawnError&&!forced&&code===0&&!signal,'Native process failed');
 assert.ok(!/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use|RID[^\n]*leak/i.test(log),'Native errors/leaks');
 const receipt=JSON.parse(readFileSync(resolve(output,'journey.json')));
 assert.equal(receipt.success,true,receipt.failure);
 assert.ok(witness.steps>100&&witness.ack>0&&witness.fire>0&&witness.shots>0&&witness.interact>0);
 assert.deepEqual([...new Set(witness.workshops)].sort(),plan.workshops.slice().sort());
 assert.equal(witness.forbidden.length,0,'No cheats/checkpoint restarts');
 assert.ok(witness.clearSamples>30);assert.equal(witness.blockedSamples,0,'Actual source poses left reviewed supported clearance');
 assert.ok(receipt.observations.some(o=>o.returnedToStart===true));
 for(const marker of ['SCENERY_LEAVE_HOME_REQUESTED','SCENERY_WORLD_TREE_EXITED','SCENERY_PACK_TREE_EXITED'])assert.ok(log.includes(marker),'Missing lifecycle marker '+marker);
 // Same product boundary as the launcher: Leave exits the campaign process,
 // owned authority closes, then Home is rendered by the next native process.
 for(let i=0;i<40&&authority.wss.clients.size;i++)await new Promise(r=>setTimeout(r,25));
 assert.equal(authority.wss.clients.size,0,'Campaign transport still connected after native exit');
 await authority.close();authority=null;
 const homeArgs=['--path',resolve(root,'godot'),'--audio-driver','Dummy','-s','res://tests/biome_assets/home_return.gd','--',`--output=${output}`,...(process.argv.includes('--compact')?['--compact']:[])];
 home=spawn(godot,homeArgs,{cwd:root,env:{...process.env,LP_NUM_THREADS:'1',COCS_SETTINGS_PATH:resolve(output,'settings.json'),COCS_BINDINGS_PATH:resolve(output,'bindings.json')},stdio:['ignore','pipe','pipe']});
 home.on('error',e=>{homeError=String(e);});
 for(const stream of [home.stdout,home.stderr])stream.on('data',b=>{homeLog+=b;});
 homeDone=new Promise(r=>home.on('close',(c,s)=>{homeClosed=true;homeCode=c;homeSignal=s;r();}));
 homeTimer=setTimeout(()=>{homeForced=true;home.kill('SIGKILL');},45000);
 await homeDone;clearTimeout(homeTimer);
 assert.ok(homeClosed&&homeCode===0&&!homeSignal&&!homeError&&!homeForced,'Home process failed');
 assert.ok(homeLog.includes('SCENERY_HOME_READY'));
 assert.ok(!/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use|RID[^\n]*leak/i.test(homeLog),'Home errors/leaks');
}catch(e){failure=String(e);process.exitCode=1;}
finally{
 clearTimeout(timer);
 clearTimeout(homeTimer);
 if(child&&!closed){forced=true;child.kill('SIGKILL');await done;}
 if(home&&!homeClosed){homeForced=true;home.kill('SIGKILL');await homeDone;}
 if(authority)await authority.close();
 writeFileSync(resolve(output,'native.log'),log);
 writeFileSync(resolve(output,'home.log'),homeLog);
 writeFileSync(resolve(output,'witness.json'),JSON.stringify({success:failure===null,failure,code,signal,spawnError,forced,closed,home:{closed:homeClosed,code:homeCode,signal:homeSignal,error:homeError,forced:homeForced},resources,witness,accepted:false},null,2));
 console.log(JSON.stringify({output,success:failure===null,failure}));
}
