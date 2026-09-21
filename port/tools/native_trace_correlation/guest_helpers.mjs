// Vendored unchanged helpers from port/tools/guest_session_integration/lib.mjs
// in mojomast/cocs commit 389561510ac7c2223a22897c963f3440304ec928.
import assert from 'node:assert/strict';
export const sleep = ms => new Promise(r => setTimeout(r, ms));
export async function until(predicate, ms, label) {
 const end = performance.now() + ms;
 while (performance.now() < end) { if (predicate()) return; await sleep(25); }
 throw Error(`Deadline: ${label} (${ms}ms)`);
}
export function parseSample(line) {
 if (!line.startsWith('GUEST_SAMPLE ')) return null;
 const v = JSON.parse(line.slice(13));
 for (const key of ['seconds','phase','phase_seconds','snapshots','ack','actor','starts']) assert.ok(Number.isFinite(v[key]), `invalid ${key}`);
 assert.equal(typeof v.pose,'boolean'); assert.equal(typeof v.error,'string');
 return v;
}
export function assertRole(counts) {
 assert.equal(counts.join,1);
 for (const type of Object.keys(counts)) assert.ok(['join','input'].includes(type),`guest sent forbidden/unexpected ${type}`);
}
export function assertPositive(samples, wire, startAt) {
 const waiting = samples.filter(s => s.phase === 11 && s.seconds < startAt);
 assert.ok(waiting.length >= 3, 'at least three waiting observations');
 assert.ok(waiting.at(-1).seconds - waiting[0].seconds >= 1, 'sustained waiting');
 assert.ok(waiting.every(s=>s.starts===0 && !s.pose && s.snapshots===0), 'not active before host start');
 assert.ok(samples.some(s=>s.phase===3 && s.pose && s.actor>=0 && s.snapshots>=5 && s.ack>5 && s.starts===1), 'native applied authoritative snapshots and ACKs');
 assert.ok(wire.snapshots>=5 && wire.starts===1 && wire.positiveAcks>0);
 assertRole(wire.guest);
}
export async function stopChild(child) {
 if (!child || !child.pid) return {pid:null, reaped:true};
 if (child.exitCode===null && child.signalCode===null) {
  child.kill('SIGTERM');
  try { await until(()=>child.exitCode!==null || child.signalCode!==null,2000,'SIGTERM reap'); }
  catch { child.kill('SIGKILL'); await until(()=>child.exitCode!==null || child.signalCode!==null,2000,'SIGKILL reap'); }
 }
 let absent=false;
 try { process.kill(child.pid,0); } catch(e) { if(e.code==='ESRCH') absent=true; else throw e; }
 assert.ok(absent,'owned child still exists');
 return {pid:child.pid,reaped:absent,exitCode:child.exitCode,signal:child.signalCode};
}
