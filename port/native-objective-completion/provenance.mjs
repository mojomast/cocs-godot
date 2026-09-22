import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {load} from './validate.mjs';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const versions={
 '2d6b7e66-6adc-43f2-b29e-9d26fed86387':{original:'460674e',integrated:'1228369'},
 'cfb8c298-c0e0-4337-9951-75b7bcc734a3':{original:'12e0707',integrated:'2077911'},
};
const index={base:'ffa6aac0bc4a61a0b5e1721dbb4000066c22a474',evidence:[]};
for(const [id,version]of Object.entries(versions)){
 const dir=`port/native-objective-completion/evidence/${id}`,{summary}=load(dir),launch=JSON.parse(readFileSync(`${dir}/launch.json`));
 // These attributable cherry-picks are reachable in public main. Verify every
 // recorded byte instead of requiring unpublished agent branch objects.
 const commit=execFileSync('git',['rev-parse',version.integrated],{encoding:'utf8'}).trim();
 for(const [path,hash]of Object.entries(summary.runtimeHashes))assert.equal(sha(execFileSync('git',['show',`${commit}:${path}`],{maxBuffer:4*1024*1024})),hash,`exact live version ${id} ${path}`);
 // The product and source modules remain identical to their live versions.
 for(const [path,hash]of Object.entries(summary.runtimeHashes))if(!path.startsWith('port/native-objective-completion/')&&!path.startsWith('godot/tests/objectives/completion'))assert.equal(sha(readFileSync(path)),hash,`unchanged product ${path}`);
  assert.equal(sha(readFileSync(process.env.GODOT_BIN??launch.binary)),launch.binarySHA256);
 assert.equal(summary.serverClosed,true);assert.equal(summary.sockets,0);assert.equal(summary.temporaryTreeRemoved,true);
 for(const child of summary.cleanup){assert.ok(child.reaped&&child.absent);let absent=false;try{process.kill(child.pid,0);}catch(e){absent=e.code==='ESRCH';}assert.ok(absent,'owned PID independently absent');}
 const files=Object.fromEntries(readdirSync(dir).sort().map(name=>{const raw=readFileSync(`${dir}/${name}`);return[name,{bytes:raw.length,sha256:sha(raw)}];}));
 index.evidence.push({id,originalExit:summary.exit,originalLiveCommit:version.original,contentVerifiedIntegration:commit,runtimeHashesMatched:Object.keys(summary.runtimeHashes).length,source:summary.source,binarySHA256:launch.binarySHA256,cleanupIndependentlyAbsent:true,files});
}
console.log(JSON.stringify(index,null,2));
