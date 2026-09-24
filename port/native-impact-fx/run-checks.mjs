import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

// Impact-FX lane verifier: the headless player-fx/blood-fx gates, the new
// marks suite, and real rendered captures at both pinned sizes under
// xvfb + llvmpipe on the Compatibility renderer. Every step runs even when an
// earlier one fails, so one evidence directory shows the whole picture.
const root=fileURLToPath(new URL('../../',import.meta.url));
const godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const stamp=Date.now();
const evidence=fileURLToPath(new URL(`./evidence/render-${stamp}/`,import.meta.url));
mkdirSync(evidence,{recursive:true});
const failures=[];
const notes=[];
const childEnv={...process.env,
  XDG_DATA_HOME:path.join(root,'.port-runtime','data'),
  XDG_CONFIG_HOME:path.join(root,'.port-runtime','config'),
  XDG_CACHE_HOME:path.join(root,'.port-runtime','cache'),
  TMPDIR:process.env.TMPDIR??'/tmp/opencode'};

const run=(label,command,args)=>{
  const result=spawnSync(command,args,{cwd:root,encoding:'utf8',timeout:900000,env:childEnv});
  const text=(result.stdout??'')+(result.stderr??'');
  writeFileSync(`${evidence}/${label}.log`,text);
  const summary=text.split('\n').filter((line)=>/PLAYER_FX|BLOOD_FX_CONTRACTS|Exported/.test(line)).join('\n');
  console.log(`${label}: exit=${result.status}${summary?`\n${summary}`:''}`);
  const shaderError=/SHADER ERROR/.test(text)&&!text.includes('shader_error_expected');
  if(shaderError)failures.push(`${label}: shader compilation failed`);
  if(/SCRIPT ERROR|Parse Error/.test(text))failures.push(`${label}: script error`);
  if(result.status!==0)failures.push(`${label}: exit ${result.status}`);
};

run('semantic-export','node',['tools/godot-export/semantic.mjs']);
run('godot-import',godot,['--headless','--path','godot','--import']);
for(const test of ['direction','low_health','lifecycle','impacts','overlay','integration','marks']) {
  run(`player-fx-${test}`,godot,['--headless','--path','godot','--script',`res://tests/player_fx/${test}.gd`]);
}
run('blood-fx-contracts',godot,['--headless','--path','godot','--script','res://tests/blood_fx/contracts.gd']);
for(const size of ['960x640','1280x800']) {
  const dir=`${evidence}${size}/`;
  mkdirSync(dir,{recursive:true});
  run(`marks-capture-${size}`,'xvfb-run',['-a','-s',`-screen 0 ${size}x24`,godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/player_fx/marks_capture.gd','--',`--size=${size}`,`--output=${dir}`]);
}
writeFileSync(`${evidence}runner.json`,JSON.stringify({stamp,pinned_godot:godot,sizes:['960x640','1280x800'],failures,notes,
  note:'Headless gates plus rendered captures on the Compatibility renderer under llvmpipe; PNGs and measurements retained as produced.'},'\t')+'\n');
if(failures.length){console.error(`IMPACT_FX_VERIFY_FAIL ${JSON.stringify(failures)} evidence=${evidence}`);process.exit(1);}
console.log(`IMPACT_FX_VERIFY_OK evidence=${evidence}`);
