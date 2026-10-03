import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {verifySourceState} from './manifest_validation.mjs';

test('large locked inventory uses bounded Git argv and detects late Unicode/space edits',()=>{
  const root=mkdtempSync(join(tmpdir(),'locked source Windows ')),repo=join(root,'repo'),trace=join(root,'trace.jsonl');
  mkdirSync(repo);mkdirSync(join(repo,'assets'));
  const git=(...args)=>execFileSync('git',args,{cwd:repo,encoding:'utf8'}).trim();
  const previous=process.env.GIT_TRACE2_EVENT;
  try {
    git('init','-q');
    const names=Array.from({length:1100},(_,i)=>`assets/${String(i).padStart(4,'0')}-${'long-name-'.repeat(8)}.txt`);
    const late='assets/zzzz café texture with spaces.txt';names.push(late);
    assert.ok(names.join(' ').length>100000,'inventory exceeds Windows argv limit');
    for(const name of names)writeFileSync(join(repo,name),'original\n');
    git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','locked source');
    const source=git('rev-parse','HEAD');
    process.env.GIT_TRACE2_EVENT=trace;
    verifySourceState(repo,source,null,{portCommit:source});
    writeFileSync(join(repo,late),'changed\n');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','late change');
    const changed=git('rev-parse','HEAD');
    assert.throws(()=>verifySourceState(repo,source,null,{portCommit:changed}),error=>error.message.includes(late)&&error.message.includes('changes locked source'));
    // All validation commands stay bounded even with a >100K source inventory.
    const starts=readFileSync(trace,'utf8').trim().split('\n').map(JSON.parse).filter(e=>e.event==='start');
    assert.ok(starts.some(e=>e.argv.includes('diff')));
    for(const e of starts)assert.ok(e.argv.join(' ').length<4096,`Unbounded Git argv: ${e.argv[1]}`);
  } finally {
    if(previous===undefined)delete process.env.GIT_TRACE2_EVENT;else process.env.GIT_TRACE2_EVENT=previous;
    rmSync(root,{recursive:true,force:true});
  }
});
