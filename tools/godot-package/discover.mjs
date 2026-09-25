// Build-time parser: V8 parses actual ESM imports rather than grepping comments.
// Invoke with node --experimental-vm-modules. Nothing here is shipped at play time.
import {SourceTextModule} from 'node:vm';
import {readFileSync, existsSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {isBuiltin} from 'node:module';
const root = resolve(process.argv[2]);
const hordeAdapters = ['port/native-horde/authority.mjs', 'port/native-horde/input-buffer.mjs', 'port/native-horde/cinderwake-schema.mjs'];
// Reviewed port-owned runtime inputs only. New helpers require a manifest edit.
const nativeArenaAdapters = ['port/native-arenas/authority.mjs', 'port/native-arenas/match.mjs',
  'port/native-arenas/schema.mjs', 'port/native-arenas/catalog.mjs',
  'port/native-arenas/input-buffer.mjs', 'port/native-arenas/event-cursor.mjs'];
// Debug reconciliation is imported by BOTH local authorities and by nothing on
// the ordinary/multi-human route. One reviewed adapter module, listed here so
// the shipped closure stays explicit.
const debugAdapters = ['port/native-debug/debug.mjs'];
// Local 24-seat construction and route-scoped debug parsing are imported only
// by the two native authorities. Include these exact reviewed helpers in the
// packaged runtime closure, never by a wildcard directory scan.
const localRosterAdapters = ['port/native-menu-debug-bots/debug-frame.mjs',
  'port/native-menu-debug-bots/seats.mjs'];
// The reviewed Domination route on Vermilion Fold: its own authority, match
// adapter and static catalog, exactly like the native-arena family.
const identityZoneAdapters = ['port/native-identity-zones/authority.mjs',
  'port/native-identity-zones/match.mjs', 'port/native-identity-zones/catalog.mjs'];
const adapters = [...hordeAdapters, ...nativeArenaAdapters, ...debugAdapters,
  ...localRosterAdapters, ...identityZoneAdapters];
// Explicit dynamic data-read manifest: the builder hashes committed bytes and
// copies these paths under runtime/, preserving catalog.mjs URL resolution.
// `dataFiles` stays the original native-arena family (existing consumers);
// `identityDataFiles` is the identity-map family added beside it.
const nativeArenaData = ['prism-foundry','aurora-basin','cinder-array']
  .map(id => `godot/native_arenas/generated/${id}.json`);
const identityArenaData = ['lacuna-court','vermilion-fold','nacre-engine']
  .map(id => `godot/identity_maps/generated/${id}.json`);
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
    const parsedModule = new SourceTextModule(source, {identifier:path});
    modules[path] = [...parsedModule.dependencySpecifiers];
    for (const spec of parsedModule.dependencySpecifiers) {
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
const identityZoneEntry = identityZoneAdapters[0];
const identityZones = existsSync(resolve(root, identityZoneEntry)) ? discover(identityZoneEntry) : null;
const all = {...ordinary.modules, ...horde.modules, ...nativeArena?.modules, ...identityZones?.modules};
const dataFiles = nativeArena ? nativeArenaData : [];
const identityDataFiles = nativeArena || identityZones ? identityArenaData : [];
const hordeDataFiles = Object.hasOwn(horde.modules,'port/native-horde/cinderwake-schema.mjs') ? ['godot/horde_maps/generated/cinderwake-drydock.json'] : [];
const sorted = value => Object.fromEntries(Object.entries(value).sort());
const sourceModules = {}, adapterModules = {};
for (const [path, dependencies] of Object.entries(all)) (adapters.includes(path) ? adapterModules : sourceModules)[path] = dependencies;
console.log(JSON.stringify({entry:'server/game-server.mjs', hordeEntry:hordeAdapters[0], nativeArenaEntry,
  identityZoneEntry,
  modules:sorted(sourceModules), adapterModules:sorted(adapterModules), external:ordinary.external,
  dataFiles, identityDataFiles, hordeDataFiles,
  dataReads:Object.fromEntries([
    ...(hordeDataFiles.length ? [['port/native-horde/cinderwake-schema.mjs', hordeDataFiles]] : []),
    ...(nativeArena ? [['port/native-arenas/catalog.mjs', [...dataFiles, ...identityDataFiles]]] : []),
    ...(identityZones ? [['port/native-identity-zones/catalog.mjs', [...identityDataFiles]]] : []),
  ]),
  routes:{ordinary:Object.keys(ordinary.modules).sort(), horde:Object.keys(horde.modules).sort(), nativeArena:Object.keys(nativeArena?.modules ?? {}).sort(),
    identityZones:Object.keys(identityZones?.modules ?? {}).sort()},
  nativeArenaAdditionalSource:Object.keys(nativeArena?.modules ?? {}).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort(),
  identityZoneAdditionalSource:Object.keys(identityZones?.modules ?? {}).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p) && !Object.hasOwn(horde.modules,p)).sort(),
  hordeAdditionalSource:Object.keys(horde.modules).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort()}, null, 2));
