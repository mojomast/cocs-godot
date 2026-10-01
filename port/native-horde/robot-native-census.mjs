import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createAuthority,HORDE_MAPS} from './authority.mjs';

const out='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde';
mkdirSync(out,{recursive:true});
const binary=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const selected=process.argv[2]?[process.argv[2]]:HORDE_MAPS;
if(selected.some(id=>!HORDE_MAPS.includes(id)))throw Error('Unsupported census map');
const results=[];
for(const mapId of selected){
 const authority=createAuthority();
 await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
 let child,output='';
 try{
  child=spawn(binary,['--headless',...(process.env.CENSUS_VERBOSE?['--verbose']:[]),'--audio-driver','Dummy','--max-fps','60','--path','godot',
   '--script','res://tests/horde/robot_census.gd','--',`--endpoint=ws://127.0.0.1:${authority.server.address().port}`,
   `--map=${mapId}`,'--waves=10'],{env:{...process.env,LP_NUM_THREADS:'1'}});
  child.stdout.on('data',b=>{output+=String(b)});
  child.stderr.on('data',b=>{output+=String(b)});
  const code=await Promise.race([new Promise(resolve=>child.once('exit',resolve)),
   new Promise((_,reject)=>setTimeout(()=>reject(Error(`Native census timeout: ${mapId}`)),24000))]);
  writeFileSync(`${out}/native-census-${mapId}.log`,output);
  const line=output.split('\n').find(row=>row.startsWith('HORDE_ROBOT_CENSUS '));
  const census=line?JSON.parse(line.slice('HORDE_ROBOT_CENSUS '.length)):null;
  const errors=output.split('\n').filter(row=>/SCRIPT ERROR|Parse Error|ERROR:|ObjectDB instances leaked|resources still in use/.test(row));
  const result={mapId,code,census,errors};results.push(result);
  console.log('HORDE_NATIVE_CENSUS '+JSON.stringify(result));
  if(code!==0||!census?.ok||errors.length)process.exitCode=1;
 }finally{if(child&&!child.killed)child.kill('SIGTERM');await authority.close();}
}
writeFileSync(`${out}/native-census.json`,JSON.stringify(results,null,2)+'\n');
