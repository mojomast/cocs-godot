// Replay historical raw recording read-only; write only in this new report tree.
import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {revision} from './horde-revision.mjs';
import {validateRun} from '../../native-horde/validate.mjs';
const path='port/reports/horde-repair-independent/evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60';
const old=process.argv.includes('--old'),target=new URL(old?'meridian-old-reject.json':'meridian-new-predicate.json',import.meta.url);
if(existsSync(target))throw Error('Refusing to overwrite replay evidence');
const read=name=>gunzipSync(readFileSync(`${path}/${name}.gz`)).toString();
const input={wire:read('wire.jsonl').split('\n').map(JSON.parse),stdout:read('native.stdout.log'),stderr:read('native.stderr.log'),
 summary:JSON.parse(readFileSync(`${path}/summary.json`)),launch:JSON.parse(readFileSync(`${path}/launch.json`))};
const validate=old?(await revision('3dbcceb91c2e1542c91e7e2e3fda55ff43a94cb2','port/native-horde/validate.mjs')).module.validateRun:validateRun;
let output;
try {output={status:'PASS',scope:'predicate replay only; historical event defect remains',originalRecording:path,validation:validate(input)};}
catch(error){output={status:'REJECT',originalRecording:path,error:error.stack};process.exitCode=1;}
writeFileSync(target,JSON.stringify(output,null,2)+'\n');console.log(JSON.stringify(output,null,2));
