// Source-only conversion of the committed production-C evidence. Promotion is a
// separate parent-authorized edit; this command never changes requirements.
import assert from 'node:assert/strict';
import {readFileSync,existsSync,mkdirSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {productionResources} from './production_resources.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
process.chdir(root);
const read=p=>readFileSync(p),has=p=>existsSync(p);
const hash=b=>createHash('sha256').update(b).digest('hex');
const hashes=paths=>Object.fromEntries([...new Set(paths)].sort().map(p=>{
  const bytes=read(p);
  assert.deepEqual(bytes,execFileSync('git',['show',`HEAD:${p}`],{maxBuffer:128*1024*1024}),`Uncommitted receipt input: ${p}`);
  return [p,hash(bytes)];
}));
const evidence=JSON.parse(read('port/new-maps/parallax-observatory/production-c.json'));
const plan=JSON.parse(read('port/finish/ASSET_PRODUCTION.json'));
const unit=plan.units.find(u=>u.id==='parallax-interiors');
const status=productionResources({read,has,strict:false}).units[unit.id];
assert.deepEqual(status.missing,[]);
const sourceHashes=hashes([...unit.recipePaths,plan.common.finishScript]);
const receipt={unit:unit.id,sourceHashes,sourceFingerprint:hash(JSON.stringify(sourceHashes)),
  packageInputs:hashes(status.expected.packageInputs),masters:evidence.masters,exports:evidence.exports,
  runtimeHooks:hashes([...Object.keys(evidence.runtimeHooks).filter(p=>!p.startsWith('godot/tests/')),'godot/multiplayer_worlds/catalog.gd']),
  rawFiles:[evidence.exports[0].path],promotionAuthorization:{sourceCommit:'b66f4ab3',
    review:'port/finish/PARALLAX_PACKAGE_PROMOTION.md',scope:'Parent-authorized bounded asset promotion only; no fresh six-mode or release attestation'}};
const path='tools/godot-package/production_receipts/parallax-interiors.json';
const bytes=JSON.stringify(receipt,null,2)+'\n';
mkdirSync('tools/godot-package/production_receipts',{recursive:true});
if(has(path))assert.equal(read(path).toString(),bytes,'Refusing to replace an existing different receipt');
else writeFileSync(path,bytes,{flag:'wx'});
console.log(JSON.stringify({receipt:path,sha256:hash(bytes)}));
