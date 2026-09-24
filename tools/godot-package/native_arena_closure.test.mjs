// SYNTHETIC static-closure fixtures. Real arena data and authority integration
// are verified by the package builder and the gameplay lane.
import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';

const script = fileURLToPath(new URL('./discover.mjs',import.meta.url));
const discover = root => JSON.parse(execFileSync(process.execPath,['--no-warnings','--experimental-vm-modules',script,root],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
const dataFiles = ['prism-foundry','aurora-basin','cinder-array'].map(id=>`godot/native_arenas/generated/${id}.json`);
const identityDataFiles = ['lacuna-court','vermilion-fold','nacre-engine'].map(id=>`godot/identity_maps/generated/${id}.json`);
test('actual local 24-bot helpers ship on native routes, outside multiplayer and Horde',()=>{
  const closure=discover(fileURLToPath(new URL('../../',import.meta.url)));
  for(const path of ['port/native-menu-debug-bots/seats.mjs','port/native-menu-debug-bots/debug-frame.mjs']){
    assert.ok(Object.hasOwn(closure.adapterModules,path),path);
    assert.ok(closure.routes.nativeArena.includes(path),path);
    assert.ok(closure.routes.identityZones.includes(path),path);
    assert.ok(!closure.routes.ordinary.includes(path),path);
    assert.ok(!closure.routes.horde.includes(path),path);
  }
});
function fixture(run) {
  const root = mkdtempSync(join(tmpdir(),'native arena closure synthetic '));
  const put = (path,text) => {mkdirSync(dirname(join(root,path)),{recursive:true});writeFileSync(join(root,path),text);};
  try {
    put('server/game-server.mjs',"import 'ws'; import '../game/core.mjs';");
    put('game/core.mjs','export class Match {}');
    put('port/native-horde/authority.mjs',"import 'ws'; import './input-buffer.mjs'; import '../../game/core.mjs';");
    put('port/native-horde/input-buffer.mjs','');
    return run(root,put);
  } finally {rmSync(root,{recursive:true,force:true});}
}
const authority = "import 'ws'; import './match.mjs'; import './catalog.mjs';";
function addNative(put) {
  put('port/native-arenas/authority.mjs',authority);
  put('port/native-arenas/match.mjs',"import {Match} from '../../game/core.mjs'; import './schema.mjs';");
  put('port/native-arenas/schema.mjs','');
  put('port/native-arenas/catalog.mjs',"import {readFileSync} from 'node:fs'; import './schema.mjs';");
}
function addIdentityZones(put) {
  put('port/native-identity-zones/authority.mjs',"import 'ws'; import './match.mjs'; import './catalog.mjs'; import '../native-debug/debug.mjs';");
  put('port/native-identity-zones/match.mjs',"import {Match} from '../../game/core.mjs'; import './catalog.mjs'; import '../native-arenas/schema.mjs';");
  put('port/native-identity-zones/catalog.mjs',"import {readFileSync} from 'node:fs'; import '../native-arenas/catalog.mjs';");
  put('port/native-debug/debug.mjs','');
}

test('Native DM SYNTHETIC closure separates exact reviewed adapters from locked source and declares data without reading missing JSON',()=>fixture((root,put)=>{
  const before = discover(root);
  assert.deepEqual(before.dataFiles,[]);
  assert.deepEqual(before.identityDataFiles,[]);
  assert.deepEqual(before.routes.nativeArena,[]);
  addNative(put);
  const closure = discover(root);
  assert.deepEqual(closure.modules,before.modules);
  assert.deepEqual(closure.routes.ordinary,before.routes.ordinary);
  assert.deepEqual(closure.routes.horde,before.routes.horde);
  assert.deepEqual(Object.keys(closure.adapterModules),[
    'port/native-arenas/authority.mjs','port/native-arenas/catalog.mjs','port/native-arenas/match.mjs','port/native-arenas/schema.mjs',
    'port/native-horde/authority.mjs','port/native-horde/input-buffer.mjs',
  ]);
  assert.equal(closure.nativeArenaEntry,'port/native-arenas/authority.mjs');
  assert.deepEqual(closure.dataFiles,dataFiles);
  assert.deepEqual(closure.identityDataFiles,identityDataFiles);
  assert.deepEqual(closure.dataReads,{'port/native-arenas/catalog.mjs':[...dataFiles,...identityDataFiles]});
  assert.deepEqual(closure.nativeArenaAdditionalSource,[]);
  assert.deepEqual(closure.external,['ws']);
  assert.ok(closure.routes.nativeArena.includes('game/core.mjs'));
  assert.ok(!closure.routes.nativeArena.includes('server/game-server.mjs'));
}));

test('Identity zone SYNTHETIC closure keeps Domination adapters explicit and separate from locked source',()=>fixture((root,put)=>{
  addNative(put); addIdentityZones(put);
  const closure = discover(root);
  assert.equal(closure.identityZoneEntry,'port/native-identity-zones/authority.mjs');
  for (const path of ['port/native-identity-zones/authority.mjs','port/native-identity-zones/catalog.mjs',
    'port/native-identity-zones/match.mjs','port/native-debug/debug.mjs']) {
    assert.ok(Object.hasOwn(closure.adapterModules,path),path);
    assert.ok(!Object.hasOwn(closure.modules,path),path);
  }
  assert.ok(closure.routes.identityZones.includes('game/core.mjs'));
  assert.ok(!closure.routes.identityZones.includes('server/game-server.mjs'));
  assert.deepEqual(closure.identityZoneAdditionalSource,[]);
  assert.deepEqual(closure.dataReads['port/native-identity-zones/catalog.mjs'],identityDataFiles);
  assert.deepEqual(closure.external,['ws']);
}));

test('Identity zone SYNTHETIC closure rejects unreviewed route helpers',()=>fixture((root,put)=>{
  addNative(put); addIdentityZones(put);
  put('port/native-identity-zones/route.mjs','');
  put('port/native-identity-zones/authority.mjs',"import 'ws'; import './match.mjs'; import './catalog.mjs'; import './route.mjs';");
  assert.throws(()=>discover(root),/route.mjs/);
}));

test('Native DM SYNTHETIC closure rejects unreviewed helpers, runtime loading, dependencies and missing modules',()=>fixture((root,put)=>{
  addNative(put);
  put('port/native-arenas/oracle.mjs','');
  put('port/native-unreviewed/authority.mjs','');
  put('port/native-arenas/authority.test.mjs','');
  for (const extra of ["import './oracle.mjs';", "import '../native-unreviewed/authority.mjs';", "import './authority.test.mjs';",
    "import 'new-dependency';", "import('./schema.mjs');", "const r = require('node:fs');", "eval('1');", "import {createRequire} from 'node:module';",
    "import '../../godot/native_arenas/generated/prism-foundry.json' with {type:'json'};"]) {
    put('port/native-arenas/authority.mjs',authority+extra);
    assert.throws(()=>discover(root),Error,extra);
  }
  put('port/native-arenas/authority.mjs',authority);
  rmSync(join(root,'port/native-arenas/schema.mjs'));
  assert.throws(()=>discover(root),/schema.mjs/);
}));
