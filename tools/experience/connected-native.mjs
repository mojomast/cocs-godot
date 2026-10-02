#!/usr/bin/env node
// Execute only after the engine grant. --plan and importing this module never
// start an authority, display or engine. Native peers use isolated private Xvfb.
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {mkdirSync,mkdtempSync,writeFileSync,readFileSync,createWriteStream,statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {ownProcess,stopOwned,until} from './connected-process.mjs';
import {filterCocsSnapshot} from '../../game/cocs-intel.mjs';
import {assistCredit,spectateActor} from '../../game/hud.mjs';

export const ROUTES=Object.freeze({
  mode:{map:'meridian-exchange',mode:'arsenal',scene:'res://mode_expansion/demo.tscn',factory:'../../server/game-server.mjs',host:['--bots=1','--time-limit=120','--wait-for-players=2'],retry:'native-retry-button'},
  world:{map:'tern-archipelago',mode:'cocs',scene:'res://multiplayer_worlds/lattice_demo.tscn',factory:'../../port/multiplayer-worlds/derived/game-server.mjs',host:['--bots=1','--time-limit=120'],retry:'explicit-home-rejoin'},
  sports:{map:'sirocco-circuit',mode:'puma-race',scene:'res://tests/experience/connected_sports.tscn',factory:'../../port/multiplayer-worlds/derived/game-server.mjs',host:['--bots=1','--time-limit=120','--round-target=10'],retry:'explicit-home-rejoin'},
  combined_arms:{map:'sunscar-convoy',mode:'combined-arms',scene:'res://tests/experience/connected_arms.tscn',factory:'../../server/game-server.mjs',host:['--bots=1','--wait-for-players=2'],retry:'explicit-home-rejoin'},
});
export function options(argv=process.argv.slice(2)) {
  const arg=(key,fallback)=>argv.find(x=>x.startsWith(`--${key}=`))?.slice(key.length+3)??fallback;
  const family=arg('family','mode');assert.ok(Object.hasOwn(ROUTES,family),'known --family');
  return {family,route:ROUTES[family],compact:argv.includes('--compact'),plan:argv.includes('--plan'),output:arg('output',process.env.EVIDENCE_DIR??'/tmp/opencode'),binary:process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64'};
}
const publicKeys=new Set(['id','name','health','team','x','y','z','yaw','pitch','eyeHeight']);
const cleanName=value=>typeof value==='string'?value.replace(/[\n\r\t]/g,' ').split(' ').filter(Boolean).join(' ').slice(0,36):'';
export function assertPublicObservation(observation,state) {
  assert.equal(observation.spectating,true);assert.equal(observation.actor,-1);
  for(const key of ['kit','marks'])assert.equal(Object.keys(observation[key]).length,0,key+' empty');
  assert.deepEqual(observation.hits,[]);
  assert.ok((observation.feedMeta??[]).every(row=>row.assist!==true),'no prior-seat ASSIST metadata');
  assert.equal(observation.recap??'','');assert.equal(observation.kill??'','');
  for(const row of observation.targets) {
    const source=state.actors.find(a=>a.id===row.id);assert.ok(source,'target in actual recipient snapshot');
    for(const [key,value] of Object.entries(row)) {
      assert.ok(publicKeys.has(key),'private target field '+key);
      assert.deepEqual(value,key==='name'?cleanName(source.name):source[key],'source-public scalar '+key);
    }
  }
  const target=spectateActor(state.actors,observation.target);
  assert.equal(observation.target,target?.id??null,'target resolves against actual public source state');
}
const redact=(key,value)=>/^(token|progressToken|voiceSession|resumeToken)$/i.test(key)?'[redacted]':value;
async function bounded(promise,ms,label) {
  let timer;
  try {return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(label)),ms);})]);}
  finally {clearTimeout(timer);}
}

export async function run(plan) {
  mkdirSync(resolve(plan.output),{recursive:true});
  const out=mkdtempSync(join(resolve(plan.output),`spectator-${plan.family}-${plan.compact?'compact':'wide'}-`));
  const save=(name,value)=>writeFileSync(join(out,name),JSON.stringify(value,redact,2)+'\n');
  const wire=createWriteStream(join(out,'wire.ndjson'),{flags:'wx'});
  const receipts=[],connections=[],children=[],reports=[],pending=new Map(),queues=new Map();
  let game,control,room,fatal=null,serial=0,deadline,sourceURL,controlURL;
  const fail=error=>{fatal??=error instanceof Error?error:Error(String(error));};
  wire.on('error',fail);
  const interrupt=()=>fail(Error('Journey interrupted by SIGINT/SIGTERM'));
  const abort=()=>{if(fatal)throw fatal;for(const owned of children) {
    if(owned.error)throw owned.error;
    if(/SCRIPT ERROR|Parse Error|SPECTATOR_JOURNEY_FAIL/.test(owned.text))throw Error(`Native runtime/assertion failure: ${owned.log}`);
    if(owned.closed&&!owned.allowExit)throw Error(`Native exited before teardown: ${owned.log}`);
  }};
  const wait=(predicate,label,ms=25000)=>until(predicate,label,{ms,abort});
  const record=entry=>wire.write(JSON.stringify({wallMs:Date.now(),...entry},redact)+'\n');
  const latest=name=>reports.filter(r=>r.name===name).at(-1)?.observation;
  const connFor=name=>connections.findLast(c=>c.peer===latest(name)?.peer);
  const command=async(name,action,extra={},ms=20000)=>{
    const id=++serial;const item={id,action,...extra};queues.get(name).push(item);
    const result=await wait(()=>pending.get(id),`${name} ${action}`,ms);
    assert.equal(result.ok,true,JSON.stringify(result.failures));return result.observation;
  };
  function launch(name,roomId,home=false) {
    abort();
    const generation=children.filter(c=>c.name===name).length;
    const dir=join(out,`${name}-${generation}`);mkdirSync(dir,{recursive:true});queues.set(name,[]);
    const env={...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',COCS_SETTINGS_PATH:join(out,`${name}-settings.json`),COCS_CAREER_ROOT:join(dir,'career')};
    for(const [key,folder] of [['XDG_DATA_HOME','data'],['XDG_CONFIG_HOME','config'],['XDG_CACHE_HOME','cache']]) {env[key]=join(dir,folder);mkdirSync(env[key],{recursive:true});}
    const args=['tools/godot-dev/xvfb_run.py',plan.binary,'--audio-driver','Dummy','--path',resolve('godot'),'--resolution',plan.compact?'760x520':'1280x800','--script','res://tests/experience/connected_native.gd','--',`--endpoint=${sourceURL}`,`--map=${plan.route.map}`,`--mode=${plan.route.mode}`,`--journey-control=${controlURL}`,`--journey-out=${dir}`,`--journey-name=${name}`,`--journey-family=${plan.family}`,`--journey-scene=${plan.route.scene}`,...(roomId?[`--join-room=${roomId}`]:plan.route.host),...(plan.compact?['--journey-compact']:[]),...(home?['--journey-home']:[])];
    save(`${name}-${generation}-launch.json`,{command:'python3',args,settings:env.COCS_SETTINGS_PATH});
    const owned=ownProcess('python3',args,{log:join(dir,'native.log'),env});owned.name=name;children.push(owned);
  }
  async function home(name) {
    const owned=children.findLast(c=>c.name===name);owned.allowExit=true;
    await command(name,'home');await wait(()=>owned.closed,`${name} ordinary Settings Leave exits`,10000);
    assert.equal(owned.child.exitCode,0,'ordinary Leave exit');
    const count=reports.length;launch(name,room.id,true);
    await wait(()=>reports.slice(count).some(r=>r.name===name&&r.id===0),`${name} supervised actual Home`);
    const observed=latest(name);assert.equal(observed.scene,'res://ui/main_menu.tscn');
    assert.deepEqual(observed.hits,[]);assert.deepEqual(observed.targets,[]);assert.equal(observed.held,0);assert.equal(Object.keys(observed.kit).length,0);
    await command(name,'capture',{label:'home'});
  }
  async function rejoin(name) {await home(name);await command(name,'join');}
  async function inspect(name) {return command(name,'inspect');}
  async function assertPublic(name) {
    const observed=await inspect(name),connection=connFor(name);
    const frame=connection?.snapshots.findLast(s=>s.time===observed.sourceTime);
    assert.ok(frame,'exact received source-clock snapshot retained');assertPublicObservation(observed,frame);
    assert.equal(observed.uiScale,plan.compact?150:100);assert.equal(observed.contentScale,plan.compact?1.5:1);
    return observed;
  }
  function stage(label,mutate) {
    assert.ok(room?.match&&!room.roundOver,'source staging requires live match');
    const match=room.match,before=match.serial;
    const receipt={label,method:'explicit source Match method staging (not unaided play)',time:match.time,beforeSerial:before};
    receipts.push(receipt);
    try {Object.assign(receipt,mutate(match)??{});return receipt;}
    catch(error) {receipt.failure=String(error);throw error;}
    finally {receipt.events=match.events.filter(e=>e.id>before);save('source-actions.json',receipts);}
  }
  function participant(name) {
    const actor=room.match.actors.find(a=>a.id===latest(name)?.actor);assert.ok(actor,`source actor ${name}`);return actor;
  }
  function prepareVictim(match,actor) {
    match.spawn(actor);actor.protection=0;actor.armor=0;
    // These are recorded setup changes, never substitute/fabricated wire events.
    if(actor.vehicleId!=null)match.releaseVehicle(actor,undefined,'experience-fixture');
  }
  process.once('SIGINT',interrupt);process.once('SIGTERM',interrupt);
  deadline=setTimeout(()=>fail(Error('Overall journey deadline 240s')),240000);
  let passed=false,errorText=null,proof={family:plan.family,compact:plan.compact};
  try {
    save('plan.json',{...plan,binary:plan.binary,scope:'two native players + late native spectator; normal source clock; explicit source staging',retry:plan.route.retry});
    assert.ok(statSync(plan.binary).isFile(),'pinned engine exists (no --version subprocess)');
    const factory=(await import(new URL(plan.route.factory,import.meta.url))).createGameServer;
    game=factory({historyPath:null,progressionPath:null,graceMs:5000});
    game.server.on('error',fail);
    game.wss.on('connection',socket=>{
      const connection={socket,peer:null,actor:null,spectating:null,phase:'handshake',snapshots:[],inputs:[],starts:[],results:[],events:[],welcomes:[],silence:false};connections.push(connection);
      socket.on('error',error=>record({kind:'socket-error',peer:connection.peer,message:error.message}));
      socket.on('message',raw=>{
        const frame=JSON.parse(String(raw));record({direction:'native-to-source',peer:connection.peer,spectating:connection.spectating,phase:connection.phase,frame});
        if(frame.type==='input') {
          connection.inputs.push({spectating:connection.spectating,phase:connection.phase,frame});
          if(connection.spectating!==false)fail(Error(`Spectator/unassigned wire input, including neutral packet, peer=${connection.peer}`));
        }
      });
      const send=socket.send;
      socket.send=function(raw,...rest) {
        const frame=JSON.parse(String(raw));
        if(connection.silence&&['snapshot','snapshot-delta','events'].includes(frame.type))return;
        if(frame.type==='welcome') {connection.peer=frame.peerId;connection.spectating=frame.spectate===true;connection.welcomes.push({spectating:connection.spectating,resumed:frame.reconnected===true});}
        if(frame.type==='lobby') {const seat=frame.players.find(p=>p.peerId===connection.peer);if(seat){connection.actor=seat.actorId;connection.spectating=seat.spectate===true;}}
        if(frame.type==='start') {connection.phase='live';connection.starts.push({map:frame.mapId,geometryHash:frame.geometryHash,config:frame.config});}
        if(frame.type==='results') {connection.phase='results';connection.results.push({time:frame.state.time,reason:frame.state.overReason});}
        if(frame.type==='events')connection.events.push(...frame.items);
        if(frame.type==='snapshot') {
          connection.snapshots.push(frame.state);if(connection.snapshots.length>160)connection.snapshots.shift();
          if(connection.spectating)try {assert.deepEqual(frame.state,filterCocsSnapshot(frame.state,null));}catch(error){fail(error);}
          record({direction:'source-to-native',peer:connection.peer,type:'snapshot',time:frame.state.time,spectating:connection.spectating,actors:frame.state.actors.map(a=>Object.fromEntries(Object.entries(a).filter(([key])=>publicKeys.has(key))))});
        } else record({direction:'source-to-native',peer:connection.peer,frame});
        return send.call(this,raw,...rest);
      };
    });
    await new Promise((ok,bad)=>{game.server.once('error',bad);game.server.listen(0,'127.0.0.1',ok);});
    sourceURL=`ws://127.0.0.1:${game.server.address().port}`;
    control=createServer(async(req,res)=>{
      try {
        const path=new URL(req.url,'http://127.0.0.1').pathname.split('/');const name=path[2];
        assert.ok(queues.has(name),'known native driver');res.setHeader('content-type','application/json');
        if(req.method==='GET'&&path[1]==='poll')return res.end(JSON.stringify(queues.get(name).shift()??{}));
        assert.ok(req.method==='POST'&&path[1]==='report','known endpoint');
        let text='';for await(const chunk of req){text+=chunk;assert.ok(text.length<524288,'bounded report');}
        const report={...JSON.parse(text),name};reports.push(report);pending.set(report.id,report);
        save('native-reports.json',reports);
        if(report.ok!==true)fail(Error(`Native report ${name}: ${JSON.stringify(report.failures)}`));
        res.end('{}');
      } catch(error) {fail(error);res.statusCode=500;res.end(JSON.stringify({error:error.message}));}
    });
    control.requestTimeout=8000;control.headersTimeout=8000;
    await new Promise((ok,bad)=>{control.once('error',bad);control.listen(0,'127.0.0.1',ok);});
    controlURL=`http://127.0.0.1:${control.address().port}`;
    launch('host');
    room=await wait(()=>[...game.registry.rooms.values()].find(r=>r.mapId===plan.route.map&&r.config?.mode===plan.route.mode),'host source configuration');
    launch('guest',room.id);
    await wait(()=>room.peers.size===2&&latest('host')&&latest('guest'),'two real native peers');
    if(plan.family==='world')await command('host','start');
    await command('host','live',{},30000);await command('guest','live',{},30000);
    assert.equal(latest('host').spectating,false);assert.equal(latest('guest').spectating,false);
    assert.notEqual(latest('host').actor,latest('guest').actor);
    let expectedGeometry;
    if(plan.family==='world'||plan.family==='sports')expectedGeometry=JSON.parse(readFileSync(`godot/multiplayer_worlds/generated/${plan.route.map}.json`)).geometryHash;
    else {
      const entry=JSON.parse(readFileSync('godot/content/generated/manifest.json')).maps.find(m=>m.id===plan.route.map);
      assert.ok(entry,'native semantic map entry');
      const bytes=readFileSync(join('godot/content/generated',entry.path));
      assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256,'native source-map bytes match catalog');
      assert.equal(JSON.parse(bytes).source_map.id,room.match.arena.id,'same exact source map');
      expectedGeometry=entry.sha256;
    }
    assert.ok(expectedGeometry,'native geometry/catalog identity');
    for(const name of ['host','guest']) {
      assert.equal(connFor(name).starts[0].map,plan.route.map,'exact source start map');
      assert.equal(connFor(name).starts[0].config.timeLimit,120,'source echoed bounded natural round limit');
      if(plan.family==='world'||plan.family==='sports')assert.equal(connFor(name).starts[0].geometryHash,expectedGeometry,'exact authority/native world geometry');
      await command(name,'player-input');
      assert.ok(connFor(name).inputs.some(x=>Object.entries(x.frame.input).some(([k,v])=>['x','z','fire','jump'].includes(k)&&v)),'ordinary native actor action reached wire');
    }
    launch('spectator',room.id);await wait(()=>latest('spectator'),'spectator driver starts');
    await command('spectator','live',{},30000);
    assert.equal(connFor('spectator').welcomes[0].spectating,true,'source late spectator seat');
    await assertPublic('spectator');
    await command('spectator','camera');await command('spectator','modal');await command('spectator','focus-boundary');
    await command('spectator','hold-free');
    connFor('spectator').silence=true;
    receipts.push({label:'starve spectator only',time:room.match.time,types:['snapshot','snapshot-delta','events']});
    await command('spectator','stale');connFor('spectator').silence=false;
    await command('spectator','live');await assertPublic('spectator');

    // ASSIST needs three actors. The third is a source bot, never a fake peer.
    // Sports has no infantry damage journey; it still exercises camera/seat/wire.
    if(plan.family!=='sports') {
      const victim=room.match.actors.find(a=>a.bot && a.id!==latest('host').actor && a.id!==latest('guest').actor);assert.ok(victim,'source third actor for assist staging');
      for(const [label,delay] of [['within-window',0.3],['outside-window',5.25]]) {
        const hit=stage(`assist ${label} positive damage`,match=>{prepareVictim(match,victim);match.damage(victim,1,participant('host'));return {victim:victim.id,source:participant('host').id,setup:['Match.spawn','protection=0','armor=0','releaseVehicle if mounted']};});
        const damage=hit.events.find(e=>e.type==='damage'&&e.actor===victim.id&&e.source===latest('host').actor&&e.amount>0);assert.ok(damage,'real positive source damage receipt');
        await wait(()=>room.match.time-hit.time>=delay,`source ${label} clock`,10000);
        const death=stage(`assist ${label} other-player death`,match=>{victim.protection=0;match.damage(victim,9999,participant('guest'));return {victim:victim.id,killer:participant('guest').id};});
        const event=death.events.find(e=>e.type==='death'&&e.actor===victim.id&&e.killer===latest('guest').actor);assert.ok(event,'real attributed death receipt');
        const wireDeath=await wait(()=>connFor('host').events.find(e=>e.id===event.id),'actual death wire receipt');
        const wireDamage=connFor('host').events.find(e=>e.id===damage.id);assert.ok(wireDamage,'actual positive damage wire receipt');
        const credited=assistCredit({[victim.id]:wireDamage.time},victim.id,wireDeath.time);assert.equal(credited,label==='within-window');
        const observed=await wait(async()=>{const o=await inspect('host');return o.feedMeta.some(m=>m.time===wireDeath.time&&m.victim===victim.name)?o:null;},'native event-backed assist enrichment',6000);
        const meta=observed.feedMeta.find(m=>m.time===wireDeath.time&&m.victim===victim.name);assert.equal(meta.assist,credited,'native assist equals source oracle');
        if(credited) {
          const replay={type:'events',items:[wireDamage,wireDeath]};
          for(const name of ['host','spectator'])connFor(name).socket.send(JSON.stringify(replay));
          receipts.push({label:'duplicate transport delivery of original received public events',time:room.match.time,eventIds:replay.items.map(e=>e.id)});
          const after=await inspect('host');
          assert.deepEqual(after.feedMeta.filter(m=>m.time===wireDeath.time&&m.victim===victim.name),[meta],'duplicate event replay cannot append/re-credit');
        }
        await command('host','capture',{label:`assist-${label}`});await assertPublic('spectator');
      }
    }
    if(plan.family!=='sports') {
      const watched=latest('host').actor;
      await command('spectator','select',{target:watched});
      const receipt=stage('watched target dies',match=>{const actor=participant('host');actor.protection=0;actor.armor=0;match.damage(actor,9999,null);return {target:actor.id};});
      assert.ok(receipt.events.some(e=>e.type==='death'&&e.actor===watched),'source confirmed watched target death');
      await wait(async()=>{const o=await inspect('spectator');return o.target!==watched;},'death fallback',5000);
      await assertPublic('spectator');
    }

    // Same-seat resume is exposed by the actual mode Retry button. Other route
    // UIs deliberately use ordinary Home/rejoin, and evidence names that limit.
    connFor('spectator').socket.terminate();
    if(plan.route.retry==='native-retry-button')await command('spectator','retry');
    else {await rejoin('spectator');await command('spectator','live');}
    await assertPublic('spectator');
    if(plan.route.retry==='native-retry-button')assert.equal(connFor('spectator').welcomes.at(-1).resumed,true,'same spectator token resumed');
    if(plan.family!=='sports') {
      stage('seed old player incoming context before seat expiry',match=>{const actor=participant('guest');prepareVictim(match,actor);match.damage(actor,2,null);return {actor:actor.id,setup:['Match.spawn','protection=0','armor=0']};});
      await wait(async()=>{const o=await inspect('guest');return o.hits.length>0;},'old seat has actual incoming hit',5000);
    }
    const oldPeer=latest('guest').peer,oldActor=latest('guest').actor;
    connFor('guest').socket.terminate();
    await wait(()=>!room.peers.has(oldPeer),'source grace expires (5s configured)',10000);
    receipts.push({label:'source leave takeover',oldPeer,oldActor,actorStillPublic:room.match.actors.some(a=>a.id===oldActor),note:'Source preserves departed actor as BOT; no invented removal/fallback.'});
    if(plan.route.retry==='native-retry-button')await command('guest','retry');
    else {await rejoin('guest');await command('guest','live');}
    assert.equal(connFor('guest').welcomes.at(-1).resumed,false,'expired seat not resumed');
    await assertPublic('guest');await command('guest','capture',{label:'expired-player-now-spectator'});

    await wait(()=>room.roundOver,'natural bounded source round',145000);
    for(const name of ['spectator','guest'])await command(name,'results-input');
    assert.ok(connFor('spectator').results.length,'spectator received source results');
    // Explicit between-round leave/join requests a player seat; no in-place promotion.
    await rejoin('guest');
    await wait(async()=>{const o=await inspect('guest');return o.peer>=0&&!o.spectating;},'between-round player admission');
    await command('host','restart');
    for(const name of ['host','guest','spectator'])await command(name,'live',{},30000);
    assert.equal(latest('guest').spectating,false);assert.ok(latest('guest').actor>=0);
    await assertPublic('spectator');
    for(const connection of connections)assert.ok(connection.inputs.every(x=>x.spectating===false),'zero spectator input, neutral included, across all epochs');
    for(const name of ['guest','spectator','host'])await home(name);
    for(const name of ['host','guest','spectator']) {
      children.findLast(c=>c.name===name).allowExit=true;
      await command(name,'quit');
    }
    await wait(()=>children.every(c=>c.closed),'all normal native exits',15000);
    for(const child of children)assert.equal(child.child.exitCode,0,'native exit zero');
    passed=true;
    proof={...proof,twoNativePlayers:true,lateNativeSpectator:true,retry:plan.route.retry,expiredSeat:true,betweenRoundPlayerJoin:true,naturalResults:true,restart:true,home:true,zeroSpectatorInputs:true,geometryHash:expectedGeometry,sourceResultTimes:connections.flatMap(c=>c.results),screenshotsRequireInspection:true};
  } catch(error) {errorText=error.stack??String(error);writeFileSync(join(out,'failure.log'),errorText+'\n');}
  finally {
    clearTimeout(deadline);process.removeListener('SIGINT',interrupt);process.removeListener('SIGTERM',interrupt);
    const cleanup=[];
    for(const child of children)try {cleanup.push(await stopOwned(child));}catch(error){cleanup.push({pid:child.child.pid,error:String(error)});passed=false;errorText??=String(error);}
    for(const connection of connections)connection.socket.terminate();
    if(game)try {game.server.closeAllConnections();await bounded(game.close(),6000,'authority close deadline');}catch(error){passed=false;errorText??=String(error);}
    if(control) {control.closeAllConnections();await bounded(new Promise(ok=>control.close(ok)),6000,'control close deadline').catch(error=>{passed=false;errorText??=String(error);});}
    await new Promise(ok=>wire.end(ok));
    save('source-actions.json',receipts);
    save('teardown.json',{passed,children:cleanup,authorityClosed:!game?.server.listening,controlClosed:!control?.listening,connections:connections.map(c=>({peer:c.peer,spectating:c.spectating,inputs:c.inputs.length,spectatorInputs:c.inputs.filter(x=>x.spectating!==false).length,welcomes:c.welcomes,starts:c.starts,results:c.results}))});
    save('acceptance.json',{...proof,passed,cleanupComplete:cleanup.every(c=>!c.error&&c.live.length===0)&&!game?.server.listening&&!control?.listening});
    if(errorText)writeFileSync(join(out,'failure.log'),errorText+'\n');
  }
  console.log(`${passed?'SPECTATOR_CONNECTED_OK':'SPECTATOR_CONNECTED_FAILED'} ${out}`);
  if(!passed)throw Error(errorText??'cleanup failed');return out;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  const plan=options();if(plan.plan)console.log(JSON.stringify(plan,null,2));else await run(plan);
}
