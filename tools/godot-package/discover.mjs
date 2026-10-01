// Build-time parser: V8 parses actual ESM imports rather than grepping comments.
// Invoke with node --experimental-vm-modules. Nothing here is shipped at play time.
import {SourceTextModule} from 'node:vm';
import {readFileSync, existsSync} from 'node:fs';
import {resolve, dirname, relative} from 'node:path';
import {isBuiltin} from 'node:module';
const root = resolve(process.argv[2]);
const hordeAdapters = ['port/native-horde/authority.mjs', 'port/native-horde/input-buffer.mjs', 'port/native-horde/cinderwake-schema.mjs', 'port/native-horde/robot-roles.mjs', 'port/native-horde/blackwater-schema.mjs', 'port/native-horde/blackwater-director.mjs'];
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
const campaignAdapters = ['authority','maps','match','missions','enemies','story','schema','core.generated']
  .map(name => `port/native-campaign/${name}.mjs`);
const worldAdapters = ['catalog','match','derived/core','derived/payload','derived/room','derived/rooms','derived/game-server']
  .map(name => `port/multiplayer-worlds/${name}.mjs`);
const adapters = [...hordeAdapters, ...nativeArenaAdapters, ...debugAdapters,
  ...localRosterAdapters, ...identityZoneAdapters, ...campaignAdapters, ...worldAdapters];
// Explicit dynamic data-read manifest: the builder hashes committed bytes and
// copies these paths under runtime/, preserving catalog.mjs URL resolution.
// `dataFiles` stays the original native-arena family (existing consumers);
// `identityDataFiles` is the identity-map family added beside it.
const nativeArenaData = ['prism-foundry','aurora-basin','cinder-array']
  .map(id => `godot/native_arenas/generated/${id}.json`);
const identityArenaData = ['lacuna-court','vermilion-fold','nacre-engine','canopy-divide','basalt-reach']
  .map(id => `godot/identity_maps/generated/${id}.json`);
const worldData = ['switchyard-ward','rainmarket-exchange','breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago'].map(id => `godot/multiplayer_worlds/generated/${id}.json`);
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
const campaignEntry = campaignAdapters[0];
const campaign = existsSync(resolve(root, campaignEntry)) ? discover(campaignEntry) : null;
const worldEntry = 'port/multiplayer-worlds/derived/game-server.mjs';
const worlds = existsSync(resolve(root, worldEntry)) ? discover(worldEntry) : null;
const campaignDataFiles = campaign ? ['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array']
  .map(id => `godot/campaign/generated/${id}.json`) : [];
const all = {...ordinary.modules, ...horde.modules, ...nativeArena?.modules, ...identityZones?.modules, ...campaign?.modules, ...worlds?.modules};
const dataFiles = nativeArena ? nativeArenaData : [];
const identityDataFiles = nativeArena || identityZones ? identityArenaData : [];
const hordeDataFiles = [
  ...(Object.hasOwn(horde.modules,'port/native-horde/cinderwake-schema.mjs') ? ['godot/horde_maps/generated/cinderwake-drydock.json'] : []),
  ...(Object.hasOwn(horde.modules,'port/native-horde/blackwater-schema.mjs') ? ['godot/horde_maps/generated/blackwater-reclamation.json'] : []),
];
const sorted = value => Object.fromEntries(Object.entries(value).sort());
const sourceModules = {}, adapterModules = {};
for (const [path, dependencies] of Object.entries(all)) (adapters.includes(path) ? adapterModules : sourceModules)[path] = dependencies;
console.log(JSON.stringify({entry:'server/game-server.mjs', hordeEntry:hordeAdapters[0], nativeArenaEntry,
  identityZoneEntry, campaignEntry,
  modules:sorted(sourceModules), adapterModules:sorted(adapterModules), external:ordinary.external,
  dataFiles, identityDataFiles, hordeDataFiles, campaignDataFiles, worldDataFiles:worlds ? worldData : [],
  dataReads:Object.fromEntries([
    ...(campaign ? [['port/native-campaign/maps.mjs', campaignDataFiles]] : []),
    ...(nativeArena ? [['port/native-arenas/catalog.mjs', [...dataFiles, ...identityDataFiles]]] : []),
    ...(identityZones ? [['port/native-identity-zones/catalog.mjs', [...identityDataFiles]]] : []),
    ...(hordeDataFiles.includes('godot/horde_maps/generated/cinderwake-drydock.json') ? [['port/native-horde/cinderwake-schema.mjs', ['godot/horde_maps/generated/cinderwake-drydock.json']]] : []),
    ...(hordeDataFiles.includes('godot/horde_maps/generated/blackwater-reclamation.json') ? [['port/native-horde/blackwater-schema.mjs', ['godot/horde_maps/generated/blackwater-reclamation.json']]] : []),
    ...(worlds ? [['port/multiplayer-worlds/catalog.mjs',worldData]] : []),
  ]),
  routes:{ordinary:Object.keys(ordinary.modules).sort(), horde:Object.keys(horde.modules).sort(), nativeArena:Object.keys(nativeArena?.modules ?? {}).sort(),
    identityZones:Object.keys(identityZones?.modules ?? {}).sort(), campaign:Object.keys(campaign?.modules ?? {}).sort(), worlds:Object.keys(worlds?.modules ?? {}).sort()},
  nativeArenaAdditionalSource:Object.keys(nativeArena?.modules ?? {}).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort(),
  identityZoneAdditionalSource:Object.keys(identityZones?.modules ?? {}).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p) && !Object.hasOwn(horde.modules,p)).sort(),
  hordeAdditionalSource:Object.keys(horde.modules).filter(p=>!adapters.includes(p) && !Object.hasOwn(ordinary.modules,p)).sort()}, null, 2));
