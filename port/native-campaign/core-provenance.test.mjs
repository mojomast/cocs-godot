// Text-only checks: no engine import or simulation slot required.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {generateCampaignCore,SOURCE_SHA256} from './generate-core.mjs';
const source=readFileSync(new URL('../../game/core.mjs',import.meta.url),'utf8');
const generated=readFileSync(new URL('./core.generated.mjs',import.meta.url),'utf8');
test('committed static adapter is exactly reproducible from the pinned source',()=>{
  assert.equal(createHash('sha256').update(source).digest('hex'),SOURCE_SHA256);
  assert.equal(generated,generateCampaignCore(source));
  assert.throws(()=>generateCampaignCore(source+'\n'),/Locked core drift/);
});
test('independent inverse comparison preserves every source byte outside imports and actorHit',()=>{
  const sourceStart=source.indexOf('function actorHit('),sourceEnd=source.indexOf('function hitActor(',sourceStart);
  assert.ok(sourceStart>0&&sourceEnd>sourceStart);
  const body=generated.split('\n').slice(2).join('\n').replace(/from '\.\.\/\.\.\/game\//g,"from './");
  const start=body.indexOf('function actorHit('),end=body.indexOf('function hitActor(',start);
  assert.ok(start>0&&end>start);
  const restored=body.slice(0,start)+source.slice(sourceStart,sourceEnd)+body.slice(end);
  assert.equal(restored,source);
  assert.equal((generated.match(/from '\.\.\/\.\.\/game\//g)||[]).length,34);
  assert.ok(!/\b(?:eval|Function)\s*\(|\bimport\s*\(/.test(generated));
});
