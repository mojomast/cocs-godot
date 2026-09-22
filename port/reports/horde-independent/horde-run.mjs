// Independent evidence-only wrapper. Executes the committed launcher with its
// authority, scheduler and native driver unchanged. Redirects fresh UUID output,
// records monotonic receipt times and includes this wrapper in launch hashes.
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
let code = readFileSync('port/native-horde/run.mjs', 'utf8');
code = code.replace("'./authority.mjs'", JSON.stringify(pathToFileURL(resolve('port/native-horde/authority.mjs')).href));
code = code.replace("resolve('port/native-horde/evidence',randomUUID())", "resolve('port/reports/horde-independent/evidence',randomUUID())");
code = code.replace('const s=JSON.stringify(record);', 'const s=JSON.stringify({...record,observedMs:performance.now()});');
code = code.replace("const files=['game/core.mjs'", "const files=['port/reports/horde-independent/horde-run.mjs','game/protocol.mjs','godot/world/session.gd','godot/net/client.gd','game/core.mjs'");
if (process.argv.includes('--product-composition')) {
 code = code.replace("'res://tests/horde/live.tscn'", "'res://tests/horde-independent-product.tscn'");
 code = code.replace("const files=[", "const files=['godot/tests/horde-independent-product.gd','godot/tests/horde-independent-product.tscn','godot/horde/demo.tscn','godot/ui/scoreboard.gd',");
}
await import('data:text/javascript;base64,' + Buffer.from(code).toString('base64'));
