// Product scene startup only: no steering, no combat/wave-clear acceptance claim.
import {createAuthority} from './authority.mjs';
import {spawn} from 'node:child_process';
import {mkdtempSync,mkdirSync,rmSync,writeFileSync,existsSync} from 'node:fs';
const temp=mkdtempSync('/tmp/opencode/horde-product-smoke-');
const env={...process.env};for(const k of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','XDG_RUNTIME_DIR']){env[k]=temp+'/'+k;mkdirSync(env[k],{mode:0o700});}
let wave=false,properDefault=false,output='',code=1,child,timer;
const authority=createAuthority({observe(r){if(r.direction==='out'&&r.frame.type==='snapshot'){const s=r.frame.state;wave ||= s.singleplayer.wave===1&&s.singleplayer.enemiesAlive>0;properDefault ||= s.singleplayer.waveTarget===10;}}});
try{
 await new Promise(r=>authority.server.listen(0,'127.0.0.1',r));
 child=spawn(process.env.GODOT_BIN,['--headless','--max-fps','60','--quit-after','720','--path','godot','res://horde/demo.tscn','--','--map=meridian-exchange',`--endpoint=ws://127.0.0.1:${authority.server.address().port}`],{env});
 child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
 timer=setTimeout(()=>child.kill('SIGKILL'),30000);
 code=await new Promise((r,j)=>{child.on('exit',r);child.on('error',j);});
}finally{clearTimeout(timer);await authority.close();rmSync(temp,{recursive:true,force:true});}
let absent=false;try{process.kill(child.pid,0);}catch(e){absent=e.code==='ESRCH';}
const result={code,wave,properDefault,pid:child.pid,absent,serverClosed:!authority.server.listening,sockets:authority.wss.clients.size,temporaryTreeRemoved:!existsSync(temp),headless:true,scope:'actual product scene startup, no physical/human acceptance'};
writeFileSync('port/reports/horde-repair/product-smoke.log',output);
writeFileSync('port/reports/horde-repair/product-smoke.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
if(code!==0||!wave||!properDefault||!absent||/SCRIPT ERROR|ERROR:/.test(output))process.exitCode=1;
