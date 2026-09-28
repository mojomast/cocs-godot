import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {acquireCareer} from './career_path.mjs';

test('native identity persists privately, rejects switched endpoints/late welcome, and reports malformed storage',()=>{
 const binary=process.env.GODOT_BIN;
 assert.ok(binary,'GODOT_BIN must point to pinned Godot 4.5.2');
 const root=mkdtempSync(join(tmpdir(),'cocs-identity-native-'));
 try{
  const career=acquireCareer({experience:'deathmatch'}, {COCS_CAREER_ROOT:root});
  career.release();
   const output=execFileSync(binary,['--headless','--path',resolve('godot'),'--script','res://tests/career/identity.gd'],{
   encoding:'utf8',timeout:30000,env:{...process.env,...career.env,COCS_CAREER_ENDPOINT:'ws://127.0.0.1:12345',PATH:'/nonexistent',COCS_CAREER_ROOT:root},
  });
  assert.doesNotMatch(output,/SCRIPT ERROR|ERROR:/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
