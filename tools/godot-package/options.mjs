// Package-only routing. Source clients retain their own capability/protocol gates.
import {lobbyEndpoint} from './endpoint.mjs';
export const EXPERIENCES = {
  combat: {scene:'res://world/session.tscn', maps:{'meridian-exchange':['deathmatch','teamdeathmatch','instagib','rockets'], 'verdant-reliquary':['deathmatch','teamdeathmatch','instagib','rockets'], 'ember-crucible':['deathmatch','teamdeathmatch','instagib','rockets']}},
  lobby: {scene:'res://world/session.tscn', maps:{'meridian-exchange':['deathmatch','teamdeathmatch','instagib','rockets'], 'verdant-reliquary':['deathmatch','teamdeathmatch','instagib','rockets'], 'ember-crucible':['deathmatch','teamdeathmatch','instagib','rockets']}},
  'arms-race': {scene:'res://arms_race/demo.tscn', maps:{'meridian-exchange':['armsrace'], 'verdant-reliquary':['armsrace'], 'ember-crucible':['armsrace']}},
  horde: {scene:'res://horde/demo.tscn', maps:{'meridian-exchange':['horde'], 'verdant-reliquary':['horde'], 'ember-crucible':['horde']}},
  zones: {scene:'res://zone_modes/demo.tscn', maps:{'meridian-exchange':['domination','koth'], 'verdant-reliquary':['koth','domination'], 'ember-crucible':['koth','domination'], 'tidal-citadel':['domination'], 'sunscar-convoy':['domination']}},
  'combined-arms': {scene:'res://combined_arms/demo.tscn', maps:{'sunscar-convoy':['combined-arms']}},
  sports: {scene:'res://sports/demo.tscn', maps:{'ion-speedway':['puma-race'], 'aurora-stadium':['puma-soccer']}},
  objectives: {scene:'res://objectives/demo.tscn', maps:{'tidal-citadel':['ctf'], 'sunscar-convoy':['payload']}},
  lattice: {scene:'res://lattice/board.tscn', maps:{'asterion-relay':['cocs','cocs-coop'], 'monsoon-foundry':['cocs','cocs-coop']}},
  'lattice-world': {scene:'res://lattice/world_demo.tscn', maps:{'asterion-relay':['cocs','cocs-coop'], 'monsoon-foundry':['cocs','cocs-coop']}},
};

// Standalone exploration/labs, deliberately outside the source map routes.
export const NATIVE_EXPERIENCES = {
  showcase: {scene:'res://showcase/demo.tscn'},
  'aurora-basin': {scene:'res://aurora_basin/demo.tscn'},
  'cinder-array': {scene:'res://cinder_array/demo.tscn'},
  'particle-lab': {scene:'res://particle_lab/demo.tscn'},
  'shader-lab': {scene:'res://shader_lab/demo.tscn'},
};

// Deathmatch roster: the three original native arenas plus the three identity
// maps. Every entry is a reviewed static asset resolved by id only.
export const IDENTITY_ARENA_MAPS = ['lacuna-court','vermilion-fold','nacre-engine'];
export const NATIVE_ARENA_MAPS = ['prism-foundry','aurora-basin','cinder-array',...IDENTITY_ARENA_MAPS];

export function options(argv, catalog) {
  const values = {}, flags = new Set();
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const key = ['experience','map','mode','endpoint','time-limit','round-target','bots','round-seconds'].find(k => arg === `--${k}` || arg.startsWith(`--${k}=`));
    if (key) {
      const value = arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : argv[++i];
      const maxLength = key === 'endpoint' ? 2048 : 64;
      if (!value || value.startsWith('--') || value.length > maxLength) throw Error(`--${key} requires a value of 1..${maxLength} characters`);
      if (Object.hasOwn(values, key)) throw Error(`Duplicate --${key}`);
      values[key] = value;
    } else if (['--play','--setup','--native-trace','--mute','--debug-hud','--smoke'].includes(arg)) {
      if (flags.has(arg)) throw Error(`Duplicate ${arg}`);
      flags.add(arg);
    } else throw Error(`Unknown option ${arg}. Use --help.`);
  }
  const experience = values.experience ?? 'combat';
  if (experience === 'native-dm') {
    for (const key of Object.keys(values)) if (!['experience','map','mode','bots','round-seconds'].includes(key)) throw Error(`--${key} is not supported by native-dm`);
    for (const flag of flags) if (flag !== '--smoke') throw Error(`${flag} is not supported by native-dm`);
    const map = values.map ?? NATIVE_ARENA_MAPS[0], mode = values.mode ?? 'deathmatch';
    if (!NATIVE_ARENA_MAPS.includes(map)) throw Error(`native-dm does not support map ${map}`);
    if (mode !== 'deathmatch') throw Error('native-dm supports only deathmatch');
    for (const [key, min, max, fallback] of [['bots',1,7,2],['round-seconds',60,300,180]]) {
      values[key] ??= String(fallback);
      if (!/^\d+$/.test(values[key]) || Number(values[key]) < min || Number(values[key]) > max) throw Error(`--${key} must be ${min}..${max}`);
    }
    const bots = Number(values.bots), roundSeconds = Number(values['round-seconds']);
    return {experience, nativeArena:true, map, mode, bots, roundSeconds, endpoint:null, scene:'res://native_arenas/demo.tscn',
      userArgs:[`--map=${map}`,`--mode=${mode}`,`--bots=${bots}`,`--round-seconds=${roundSeconds}`,...(flags.has('--smoke') ? ['--smoke'] : [])]};
  }
  for (const key of ['bots','round-seconds']) if (values[key] !== undefined) throw Error(`--${key} requires native-dm`);
  if (Object.hasOwn(NATIVE_EXPERIENCES, experience)) {
    for (const key of Object.keys(values)) if (key !== 'experience') throw Error(`--${key} is not supported by native-only ${experience}`);
    for (const flag of flags) if (flag !== '--smoke') throw Error(`${flag} is not supported by native-only ${experience}`);
    return {experience, scene:NATIVE_EXPERIENCES[experience].scene, nativeOnly:true, endpoint:null, userArgs:flags.has('--smoke') ? ['--smoke'] : []};
  }
  if (!Object.hasOwn(EXPERIENCES, experience)) throw Error(`Unknown experience: ${experience}`);
  const endpoint = lobbyEndpoint(values.endpoint, experience);
  const selected = EXPERIENCES[experience];
  const map = values.map ?? Object.keys(selected.maps)[0];
  if (!Object.hasOwn(selected.maps, map)) throw Error(`${experience} does not support map ${map}`);
  const mode = values.mode ?? selected.maps[map][0];
  if (!selected.maps[map].includes(mode) || !catalog.maps.find(m => m.id === map)?.supported_modes.includes(mode)) throw Error(`Unsupported ${map} / ${mode}`);
  if (flags.has('--play') && flags.has('--setup')) throw Error('Choose --play or --setup');
  if (flags.has('--smoke') && (flags.has('--play') || flags.has('--setup'))) throw Error('--smoke cannot be combined with --play or --setup');
  for (const flag of ['--play','--setup','--mute','--debug-hud','--smoke']) if (flags.has(flag) && experience !== 'combat') throw Error(`${flag} requires combat`);
  if (flags.has('--native-trace') && !['combat','lattice-world'].includes(experience)) throw Error('--native-trace requires combat or lattice-world');
  for (const key of ['time-limit','round-target']) {
    if (values[key] === undefined) continue;
    if (experience !== 'sports') throw Error(`--${key} requires sports`);
    const min = key === 'time-limit' ? 60 : 1;
    const max = key === 'time-limit' ? 900 : map === 'ion-speedway' ? 10 : 15;
    if (!/^\d+$/.test(values[key]) || !Number.isSafeInteger(Number(values[key])) || Number(values[key]) < min || Number(values[key]) > max) throw Error(`--${key} must be ${min}..${max}`);
  }
  const userArgs = [`--map=${map}`, `--mode=${mode}`];
  for (const key of ['time-limit','round-target']) if (values[key] !== undefined) userArgs.push(`--${key}=${values[key]}`);
  for (const flag of ['--native-trace','--mute','--debug-hud']) if (flags.has(flag)) userArgs.push(flag);
  if (flags.has('--smoke')) userArgs.push('--session-smoke');
  if (experience === 'combat' && !flags.has('--play') && !flags.has('--smoke')) userArgs.push('--setup');
  if (experience === 'lobby') userArgs.push('--lobby-menu');
  return {experience, map, mode, scene:selected.scene, userArgs, endpoint};
}

export const HELP = `COCS native demo — Node >=22.13.0 (bundled on Windows)
  node run.mjs                              Native combat host setup
  node run.mjs --experience=lobby            Multiplayer lobby, owned loopback server
  node run.mjs --experience=lobby --endpoint=ws://127.0.0.1:PORT
  node run.mjs --play --map=meridian-exchange --mode=deathmatch
  node run.mjs --experience=zones --map=meridian-exchange --mode=domination
  node run.mjs --experience=zones --map=verdant-reliquary --mode=koth
  node run.mjs --experience=combined-arms
  node run.mjs --experience=arms-race --map=meridian-exchange
  node run.mjs --experience=horde --map=meridian-exchange
  node run.mjs --experience=sports --map=ion-speedway
  node run.mjs --experience=sports --map=aurora-stadium
  node run.mjs --experience=objectives --map=tidal-citadel
  node run.mjs --experience=objectives --map=sunscar-convoy
  node run.mjs --experience=lattice --map=asterion-relay --mode=cocs
  node run.mjs --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
  node run.mjs --experience=showcase
  node run.mjs --experience=aurora-basin
  node run.mjs --experience=cinder-array
  node run.mjs --experience=particle-lab
  node run.mjs --experience=shader-lab --smoke
  node run.mjs --experience=native-dm --map=prism-foundry
  node run.mjs --experience=native-dm --map=cinder-array --bots=4 --round-seconds=120 --smoke
  node run.mjs --experience=native-dm --map=lacuna-court
  node run.mjs --experience=native-dm --map=vermilion-fold --smoke
  node run.mjs --experience=native-dm --map=nacre-engine

Native-only graphics: showcase, aurora-basin, cinder-array, particle-lab, shader-lab.
  Standalone exploration/labs; no Node authority, network endpoint or source match.
  These are not source map catalog choices. Only --smoke is supported in addition
  to --experience: runs the scene's own diagnostic headlessly with Dummy audio.
  --map, --mode, --endpoint and source-match controls are rejected.

Combat: 3 combat maps; deathmatch/teamdeathmatch/instagib/rockets.
Native DM: prism-foundry (default), aurora-basin, cinder-array, lacuna-court,
  vermilion-fold, nacre-engine; Deathmatch only.
  Owned local loopback authority, one human plus --bots=1..7 (default 2).
  --round-seconds=60..300 (default 180). No endpoint, join or setup options.
  --smoke runs the scene headlessly with Dummy audio, bounded to 20 seconds.
Lobby: explicit Create/Join/Start; guests select the expected host map.
  With --endpoint, no authority is created or stopped. Escape exposes Leave.
  --play skips setup; --setup, --mute, --debug-hud supported.
Sports: --time-limit=60..900; --round-target=1..10 laps or 1..15 goals.
Horde: three combat arenas; local-only solo authority, default ten waves.
  Click to engage; Tab scores; Escape releases controls; Enter restarts results.
Arms Race: three combat arenas; two Normal bots, ten weapons, 180-second rounds.
  Source locks weapons. Click to engage; Enter restarts results.
Zones: koth/domination on combat arenas; domination on Tidal/Sunscar.
  Two bots, 60-second rounds. Click to engage; Enter restarts results.
Combined arms: Sunscar Puma slice. Enter engages; E mounts/exits; Space brake tap.
LATTICE board: click Connect / start. LATTICE world starts directly.
--native-trace is available for combat and lattice-world.
Combat --smoke runs the network diagnostic headlessly and exits automatically.
Source-match routes own a fresh loopback port unless using an external lobby.
Close the window or Ctrl+C to stop the owned native process.
No editor, git, npm, installation, or source checkout is needed to play.
Private prototype only; source asset redistribution rights remain unresolved.
`;
