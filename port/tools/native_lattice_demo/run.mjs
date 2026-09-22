import {register} from 'node:module';
register('./dependencies.mjs',import.meta.url);
const {createGameServer}=await import('../../../server/game-server.mjs');
import {spawn,execFileSync} from 'node:child_process';
import {readFileSync,mkdtempSync,mkdirSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {verifySource} from '../../../tools/godot-export/semantic.mjs';
const lock=JSON.parse(readFileSync('port/contracts/source-lock.json')); verifySource(lock);
const bin=process.env.GODOT_BIN;
if (!bin || execFileSync(bin,['--version'],{encoding:'utf8'}).trim()!==lock.godot_version) throw Error('Pinned GODOT_BIN required');
const runtime=mkdtempSync(join(tmpdir(),'native-lattice-'));
const env={...process.env};
for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']) {env[key]=join(runtime,key);mkdirSync(env[key]);}
const game=createGameServer({historyPath:null,progressionPath:null});
let child, timer;
const stop=()=>child?.kill('SIGTERM');
process.once('SIGINT',stop);process.once('SIGTERM',stop);
try {
 await new Promise((resolve,reject)=>{game.server.once('error',reject);game.server.listen(0,'127.0.0.1',resolve);});
 const port=game.server.address().port;
 const response=await fetch(`http://127.0.0.1:${port}`,{signal:AbortSignal.timeout(5000)});
 if(!response.ok)throw Error('Readiness failed');
 const options=process.argv.slice(2), headless=options.includes('--headless');
 const size=options.find(s=>s.startsWith('--size='))?.slice(7)??'960x640';
 console.log(`Owned loopback server ready ${port}; normal simulation rate`);
 child=spawn(bin,[...(headless?['--headless']:[]),'--audio-driver','Dummy','--path','godot','--resolution',size,'res://lattice/board.tscn','--',`--endpoint=ws://127.0.0.1:${port}`,...options.filter(s=>s!=='--headless'&&!s.startsWith('--size='))],{stdio:'inherit',env});
 timer=setTimeout(()=>{console.error('120s attempt deadline');stop();},120000);
 process.exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',(code)=>resolve(code??1));});
}finally{
 clearTimeout(timer);stop();await game.close();
 rmSync(runtime,{recursive:true,force:true});
 process.removeListener('SIGINT',stop);process.removeListener('SIGTERM',stop);
 console.log('Owned native child exited and loopback server closed');
}
