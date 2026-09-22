// Redirect the committed product/default-ten-wave smoke's fixed output files.
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
const expected=JSON.parse(readFileSync('port/contracts/source-lock.json')).godot_version;
if(execFileSync(process.env.GODOT_BIN,['--version'],{encoding:'utf8'}).trim()!==expected)throw Error('Pinned engine required');
let code=readFileSync('port/native-horde/scene-smoke.mjs','utf8');
code=code.replace("'./authority.mjs'",JSON.stringify(pathToFileURL(resolve('port/native-horde/authority.mjs')).href));
code=code.replaceAll('port/native-horde/product-smoke','port/reports/horde-independent/product-smoke');
code=code.replace("'XDG_CACHE_HOME'","'XDG_CACHE_HOME','XDG_RUNTIME_DIR'");
code=code.replace('mkdirSync(env[k]);','mkdirSync(env[k],{mode:0o700});');
await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'));
