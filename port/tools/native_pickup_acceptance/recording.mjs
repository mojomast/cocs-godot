import assert from 'node:assert/strict';

// Apply at JSON decode, before any recorder or host-handshake retention.
// Return a copy so transport bytes and the peer's real welcome remain untouched.
export function decodeRecordedFrame(raw) {
  const frame=JSON.parse(raw);
  if(frame.type==='welcome') {
    for(const key of ['token','progressToken']) {
      if(Object.hasOwn(frame,key))frame[key]=null;
    }
    // Welcome profile repeats the progression credential under this alias.
    if(frame.profile&&Object.hasOwn(frame.profile,'ownerToken'))frame.profile.ownerToken=null;
  }
  return frame;
}

export function assertGodotSuccess(child, label) {
  assert.equal(child.failure,null,`${label}: child failure recorded`);
  assert.equal(child.exitCode,0,`${label}: nonzero exit`);
  assert.equal(child.signalCode,null,`${label}: terminated by signal`);
  // Inspect both streams; do not include their potentially sensitive contents in errors.
  const errors=/^\s*(?:SCRIPT ERROR|ERROR):/m;
  assert.ok(!errors.test(child.text)&&!errors.test(child.errors),`${label}: Godot error diagnostic`);
}
