import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {deflateSync} from 'node:zlib';
import {manifest} from './manifest.mjs';
import {validateManifest,plan,verifyFrames,root,outside,sha256} from './contracts.mjs';
import {createFixture} from './fixture.mjs';
import {runProcess} from './process.mjs';
import {main} from './pipeline.mjs';
import {assetInputs,assertAssetIdentity} from './assets.mjs';
import {installMenu,replaceMenuTransaction} from './install.mjs';
import {writeProof,readProof} from './proof.mjs';
import {closeReceipt} from './receipt.mjs';

function testPNG() {
  const crc=bytes=>{let value=0xffffffff;for(const byte of bytes){value^=byte;for(let bit=0;bit<8;bit++)value=(value>>>1)^((value&1)?0xedb88320:0);}return (value^0xffffffff)>>>0;};
  const chunk=(name,bytes)=>{const type=Buffer.from(name),size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(bytes.length);sum.writeUInt32BE(crc(Buffer.concat([type,bytes])));return Buffer.concat([size,type,bytes,sum]);};
  const header=Buffer.alloc(13);header.writeUInt32BE(1280,0);header.writeUInt32BE(720,4);header[8]=8;header[9]=2;
  return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',header),chunk('IDAT',deflateSync(Buffer.alloc((1280*3+1)*720))),chunk('IEND',Buffer.alloc(0))]);
}

test('75 second plan resolves all four pinned geometries, safe splines and licensed original stems',async()=>{
  const p=await plan(manifest);
  assert.equal(p.duration,75);assert.equal(p.frames,1800);
  assert.equal(p.shots.filter(s=>s.path).length,6);
  assert.ok(p.provenance.runtimeIndexSHA256.match(/^[a-f0-9]{64}$/));
  assert.ok(p.shots.filter(s=>s.path).every(s=>s.path.controls.length===4));
});
test('reject changed geometry, unaccepted assets, hidden gameplay HUD and in-repo evidence',async()=>{
  let m=structuredClone(manifest);m.chapters[0].geometryHash='0'.repeat(64);await assert.rejects(plan(m),/geometry revision/);
  m=structuredClone(manifest);m.optionalAssets.push({id:'not-shipped'});assert.throws(()=>validateManifest(m),/Optional map/);
  m=structuredClone(manifest);m.shots.find(s=>s.camera==='fp').hud=false;assert.throws(()=>validateManifest(m),/HUD/);
  assert.throws(()=>outside(join(root,'evidence')),/outside/);
});
test('capture and encode cannot execute without explicit slot grant',async()=>{
  await assert.rejects(main(['--capture','--output=/tmp/opencode/no-render']),/grant/);
  await assert.rejects(main(['--edit','--output=/tmp/opencode/no-render']),/grant/);
  await assert.rejects(main(['--menu-check','--output=/tmp/opencode/no-render']),/grant/);
  await assert.rejects(main(['--install-menu','--output=/tmp/opencode/no-render']),/grant/);
});
test('ordinary source inputs walk, jump and damage active production opposition',()=>{
  for(const id of ['root-run','ember-run','silt-fire']) {
    const shot=manifest.shots.find(s=>s.id===id),fixture=createFixture(shot,manifest.seed);
    let first,last,damage=0,vertical=0;
    for(let i=0;i<shot.seconds*manifest.fps;i++){
      const r=fixture.step(i,manifest.fps),actor=r.state.actors[0];first??=actor;last=actor;
      assert.equal(r.acks[0],i+1);assert.equal(r.input.seq,i+1);
      vertical=Math.max(vertical,Math.abs(actor.vy??0));
      damage+=r.events.filter(e=>e.type==='damage'&&e.source===0&&e.amount>0).length;
    }
    if(id==='silt-fire'){assert.ok(damage>0);assert.equal(fixture.header.setup.opposition,'production AI active');}
    else assert.ok(Math.hypot(last.x-first.x,last.z-first.z)>8,id);
    if(id==='ember-run')assert.ok(vertical>1,'jump has actual vertical velocity');
  }
});
test('cadence rejects missing/dropped frames instead of calling encoded FPS captured FPS',async()=>{
  const dir=await mkdtemp('/tmp/opencode/cinematic-cadence-');
  try {
    await mkdir(join(dir,'frames'));
    const png=testPNG(),captureToken='a'.repeat(64),records=Array.from({length:3},(_,i)=>JSON.stringify({frame:i,input:{seq:i+1},acks:{0:i+1},state:{time:(i+1)/3}}));
    await writeFile(join(dir,'invocation.json'),JSON.stringify({captureToken}));
    await writeFile(join(dir,'replay.jsonl'),JSON.stringify({shot:{id:'test',seconds:1}})+'\n'+records.join('\n')+'\n');
    for(let i=0;i<3;i++)await writeFile(join(dir,'frames',`${String(i).padStart(6,'0')}.png`),png);
    const rows=Array.from({length:3},(_,i)=>({frame:i,sourceFrame:i,sourceTime:(i+1)/3,sourceRecordSHA256:sha256(records[i]),pngSHA256:sha256(png),captureToken,
      wallUsec:100000+i*500000,saveFinishedUsec:200000+i*500000,saveError:0,width:1280,height:720,engineProcessFrames:1}));
    await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    const r=await verifyFrames(dir,{id:'test',seconds:1},3);assert.equal(r.observedWallFPS,2);assert.equal(r.encodedFPS,3);assert.equal(r.realtimeCapture,false);
    await assert.rejects(verifyFrames(dir,{id:'test',seconds:1},3,'b'.repeat(64)),/input identity/);
    rows[2].sourceFrame=4;await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    await assert.rejects(verifyFrames(dir,{id:'test',seconds:1},3),/cadence/);
    rows[2].sourceFrame=2;rows[2].captureToken='b'.repeat(64);await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    await assert.rejects(verifyFrames(dir,{id:'test',seconds:1},3),/nonce/);
    rows[2].captureToken=captureToken;rows[2].sourceTime=5;await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    await assert.rejects(verifyFrames(dir,{id:'test',seconds:1},3),/clock/);
  }finally{await rm(dir,{recursive:true});}
});

test('final production assets cannot silently fall back when units are pending or identity changes',()=>{
  const current=assetInputs();assert.equal(current.registeredWorlds.length>=10,true);
  assert.throws(()=>assertAssetIdentity({sha256:'a'},{sha256:'a',pending:['robots']}),/missing\/pending/);
  assert.throws(()=>assertAssetIdentity({sha256:'a'},{sha256:'b',pending:[]}),/changed/);
  assert.doesNotThrow(()=>assertAssetIdentity({sha256:'a'},{sha256:'a',pending:[]}));
});
test('missing native outputs refuse installation and final receipts cannot re-stamp source plans',async()=>{
  const dir=await mkdtemp('/tmp/opencode/cinematic-install-missing-'),path=join(root,'godot/ui/attract/demo.json'),before=await readFile(path);
  try {
    await assert.rejects(installMenu(dir,{shots:[{id:'missing'}]},()=>assert.fail('must not reach native')),/ENOENT/);
    assert.deepEqual(await readFile(path),before);
    await assert.rejects(closeReceipt(dir,{}),/execution-time final ledger/);
  }finally{await rm(dir,{recursive:true});}
});
test('menu transaction preserves previous bytes and rolls back an actual check failure',async()=>{
  const dir=await mkdtemp('/tmp/opencode/cinematic-install-');
  try {
    const path=join(dir,'demo.json'),candidate=join(dir,'candidate.json'),before=Buffer.from('preserved-v2'),next=Buffer.from('new-candidate');
    await writeFile(path,before);await writeFile(candidate,next);
    await assert.rejects(replaceMenuTransaction({out:dir,path,candidate,expectedBefore:sha256(before),check:async()=>{assert.deepEqual(await readFile(path),next);throw Error('native teardown failed');}}),/teardown/);
    assert.deepEqual(await readFile(path),before);assert.deepEqual(await readFile(join(dir,'installation/preserved-before.json')),before);
    await assert.rejects(replaceMenuTransaction({out:dir,path,candidate,expectedBefore:'0'.repeat(64),check:async()=>{}}),/changed/);
  }finally{await rm(dir,{recursive:true});}
});
test('execution artifact mutation and source-only receipts are rejected',async()=>{
  const dir=await mkdtemp('/tmp/opencode/cinematic-proof-');
  try {
    const file=join(dir,'native.log'),receipt=join(dir,'receipt.json');await writeFile(file,'native execution');
    await writeProof(receipt,{kind:'native-shot',executed:true,status:'passed'},{log:file});
    await readProof(receipt,'native-shot');await writeFile(file,'changed');
    await assert.rejects(readProof(receipt,'native-shot'),/identity/);
    await writeFile(receipt,JSON.stringify({kind:'native-shot',executed:false,status:'passed'}));
    await assert.rejects(readProof(receipt,'native-shot'),/actual executed/);
  }finally{await rm(dir,{recursive:true});}
});
test('owned child timeout is awaited and worker environment is serial',async()=>{
  const dir=await mkdtemp('/tmp/opencode/cinematic-process-');
  try {
    const log=join(dir,'env.log');await runProcess(process.execPath,['-e','console.log(process.env.LP_NUM_THREADS)'],{cwd:root,log,timeoutMs:2000});
    assert.equal((await readFile(log,'utf8')).trim(),'1');
    await assert.rejects(runProcess(process.execPath,['-e','setInterval(()=>{},100)'],{cwd:root,log:join(dir,'timeout.log'),timeoutMs:100}),/deadline/);
  }finally{await rm(dir,{recursive:true});}
});
