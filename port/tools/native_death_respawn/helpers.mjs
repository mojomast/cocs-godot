// Cleanup/wait patterns from guest_session_integration/lib.mjs,
// 389561510ac7c2223a22897c963f3440304ec928, via native_trace_correlation fbc8345.
import assert from 'node:assert/strict';
export const sleep = ms => new Promise(r => setTimeout(r, ms));
export async function until(predicate, ms, label) {
 const end = performance.now() + ms;
 while (performance.now() < end) { if (predicate()) return; await sleep(25); }
 throw Error(`Deadline: ${label} (${ms}ms)`);
}
export async function stopChild(child) {
 if (!child?.pid) return {pid:null,reaped:true};
 if (child.exitCode===null && child.signalCode===null) {
  child.kill('SIGTERM');
  try { await until(()=>child.exitCode!==null||child.signalCode!==null,2000,'SIGTERM reap'); }
  catch { child.kill('SIGKILL'); await until(()=>child.exitCode!==null||child.signalCode!==null,2000,'SIGKILL reap'); }
 }
 let absent=false;
 try {process.kill(child.pid,0);} catch(e) {if(e.code==='ESRCH')absent=true;else throw e;}
 assert.ok(absent,'owned child still exists');
 return {pid:child.pid,reaped:absent,exitCode:child.exitCode,signal:child.signalCode};
}
