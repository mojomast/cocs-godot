#!/usr/bin/env node
// SOURCE-ONLY SAFE: --plan/import perform no authority, process, or engine work.
// Execute only under the owner's future vehicle grant, after nine assets import.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {existsSync,mkdirSync,mkdtempSync,readFileSync,writeFileSync,renameSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {observeChild,shutdownPeers,faultPattern} from '../asset-production/process-evidence.mjs';
import {KINDS,MAP,MODE,ROUND_SECONDS,neutral,look,walk,drive,distance,signedSpeed,wrap,validateCommand,assertRole,assertObservation,assertEventPosition,assertCase,walkingController,seatSettled} from './journey-contract.mjs';
const ROOT=fileURLToPath(new URL('../../',import.meta.url));
export function options(argv=process.argv.slice(2)){
  const arg=(key,fallback)=>argv.find(a=>a.startsWith(`--${key}=`))?.slice(key.length+3)??fallback;
  const kind=arg('kind','all');assert.ok(kind==='all'||KINDS.includes(kind));
  assert.ok(!argv.includes('--allow-fallback'),'fallback must run separately before production');
  return {plan:argv.includes('--plan'),granted:argv.includes('--granted'),compact:argv.includes('--compact'),kinds:kind==='all'?[...KINDS]:[kind],requireAssets:true,map:MAP,mode:MODE,roundSeconds:ROUND_SECONDS,
    output:resolve(arg('output','/home/mojo/.tmp-on-disk/cocs-expansion-four-vehicles-evidence-20261002/connected')),
    binary:arg('godot','/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'),
    classification:'three actual native controls/transports; normal source clock; no source pose/health/score writes; controlled live-mesh weather probe; sequential per-kind cases'};
}
export function assetInputs(root=ROOT){
  const hashes={};
  for(const kind of KINDS)for(let lod=0;lod<3;lod++){
    const name=`godot/vehicle_assets/generated/${kind}-lod${lod}.glb`,bytes=readFileSync(join(root,name));
    assert.ok(bytes.length>20&&bytes.toString('ascii',0,4)==='glTF'&&bytes.readUInt32LE(4)===2&&bytes.readUInt32LE(8)===bytes.length,`actual complete GLB required: ${name}`);
    hashes[name]=createHash('sha256').update(bytes).digest('hex');
  }
  return hashes;
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const redact=(key,value)=>/token|sessionkey/i.test(key)?'[redacted]':value;
const save=(path,value)=>writeFileSync(path,JSON.stringify(value,redact,2)+'\n');
const minimal=state=>({time:state.time,actors:state.actors.map(({id,team,vehicleId,vehicleSeat})=>({id,team,vehicleId,vehicleSeat})),vehicles:state.vehicles.map(v=>({...v}))});

export async function runCase(plan,kind,out){
  assert.equal(plan.granted,true,'Explicit vehicle grant required');
  mkdirSync(out,{recursive:true});
  const peers=[],wire=[],observations=[],receipts=[],sourceEvents=[],nativeEvents=[],inputs=[],snapshots=new Map();
  const proof={kind,gunnerFire:false};let game,room,m,stage='startup',failure=null,abortError=null,serial=0,assets,geometryHash,success=false,serverError=null;
  const targetId=`sunscar-0-${kind}`,latest=new Map(),connections=[];
  const fixtureHashes=Object.fromEntries(['tools/godot-vehicle-assets/journey.mjs','tools/godot-vehicle-assets/journey-contract.mjs','godot/tests/vehicle_assets/journey.gd','godot/tests/vehicle_assets/journey.tscn'].map(path=>[path,createHash('sha256').update(readFileSync(join(ROOT,path))).digest('hex')]));
  const interrupt=()=>{abortError=Error('Interrupted');};
  process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
  const boundedPush=(array,value,cap=60000)=>{assert.ok(array.length<cap,'bounded evidence exhausted');array.push(value);};
  const check=()=>{
    if(abortError)throw abortError;
    for(const p of peers)if(p.closed||p.spawnError||faultPattern.test(p.log))throw Error(`native failure ${p.role}: ${p.spawnError??p.log.slice(-1600)}`);
  };
  const command=(role,value={})=>{
    const c=validateCommand({id:++serial,stage,keys:[],fire:false,...value});
    const path=join(out,role+'-commands.json');writeFileSync(path+'.tmp',JSON.stringify(c));renameSync(path+'.tmp',path);
  };
  async function until(label,predicate,ms=30000,stimulate=()=>{}){
    const deadline=Date.now()+ms;
    while(Date.now()<deadline){check();stimulate();const result=predicate();if(result)return result;await sleep(50);}
    throw Error('Timeout '+label);
  }
  const actor=role=>m?.actors.find(a=>a.id===latest.get(role)?.actor?.id);
  const vehicle=()=>m?.vehicles.find(v=>v.id===targetId);
  const reportFresh=role=>{const r=latest.get(role);return r?.phase==='active'&&r.stage===stage&&r.round===1&&m.time-r.sourceTime<.7;};
  function parseLine(role,line){
    try{
      if(line.startsWith('VEHICLE_REPORT ')){
        const r=JSON.parse(line.slice(15));
        assert.equal(r.role,role);assert.equal(r.failures.length,0);
        if(r.phase==='active'&&r.sourceTime>=0){
          const state=snapshots.get(`${r.round}:${r.sourceTime}`);assert.ok(state,'exact emitted source snapshot retained');
          assertObservation(r,state);proof.nativeAssets=true;
        }
        latest.set(role,r);boundedPush(observations,r,20000);
      }else if(line.startsWith('VEHICLE_INPUT '))boundedPush(inputs,JSON.parse(line.slice(14)));
      else if(line.startsWith('VEHICLE_EVENT '))boundedPush(nativeEvents,JSON.parse(line.slice(14)));
    }catch(error){abortError??=error;}
  }
  function launch(role,joinRoom=''){
    command(role);
    const env={...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',COCS_SETTINGS_PATH:join(out,role+'-settings.json')};
    for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']){env[key]=join(out,role,key);mkdirSync(env[key],{recursive:true});}
    const program='python3';
    const args=[join(ROOT,'tools/godot-dev/xvfb_run.py'),plan.binary,'--path',join(ROOT,'godot'),'--audio-driver','Dummy','--resolution',role==='driver'?(plan.compact?'760x520':'1280x800'):'320x240','res://tests/vehicle_assets/journey.tscn','--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,`--map=${MAP}`,'--bots=0','--wait-for-players=3','--require-assets',`--vehicle-target=${targetId}`,`--vehicle-role=${role}`,`--vehicle-command=${join(out,role+'-commands.json')}`,...(role==='driver'?[`--vehicle-capture=${join(out,'frames')}`]:[]),...(plan.compact?['--vehicle-compact']:[]),...(joinRoom?[`--join-room=${joinRoom}`]:[])];
    save(join(out,role+'-launch.json'),{command:program,args});
    const child=spawn(program,args,{cwd:ROOT,env,stdio:['ignore','pipe','pipe']});
    const peer=observeChild(child,role);peers.push(peer);
    let pending='';child.stdout.on('data',chunk=>{pending+=chunk;const lines=pending.split('\n');pending=lines.pop();for(const line of lines)parseLine(role,line);});
    child.on('close',()=>{if(pending.trim())parseLine(role,pending);});
  }
  async function step(name,stimulate,predicate,ms=25000){
    stage=name;const start=m.time;
    for(const p of peers)command(p.role);
    await until(name,()=>peers.every(p=>reportFresh(p.role))&&predicate(),ms,()=>{
      assert.ok(!m.over,'round ended before '+name);stimulate();
    });
    boundedPush(receipts,{stage:name,start,end:m.time,actorIds:peers.map(p=>({role:p.role,id:actor(p.role)?.id,seat:actor(p.role)?.vehicleSeat})),vehicle:{id:vehicle().id,health:vehicle().health,position:{...vehicle().position}}},200);
  }
  function sameStageNeutral(except=[],wet=false){for(const p of peers)if(!except.includes(p.role))command(p.role,{wet});}
  const follow=walkingController();
  function walkTo(role,point,key,stopRadius=1.05){
    const a=actor(role);assert.ok(a,role+' assigned source actor');
    if(a.health<=0)return neutral(); // await the actual normal source respawn
    if(distance(a,point)<stopRadius)return neutral();
    if(distance(a,point)<4)return walk(a,point);
    return follow(m,a,point,key);
  }
  async function approach(role){
    await step(`approach-${role}-${serial}`,()=>{
      sameStageNeutral([role]);command(role,walkTo(role,vehicle().position,`${kind}-${role}-approach-${vehicle().position.x.toFixed(0)}`,1.7));
    },()=>actor(role).health>0&&distance(actor(role),vehicle().position)<1.9&&distance(latest.get(role)?.actor??{x:Infinity,z:Infinity},vehicle().position)<1.9&&Object.keys(latest.get(role)?.inputState?.keys??{pending:true}).length===0,70000);
  }
  async function enter(role,seat,wet=false){
    const name=`enter-${role}-${seat}-${serial}`;
    await step(name,()=>{
      sameStageNeutral([role],wet);
      const a=actor(role);
      const input=a.vehicleId===targetId?neutral():distance(a,vehicle().position)>1.8?walkTo(role,vehicle().position,name+'-final-approach',1.7):{keys:['E']};
      command(role,{...input,wet});
    },()=>seatSettled(actor(role),latest.get(role)?.actor,targetId,seat),15000);
    assertRole(m.snapshot(),actor(role).id,targetId,seat);
  }
  async function exit(role,wet=false){
    await step(`exit-${role}-${serial}`,()=>{sameStageNeutral([role],wet);command(role,{keys:['E'],wet});},()=>seatSettled(actor(role),latest.get(role)?.actor,null),10000);
  }
  async function fire(role,type){
    const start=m.serial;
    const types=type==='personal-fire'?['shot','launch']:[type];
    await step(`${role}-${type}-${serial}`,()=>{
      sameStageNeutral([role]);command(role,{keys:[],fire:true,yaw:vehicle().heading-Math.PI,pitch:.55});
    },()=>sourceEvents.some(e=>e.id>start&&types.includes(e.type)&&e.actor===actor(role).id)&&nativeEvents.some(r=>r.event.id>start&&types.includes(r.event.type)&&r.event.actor===actor(role).id),12000);
  }
  try{
    assets=assetInputs();assert.ok(existsSync(plan.binary),'pinned Godot executable');
    const manifest=JSON.parse(readFileSync(join(ROOT,'godot/content/generated/manifest.json'))),entry=manifest.maps.find(x=>x.id===MAP);
    assert.ok(entry);const mapBytes=readFileSync(join(ROOT,'godot/content/generated',entry.path));
    geometryHash=createHash('sha256').update(mapBytes).digest('hex');assert.equal(geometryHash,entry.sha256);
    const {createGameServer}=await import('../../server/game-server.mjs');
    const {visible}=await import('../../game/core.mjs');
    game=createGameServer({historyPath:null,progressionPath:null,tickMs:1000/60});
    game.server.on('error',error=>{abortError??=error;});
    game.wss.on('connection',socket=>{
      const connection={round:0,peer:null};connections.push(connection);
      socket.on('message',raw=>{try{const frame=JSON.parse(String(raw));boundedPush(wire,{direction:'input',peer:connection.peer,round:connection.round,frame});}catch(e){abortError??=e;}});
      const send=socket.send;
      socket.send=function(raw,...rest){
        try{
          const frame=JSON.parse(String(raw));
          if(frame.type==='welcome')connection.peer=frame.peerId;
          if(frame.type==='start'){
            connection.round++;assert.equal(frame.mapId,MAP);assert.equal(frame.config.mode,MODE);assert.equal(frame.config.timeLimit,ROUND_SECONDS);
          }
          if(frame.type==='snapshot'){
            assert.ok(snapshots.size<16000,'snapshot evidence bound');snapshots.set(`${connection.round}:${frame.state.time}`,minimal(frame.state));
          }else if(frame.type==='events'){
            // Keep one copy by authoritative event ID/round, with emitted position.
            for(const e of frame.items)if(!sourceEvents.some(old=>old.id===e.id&&old.round===connection.round))boundedPush(sourceEvents,{...e,round:connection.round});
          }else boundedPush(wire,{direction:'source',peer:connection.peer,round:connection.round,frame});
        }catch(e){abortError??=e;}
        return send.call(this,raw,...rest);
      };
    });
    await new Promise((yes,no)=>{game.server.once('error',no);game.server.listen(0,'127.0.0.1',yes);});
    launch('driver');
    room=await until('native host configured',()=>[...game.registry.rooms.values()].find(r=>r.mapId===MAP&&r.config?.mode===MODE));
    launch('opponent',room.id);
    await until('second native peer joined',()=>room.peers.size===2);
    launch('crew',room.id);
    m=await until('three native start',()=>room.match);
    await until('three active authored native observations',()=>peers.every(p=>latest.get(p.role)?.phase==='active'&&latest.get(p.role)?.sourceTime>=0));
    assert.equal(m.arena.id,MAP);assert.equal(m.config.mode,MODE);assert.equal(m.actors.filter(a=>!a.bot).length,3);
    assert.ok(vehicle());assert.notEqual(actor('driver').team,actor('opponent').team);assert.equal(actor('driver').team,actor('crew').team);
    assert.equal(actor('driver').harness,'codex','repair chosen via create protocol');
    await approach('driver');await enter('driver','driver');proof.driver=true;
    const origin={...vehicle().position};
    await step('drive-boost',()=>{sameStageNeutral(['driver']);command('driver',drive(vehicle(),['W','SHIFT']));},()=>distance(origin,vehicle().position)>5&&signedSpeed(vehicle())>3,10000);proof.drive=true;
    const heading=vehicle().heading;
    await step('drive-bend',()=>{sameStageNeutral(['driver']);command('driver',drive(vehicle(),['W','D']));},()=>Math.abs(wrap(vehicle().heading-heading))>.2&&Math.abs(vehicle().roll)>.005,8000);proof.bend=true;
    await step('reverse',()=>{sameStageNeutral(['driver']);command('driver',drive(vehicle(),['S']));},()=>signedSpeed(vehicle())<-.8,10000);proof.reverse=true;
    await step('stop',()=>{sameStageNeutral(['driver']);command('driver',drive(vehicle(),['W']));},()=>Math.abs(signedSpeed(vehicle()))<.3,6000);
    await step('park-brake',()=>{sameStageNeutral(['driver']);command('driver',drive(vehicle(),['SPACE']));},()=>Math.abs(signedSpeed(vehicle()))<.01,6000);
    await fire('driver','vehicle-shot');proof.driverFire=true;
    await approach('opponent');
    // While wet, release the source driver, then allow the opposing public team
    // to occupy the free driver slot. The source permits mixed-team boarding.
    await exit('driver',true);await enter('opponent','driver',true);
    await step('team-swap-wet',()=>sameStageNeutral([],true),()=>peers.every(p=>latest.get(p.role)?.wet&&latest.get(p.role)?.fleet.find(v=>v.id===targetId)?.team===actor('opponent').team),6000);proof.teamSwapWet=true;
    await exit('opponent',true);await approach('driver');await enter('driver','driver');
    if(kind!=='scout'){
      await approach('opponent');await enter('opponent','gunner');await fire('opponent','vehicle-shot');proof.gunnerFire=true;
    }
    await approach('crew');await enter('crew','passenger');await fire('crew','personal-fire');proof.passengerFire=true;
    await exit('crew');if(kind!=='scout')await exit('opponent');await exit('driver');
    // Pick an actual navigable firing point with source world line of sight.
    const v=vehicle(),enemy=actor('opponent');
    const firingPoint=m.nav.filter(p=>distance(p,v.position)>=7&&distance(p,v.position)<=18&&visible({x:p.x,y:(p.y??0)+1.45,z:p.z},{x:v.position.x,y:v.position.y+.3,z:v.position.z},m.arena)).sort((a,b)=>distance(a,enemy)-distance(b,enemy))[0];
    assert.ok(firingPoint,'source navigable line of sight to hull');
    await step('opponent-to-hull',()=>{sameStageNeutral(['opponent']);command('opponent',walkTo('opponent',firingPoint,kind+'-firing-point'));},()=>distance(actor('opponent'),firingPoint)<1.6&&Math.hypot(actor('opponent').vx,actor('opponent').vz)<.5,65000);
    const damageSerial=m.serial;
    const shoot=()=>{sameStageNeutral(['opponent']);const a=actor('opponent');command('opponent',{keys:a.ammo[a.weapon]===0?['R']:[],fire:true,...look(a,vehicle().position,.3)});};
    await step('ordinary-damage',shoot,()=>sourceEvents.some(e=>e.id>damageSerial&&e.type==='vehicle-damage'&&e.vehicle===targetId)&&vehicle().health<vehicle().maxHealth-35,15000);proof.damage=true;
    assert.ok(vehicle().health>0,'repair needs a live genuinely damaged hull');
    const damaged=vehicle().health,repairSerial=m.serial;
    // Source hits can intentionally select visible crew through the solid hull
    // OBB. Damage the empty chassis, then actually reboard with Codex to repair;
    // do not manufacture surviving crew health or a repair heartbeat.
    await approach('driver');await enter('driver','driver');
    await step('passive-codex-repair',()=>sameStageNeutral(),()=>vehicle().health>damaged+12&&sourceEvents.some(e=>e.id>repairSerial&&e.type==='vehicle-repair'&&e.vehicle===targetId),15000);
    const repaired=sourceEvents.find(e=>e.id>repairSerial&&e.type==='vehicle-repair'&&e.vehicle===targetId);assertEventPosition(repaired,vehicle());proof.repair=true;
    await exit('driver');
    const wreckSerial=m.serial;
    await step('ordinary-wreck',shoot,()=>sourceEvents.some(e=>e.id>wreckSerial&&e.type==='vehicle-destroyed'&&e.vehicle===targetId)&&vehicle().health===0,50000);
    const wreck=sourceEvents.find(e=>e.id>wreckSerial&&e.type==='vehicle-destroyed'&&e.vehicle===targetId);assertEventPosition(wreck,vehicle());assert.equal(actor('driver').vehicleId,null);proof.wreck=true;
    await step('source-respawn',()=>sameStageNeutral(),()=>vehicle().health===vehicle().maxHealth&&vehicle().respawnTimer===0&&sourceEvents.some(e=>e.id>wreckSerial&&e.type==='vehicle-respawn'&&e.vehicle===targetId),18000);proof.respawn=true;
    proof.wireInputs=peers.every(p=>inputs.some(i=>i.role===p.role&&i.result===0&&i.packet.fire===true))&&wire.some(w=>w.direction==='input'&&w.frame.type==='input'&&w.frame.input?.interact);
    assert.ok(proof.wireInputs,'native controls reached actual authoritative input wire');
    // Natural configured time/objective result, followed by production Enter.
    stage='natural-results';for(const p of peers)command(p.role);
    await until('natural source results',()=>m.over&&peers.every(p=>latest.get(p.role)?.phase==='results'),Math.max(20000,(ROUND_SECONDS+18-m.time)*2000));
    stage='ordinary-rematch';command('driver',{keys:['ENTER']});
    await until('native ordinary rematch cleanup',()=>peers.every(p=>{const r=latest.get(p.role);return r?.round===2&&r.phase==='active'&&r.resetClean&&r.retired;}),20000,()=>{for(const p of peers)if(p.role!=='driver')command(p.role);});
    assert.notEqual(room.match,m);proof.reset=true;proof.resetCleanup=true;
    assertCase(proof,kind);success=true;
  }catch(error){failure={stage,message:String(error),stack:error.stack};}
  finally{
    stage='teardown';
    const teardown=await shutdownPeers(peers,p=>command(p.role,{quit:true}));
    if(game){
      let timer;
      try{
        const closed=game.server.listening?new Promise(r=>game.server.once('close',r)):Promise.resolve();
        await Promise.race([Promise.all([game.close(),closed]),new Promise((_,no)=>{timer=setTimeout(()=>no(Error('authority shutdown timeout')),5000);})]);
      }catch(error){serverError=String(error);for(const socket of game.wss.clients)socket.terminate();}
      finally{clearTimeout(timer);}
    }
    process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
    // Complete logs are persisted only AFTER every owned native stdio closes.
    for(const p of peers){writeFileSync(join(out,p.role+'.log'),p.log);writeFileSync(join(out,p.role+'-stderr.log'),p.stderr);}
    if(abortError&&!failure)failure={stage:'teardown',message:String(abortError)};
    success=success&&!failure&&!serverError&&peers.length===3&&teardown.every(p=>p.clean);
    save(join(out,'wire.json'),wire);save(join(out,'observations.json'),observations);save(join(out,'inputs.json'),inputs);
    save(join(out,'events.json'),{source:sourceEvents,native:nativeEvents});save(join(out,'stages.json'),receipts);
    const result={kind,map:MAP,mode:MODE,success,accepted:false,classification:plan.classification,assets,fixtureHashes,geometryHash,proof,failure,serverError,teardown};
    save(join(out,'outcome.json'),result);return result;
  }
}
export async function run(plan){
  assert.ok(plan.granted&&!plan.plan,'Explicit future grant required');
  mkdirSync(plan.output,{recursive:true});const out=mkdtempSync(join(plan.output,'journey-'));save(join(out,'plan.json'),plan);
  const results=[];
  // Cases are serialized. Previous native clients and source server must fully
  // close before another case can start; failures stop the queue immediately.
  for(const kind of plan.kinds){const result=await runCase(plan,kind,join(out,kind));results.push(result);if(!result.success)break;}
  const success=results.length===plan.kinds.length&&results.every(r=>r.success);
  save(join(out,'summary.json'),{success,accepted:false,results:results.map(r=>({kind:r.kind,success:r.success,failure:r.failure}))});
  console.log(success?'VEHICLE_JOURNEY_OK':'VEHICLE_JOURNEY_FAILED',out);return success;
}
if(process.argv[1]&&pathToFileURL(resolve(process.argv[1])).href===import.meta.url){
  const plan=options();if(plan.plan)console.log(JSON.stringify(plan,null,2));else{assert.ok(plan.granted,'Use --plan now; --granted requires explicit vehicle slot');if(!await run(plan))process.exitCode=1;}
}
