import {spawnSync} from 'node:child_process';
import fs from 'node:fs';
import assert from 'node:assert/strict';

const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const ids=['prism-foundry','aurora-basin','cinder-array'];
const previous=Object.fromEntries(ids.map(id=>[id,fs.existsSync(`godot/native_arenas/generated/${id}.json`)?JSON.parse(fs.readFileSync(`godot/native_arenas/generated/${id}.json`)).geometryHash:null]));
const run=(command,args)=>{const result=spawnSync(command,args,{stdio:'inherit'});if(result.status!==0)throw new Error(`${command} failed: ${result.status}`);};
run(godot,['--headless','--path','godot','--script','../tools/godot-native-arenas/dump.gd','--','--output=/tmp/opencode/native-dm-colliders.json']);
run(process.execPath,['tools/godot-native-arenas/compile.mjs']);
if(process.argv.includes('--check-determinism'))for(const id of ids){
  const current=JSON.parse(fs.readFileSync(`godot/native_arenas/generated/${id}.json`)).geometryHash;
  assert.equal(current,previous[id],`${id} deterministic rebuild changed geometry hash`);
}
run(godot,['--headless','--path','godot','--script','res://tests/native_arenas/geometry/probe.gd']);
run(process.execPath,['tools/godot-native-arenas/verify.mjs']);
