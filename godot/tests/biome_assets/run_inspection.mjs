// Heavy job, explicit parent grant only. Owns serial authorities/native processes.
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {once} from 'node:events';
import {resolve} from 'node:path';
import {createAuthority} from '../../../port/native-campaign/authority.mjs';
import {maps} from '../../../tools/godot-biomes/expansion/recipe.mjs';
import {root} from '../../../tools/godot-biomes/expansion/compile.mjs';

if(!process.argv.includes('--granted'))throw Error('Requires explicit Blender/Godot slot grant and --granted');
const godot=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const evidence=resolve(process.env.SCENERY_EVIDENCE??'/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/native',new Date().toISOString().replaceAll(':','-'));
mkdirSync(evidence,{recursive:true});
let child,authority;
async function cleanup() {if(child?.pid&&child.exitCode===null&&child.signalCode===null){child.kill('SIGKILL');await once(child,'exit');}if(authority)await authority.close();}
for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>{void cleanup().finally(()=>process.exit(130));});
const results=[];
const selectedMap=process.argv.find(a=>a.startsWith('--map='))?.slice(6);
if(selectedMap&&!maps.includes(selectedMap))throw Error('Unknown chapter');
try {
  for(const map of selectedMap?[selectedMap]:maps)for(const profile of process.argv.includes('--wide-only')?['wide']:['wide','compact']) {
    const directory=resolve(evidence,map,profile);mkdirSync(directory,{recursive:true});
    authority=createAuthority({mapId:map,random:()=>.5});
    authority.server.listen(0,'127.0.0.1');await once(authority.server,'listening');
    const endpoint=`ws://127.0.0.1:${authority.server.address().port}/native-campaign`;
    const args=['--path',root+'godot','--rendering-driver','opengl3','-s','res://tests/biome_assets/native_inspection.gd','--',`--map=${map}`,`--endpoint=${endpoint}`,`--output=${directory}`];
    if(profile==='compact')args.push('--compact');
    if(process.argv.includes('--architecture-only'))args.push('--architecture-only');
    args.unshift('--audio-driver','Dummy');
    let log='';
    child=spawn(godot,args,{cwd:root,env:{...process.env,LP_NUM_THREADS:'1'},stdio:['ignore','pipe','pipe']});
    child.stdout.on('data',b=>{log+=b;});child.stderr.on('data',b=>{log+=b;});
    let timeout=false;
    const timer=setTimeout(()=>{timeout=true;child.kill('SIGKILL');},180000);
    const [code,signal]=await once(child,'close');clearTimeout(timer);
    writeFileSync(resolve(directory,'native.log'),log);
    results.push({map,profile,code,signal,timeout});
    writeFileSync(resolve(evidence,'runs.json'),JSON.stringify(results,null,2));
    child=null;await authority.close();authority=null;
    if(code!==0||timeout||/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use/.test(log))throw Error(`Native inspection failed: ${map}/${profile}; retained ${directory}`);
  }
} finally {await cleanup();}
