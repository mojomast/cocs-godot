// Execute the reviewed launcher unchanged except owned output root/import and
// explicit independent provenance. Product, input steering and clock are exact.
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
let source=readFileSync('port/native-horde/run.mjs','utf8');
function replaceOnce(before,after) {
 if(source.split(before).length!==2)throw Error(`Launcher anchor changed: ${before}`);
 source=source.replace(before,after);
}
replaceOnce("from './authority.mjs'",`from '${pathToFileURL(resolve('port/native-horde/authority.mjs')).href}'`);
replaceOnce("resolve('port/reports/horde-repair/evidence')","resolve('port/reports/horde-repair-independent/evidence')");
replaceOnce("'fresh horde-repair, two per map/scenario, native 170s/outer 180s'","'fresh independent repair review, two per map/scenario, native 170s/outer 180s'");
replaceOnce("'port/native-horde/validate.mjs'];","'port/native-horde/validate.mjs','port/reports/horde-repair-independent/horde-run.mjs'];");
await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
