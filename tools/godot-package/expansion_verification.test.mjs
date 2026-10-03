import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {mkdtemp,mkdir,writeFile,rm} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {coverage,sourceModeCoverage,gracefulAuthority,waitExit,forceStop,diagnosticRows} from './verify_expansion.mjs';
import {EXPERIENCES} from './options.mjs';
import {Room as SourceRoom} from '../../server/room.mjs';
import {WORLDS,readWorld} from '../../port/multiplayer-worlds/catalog.mjs';
import {Room} from '../../port/multiplayer-worlds/derived/room.mjs';
import {createAuthority} from '../../port/native-horde/authority.mjs';
import {readBlackwater} from '../../port/native-horde/blackwater-schema.mjs';

const files=Object.keys(WORLDS).map(id=>`godot/multiplayer_worlds/generated/${id}.json`);
const manifest={server_closure:{worldDataFiles:files,hordeDataFiles:['godot/horde_maps/generated/blackwater-reclamation.json']}};
test('single-case diagnostics select only a registered pair; default retains full coverage',()=>{
  const rows=coverage(manifest,WORLDS);
  assert.equal(diagnosticRows(rows),rows);
  assert.deepEqual(diagnosticRows(rows,'helix-conservatory/deathmatch'),[{map:'helix-conservatory',mode:'deathmatch'}]);
  for(const bad of ['', 'unknown/deathmatch','helix-conservatory/payload','../deathmatch'])assert.throws(()=>diagnosticRows(rows,bad));
});
test('the extracted manifest retains 43 original pairs, 11 Helix/Foundry, six Parallax and twelve public Vesper/Abyssal pairs',()=>{
  const pairs=coverage(manifest,WORLDS);
  const original=['switchyard-ward','rainmarket-exchange','breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago'];
  const additions={
    'helix-conservatory':['deathmatch','teamdeathmatch','ctf','domination','koth'],
    'gravemill-foundry':['deathmatch','teamdeathmatch','domination','assault','payload','combined-arms'],
    'parallax-observatory':['deathmatch','teamdeathmatch','ctf','koth','uplink','holdout'],
    'vesper-viaduct':['deathmatch','teamdeathmatch','ctf','domination','koth','uplink'],
    'abyssal-pressureworks':['deathmatch','teamdeathmatch','ctf','koth','domination','holdout'],
  };
  assert.deepEqual([...new Set(pairs.map(row=>row.map))].sort(),[...original,...Object.keys(additions)].sort());
  assert.equal(pairs.filter(row=>original.includes(row.map)).length,43);
  for(const [map,modes] of Object.entries(additions))assert.deepEqual(pairs.filter(row=>row.map===map).map(row=>row.mode).sort(),[...modes].sort());
  assert.equal(new Set(pairs.map(row=>`${row.map}:${row.mode}`)).size,72);
  assert.equal(pairs.length,72);
  for(const mode of ['puma-race','puma-soccer','cocs','cocs-coop','combined-arms','payload'])assert.ok(pairs.some(row=>row.mode===mode));
});
test('missing manifest family or packaged catalog option fails instead of silently skipping expansion',()=>{
  assert.throws(()=>coverage({server_closure:{hordeDataFiles:manifest.server_closure.hordeDataFiles}},WORLDS),/worldDataFiles/);
  assert.throws(()=>coverage({server_closure:{...manifest.server_closure,worldDataFiles:files.slice(1)}},WORLDS));
  assert.throws(()=>coverage({server_closure:{...manifest.server_closure,hordeDataFiles:[]}},WORLDS),/Blackwater/);
  assert.throws(()=>coverage(manifest,Object.fromEntries(Object.entries(WORLDS).slice(1))));
});
test('all eight packaged source-mode routes yield the objective/loadout shapes consumed by native probes',()=>{
  const pairs=sourceModeCoverage(EXPERIENCES);
  assert.equal(pairs.length,8);
  assert.throws(()=>sourceModeCoverage({}));
  const broken=structuredClone(EXPERIENCES);broken['mode-expansion'].maps['meridian-exchange'].pop();
  assert.throws(()=>sourceModeCoverage(broken));
  for(const {map,mode} of pairs){
    const room=new SourceRoom();room.join(1,'Host');room.host(1,{mode,botCount:2,timeLimit:120},map);
    assert.equal(room.start(1),true);
    const state=room.match.snapshot();assert.equal(state.mapId,map);assert.equal(state.config.mode,mode);
    if(mode==='arsenal')assert.deepEqual(state.actors[0].ammo,Array(10).fill('∞'));
    if(mode==='juggernaut'){assert.ok(state.objectives.juggernautId>=0);assert.ok(state.objectives.points);}
    if(mode==='team-elimination')assert.equal(Object.keys(state.objectives.lives).length,2);
    if(mode==='vip-escort'){assert.ok(state.objectives.vipId>=0);assert.ok(state.objectives.extract);}
  }
});
test('external probe loads production scenes/PCK resources and never substitutes product authority',()=>{
  const probe=readFileSync(new URL('../../godot/tests/package_expansion.gd',import.meta.url),'utf8');
  for(const scene of ['multiplayer_worlds/demo.tscn','multiplayer_worlds/sports_demo.tscn','multiplayer_worlds/lattice_demo.tscn','horde_maps/blackwater_demo.tscn'])assert.ok(probe.includes(scene));
  assert.match(probe,/client\.snapshot\.connect/);
  assert.match(probe,/start_hash != expected_hash/);
  assert.match(probe,/ResourceLoader\.exists\(art\)/);
  const verifier=readFileSync(new URL('./verify_expansion.mjs',import.meta.url),'utf8');
  assert.match(verifier,/runtime\/port\/multiplayer-worlds\/catalog\.mjs/);
  assert.match(verifier,/--main-pack/);
  assert.match(verifier,/join\(root,'cocs\.pck'\)/);
  assert.doesNotMatch(verifier,/\b--smoke\b|\b--path\b/);
});

test('real Node child accepts cross-platform stdin shutdown; broken close times out and is forcibly reaped', {timeout:9000},async()=>{
  const root=await mkdtemp(join(tmpdir(),'expansion authority lifecycle '));
  const entry=join(root,'runtime/port/multiplayer-worlds/derived/game-server.mjs');
  await mkdir(dirname(entry),{recursive:true});
  // Packaged-shaped dynamic entry, no engine: real HTTP listener and close().
  const fixture=`import http from 'node:http'; export function createGameServer(){const server=http.createServer((req,res)=>res.end(JSON.stringify({port:server.address().port})));return {server,close:()=>new Promise(ok=>server.close(ok))};}`;
  await writeFile(entry,fixture);
  const spawnOwned=async()=>{
    const child=spawn(process.execPath,[fileURLToPath(new URL('./verify_expansion.mjs',import.meta.url)),'--authority',entry],{cwd:root,stdio:['pipe','pipe','pipe']});
    let text='';child.stdout.on('data',part=>{text+=String(part)});child.stderr.on('data',part=>{text+=String(part)});
    const owned={child,read:()=>text};
    for(let i=0;i<150 && !text.includes('EXPANSION_AUTHORITY_READY ');i++)await new Promise(ok=>setTimeout(ok,10));
    assert.match(text,/EXPANSION_AUTHORITY_READY /);
    return owned;
  };
  let owned;
  try{
    owned=await spawnOwned();
    const port=JSON.parse(owned.read().split('EXPANSION_AUTHORITY_READY ')[1].split('\n')[0]).port;
    assert.equal((await (await fetch(`http://127.0.0.1:${port}`)).json()).port,port);
    await gracefulAuthority(owned,1500);
    assert.equal(owned.child.exitCode,0);
    assert.match(owned.read(),/EXPANSION_AUTHORITY_CLOSED/);
    await writeFile(entry,fixture.replace('new Promise(ok=>server.close(ok))','new Promise(()=>{})'));
    owned=await spawnOwned();
    await assert.rejects(gracefulAuthority(owned,100),/acknowledgment timed out/);
    await forceStop(owned.child);
    const result=await waitExit(owned.child,2000);
    assert.ok(result.signal!==null || result.code!==0);
    assert.doesNotMatch(owned.read(),/EXPANSION_AUTHORITY_CLOSED/);
  }finally{
    if(owned && owned.child.exitCode===null && owned.child.signalCode===null){owned.child.kill('SIGKILL');await waitExit(owned.child,2000);}
    await rm(root,{recursive:true,force:true});
  }
});

test('real world snapshots have the shapes consumed by the external probe',()=>{
  for(const [map,mode,field] of [
    ['thermal-divide','ctf','flags'],['rainmarket-exchange','payload','payload'],
    ['breakwater-exchange','assault','zones'],['sirocco-circuit','puma-race','race'],
    ['copper-bowl','puma-soccer','race'],['tern-archipelago','cocs','cocs']]){
    const room=new Room();room.join(1,'Host');room.join(2,'Guest');
    room.host(1,{mode,botCount:2,timeLimit:120,fragLimit:3},map);
    assert.equal(room.start(1),true);
    const start=room.drain().findLast(item=>item.msg.type==='start').msg;
    assert.equal(start.geometryHash,readWorld(map).geometryHash);
    const state=room.match.snapshot();
    assert.equal(state.mapId,map);
    if(field==='flags')assert.equal(state.objectives.flags.length,2);
    if(field==='payload')assert.ok(state.objectives.payload.total>60);
    if(field==='zones')assert.ok(state.objectives.zones.length>0);
    if(field==='race')assert.ok(state.race.phase);
    if(field==='cocs')assert.ok(state.cocs);
  }
});

test('actual Blackwater wire start contract carries the source geometry hash', {timeout:8000},async()=>{
  const authority=createAuthority();
  await new Promise(ok=>authority.server.listen(0,'127.0.0.1',ok));
  const socket=new WebSocket(`ws://127.0.0.1:${authority.server.address().port}`);
  const frames=[];socket.on('message',b=>frames.push(JSON.parse(String(b))));
  const until=async predicate=>{for(let i=0;i<300;i++){const item=frames.find(predicate);if(item)return item;await new Promise(ok=>setTimeout(ok,10));}throw Error('Blackwater wire deadline');};
  try{
    await once(socket,'open');
    socket.send(JSON.stringify({type:'create',v:3}));await until(f=>f.type==='lobby');
    socket.send(JSON.stringify({type:'host',mapId:'blackwater-reclamation',config:{mode:'horde',fragLimit:10}}));
    await until(f=>f.type==='lobby'&&f.mapId==='blackwater-reclamation'&&f.config);
    socket.send(JSON.stringify({type:'start'}));
    const start=await until(f=>f.type==='start');
    const envelope=readBlackwater();
    assert.equal(start.hordeMapContract.geometryHash,envelope.geometryHash);
    assert.equal(start.hordeMapContract.planHash,envelope.planHash);
    const snap=await until(f=>f.type==='snapshot'&&f.state?.blackwater?.version===1);
    assert.equal(snap.hordeMapContract.geometryHash,start.hordeMapContract.geometryHash);
    assert.equal(snap.state.mapId,'blackwater-reclamation');
  }finally{socket.close();await once(socket,'close');await authority.close();}
});
