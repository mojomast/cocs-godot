// Build-time parser: V8 parses actual ESM imports rather than grepping comments.
// Invoke with node --experimental-vm-modules. Nothing here is shipped at play time.
import {SourceTextModule} from 'node:vm';
import {readFileSync, existsSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {isBuiltin} from 'node:module';
const root = resolve(process.argv[2]);
const hordeAdapters = ['port/native-horde/authority.mjs', 'port/native-horde/input-buffer.mjs'];
// Reviewed port-owned runtime inputs only. New helpers require a manifest edit.
const nativeArenaAdapters = ['port/native-arenas/authority.mjs', 'port/native-arenas/match.mjs',
  'port/native-arenas/schema.mjs', 'port/native-arenas/catalog.mjs'];
const adapters = [...hordeAdapters, ...nativeArenaAdapters];
// Explicit dynamic data-read manifest: the builder hashes committed bytes and
// copies these paths under runtime/, preserving catalog.mjs URL resolution.
const nativeArenaData = ['prism-foundry','aurora-basin','cinder-array']
  .map(id => `godot/native_arenas/generated/${id}.json`);
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
const ordinary = discover('server/game-server.mjs'), horde = discover(hordeAdapters[0]);
const nativeArenaEntry = nativeArenaAdapters[0];
// During parallel implementation the entry may be absent; an existing entry
// must have a complete static closure. Data existence is checked by the builder.
const nativeArena = existsSync(resolve(root, nativeArenaEntry)) ? discover(nativeArenaEntry) : null;
const all = {...ordinary.modules, ...horde.modules, ...nativeArena?.modules};
const dataFiles = nativeArena ? nativeArenaData : [];
const sorted = value => Object.fromEntries(Object.entries(value).sort());
const sourceModules = {}, adapterModules = {};
for (const [path, dependencies] of Object.entries(all)) (adapters.includes(path) ? adapterModules : sourceModules)[path] = dependencies;
console.log(JSON.stringify({entry:'server/game-server.mjs', hordeEntry:hordeAdapters[0], nativeArenaEntry,
  modules:sorted(sourceModules), adapterModules:sorted(adapterModules), external:ordinary.external,
  dataFiles, dataReads:nativeArena ? {'port/native-arenas/catalog.mjs':dataFiles} : {},
  routes:{ordinary:Object.keys(ordinary.modules).sort(), horde:Object.keys(horde.modules).sort(), nativeArena:Object.keys(nativeArena?.modules ?? {}).sort()},
  nativeArenaAdditionalSource:Object.keys(nativeArena?.modules ?? {}).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort(),
  hordeAdditionalSource:Object.keys(horde.modules).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort()}, null, 2));
