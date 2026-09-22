import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync, mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {tmpdir} from 'node:os';
import {Room} from '../../server/room.mjs';
const root = resolve(import.meta.dirname, '../..');
const discover = path => JSON.parse(execFileSync(process.execPath, ['--no-warnings','--experimental-vm-modules',join(root,'tools/godot-package/discover.mjs'),path], {encoding:'utf8',stdio:['ignore','pipe','pipe']}));

test('actual Horde transitive closure is classified separately and source-byte locked', () => {
  const closure = discover(root);
  const lock = JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
  assert.deepEqual(Object.keys(closure.adapterModules), ['port/native-horde/authority.mjs','port/native-horde/input-buffer.mjs']);
  assert.equal(Object.keys(closure.modules).length,84);
  assert.deepEqual(closure.hordeAdditionalSource,[]);
  assert.ok(closure.routes.horde.includes('game/singleplayer.mjs'));
  assert.ok(!closure.routes.horde.includes('server/room.mjs'));
  for (const path of Object.keys(closure.modules)) {
    assert.deepEqual(readFileSync(join(root,path)),execFileSync('git',['show',`${lock.source_commit}:${path}`],{cwd:root,maxBuffer:64*1024*1024}),path);
  }
  assert.deepEqual(closure.external,['ws']);
});

test('closure rejects unreviewed adapter imports, external dependencies and runtime imports', () => {
  const fixture=mkdtempSync(join(tmpdir(),'horde-closure-synthetic-'));
  const put=(path,text)=>{mkdirSync(dirname(join(fixture,path)),{recursive:true});writeFileSync(join(fixture,path),text);};
  try {
    put('server/game-server.mjs',"import 'ws';");
    put('port/native-horde/input-buffer.mjs','');
    for (const dependency of ["import './oracle.mjs';", "import 'other';", "import('./input-buffer.mjs');", "import '../../outside.mjs';"]) {
      put('port/native-horde/authority.mjs',"import 'ws';"+dependency);
      assert.throws(()=>discover(fixture),Error,dependency);
    }
  } finally {rmSync(fixture,{recursive:true,force:true});}
});

test('unchanged public Room still rejects Horde configuration', () => {
  const room=new Room('horde-route-boundary');
  room.join(1,'Local');room.drain();
  room.host(1,{mode:'horde'},'meridian-exchange');
  assert.ok(room.drain().some(({msg})=>msg.type==='error'&&msg.message==='single-player modes are local only'));
  assert.equal(room.config.mode,'deathmatch');
  assert.equal(room.match,null);
});
