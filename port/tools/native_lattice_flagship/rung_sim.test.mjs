import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';

test('privileged direct Match rung experiment passes on both authored maps',()=>{
 const run=spawnSync(process.execPath,['port/tools/native_lattice_flagship/rung_sim.mjs'],{encoding:'utf8'});
 assert.equal(run.status,0,`${run.stdout}\n${run.stderr}`);
 const dir=run.stdout.match(/(\/[^:]+): PASS/ )?.[1];assert.ok(dir,run.stdout);
  const result=JSON.parse(readFileSync(`${dir}/results.json`,'utf8'));
  assert.equal(result.source_commit,JSON.parse(readFileSync('port/contracts/source-lock.json','utf8')).source_commit);
 assert.equal(result.cases.length,12);
 assert.ok(result.cases.every(c=>c.passed&&c.observed&&c.evidence_class==='direct-sim'));
 assert.deepEqual(result.gaps.map(g=>g.status),['UNAVAILABLE','UNAVAILABLE']);
});
