// Build-time parser: V8 parses actual ESM imports rather than grepping comments.
// Invoke with node --experimental-vm-modules. Nothing here is shipped at play time.
import {SourceTextModule} from 'node:vm';
import {readFileSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {isBuiltin} from 'node:module';
const root = resolve(process.argv[2]);
const adapters = ['port/native-horde/authority.mjs', 'port/native-horde/input-buffer.mjs'];
function discover(entry) {
  const pending = [entry], modules = {}, external = new Set();
  while (pending.length) {
    const path = pending.pop();
    if (Object.hasOwn(modules, path)) continue;
    if ((!/^(server|game)\/.+\.mjs$/.test(path) && !adapters.includes(path)) || path.includes('..') || path.includes('.test.')) throw Error(`Unexpected runtime input: ${path}`);
    const source = readFileSync(resolve(root, path), 'utf8');
    // Conservative review tripwire, including comments: computed/runtime module
    // loading is outside this static closure contract. Never silently omit it.
    if (/\b(?:import|require|eval|Function)\s*\(|\bcreateRequire\b/.test(source)) throw Error(`Review runtime loading in ${path}`);
    const module = new SourceTextModule(source, {identifier:path});
    modules[path] = [...module.dependencySpecifiers];
    for (const spec of module.dependencySpecifiers) {
      if (spec.startsWith('.')) pending.push(relative(root, resolve(root, dirname(path), spec)));
      else if (!isBuiltin(spec)) external.add(spec);
    }
  }
  if (JSON.stringify([...external].sort()) !== '["ws"]') throw Error(`Review new external dependencies: ${[...external]}`);
  return {modules, external:[...external].sort()};
}
const ordinary = discover('server/game-server.mjs'), horde = discover(adapters[0]);
const all = {...ordinary.modules, ...horde.modules};
const sorted = value => Object.fromEntries(Object.entries(value).sort());
const sourceModules = {}, adapterModules = {};
for (const [path, dependencies] of Object.entries(all)) (adapters.includes(path) ? adapterModules : sourceModules)[path] = dependencies;
console.log(JSON.stringify({entry:'server/game-server.mjs', hordeEntry:adapters[0],
  modules:sorted(sourceModules), adapterModules:sorted(adapterModules), external:ordinary.external,
  routes:{ordinary:Object.keys(ordinary.modules).sort(), horde:Object.keys(horde.modules).sort()},
  hordeAdditionalSource:Object.keys(horde.modules).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort()}, null, 2));
