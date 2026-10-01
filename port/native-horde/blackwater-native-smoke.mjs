import {spawn} from 'node:child_process';
import {writeFileSync,mkdirSync} from 'node:fs';
import {createAuthority} from './authority.mjs';

const out='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde';
mkdirSync(out,{recursive:true});
const binary=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const authority=createAuthority();
await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
let child,stdout='',stderr='',code=-1;
try{
 const endpoint=`ws://127.0.0.1:${authority.server.address().port}`;
 child=spawn(binary,['--headless','--audio-driver','Dummy','--max-fps','60','--quit-after','720','--path','godot',
  'res://horde_maps/blackwater_demo.tscn','--',`--endpoint=${endpoint}`,'--map=blackwater-reclamation','--waves=10','--horde-evidence','--native-trace'],
 {env:{...process.env,LP_NUM_THREADS:'1'}});
 child.stdout.on('data',b=>{stdout+=String(b);});
 child.stderr.on('data',b=>{stderr+=String(b);});
 code=await Promise.race([new Promise(resolve=>child.once('exit',resolve)),new Promise((_,reject)=>setTimeout(()=>reject(Error('Blackwater native smoke timed out')),25000))]);
 writeFileSync(`${out}/blackwater-native-smoke.log`,stdout+'\n'+stderr);
 const starts=stdout.includes('HORDE_NATIVE ');
 const robots=[...stdout.matchAll(/"npcModel":"([a-z]+)"/g)].map(m=>m[1]);
 const status={code,starts,nativeRows:(stdout.match(/HORDE_NATIVE /g)||[]).length,robotIds:[...new Set(robots)],
  errors:(stdout+stderr).split('\n').filter(line=>/ERROR:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|resources still in use/.test(line)).slice(0,20)};
 writeFileSync(`${out}/blackwater-native-smoke.json`,JSON.stringify(status,null,2)+'\n');
 console.log(JSON.stringify(status));
 if(code!==0||!starts||status.errors.length)process.exitCode=1;
}finally{if(child&&!child.killed)child.kill('SIGTERM');await authority.close();}
