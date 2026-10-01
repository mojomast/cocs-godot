import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync} from 'node:fs';
import {createAuthority} from './authority.mjs';
const out='/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde';
mkdirSync(out,{recursive:true});
const binary=process.env.GODOT_BIN??'/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64';
const authority=createAuthority({observe:value=>{
 if(['transport-error','error','inbound-reject'].includes(value.direction))console.error('BLACKWATER_TRANSPORT '+JSON.stringify(value));
}});
await new Promise(resolve=>authority.server.listen(0,'127.0.0.1',resolve));
let child,output='';
try{
 const endpoint=`ws://127.0.0.1:${authority.server.address().port}`;
 const headless=!!process.env.BLACKWATER_HEADLESS;
 const size=process.env.BLACKWATER_CLIP?'960x640':'1280x800';
 const args=headless?['--headless','--path','godot','res://tests/horde/blackwater_live.tscn','--']:
  ['-a','-s',`-screen 0 ${size}x24`,binary,'--audio-driver','Dummy','--rendering-method','gl_compatibility',
  '--resolution',size,'--path','godot','res://tests/horde/blackwater_live.tscn','--'];
 args.push(`--endpoint=${endpoint}`,'--map=blackwater-reclamation','--waves=10');
 if(!headless)args.push(`--screenshot=${out}/blackwater-live.png`);
 if(process.env.BLACKWATER_CLIP&&!headless){
  const recording=`${out}/blackwater-live-untrimmed.mp4`;
  const shell='ffmpeg -nostdin -hide_banner -loglevel error -f x11grab -framerate 12 -video_size 960x640 -i "$DISPLAY" -t 35 -an -c:v libx264 -preset ultrafast -crf 27 -pix_fmt yuv420p '+JSON.stringify(recording)+' 2>'+JSON.stringify(`${out}/clip-capture.log`)+' & exec "$@"';
  args.splice(3,0,'sh','-c',shell,'blackwater-clip');
 }
 child=spawn(headless?binary:'xvfb-run',args,{env:{...process.env,LP_NUM_THREADS:'1',LIBGL_ALWAYS_SOFTWARE:'1',GALLIUM_DRIVER:'llvmpipe'}});
 child.stdout.on('data',b=>{output+=String(b);process.stdout.write(b)});
 child.stderr.on('data',b=>{output+=String(b);process.stderr.write(b)});
 const code=await Promise.race([new Promise(resolve=>child.once('exit',resolve)),new Promise((_,reject)=>setTimeout(()=>reject(Error('Native live chain exceeded 540 seconds')),540000))]);
 writeFileSync(`${out}/blackwater-native-live.log`,output);
 const done=output.split('\n').findLast(row=>row.startsWith('HORDE_DONE '));
 console.log('BLACKWATER_NATIVE_RESULT '+JSON.stringify({code,done:done??null}));
 if(code!==0||!done?.includes('"ok":true')||/SCRIPT ERROR|Parse Error|ERROR:/.test(output))process.exitCode=1;
}finally{if(child&&!child.killed)child.kill('SIGTERM');await authority.close();}
