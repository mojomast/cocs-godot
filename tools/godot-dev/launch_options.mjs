// Scene routing only: capability and protocol checks still belong to each client.
export const EXPERIENCES = {
  combat: {scene:'res://world/session.tscn', map:'meridian-exchange'},
  sports: {scene:'res://sports/demo.tscn', map:'ion-speedway', modes:{'ion-speedway':['puma-race'], 'aurora-stadium':['puma-soccer']}},
  objectives: {scene:'res://objectives/demo.tscn', map:'tidal-citadel', modes:{'tidal-citadel':['ctf'], 'sunscar-convoy':['payload']}},
  lattice: {scene:'res://lattice/board.tscn', map:'asterion-relay', modes:{'asterion-relay':['cocs','cocs-coop'], 'monsoon-foundry':['cocs','cocs-coop']}},
};

export function launchOptions(argv, catalog) {
  const values = {}, flags = new Set(), sessionOptions = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const key = ['map','mode','experience'].find(key => arg === `--${key}` || arg.startsWith(`--${key}=`));
    if (key) {
      const value = arg.includes('=') ? arg.slice(arg.indexOf('=') + 1) : argv[++i];
      if (!value || value.startsWith('--')) throw Error(`--${key} requires a value`);
      if (values[key] !== undefined) throw Error(`--${key} must be supplied once`);
      values[key] = value;
    } else if (['--play','--setup','--native-trace','--mute','--debug-hud','--network-smoke','--session-smoke','--lifecycle-smoke'].includes(arg)) {
      flags.add(arg);
    } else throw Error(`Unknown launcher option: ${arg}. Use --help.`);
  }
  const smokeFlags = ['--network-smoke','--session-smoke','--lifecycle-smoke'].filter(arg => flags.has(arg));
  if (smokeFlags.length > 1) throw Error('Select one smoke check at a time');
  const play = flags.has('--play') || flags.has('--setup') || values.experience || values.map || values.mode ||
    ['--native-trace','--mute','--debug-hud','--session-smoke','--lifecycle-smoke'].some(arg => flags.has(arg));
  const experience = values.experience ?? 'combat';
  const selected = Object.hasOwn(EXPERIENCES, experience) ? EXPERIENCES[experience] : null;
  if (!selected) throw Error(`Unknown experience: ${experience}. Choose ${Object.keys(EXPERIENCES).join(', ')}.`);
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
  for (const key of ['map','mode']) if (values[key]) sessionOptions.push(`--${key}=${values[key]}`);
  for (const flag of ['--setup','--native-trace','--mute','--debug-hud']) if (flags.has(flag)) sessionOptions.push(flag);
  const smoke = smokeFlags[0];
  const args = smoke === '--network-smoke'
    ? ['--headless','--path','godot','--script','res://tests/protocol/live.gd']
    : [...(smoke ? ['--headless'] : []),'--path','godot',...(play ? [selected.scene] : [])];
  if (smoke && smoke !== '--network-smoke') sessionOptions.push(smoke);
  return {args, sessionOptions, experience:play ? experience : 'viewer', smoke:smoke ?? null};
}

export const HELP = `Native COCS launcher — owned loopback authority, normal simulation timing

  node tools/godot-dev/launch.mjs --play --setup
  node tools/godot-dev/launch.mjs --experience=sports --map=ion-speedway
  node tools/godot-dev/launch.mjs --experience=sports --map=aurora-stadium
  node tools/godot-dev/launch.mjs --experience=objectives --map=tidal-citadel
  node tools/godot-dev/launch.mjs --experience=objectives --map=sunscar-convoy
  node tools/godot-dev/launch.mjs --experience=lattice --map=asterion-relay --mode=cocs

Set GODOT_BIN to the pinned Godot 4.5.2 binary. Run semantic export and import first.
PORT=0 (default) allocates a free port. Close the client or press Ctrl+C to stop.
Interactive sessions have no harness deadline. With no options, open the map viewer.

Combat: --map, --mode, --setup, --mute, --debug-hud, --native-trace
Sports: ion-speedway (puma-race), aurora-stadium (puma-soccer)
Objectives: tidal-citadel (ctf), sunscar-convoy (payload)
LATTICE: asterion-relay or monsoon-foundry; --mode=cocs or cocs-coop
  Click Connect / start in the command board to begin.
Checks: --network-smoke, --session-smoke or --lifecycle-smoke (combat only)
`;
