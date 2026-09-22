import {spawn} from 'node:child_process';
import fs from 'node:fs';
import {createAuthority} from '../../port/native-arenas/authority.mjs';

const godot='/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
fs.mkdirSync('/tmp/opencode/native-dm-captures',{recursive:true});
const captureRoot=`/tmp/opencode/native-dm-captures/${new Date().toISOString().replaceAll(':','-')}`;
fs.mkdirSync(captureRoot,{recursive:true});
console.log('captureRoot',captureRoot);
for(const mapId of process.argv.slice(2).length?process.argv.slice(2):['prism-foundry','aurora-basin','cinder-array']){
  let seed=71027;
  const random=()=>((seed=Math.imul(seed,1664525)+1013904223>>>0)/4294967296);
  const resets=[];
  const authority=createAuthority({mapId,botCount:5,timeLimit:300,difficulty:'easy',random,
    observe:event=>{if(event.direction==='control-reset')resets.push({reason:event.reason,epoch:event.inputEpoch});}});
  await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
  const endpoint=`ws://127.0.0.1:${authority.server.address().port}/native-arenas`;
  const args=['-a','-s','-screen 0 1920x1080x24',godot,'--path','godot','--audio-driver','Dummy','--rendering-method','gl_compatibility','--script','res://tests/native_arenas/geometry/capture.gd','--','--map='+mapId,'--endpoint='+endpoint,'--bots=5','--round-seconds=300','--autostart','--capture-root='+captureRoot];
  const log=fs.createWriteStream(`${captureRoot}/${mapId}.log`);
  const child=spawn('xvfb-run',args,{stdio:['ignore','pipe','pipe'],env:{...process.env,LP_NUM_THREADS:'8'}});
  child.stdout.pipe(log);child.stderr.pipe(log);
  const code=await new Promise(resolve=>child.on('exit',resolve));
  log.end();await authority.close();
  console.log(mapId,'capture exit',code);
  fs.writeFileSync(`${captureRoot}/${mapId}-controls.json`,JSON.stringify({resets},null,2));
  if(code!==0)process.exitCode=1;
}
