// Evidence mutation tests: prove ACKs and plausible counters cannot replace a
// matching receipt, and that lease/input/identity/duplicate checks fail closed.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {audit} from './audit.mjs';

const out = resolve(process.argv[2]);
const records = readFileSync(join(out,'wire.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
const native = readFileSync(join(out,'native.log'),'utf8');
const manifest = JSON.parse(readFileSync(join(out,'manifest.json')));
const options = {exit:0,overflow:false,timedOut:false,manifest};
assert.equal(audit(records,native,options).passed,true,'unmodified live evidence must pass');
const result = [];
const test = (name, mutate, expected) => {
 const copy = structuredClone(records);
 mutate(copy);
 const altered = audit(copy,native,options);
 assert.equal(altered.passed,false,name);
 assert.equal(altered.checks[expected],false,`${name}: specific check must fail`);
 result.push({name,rejected:true,check:expected});
};
test('ACK and counters cannot replace done receipt', rows => {
 for (const r of rows) if (r.type === 'recipient') for (const c of r.cards ?? []) if (c.state === 'done') c.state = 'running';
}, 'doneReceipt');
test('wrong actor receipt', rows => {
 for (const r of rows) if (r.type === 'recipient') for (const c of r.cards ?? []) if (c.state === 'done') c.actorId += 1;
}, 'doneReceipt');
test('duplicate purchase', rows => rows.push(structuredClone(rows.find(r => r.type === 'request' && r.frame.type === 'economy'))), 'oneReinforce');
test('REQ debit invalidates FLUX-only claim', rows => {
 const buy = rows.find(r => r.type === 'request' && r.frame.type === 'economy');
 for (const r of rows) if (r.type === 'recipient' && r.seq > buy.priorSeq) r.req.spent += 1;
}, 'sourceCostSpawnReq');
test('no source spawn despite receipt', rows => {
 for (const r of rows) if (r.type === 'recipient') r.spawned = 0;
}, 'sourceCostSpawnReq');
test('no lease rotation', rows => {
 for (const r of rows) if (r.type === 'recipient') r.command.leaseUntil = 600;
}, 'naturalLease');
test('fire while overlay visible', rows => {
 const opened = native.split('\n').filter(line => line.startsWith('WORLD_COMMANDS ')).map(line => JSON.parse(line.slice(15))).find(r => r.event === 'opened');
 rows.find(r => r.type === 'request' && r.frame.type === 'input' && r.frame.seq > opened.inputSeq + 5).frame.input.fire = true;
}, 'neutralWhileOpen');
test('extra gameplay socket', rows => rows.push({type:'welcome',peer:99}), 'oneSocket');
writeFileSync(join(out,'audit-negative.json'),JSON.stringify({passed:true,tests:result},null,2)+'\n');
console.log(JSON.stringify({passed:true,tests:result},null,2));
