import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fighterImports} from './fighter_imports.mjs';
import {verifyFighterImportProvenance} from './manifest_validation.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const read=p=>readFileSync(join(root,p)),has=p=>existsSync(join(root,p));
test('all nine actual committed import settings preserve per-node paired-animation keys',()=>{
  const inventory=fighterImports({read,has});assert.equal(Object.keys(inventory).length,9);
  const path='godot/fighting/assets/operators/meta.glb.import';
  for(const key of ['optimizer/enabled','compression/enabled'])assert.throws(()=>fighterImports({has,read:p=>p===path?Buffer.from(read(p).toString().replace(`"${key}": false`,`"${key}": true`)):read(p)}),/stay disabled/);
  assert.throws(()=>fighterImports({has,read:p=>{if(p===path)throw Error('missing import');return read(p);}}),/missing import/);
});
test('recorded import hashes resist dirty checkout, dropped entries and refreshed hashes',()=>{
  const repo=mkdtempSync(join(tmpdir(),'fighter import identities '));
  const put=(p,b)=>{mkdirSync(dirname(join(repo,p)),{recursive:true});writeFileSync(join(repo,p),b);};
  const git=(...args)=>execFileSync('git',args,{cwd:repo,encoding:'utf8'}).trim();
  try {
    const hashes=fighterImports({read,has});for(const p of Object.keys(hashes))put(p,read(p));put('godot/fighting/main.gd',read('godot/fighting/main.gd'));
    const generator='tools/fighting/animation/prepare_native.py';put(generator,read(generator));
    git('init','-q');git('add','.');git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','actual fighter import settings');
    const identity={port_commit:git('rev-parse','HEAD'),manifest:{fighter_import_sha256:{...hashes},fighter_import_generator_sha256:createHash('sha256').update(read(generator)).digest('hex')}};
    verifyFighterImportProvenance(repo,identity);
    const path=Object.keys(hashes)[0];put(path,'dirty worktree');verifyFighterImportProvenance(repo,identity);
    identity.manifest.fighter_import_sha256[path]='0'.repeat(64);assert.throws(()=>verifyFighterImportProvenance(repo,identity),/differ from recorded/);
    delete identity.manifest.fighter_import_sha256[path];assert.throws(()=>verifyFighterImportProvenance(repo,identity),/differ from recorded/);
  }finally{rmSync(repo,{recursive:true,force:true});}
});
