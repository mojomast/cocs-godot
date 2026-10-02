import {spawn} from 'node:child_process';
import fs from 'node:fs';
const root='/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/native-final';
fs.mkdirSync(root,{recursive:true});
for(const mode of (process.argv.slice(2).length?process.argv.slice(2):['payload','combined-arms','deathmatch','assault','domination','teamdeathmatch'])){
 const log=fs.openSync(`${root}/${mode}-run.log`,'w');
 const child=spawn(process.execPath,['port/new-maps/gravemill-foundry/native-journey.mjs',mode],{env:{...process.env,FOUNDRY_EVIDENCE:root,LP_NUM_THREADS:'1'},stdio:['ignore',log,log]});
 const code=await new Promise(resolve=>child.on('exit',resolve));fs.closeSync(log);console.log(`${mode} exited ${code}`);if(code!==0)process.exit(code??1);
}
