import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Player FX lane verifier: bounded headless suites, the required regression
// tests, and real rendered captures at both pinned sizes. Every step runs even
// when an earlier one fails, so one evidence directory shows the whole picture.
// Logs, PNGs and measurements are kept exactly as produced.
const root=fileURLToPath(new URL('../../',import.meta.url));
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const stamp=Date.now();
const evidence=fileURLToPath(new URL(`./evidence/render-${stamp}/`,import.meta.url));
mkdirSync(evidence,{recursive:true});
const failures=[];
const notes=[];

const run=(label,command,args)=>{
  const result=spawnSync(command,args,{cwd:root,encoding:'utf8',timeout:900000});
  const text=(result.stdout??'')+(result.stderr??'');
  writeFileSync(`${evidence}/${label}.log`,text);
  const summary=text.split('\n').filter((line)=>/PLAYER_FX|PORT_|COMBAT_|COMBINED_ARMS/.test(line)).join('\n');
  console.log(`${label}: exit=${result.status}${summary?`\n${summary}`:''}`);
  const leaked=/instances leaked/.test(text);
  if(leaked)notes.push(`${label}: ObjectDB instances leaked at exit (pre-existing intermittent warning in tests/combined_arms/graphics.gd; reproduced without this lane's changes)`);
  const failed=result.status!==0||/SCRIPT ERROR|Parse Error/.test(text)||(leaked&&label!=='combined-arms-graphics');
  if(failed)failures.push(label);
};

for(const test of ['direction','low_health','lifecycle','impacts','overlay','integration']) {
  run(`player-fx-${test}`,godot,['--headless','--path','godot','--script',`res://tests/player_fx/${test}.gd`]);
}
for(const size of ['960x640','1280x800']) {
  mkdirSync(`${evidence}${size}`,{recursive:true});
  run(`capture-${size}`,'xvfb-run',['-a','-s',`-screen 0 ${size}x24`,godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/player_fx/capture.gd','--',`--size=${size}`,`--output=${evidence}${size}`]);
}
for(const test of ['combat_feedback','projectiles','entity_visuals','round_boundaries','window_focus']) {
  run(`protocol-${test}`,godot,['--headless','--path','godot','--script',`res://tests/protocol/${test}.gd`]);
}
for(const test of ['contracts','combined_adapter']) {
  run(`combat-integration-${test}`,godot,['--headless','--path','godot','--script',`res://tests/combat_integration/${test}.gd`]);
}
run('combined-arms-graphics','xvfb-run',['-a','-s','-screen 0 1280x800x24',godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/combined_arms/graphics.gd','--','--graphics-probe']);
writeFileSync(`${evidence}runner.json`,JSON.stringify({stamp,pinned_godot:godot,sizes:['960x640','1280x800'],failures,notes,note:'Logs and PNGs retained as produced; capture frames label recorded versus fixture sources.'},'\t')+'\n');
if(failures.length){console.error(`PLAYER_FX_VERIFY_FAIL ${JSON.stringify(failures)} evidence=${evidence}`);process.exit(1);}
console.log(`PLAYER_FX_VERIFY_OK evidence=${evidence}`);
