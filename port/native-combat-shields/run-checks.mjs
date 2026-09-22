import {spawnSync} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const evidence=fileURLToPath(new URL('./evidence/',import.meta.url));
mkdirSync(evidence,{recursive:true});
const run=(label,command,args)=>{
  const result=spawnSync(command,args,{cwd:root,encoding:'utf8',timeout:180000});
  const text=(result.stdout??'')+(result.stderr??'');
  // Keep numbered attempts, including failures, for honest investigation.
  const stamp=Date.now();
  writeFileSync(`${evidence}/${label}-${stamp}.log`,text);
  console.log(`${label}: exit=${result.status}\n${text}`);
  if(result.status!==0||/SCRIPT ERROR|Parse Error|ERROR:|instances leaked|resources still in use/.test(text))throw Error(`${label} failed; evidence retained`);
};
run('source','node',['port/native-combat-shields/source-fixtures.mjs']);
run('headless',godot,['--headless','--path','godot','--script','res://tests/combat_shields/validate.gd']);
run('live','node',['port/native-combat-shields/live-oracle.mjs']);
for(const size of ['960x640','1280x720']) {
  mkdirSync(`${evidence}/${size}`,{recursive:true});
  run(`graphics-${size}`,'xvfb-run',['-a','-s',`-screen 0 ${size}x24`,godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/combat_shields/graphics.gd','--',`--size=${size}`,`--output=${evidence}/${size}`]);
}
