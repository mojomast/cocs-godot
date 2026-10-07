// Rendered three-cycle Home/combat/LATTICE/sports journey using actual scenes,
// source authorities and the real dev supervisor. Only the UI actions are scripted.
// Run under tools/godot-dev/xvfb_run.py with pinned GODOT_BIN and explicit derivative.
import assert from 'node:assert/strict';
import {spawn, execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdtempSync, writeFileSync, chmodSync, readFileSync, mkdirSync, statSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createConnection} from 'node:net';
import {DEFAULT_ITINERARY, journeyOptions} from './journey_options.mjs';
import {recordedDerivative} from './recorded_derivative.mjs';
import {normalizeConfig} from '../../game/config.mjs';
const args=process.argv.slice(2);
assert.ok(args.every(arg=>arg==='--capture'||arg==='--player-flow'||arg.startsWith('--itinerary=')), 'Unknown journey option');
const playerFlow=args.includes('--player-flow');
const selected=args.filter(arg=>arg.startsWith('--itinerary='));
assert.ok(selected.length<=1, 'Select one itinerary');
assert.ok(!playerFlow||selected.length===0, 'Player flow owns its lobby itinerary');
const itineraryPath=selected[0]?.slice('--itinerary='.length);
if(itineraryPath)assert.ok(statSync(itineraryPath).size<=65536, 'Itinerary exceeds 64 KiB');
const registry=JSON.parse(readFileSync('godot/ui/routes.json'));
const itinerary=journeyOptions(playerFlow?[{route:'lobby',options:{}}]:itineraryPath?JSON.parse(readFileSync(itineraryPath)):DEFAULT_ITINERARY,registry);
const cycles=playerFlow?1:3;
const expectedSessions=itinerary.length*cycles;
const expectedDecks=itinerary.filter(entry=>entry.route==='lattice-world').length*cycles;
const expectedCareerHome=expectedSessions+1;
const expectsEquipment=playerFlow||itinerary.some(entry=>entry.route==='combat');
const real = process.env.GODOT_BIN;
assert.ok(real, 'Set pinned GODOT_BIN');
assert.ok(process.env.DISPLAY, 'Run with a private Xvfb display');
const sourceLock=JSON.parse(readFileSync('port/contracts/source-lock.json'));
const derivative=recordedDerivative();
const hash=path=>createHash('sha256').update(readFileSync(path)).digest('hex');
mkdirSync('.port-runtime/product-journeys', {recursive:true});
const output = mkdtempSync(resolve('.port-runtime/product-journeys/attempt-'));
const state = join(output, 'state.json');
const lobbyConfig=normalizeConfig({mode:'deathmatch',botCount:2,timeLimit:60,fragLimit:100});
writeFileSync(state, JSON.stringify({visits:0,expected_volume:100,itinerary,cycles,player_flow:playerFlow,
  expected_lobby_config:{mode:lobbyConfig.mode,botCount:lobbyConfig.botCount,timeLimit:lobbyConfig.timeLimit,fragLimit:lobbyConfig.fragLimit},
  career_home_checks:0,career_live_checks:0}));
const wrapper = join(output, 'godot-wrapper.mjs');
writeFileSync(wrapper, `#!${process.execPath}
import {spawn} from 'node:child_process';
let args=process.argv.slice(2),env={...process.env};
if(!args.includes('--version')){
 const scene=args.find(a=>a.startsWith('res://')&&a.endsWith('.tscn'));
 if(!scene)throw Error('Journey expected a scene launch');
 env.COCS_JOURNEY_SCENE=scene;
 args=args.filter(a=>a!==scene);
 const split=args.indexOf('--');
 args.splice(split<0?args.length:split,0,'--audio-driver','Dummy','--script','res://tests/product_journey/driver.gd');
}
const child=spawn(process.env.COCS_JOURNEY_GODOT,args,{env,stdio:'inherit'});
for(const signal of ['SIGINT','SIGTERM'])process.on(signal,()=>child.kill(signal));
child.once('error',e=>{console.error(e);process.exitCode=1;});
child.once('exit',(code,signal)=>{process.exitCode=code??(signal?1:0);});
`);
chmodSync(wrapper, 0o755);
const env = {...process.env, GODOT_BIN:wrapper, COCS_JOURNEY_GODOT:real, COCS_JOURNEY_STATE:state,
  COCS_SETTINGS_PATH:join(output,'local_settings.json'), COCS_CAREER_ROOT:join(output,'career'), COCS_JOURNEY_CAPTURE:process.argv.includes('--capture')?'1':'0', PORT:'0'};
const child = spawn(process.execPath,['tools/godot-dev/launch.mjs','--experience=menu'], {env,detached:true,stdio:['ignore','pipe','pipe']});
let text='';
for (const stream of [child.stdout,child.stderr])stream.on('data',chunk=>{text+=chunk;});
const timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{/* already exited */}},Math.max(240000,expectedSessions*30000));
let code;
try {code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});}
finally {clearTimeout(timer);writeFileSync(join(output,'console.log'),text);}
const matches=text.split('\n').filter(line=>line.startsWith('PRODUCT_JOURNEY_MATCH ')).map(line=>JSON.parse(line.slice('PRODUCT_JOURNEY_MATCH '.length)));
const captures=text.split('\n').filter(line=>line.startsWith('PRODUCT_JOURNEY_CAPTURE ')).map(line=>JSON.parse(line.slice('PRODUCT_JOURNEY_CAPTURE '.length)));
const decks=text.split('\n').filter(line=>line.startsWith('PRODUCT_JOURNEY_DECK ')).map(line=>JSON.parse(line.slice('PRODUCT_JOURNEY_DECK '.length)));
const careers=text.split('\n').filter(line=>line.startsWith('PRODUCT_JOURNEY_CAREER ')).map(line=>JSON.parse(line.slice('PRODUCT_JOURNEY_CAREER '.length)));
const careerHomes=careers.filter(row=>row.route==='home');
const careerLives=careers.filter(row=>row.route!=='home');
const ports=[...text.matchAll(/Owned local server ready at ws:\/\/127\.0\.0\.1:(\d+)/g)].map(match=>Number(match[1]));
const closed=[];
for(const port of new Set(ports))closed.push(await new Promise(resolve=>{
  const socket=createConnection({host:'127.0.0.1',port});
  socket.once('error',()=>{socket.destroy();resolve(true);});
  socket.once('connect',()=>{socket.destroy();resolve(false);});
  socket.setTimeout(1000,()=>{socket.destroy();resolve(false);});
}));
const finalState=JSON.parse(readFileSync(state));
const careerPassed=careerHomes.length===expectedCareerHome&&careerLives.length===expectedSessions&&
  careerHomes.every(row=>row.has_profile===false&&row.bounds===true)&&
  careerLives.every(row=>row.bounds===true&&(!['combat','lattice-world'].includes(row.route)||row.has_profile===true))&&
  finalState.career_home_checks===expectedCareerHome&&finalState.career_live_checks===expectedSessions;
const equipmentPassed=!expectsEquipment||finalState.career_equipment_confirmed===true;
const flowPassed=!playerFlow||(finalState.player_flow_complete===true&&finalState.player_flow_checks?.length>=15);
const passed=code===0&&!text.includes('ERROR:')&&matches.length===expectedSessions&&decks.length===expectedDecks&&careerPassed&&equipmentPassed&&flowPassed&&ports.length===expectedSessions&&closed.every(Boolean)&&text.includes('PRODUCT_JOURNEY_COMPLETE ');
const summary={scope:'source-driven scripted UI lifecycle; not natural rounds/human acceptance',passed,exit_code:code,
  port_commit:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),source_commit:sourceLock.source_commit,
  source_derivative_commit:derivative?.commit??null,
  input_sha256:Object.fromEntries(['godot/tests/product_journey/driver.gd','godot/ui/local_settings.gd','godot/ui/main_menu.gd','godot/career/service.gd','godot/career/catalog.json','godot/lattice/world_commands.gd',
    'tools/godot-dev/product_journey.mjs','tools/godot-dev/launch.mjs'].map(path=>[path,hash(path)])),
  itinerary,cycles,player_flow:playerFlow,source_sessions:matches,deck_checks:decks,career_checks:careers,
  career_counts:{home:careerHomes.length,live:careerLives.length,expected_home:expectedCareerHome,expected_live:expectedSessions,passed:careerPassed},
  captures,owned_ports:ports,all_owned_ports_closed:closed.every(Boolean),state:finalState,output};
for(const capture of captures)capture.sha256=hash(capture.path);
writeFileSync(join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
console.log('PRODUCT_JOURNEY '+JSON.stringify(summary));
if(!passed){console.error(text);process.exitCode=1;}
