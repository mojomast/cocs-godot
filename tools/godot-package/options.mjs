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

export function options(argv, catalog) {
  const values = {}, flags = new Set();
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const key = ['experience','map','mode','endpoint','time-limit','round-target'].find(k => arg === `--${k}` || arg.startsWith(`--${k}=`));
    if (key) {
      const value = arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : argv[++i];
      const maxLength = key === 'endpoint' ? 2048 : 64;
      if (!value || value.startsWith('--') || value.length > maxLength) throw Error(`--${key} requires a value of 1..${maxLength} characters`);
      if (Object.hasOwn(values, key)) throw Error(`Duplicate --${key}`);
      values[key] = value;
    } else if (['--play','--setup','--native-trace','--mute','--debug-hud'].includes(arg)) {
      if (flags.has(arg)) throw Error(`Duplicate ${arg}`);
      flags.add(arg);
    } else throw Error(`Unknown option ${arg}. Use --help.`);
  }
  const experience = values.experience ?? 'combat';
  if (!Object.hasOwn(EXPERIENCES, experience)) throw Error(`Unknown experience: ${experience}`);
  const endpoint = lobbyEndpoint(values.endpoint, experience);
  const selected = EXPERIENCES[experience];
  const map = values.map ?? Object.keys(selected.maps)[0];
  if (!Object.hasOwn(selected.maps, map)) throw Error(`${experience} does not support map ${map}`);
  const mode = values.mode ?? selected.maps[map][0];
  if (!selected.maps[map].includes(mode) || !catalog.maps.find(m => m.id === map)?.supported_modes.includes(mode)) throw Error(`Unsupported ${map} / ${mode}`);
  if (flags.has('--play') && flags.has('--setup')) throw Error('Choose --play or --setup');
  for (const flag of ['--play','--setup','--mute','--debug-hud']) if (flags.has(flag) && experience !== 'combat') throw Error(`${flag} requires combat`);
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
  if (experience === 'combat' && !flags.has('--play')) userArgs.push('--setup');
  if (experience === 'lobby') userArgs.push('--lobby-menu');
  return {experience, map, mode, scene:selected.scene, userArgs, endpoint};
}

export const HELP = `Private local COCS Linux prototype — Node >=22.13.0 required
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

Combat: 3 combat maps; deathmatch/teamdeathmatch/instagib/rockets.
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
An ordinary server owns a fresh loopback port. Close the window or Ctrl+C to stop.
No editor, git, npm, installation, or source checkout is needed to play.
Private prototype only; source asset redistribution rights remain unresolved.
`;
