// Small, bounded art/session capture. Requires the pinned GODOT_BIN and existing deps.
import {spawn} from 'node:child_process';
import {mkdtempSync, mkdirSync, writeFileSync, rmSync} from 'node:fs';
import {resolve} from 'node:path';
import {createGameServer} from '../../server/game-server.mjs';
const binary=process.env.GODOT_BIN;
if(!binary)throw Error('Set GODOT_BIN to the pinned 4.5.2 binary');
const scripts=resolve('port/native-entity-presentation');
const output=resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)??scripts);
mkdirSync(output,{recursive:true});
const temp=mkdtempSync('/tmp/opencode/entity-capture-');
const env={PATH:process.env.PATH,HOME:temp,LANG:'C.UTF-8',LIBGL_ALWAYS_SOFTWARE:'1'};
for(const k of ['XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME']){env[k]=resolve(temp,k);mkdirSync(env[k]);}
const children=[];
let game;
function launch(command,args,name,extra={}){
  const child=spawn(command,args,{env,stdio:['ignore','pipe','pipe'],...extra});
  children.push(child);
  let text='';
  child.stdout.on('data',d=>text+=d);child.stderr.on('data',d=>text+=d);
  child.done=new Promise((res,rej)=>{child.once('error',rej);child.once('close',code=>{writeFileSync(resolve(output,name+'.txt'),text);res(code);});});
  return child;
}
const deadline=setTimeout(()=>{for(const child of children)child.kill('SIGKILL');},45000);
try{
  const xvfb=launch('Xvfb',['-displayfd','3','-screen','0','1280x800x24','-nolisten','tcp','-nolisten','unix'],'display',{stdio:['ignore','pipe','pipe','pipe']});
  const display=await new Promise((res,rej)=>{
    const timeout=setTimeout(()=>rej(Error('Display startup timeout')),5000);
    xvfb.stdio[3].once('data',d=>{clearTimeout(timeout);res(d.toString().trim());});
  });
  env.DISPLAY=':'+display;
  const common=['--path','godot','--audio-driver','Dummy','--max-fps','60'];
  const fixture=launch(binary,[...common,'--script',resolve(scripts,'render_fixture.gd'),'--','--output='+resolve(output,'composition.png')],'render');
  if(await fixture.done!==0)throw Error('Fixture failed');
  game=createGameServer({historyPath:null,progressionPath:null});
  await new Promise(res=>game.server.listen(0,'127.0.0.1',res));
  const native=launch(binary,[...common,'--script',resolve(scripts,'capture_session.gd'),'--',`--endpoint=ws://127.0.0.1:${game.server.address().port}`,'--output='+output],'native');
  if(await native.done!==0)throw Error('Native capture failed');
  console.log('Captured composition.png, native-pickup.png, native-actor.png');
}finally{
  clearTimeout(deadline);
  for(const child of children){
    if(child.exitCode===null&&child.signalCode===null){
      child.kill('SIGTERM');
      const kill=setTimeout(()=>child.kill('SIGKILL'),3000);
      await child.done;clearTimeout(kill);
    }
  }
  if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();}
  rmSync(temp,{recursive:true,force:true});
}
