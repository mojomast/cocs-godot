// Rendered three-cycle Home/combat/LATTICE/sports journey using actual scenes,
// source authorities and the real dev supervisor. Only the UI actions are scripted.
// Run under tools/godot-dev/xvfb_run.py with pinned GODOT_BIN and explicit derivative.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {mkdtempSync, writeFileSync, chmodSync, readFileSync, mkdirSync} from 'node:fs';
import {resolve, join} from 'node:path';
import {createConnection} from 'node:net';
const real = process.env.GODOT_BIN;
assert.ok(real, 'Set pinned GODOT_BIN');
assert.ok(process.env.DISPLAY, 'Run with a private Xvfb display');
mkdirSync('.port-runtime/product-journeys', {recursive:true});
const output = mkdtempSync(resolve('.port-runtime/product-journeys/attempt-'));
const state = join(output, 'state.json');
writeFileSync(state, JSON.stringify({visits:0,expected_volume:100}));
const wrapper = join(output, 'godot-wrapper');
writeFileSync(wrapper, `#!${process.execPath}
const {spawn}=require('node:child_process');
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
  COCS_SETTINGS_PATH:join(output,'local_settings.json'), PORT:'0'};
const child = spawn(process.execPath,['tools/godot-dev/launch.mjs','--experience=menu'], {env,detached:true,stdio:['ignore','pipe','pipe']});
let text='';
for (const stream of [child.stdout,child.stderr])stream.on('data',chunk=>{text+=chunk;});
const timer=setTimeout(()=>{try{process.kill(-child.pid,'SIGKILL');}catch{/* already exited */}},240000);
let code;
try {code=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});}
finally {clearTimeout(timer);writeFileSync(join(output,'console.log'),text);}
const matches=text.split('\n').filter(line=>line.startsWith('PRODUCT_JOURNEY_MATCH ')).map(line=>JSON.parse(line.slice('PRODUCT_JOURNEY_MATCH '.length)));
const ports=[...text.matchAll(/Owned local server ready at ws:\/\/127\.0\.0\.1:(\d+)/g)].map(match=>Number(match[1]));
const closed=[];
for(const port of new Set(ports))closed.push(await new Promise(resolve=>{
  const socket=createConnection({host:'127.0.0.1',port});
  socket.once('error',()=>{socket.destroy();resolve(true);});
  socket.once('connect',()=>{socket.destroy();resolve(false);});
  socket.setTimeout(1000,()=>{socket.destroy();resolve(false);});
}));
const passed=code===0&&!text.includes('ERROR:')&&matches.length===9&&ports.length===9&&closed.every(Boolean)&&text.includes('PRODUCT_JOURNEY_COMPLETE ');
const summary={scope:'source-driven scripted UI lifecycle; not natural rounds/human acceptance',passed,exit_code:code,
  source_sessions:matches,owned_ports:ports,all_owned_ports_closed:closed.every(Boolean),state:JSON.parse(readFileSync(state)),output};
writeFileSync(join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
console.log('PRODUCT_JOURNEY '+JSON.stringify(summary));
if(!passed){console.error(text);process.exitCode=1;}
