import {spawnSync} from 'node:child_process';
import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const evidence=fileURLToPath(new URL('./evidence/',import.meta.url));
const home='/tmp/opencode/cocs-pickup-assets-home';
mkdirSync(evidence,{recursive:true}); mkdirSync(home,{recursive:true});
const run=(label,command,args)=>{
  const result=spawnSync(command,args,{cwd:root,encoding:'utf8',timeout:180000,env:{...process.env,HOME:home,XDG_CACHE_HOME:`${home}/cache`,XDG_CONFIG_HOME:`${home}/config`,XDG_DATA_HOME:`${home}/data`}});
  const text=(result.stdout??'')+(result.stderr??'');
  writeFileSync(`${evidence}/${label}-${Date.now()}.log`,text);
  console.log(`${label}: exit=${result.status}\n${text}`);
  if(result.status!==0||/SCRIPT ERROR|Parse Error|ERROR:|instances leaked|resources still in use/.test(text))throw Error(`${label} failed; attempt retained`);
};
run('source','node',['port/native-combat-pickup-assets/source-fixtures.mjs']);
run('source-powerups','node',['--test','game/powerups.test.mjs']);
run('logic',godot,['--headless','--path','godot','--script','res://tests/combat_pickup_assets/validate.gd']);
run('protocol-pickups',godot,['--headless','--path','godot','--script','res://tests/protocol/pickups.gd']);
if(!process.argv.includes('--logic-only')) for(const size of ['960x640','1280x720']) {
  mkdirSync(`${evidence}/${size}`,{recursive:true});
  run(`graphics-${size}`,'xvfb-run',['-a','-s',`-screen 0 ${size}x24`,godot,'--path','godot','--rendering-method','gl_compatibility','--audio-driver','Dummy','--script','res://tests/combat_pickup_assets/graphics.gd','--',`--size=${size}`,`--output=${evidence}/${size}`]);
}
