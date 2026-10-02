import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {manifest} from './manifest.mjs';
import {validateManifest,plan,verifyFrames,root,outside} from './contracts.mjs';
import {createFixture} from './fixture.mjs';
import {runProcess} from './process.mjs';
import {main} from './pipeline.mjs';

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
    for(let i=0;i<3;i++)await writeFile(join(dir,'frames',`${String(i).padStart(6,'0')}.png`),'test');
    const rows=Array.from({length:3},(_,i)=>({frame:i,sourceFrame:i,wallUsec:100000+i*500000,saveError:0,width:1280,height:720,engineProcessFrames:1}));
    await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    const r=await verifyFrames(dir,{id:'test',seconds:1},3);assert.equal(r.observedWallFPS,2);assert.equal(r.encodedFPS,3);assert.equal(r.realtimeCapture,false);
    rows[2].sourceFrame=4;await writeFile(join(dir,'cadence.jsonl'),rows.map(JSON.stringify).join('\n'));
    await assert.rejects(verifyFrames(dir,{id:'test',seconds:1},3),/cadence/);
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
