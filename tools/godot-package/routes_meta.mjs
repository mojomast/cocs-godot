// Hand-written UI metadata for the unified main menu registry.
// gen_routes.mjs merges this with the options.mjs experience tables and the
// locked map catalog to emit godot/ui/routes.json (schema version 1).
//
// Param schemas here are EXACT mirrors of tools/godot-package/options.mjs
// bounds: choice params carry ordered `values` (or `values_by_map` for per-map
// modes, ordering identical to EXPERIENCES), range params carry inclusive
// min/max/step/`default` plus optional per-map `max_by_map` clamps. The
// generator cross-checks every choice list against the experience tables, so
// drift here fails generation instead of shipping.

// Ordered exactly as routes.json must render them.
//
// Category *ids* are stable (menu preferences and the Godot contracts key on
// them); only the player-facing labels move toward the NATIVE-03 vocabulary.
// Distinct player-facing names keep the stable groups easy to navigate.
export const CATEGORIES = [
  {id: 'play',   label: 'Play',       description: 'Core combat and multiplayer'},
  {id: 'native', label: 'Bot Matches', description: 'Local matches against bots'},
  {id: 'modes',  label: 'Activities', description: 'Objective, vehicle and LATTICE activities'},
  {id: 'lab',    label: 'Extras',     description: 'Previews, galleries and labs'},
  {id: 'cheats', label: 'Cheats',     description: 'Local debug panel routes'},
];

// Display names for maps absent from port/contracts/map-selection.json: the eight
// native arenas (which include the three identity maps). Catalog maps resolve
// their `name` field directly and must never be duplicated here.
export const MAP_NAMES = {
  'parallax-observatory': 'Parallax Observatory',
  'rootfall-verge': 'Rootfall Verge',
  'siltwake-crossing': 'Siltwake Crossing',
  'emberline-ascent': 'Emberline Ascent',
  'crown-array': 'Crown Array',
  'prism-foundry':  'Prism Foundry',
  'aurora-basin':   'Aurora Basin',
  'cinder-array':   'Cinder Array',
  'lacuna-court':   'Lacuna Court',
  'vermilion-fold': 'Vermilion Fold',
  'nacre-engine':   'Nacre Engine',
  'cinderwake-drydock': 'Cinderwake Drydock (Preview)',
  'blackwater-reclamation': 'Blackwater Reclamation',
  'canopy-divide': 'Canopy Divide',
  'basalt-reach': 'Basalt Reach',
  'switchyard-ward': 'Switchyard Ward',
  'rainmarket-exchange': 'Rainmarket Exchange',
  'breakwater-exchange': 'Breakwater Exchange',
  'thermal-divide': 'Thermal Divide',
  'sirocco-circuit': 'Sirocco Circuit',
  'copper-bowl': 'Copper Bowl',
  'tern-archipelago': 'Tern Archipelago',
};

// The three locked combat arenas (options.mjs EXPERIENCES combat/lobby/...).
const COMBAT_MAPS = ['meridian-exchange', 'verdant-reliquary', 'ember-crucible'];

// Combat and lobby share one schema; fresh objects per route so the generator
// can never alias two routes onto one param array.
const combatParams = () => ([
  {key: 'map', kind: 'choice', label: 'Map',
   values: [...COMBAT_MAPS], default: 'meridian-exchange'},
  {key: 'mode', kind: 'choice', label: 'Mode',
   values_by_map: {
     'meridian-exchange': ['deathmatch', 'teamdeathmatch', 'instagib', 'rockets'],
     'verdant-reliquary': ['deathmatch', 'teamdeathmatch', 'instagib', 'rockets'],
     'ember-crucible':    ['deathmatch', 'teamdeathmatch', 'instagib', 'rockets'],
   },
   default: 'deathmatch'},
]);
const soloCombatParams = () => ([...combatParams(),
  {key: 'bots', kind: 'range', label: 'Bots', min: 0, max: 8, default: 2, step: 1},
]);

const nativeDmParams = () => ([
  {key: 'map', kind: 'choice', label: 'Map',
   values: ['prism-foundry', 'aurora-basin', 'cinder-array',
            'lacuna-court', 'vermilion-fold', 'nacre-engine', 'canopy-divide', 'basalt-reach'],
   default: 'prism-foundry'},
  {key: 'bots', kind: 'range', label: 'Bots', min: 1, max: 24, default: 2, step: 1},
  {key: 'round-seconds', kind: 'range', label: 'Round', min: 60, max: 300,
   default: 180, step: 15},
]);

const identityZonesParams = () => ([
  {key: 'bots', kind: 'range', label: 'Bots', min: 0, max: 24, default: 2, step: 1},
  {key: 'round-seconds', kind: 'range', label: 'Round', min: 60, max: 900,
   default: 120, step: 15},
  {key: 'score-limit', kind: 'range', label: 'Score', min: 1, max: 900,
   default: 30, step: 1},
]);

const hordeParams = () => ([
  {key: 'map', kind: 'choice', label: 'Map',
    values: [...COMBAT_MAPS, 'nacre-engine', 'cinderwake-drydock', 'blackwater-reclamation'], default: 'meridian-exchange'},
  {key: 'waves', kind: 'range', label: 'Waves', min: 1, max: 30, default: 10, step: 1},
  {key: 'operator', kind: 'choice', label: 'Operator',
    values: ['chatgpt','claude','grok','meta','gemini','deepseek','mistral','kimi','qwen'], default: 'chatgpt'},
  {key: 'harness', kind: 'choice', label: 'Harness',
    values: ['openclaw','hermes','opencode','claudecode','codex','cline','roo'], default: 'openclaw'},
]);

const latticeParams = () => ([
  {key: 'map', kind: 'choice', label: 'Map',
   values: ['asterion-relay', 'monsoon-foundry'], default: 'asterion-relay'},
  {key: 'mode', kind: 'choice', label: 'Mode',
   values: ['cocs', 'cocs-coop'], default: 'cocs'},
  {key: 'time-limit', kind: 'range', label: 'Time Limit', min: 60, max: 900, default: 900, step: 1},
  {key: 'bots', kind: 'range', label: 'Practice Bots', min: 0, max: 16, default: 2, step: 1},
]);

// The original 22 route ids plus one source-backed Assault destination, in menu order (category order,
// then table order inside each category).
export const ROUTES = [
  // --- play ---
  {
    id: 'campaign', category: 'play', label: 'The Quiet Relay',
    description: 'Four linked solo chapters through forest ravines and canyon relay works, against security robots',
    params: [
      {key:'map', kind:'choice', label:'Chapter', values:['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'], default:'rootfall-verge'},
      {key:'difficulty', kind:'choice', label:'Difficulty', values:['easy','normal','hard'], default:'normal'},
    ],
  },
  {
    id: 'combat', category: 'play',
    label: 'Combat',
    description: 'Core deathmatch on the three combat maps with an owned loopback server',
    params: soloCombatParams(),
  },
  {
    id: 'lobby', category: 'play',
    label: 'Multiplayer Lobby',
    description: 'Host or join a human-vs-human loopback match; no debug variant ever',
    params: combatParams(),
  },
  {
    id: 'multiplayer-worlds', category: 'play', label: 'Multiplayer Worlds',
    description: 'Seven authored source-backed worlds: urban infantry, freight, alpine, Puma sports and LATTICE',
    params: [
      {key:'map',kind:'choice',label:'Map',values:['switchyard-ward','rainmarket-exchange','breakwater-exchange','thermal-divide','sirocco-circuit','copper-bowl','tern-archipelago','parallax-observatory'],default:'switchyard-ward'},
      {key:'mode',kind:'choice',label:'Mode',values_by_map:{
        'parallax-observatory':['deathmatch','teamdeathmatch','ctf','koth','uplink','holdout'],
        'switchyard-ward':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'],
        'rainmarket-exchange':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','domination','koth','uplink','holdout','assault','payload'],
        'breakwater-exchange':['deathmatch','teamdeathmatch','domination','assault','payload','combined-arms'],
        'thermal-divide':['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'],
        'sirocco-circuit':['puma-race'],'copper-bowl':['puma-soccer'],'tern-archipelago':['cocs','cocs-coop']},default:'deathmatch'},
      {key:'bots',kind:'range',label:'Bots',min:0,max:8,default:2,step:1},
    ],
  },
  // --- native ---
  {
    id: 'native-dm', category: 'native',
    label: 'Native Deathmatch',
    description: 'One human plus bots, eight arenas, local loopback authority',
    params: nativeDmParams(),
  },
  {
    id: 'identity-zones', category: 'native',
    label: 'Domination',
    description: 'Vermilion Fold capture zones, one reviewed pair, local loopback authority',
    params: identityZonesParams(),
  },
  {
    id: 'horde', category: 'native',
    label: 'Horde',
    description: 'Hold out against security robots in combat arenas or the scripted Blackwater Reclamation mission',
    params: hordeParams(),
  },
  // --- modes ---
  {
    id:'mode-expansion',category:'modes',label:'Competitive Modes',
    description:'Full Arsenal, Juggernaut, shared-ticket Team Elimination and VIP Escort with source-owned rules',
    params:[
      {key:'map',kind:'choice',label:'Map',values:['meridian-exchange','verdant-reliquary','ember-crucible','tidal-citadel','sunscar-convoy'],default:'meridian-exchange'},
      {key:'mode',kind:'choice',label:'Mode',values_by_map:{'meridian-exchange':['arsenal','juggernaut'],'verdant-reliquary':['arsenal','juggernaut'],'ember-crucible':['arsenal','juggernaut'],'tidal-citadel':['team-elimination'],'sunscar-convoy':['vip-escort']},default:'arsenal'},
      {key:'bots',kind:'range',label:'Bots',min:0,max:8,default:2,step:1},
      {key:'time-limit',kind:'range',label:'Round seconds',min:60,max:900,default:180,step:30},
      {key:'wait-for-players',kind:'range',label:'Wait for players',min:1,max:8,default:1,step:1},
    ],
  },
  {
    id: 'arms-race', category: 'modes',
    label: 'Arms Race',
    description: 'Ten-weapon scramble across the three combat arenas',
    params: [
      {key: 'map', kind: 'choice', label: 'Map',
       values: [...COMBAT_MAPS], default: 'meridian-exchange'},
    ],
  },
  {
    id: 'zones', category: 'modes',
    label: 'Zones',
    description: 'King of the Hill, Domination, Uplink and Holdout on combat arenas; Domination on Tidal and Sunscar',
    params: [
      {key: 'map', kind: 'choice', label: 'Map',
       values: [...COMBAT_MAPS, 'tidal-citadel', 'sunscar-convoy'],
       default: 'meridian-exchange'},
      {key: 'mode', kind: 'choice', label: 'Mode',
       values_by_map: {
         'meridian-exchange': ['domination', 'koth', 'uplink', 'holdout'],
         'verdant-reliquary': ['koth', 'domination', 'uplink', 'holdout'],
         'ember-crucible':    ['koth', 'domination', 'uplink', 'holdout'],
         'tidal-citadel':     ['domination'],
         'sunscar-convoy':    ['domination'],
       },
       default: 'domination'},
      {key: 'bots', kind: 'range', label: 'Bots', min: 0, max: 8, default: 2, step: 1},
      {key: 'round-seconds', kind: 'range', label: 'Round seconds', min: 60, max: 900, default: 60, step: 1},
      {key: 'score-limit', kind: 'range', label: 'Frag limit', min: 1, max: 900, default: 100, step: 1},
    ],
  },
  {
    id: 'assault', category: 'modes',
    label: 'Assault',
    description: 'Attack or defend source-owned sectors on Tidal Citadel and Sunscar Convoy, with vehicles',
    params: [
      {key: 'map', kind: 'choice', label: 'Map', values: ['tidal-citadel', 'sunscar-convoy'], default: 'tidal-citadel'},
      {key: 'mode', kind: 'choice', label: 'Mode', values_by_map: {'tidal-citadel':['assault'], 'sunscar-convoy':['assault']}, default: 'assault'},
      {key: 'bots', kind: 'range', label: 'Bots', min: 0, max: 8, default: 2, step: 1},
      {key: 'round-seconds', kind: 'range', label: 'Round seconds', min: 60, max: 900, default: 60, step: 1},
      {key: 'score-limit', kind: 'range', label: 'Sectors', min: 1, max: 9, default: 3, step: 1},
    ],
  },
  {
    id: 'objectives', category: 'modes',
    label: 'Objectives',
    description: 'Capture the flag at Tidal Citadel, payload escort at Sunscar Convoy',
    params: [
      {key: 'map', kind: 'choice', label: 'Map',
       values: ['tidal-citadel', 'sunscar-convoy'], default: 'tidal-citadel'},
      {key: 'mode', kind: 'choice', label: 'Mode',
       values_by_map: {'tidal-citadel': ['ctf'], 'sunscar-convoy': ['payload']},
       default: 'ctf'},
    ],
  },
  {
    id: 'combined-arms', category: 'modes',
    label: 'Combined Arms',
    description: 'Sunscar Puma driving and combat slice; no route parameters',
    params: [],
  },
  {
    id: 'sports', category: 'modes',
    label: 'Sports',
    description: 'Puma race and soccer arenas with adjustable match limits',
    params: [
      {key: 'map', kind: 'choice', label: 'Map',
       values: ['ion-speedway', 'aurora-stadium'], default: 'ion-speedway'},
      {key: 'mode', kind: 'choice', label: 'Mode',
       values_by_map: {'ion-speedway': ['puma-race'], 'aurora-stadium': ['puma-soccer']},
       default: 'puma-race'},
      {key: 'time-limit', kind: 'range', label: 'Time Limit', min: 60, max: 900,
       default: 60, step: 1},
      {key: 'round-target', kind: 'range', label: 'Round Target', min: 1, max: 15,
       default: 5, step: 1,
       max_by_map: {'ion-speedway': 10, 'aurora-stadium': 15}},
    ],
  },
  {
    id: 'lattice', category: 'modes',
    label: 'LATTICE Board',
    description: 'Practice PvP or Operations with configurable bots; competitive rung hosting requires an explicit launcher --rung and eight human seats',
    params: latticeParams(),
  },
  {
    id: 'lattice-world', category: 'modes',
    label: 'LATTICE World',
    description: 'Practice PvP or Operations in the 3D world; competitive rung hosting requires an explicit launcher --rung and eight human seats',
    params: latticeParams(),
  },
  // --- lab (Extras) ---
  {
    id: 'viewer', category: 'lab',
    label: 'Map Viewer',
    description: 'Browse the locked map catalog with no match and no authority',
    params: [],
  },
  {
    id: 'operator-preview', category: 'lab',
    label: 'Operator Preview',
    description: 'Inspect the operator models on the preview stage, no authority',
    params: [],
  },
  {
    id: 'showcase', category: 'lab',
    label: 'Graphics Showcase',
    description: 'Curated native graphics gallery, standalone exploration scene',
    params: [],
  },
  {
    id: 'aurora-basin', category: 'lab',
    label: 'Aurora Basin Demo',
    description: 'Polar observatory exploration scene with no authority',
    params: [],
  },
  {
    id: 'cinder-array', category: 'lab',
    label: 'Cinder Array Demo',
    description: 'Volcanic caldera exploration scene with no authority',
    params: [],
  },
  {
    id: 'particle-lab', category: 'lab',
    label: 'Particle Observatory',
    description: 'GPU particle experiments from 8K to one million particles',
    params: [],
  },
  {
    id: 'shader-lab', category: 'lab',
    label: 'Moth Shader Gallery',
    description: 'Shield, energy and phase shader effects gallery',
    params: [],
  },
  // --- cheats ---
  {
    id: 'cheats-native-dm', category: 'cheats',
    label: 'Cheats: Native Deathmatch',
    description: 'Native Deathmatch with the local debug panel armed (F3/F4/F5/F6)',
    params: nativeDmParams(),
  },
  {
    id: 'cheats-identity-zones', category: 'cheats',
    label: 'Cheats: Domination',
    description: 'Vermilion Fold Domination with the local debug panel armed (F3/F4/F5/F6)',
    params: identityZonesParams(),
  },
  {
    id: 'cheats-horde', category: 'cheats',
    label: 'Cheats: Horde',
    description: 'Horde waves with the local debug panel armed (F3/F4/F5/F6)',
    params: hordeParams(),
  },
];
