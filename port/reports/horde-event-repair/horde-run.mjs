// Same actual product/observer/steering and normal clock as the committed
// launcher. Only output/provenance differs; a read-only object oracle observes
// the adapter cursor boundary without editing Match, its state or source code.
import {readFileSync,readdirSync,existsSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {gzipSync} from 'node:zlib';
import {EventCursor} from '../../native-horde/authority.mjs';
import {installCursorOracle} from './horde-object-oracle.mjs';
if(process.argv.includes('--manual')||process.argv.some(s=>s.startsWith('--map=')&&s!=='--map=meridian-exchange'))throw Error('Only bounded Meridian is authorized');
const root=resolve('port/reports/horde-event-repair/evidence');
const before=new Set(existsSync(root)?readdirSync(root):[]);
const {oracle,restore}=installCursorOracle(EventCursor);
let source=readFileSync('port/native-horde/run.mjs','utf8');
function replaceOnce(a,b){if(source.split(a).length!==2)throw Error(`Launcher anchor changed: ${a}`);source=source.replace(a,b);}
replaceOnce("from './authority.mjs'",`from '${pathToFileURL(resolve('port/native-horde/authority.mjs')).href}'`);
replaceOnce("resolve('port/reports/horde-repair/evidence')","resolve('port/reports/horde-event-repair/evidence')");
replaceOnce("'fresh horde-repair, two per map/scenario, native 170s/outer 180s'","'fresh event repair, two Meridian attempts maximum, native 170s/outer 180s'");
replaceOnce("'port/native-horde/validate.mjs'];","'port/native-horde/validate.mjs','port/reports/horde-event-repair/horde-run.mjs','port/reports/horde-event-repair/horde-object-oracle.mjs'];");
try {await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));}
finally {
 restore();
 const added=(existsSync(root)?readdirSync(root):[]).filter(id=>!before.has(id));
 if(added.length!==1)throw Error('Expected exactly one new run directory');
 const folder=resolve(root,added[0]);
 writeFileSync(resolve(folder,'source-object-oracle.jsonl.gz'),gzipSync(oracle.records.map(r=>JSON.stringify(r)).join('\n')));
 writeFileSync(resolve(folder,'source-object-oracle.json'),JSON.stringify(oracle.summary(),null,2)+'\n');
 console.log('SOURCE_OBJECT_ORACLE',JSON.stringify(oracle.summary()));
 if(!oracle.summary().passed||oracle.summary().matchCount!==2)process.exitCode=1;
}
