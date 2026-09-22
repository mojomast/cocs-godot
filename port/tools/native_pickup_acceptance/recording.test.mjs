import test from 'node:test';
import assert from 'node:assert/strict';
import {gzipSync,gunzipSync} from 'node:zlib';
import {readFileSync} from 'node:fs';
import {decodeRecordedFrame,assertGodotSuccess} from './recording.mjs';

test('welcome credentials are null before retention and absent after compressed round-trip',()=>{
  const raw=Buffer.from(JSON.stringify({type:'welcome',peerId:2,roomId:'test-room',
    token:'synthetic-room-credential',progressToken:'synthetic-progress-credential',
    profile:{ownerToken:'synthetic-progress-credential',level:1},v:3}));
  const original=Buffer.from(raw),retained=[{direction:'server',frame:decodeRecordedFrame(raw)}];
  assert.equal(retained[0].frame.token,null);assert.equal(retained[0].frame.progressToken,null);
  assert.equal(retained[0].frame.profile.ownerToken,null);
  assert.deepEqual(raw,original,'Actual wire transport bytes must remain unchanged');
  const archived=gunzipSync(gzipSync(JSON.stringify(retained))).toString();
  for(const secret of ['synthetic-room-credential','synthetic-progress-credential'])assert.ok(!archived.includes(secret));
  assert.deepEqual(JSON.parse(archived)[0].frame,{type:'welcome',peerId:2,roomId:'test-room',token:null,progressToken:null,profile:{ownerToken:null,level:1},v:3});
});

test('redaction preserves gameplay and absent/null welcome fields',()=>{
  for(const frame of [{type:'welcome',token:null},{type:'welcome',peerId:2},
    {type:'snapshot',seq:386,state:{pickups:[{id:0,wait:15}],actors:[{id:1,ammo:[0,6]}]}}]) {
    assert.deepEqual(decodeRecordedFrame(JSON.stringify(frame)),frame);
  }
});

test('every recorder decode uses the redacting boundary, and original transport is forwarded',()=>{
  const source=readFileSync(new URL('./run.mjs',import.meta.url),'utf8');
  assert.equal((source.match(/decodeRecordedFrame\((?:raw|data)\)/g)??[]).length,3);
  assert.ok(!/JSON\.parse\((?:raw|data)\)/.test(source));
  assert.ok(source.includes('return send.call(this,data,...args)'));
  assert.ok(source.includes("assertGodotSuccess(native,'native')"));
  assert.ok(source.includes("assertGodotSuccess(importer,'import')"));
});

test('positive exit cannot mask late output cap, deadline, signal, or Godot errors',()=>{
  const ok={failure:null,exitCode:0,signalCode:null,text:'Godot Engine\n',errors:'WARNING: VSync unavailable\n'};
  assert.doesNotThrow(()=>assertGodotSuccess(ok,'native'));
  for(const failure of ['stdout cap','stderr cap','owned child deadline']) {
    assert.throws(()=>assertGodotSuccess({...ok,failure},'native'),/child failure recorded/);
  }
  assert.throws(()=>assertGodotSuccess({...ok,exitCode:2},'native'),/nonzero exit/);
  assert.throws(()=>assertGodotSuccess({...ok,signalCode:'SIGKILL'},'native'),/terminated by signal/);
  for(const stream of ['text','errors'])for(const message of ['SCRIPT ERROR: bad script','ERROR: failed device']) {
    assert.throws(()=>assertGodotSuccess({...ok,[stream]:`header\n  ${message}\n`},'native'),/Godot error diagnostic/);
  }
});
