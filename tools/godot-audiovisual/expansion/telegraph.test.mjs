import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {source,root,cues,themes,envelope,render,generate} from './telegraph_pack.mjs';
const fixtures=JSON.parse(fs.readFileSync(path.join(root,'godot/tests/audio_expansion/policy_cases.json')));
test('generated source vectors and all 160 unnormalized PCM files reproduce exactly',()=>{
 const result=generate(true);
 assert.equal(result.files,160);assert.ok(result.peak<.1);assert.ok(result.bytes<3_200_000);
 assert.equal(Object.keys(cues).length,8);
});
test('actual source _beat schedules fixture frequencies, onset, gain, duration and shimmer',()=>{
 const body=source.slice(source.indexOf('  _beat(cue,pan,'),source.indexOf('  // Mounted chaingun:'));
 const beat=vm.runInNewContext(`({${body.trim()}})`);
 for(const theme of Object.values(themes)) for(const cue of Object.values(cues)) {
  const tones=[],noise=[];let voices=0;
  beat.theme=theme;beat._tone=(t,o,n,p)=>tones.push({t,...p});beat._noise=(t,o,n,p)=>noise.push({t,...p});
  beat._play=(duration,pan,build,opts)=>{voices++;assert.equal(opts.send,.22);build(0,null,[]);};
  beat._beat(cue,0,1,.22);
  assert.equal(voices,1);assert.equal(tones.length,cue.notes.length);
  tones.forEach((tone,i)=>{assert.equal(tone.t,i*cue.step);assert.equal(tone.freq,theme.root*2**(cue.notes[i]/12));assert.equal(tone.end,tone.freq*1.42);assert.equal(tone.duration,cue.length);assert.equal(tone.gain,cue.gain);assert.equal(tone.type,'triangle');});
  assert.equal(noise.length,Number(cue.shimmer));
  if(cue.shimmer) assert.deepEqual(JSON.parse(JSON.stringify(noise[0])),{t:.01,duration:.24,gain:.05,type:'highpass',freq:3000,sweep:1400,q:.6,attack:.015});
 }
});
test('attack/exponential release oracle and finite unclipped distinct sample fixtures',()=>{
 assert.equal(envelope(0,.2,.07),.0001);
 assert.ok(Math.abs(envelope(.003,.2,.07)-.07)<1e-12);
 assert.ok(Math.abs(envelope(.1015,.2,.07)-Math.sqrt(.07*.0001))<1e-12);
 assert.equal(envelope(.24,.2,.07),0);
 const signatures=new Set();
 for(const cue of Object.values(cues)) {
  const pcm=render(cue,54);assert.ok(pcm.every(Number.isFinite));
  assert.ok(pcm.slice(-100).every(x=>x===0));
  signatures.add(JSON.stringify([...pcm.slice(2000,2010)]));
 }
 assert.equal(signatures.size,8);
});
test('actual source falloff matches shared native distance fixtures',()=>{
 const method=source.match(/_falloff\(pos,player,max=36\)\{[^\n]+\}/)[0];
 const oracle=vm.runInNewContext(`({${method}})`);
 for(const [x,z,gain] of fixtures.distance) assert.equal(oracle._falloff({x,z},{x:0,z:0},30),gain);
});
test('bounded priority policy reference: no queue, guarded attacks, steal hysteresis',()=>{
 // Executed native counterpart reads these exact fixtures after engine grant.
 function slot(c) {
  const free=c.active.indexOf(false);if(free>=0)return free;
  let weak=-1;
  for(let i=0;i<c.active.length;i++) if(c.now-c.starts[i]>=.08&&(weak<0||c.weights[i]<c.weights[weak]))weak=i;
  return weak>=0&&c.weight>c.weights[weak]+.15?weak:-1;
 }
 for(const c of fixtures.slots) assert.equal(slot(c),c.expected);
});
