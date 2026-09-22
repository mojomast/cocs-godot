// Scene routing only: capability and protocol checks still belong to each client.
import {lobbyEndpoint} from '../godot-package/endpoint.mjs';
export const EXPERIENCES = {
  combat: {scene:'res://world/session.tscn', map:'meridian-exchange'},
  lobby: {scene:'res://world/session.tscn', map:'meridian-exchange', modes:{'meridian-exchange':['deathmatch','teamdeathmatch','instagib','rockets'], 'verdant-reliquary':['deathmatch','teamdeathmatch','instagib','rockets'], 'ember-crucible':['deathmatch','teamdeathmatch','instagib','rockets']}},
  'arms-race': {scene:'res://arms_race/demo.tscn', map:'meridian-exchange', modes:{'meridian-exchange':['armsrace'], 'verdant-reliquary':['armsrace'], 'ember-crucible':['armsrace']}},
  horde: {scene:'res://horde/demo.tscn', map:'meridian-exchange', modes:{'meridian-exchange':['horde'], 'verdant-reliquary':['horde'], 'ember-crucible':['horde']}},
  zones: {scene:'res://zone_modes/demo.tscn', map:'meridian-exchange', modes:{'meridian-exchange':['domination','koth'], 'verdant-reliquary':['koth','domination'], 'ember-crucible':['koth','domination'], 'tidal-citadel':['domination'], 'sunscar-convoy':['domination']}},
  'combined-arms': {scene:'res://combined_arms/demo.tscn', map:'sunscar-convoy', modes:{'sunscar-convoy':['combined-arms']}},
  sports: {scene:'res://sports/demo.tscn', map:'ion-speedway', modes:{'ion-speedway':['puma-race'], 'aurora-stadium':['puma-soccer']}},
  objectives: {scene:'res://objectives/demo.tscn', map:'tidal-citadel', modes:{'tidal-citadel':['ctf'], 'sunscar-convoy':['payload']}},
  lattice: {scene:'res://lattice/board.tscn', map:'asterion-relay', modes:{'asterion-relay':['cocs','cocs-coop'], 'monsoon-foundry':['cocs','cocs-coop']}},
  'lattice-world': {scene:'res://lattice/world_demo.tscn', map:'asterion-relay', modes:{'asterion-relay':['cocs','cocs-coop'], 'monsoon-foundry':['cocs','cocs-coop']}},
};

// Standalone exploration/labs, deliberately outside the source map routes.
export const NATIVE_EXPERIENCES = {
  showcase: {scene:'res://showcase/demo.tscn'},
  'aurora-basin': {scene:'res://aurora_basin/demo.tscn'},
  'cinder-array': {scene:'res://cinder_array/demo.tscn'},
  'particle-lab': {scene:'res://particle_lab/demo.tscn'},
  'shader-lab': {scene:'res://shader_lab/demo.tscn'},
};

export function launchOptions(argv, catalog) {
  const values = {}, flags = new Set(), sessionOptions = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const key = ['map','mode','experience','endpoint','time-limit','round-target'].find(key => arg === `--${key}` || arg.startsWith(`--${key}=`));
    if (key) {
      const value = arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : argv[++i];
      if (!value || value.startsWith('--')) throw Error(`--${key} requires a value`);
      if (values[key] !== undefined) throw Error(`--${key} must be supplied once`);
      values[key] = value;
    } else if (['--play','--setup','--native-trace','--mute','--debug-hud','--smoke','--network-smoke','--session-smoke','--lifecycle-smoke'].includes(arg)) {
      if (arg === '--smoke' && flags.has(arg)) throw Error(`Duplicate ${arg}`);
      flags.add(arg);
    } else throw Error(`Unknown launcher option: ${arg}. Use --help.`);
  }
  const smokeFlags = ['--network-smoke','--session-smoke','--lifecycle-smoke'].filter(arg => flags.has(arg));
  if (smokeFlags.length > 1) throw Error('Select one smoke check at a time');
  const play = flags.has('--play') || flags.has('--setup') || values.experience || values.map || values.mode ||
    ['--native-trace','--mute','--debug-hud','--session-smoke','--lifecycle-smoke'].some(arg => flags.has(arg));
  const experience = values.experience ?? 'combat';
  if (Object.hasOwn(NATIVE_EXPERIENCES, experience)) {
    for (const key of Object.keys(values)) if (key !== 'experience') throw Error(`--${key} is not supported by native-only ${experience}`);
    for (const flag of flags) if (flag !== '--smoke') throw Error(`${flag} is not supported by native-only ${experience}`);
    const smoke = flags.has('--smoke') ? '--smoke' : null;
    return {experience, nativeOnly:true, endpoint:null, smoke, sessionOptions:smoke ? [smoke] : [],
      args:[...(smoke ? ['--headless','--audio-driver','Dummy'] : []),'--path','godot',NATIVE_EXPERIENCES[experience].scene]};
  }
  if (flags.has('--smoke')) throw Error('--smoke is supported only by native-only graphics routes; combat uses --network-smoke, --session-smoke or --lifecycle-smoke');
  const selected = Object.hasOwn(EXPERIENCES, experience) ? EXPERIENCES[experience] : null;
  if (!selected) throw Error(`Unknown experience: ${experience}. Choose ${[...Object.keys(EXPERIENCES),...Object.keys(NATIVE_EXPERIENCES)].join(', ')}.`);
  const endpoint = lobbyEndpoint(values.endpoint, experience);
  for (const key of ['time-limit','round-target']) {
    if (values[key] === undefined) continue;
    if (experience !== 'sports') throw Error(`--${key} is supported only by the sports launcher`);
    if (!/^\d+$/.test(values[key])) throw Error(`--${key} must be a whole number`);
  }
  if (experience !== 'combat') {
    for (const arg of ['--setup','--native-trace','--debug-hud',...smokeFlags]) {
      if (flags.has(arg)) throw Error(`${arg} is supported only by the combat launcher`);
    }
    // Do not promise mute support for standalone scenes that do not implement it.
    if (flags.has('--mute')) throw Error('--mute is supported only by the combat launcher');
    values.map ??= selected.map;
    const modes = Object.hasOwn(selected.modes, values.map) ? selected.modes[values.map] : null;
    if (!modes) throw Error(`${experience} does not support map ${values.map}`);
    values.mode ??= modes[0];
    if (!modes.includes(values.mode)) throw Error(`${values.map} does not support native ${experience} mode ${values.mode}`);
    const locked = catalog.maps.find(map => map.id === values.map);
    if (!locked?.supported_modes.includes(values.mode)) throw Error('Selected map/mode is not in the locked catalog');
  }
  if (values['time-limit'] !== undefined && (Number(values['time-limit']) < 60 || Number(values['time-limit']) > 900)) {
    throw Error('--time-limit must be 60..900 seconds');
  }
  const maxTarget = values.map === 'ion-speedway' ? 10 : 15;
  if (values['round-target'] !== undefined && (Number(values['round-target']) < 1 || Number(values['round-target']) > maxTarget)) {
    throw Error(`--round-target must be 1..${maxTarget} for the selected sports map`);
  }
  for (const key of ['map','mode','time-limit','round-target']) if (values[key]) sessionOptions.push(`--${key}=${values[key]}`);
  for (const flag of ['--setup','--native-trace','--mute','--debug-hud']) if (flags.has(flag)) sessionOptions.push(flag);
  const smoke = smokeFlags[0];
  if (experience === 'lobby') sessionOptions.push('--lobby-menu');
  const args = smoke === '--network-smoke'
    ? ['--headless','--path','godot','--script','res://tests/protocol/live.gd']
    : [...(smoke ? ['--headless'] : []),'--path','godot',...(play ? [selected.scene] : [])];
  if (smoke && smoke !== '--network-smoke') sessionOptions.push(smoke);
  return {args, sessionOptions, experience:play ? experience : 'viewer', smoke:smoke ?? null, endpoint};
}

export const HELP = `Native COCS launcher — source matches and native-only graphics

  node tools/godot-dev/launch.mjs --play --setup
  node tools/godot-dev/launch.mjs --experience=lobby
  node tools/godot-dev/launch.mjs --experience=lobby --endpoint=ws://127.0.0.1:PORT
  node tools/godot-dev/launch.mjs --experience=zones --map=meridian-exchange --mode=domination
  node tools/godot-dev/launch.mjs --experience=zones --map=verdant-reliquary --mode=koth
  node tools/godot-dev/launch.mjs --experience=combined-arms
  node tools/godot-dev/launch.mjs --experience=arms-race --map=meridian-exchange
  node tools/godot-dev/launch.mjs --experience=horde --map=meridian-exchange
  node tools/godot-dev/launch.mjs --experience=sports --map=ion-speedway
  node tools/godot-dev/launch.mjs --experience=sports --map=aurora-stadium
  node tools/godot-dev/launch.mjs --experience=objectives --map=tidal-citadel
  node tools/godot-dev/launch.mjs --experience=objectives --map=sunscar-convoy
  node tools/godot-dev/launch.mjs --experience=lattice --map=asterion-relay --mode=cocs
  node tools/godot-dev/launch.mjs --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
  node tools/godot-dev/launch.mjs --experience=showcase
  node tools/godot-dev/launch.mjs --experience=aurora-basin
  node tools/godot-dev/launch.mjs --experience=cinder-array
  node tools/godot-dev/launch.mjs --experience=particle-lab
  node tools/godot-dev/launch.mjs --experience=shader-lab --smoke

Set GODOT_BIN to the pinned Godot 4.5.2 binary. Run semantic export and import first.
Source matches: PORT=0 (default) allocates a free port; normal simulation timing.
Close the client or press Ctrl+C to stop the owned native process.
Interactive sessions have no harness deadline. With no options, open the map viewer.
Native-only graphics: showcase, aurora-basin, cinder-array, particle-lab, shader-lab.
  Standalone exploration/labs; no Node authority, network endpoint or source match.
  These are not source map catalog choices. Only --smoke is supported in addition
  to --experience: runs the scene's own diagnostic headlessly with Dummy audio.
  --map, --mode, --endpoint and source-match controls are rejected.
Lobby: explicit Host/Create or Guest/Join, roster and host-only Start/Restart.
  Without --endpoint, owns a loopback authority; share its printed endpoint/code.
  With --endpoint, uses the existing authority and never starts or closes it.
  Guests select the expected host map. Escape exposes Leave match.

Combat: --map, --mode, --setup, --mute, --debug-hud, --native-trace
Horde: three combat arenas; local-only solo authority, default ten waves.
  Click to engage; Tab scores; Escape releases controls; Enter restarts results.
Arms Race: three combat arenas; two Normal bots, ten weapons, 180-second rounds.
  Source locks weapon selection. Click to engage; Enter restarts results.
Zones: koth/domination on the three combat arenas; domination on Tidal/Sunscar.
  Click to engage; Enter restarts results. Two source bots, 60-second rounds.
Combined arms: Sunscar Puma driving slice; Enter engages, E mounts/exits.
  Seat changes require fresh Enter/movement. Space is a brake tap while driving.
Sports: ion-speedway (puma-race), aurora-stadium (puma-soccer)
  Optional --time-limit=60..900 and --round-target=1..10 laps or 1..15 goals
Objectives: tidal-citadel (ctf), sunscar-convoy (payload)
LATTICE: asterion-relay or monsoon-foundry; --mode=cocs or cocs-coop
  Click Connect / start in the command board to begin.
LATTICE world: --experience=lattice-world with the same maps/modes
  Click to engage, WASD/mouse to move/look, Escape to release. Standalone host.
Checks: --network-smoke, --session-smoke or --lifecycle-smoke (combat only)
`;
