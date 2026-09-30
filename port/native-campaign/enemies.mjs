import {spawnGroup, placeGroup} from '../../game/singleplayer.mjs';
import {obstructed} from '../../game/core.mjs';

// Visual identity is additive. Every brain and damage primitive is source-owned.
export const ROBOTS = Object.freeze({
  scrapper:{npcType:'husk', name:'Scrapper', hitScale:.72, chassis:[.5184,.288,.648], chassisY:.3456},
  skirmisher:{npcType:'lancer', name:'Skirmisher', hitScale:.86, chassis:[.3268,.473,.4472], chassisY:.9632},
  sentinel:{npcType:'sentinel', name:'Sentinel', hitScale:1.28, chassis:[.9216,.384,1.0496], chassisY:.6144},
  mortar:{npcType:'mortar', name:'Mortar', hitScale:1.15, chassis:[.828,.345,.943], chassisY:.828},
  bulwark:{npcType:'bulwark', name:'Bulwark', hitScale:1.5, chassis:[1.08,.72,.72], chassisY:1.68},
  warden:{npcType:'warden', name:'Quarantine Warden', hitScale:2, chassis:[1.68,.64,1.44], chassisY:1.152},
});
export const MAX_ACTIVE_ENEMIES = 10;
export function deployEncounter(match, state, encounter, anchor) {
  const count = Object.values(encounter.roster).reduce((a, b) => a + b, 0);
  if (count > MAX_ACTIVE_ENEMIES || Object.keys(encounter.roster).length > 3) throw new Error('Encounter budget exceeded');
  // Preserve indexed corpse slots: source projectiles and bots use actors[id].
  state.enemies = []; state.groups = {}; state.boss = null; state.bossPhase = 1;
  for (const [model, count] of Object.entries(encounter.roster)) {
    const robot = ROBOTS[model];
    if (!robot) throw new Error(`Unknown robot: ${model}`);
    const ids = spawnGroup(match, state, {type:robot.npcType, count, summons:false,
      group:`encounter-${state.stepIndex}`, x:anchor.x, z:anchor.z,
      zone:{x:anchor.x, z:anchor.z, r:14, leash:32, kind:'hold'}}, {team:1});
    for (const id of ids) {
      const actor = match.actors.find(actor => actor.id === id);
      actor.npcModel = model; actor.name = robot.name; actor.hitScale=robot.hitScale;
    }
  }
  placeGroup(match, match.actors.filter(actor=>state.enemies.includes(actor.id)), anchor.x, anchor.z, 14);
  for (const actor of match.actors.filter(actor=>state.enemies.includes(actor.id)&&actor.npcModel==='warden')) {
    const point=match.nav.filter(node=>Math.hypot(node.x-anchor.x,node.z-anchor.z)<=18 &&
      !obstructed(node.x,node.y,node.z,1.65,match.arena) &&
      match.actors.every(other=>other===actor||other.health<=0||Math.hypot(other.x-node.x,other.z-node.z)>2))
      .sort((a,b)=>Math.hypot(a.x-anchor.x,a.z-anchor.z)-Math.hypot(b.x-anchor.x,b.z-anchor.z))[0];
    if (!point) throw new Error('Guardian anchor lacks 1.65 m visual clearance');
    Object.assign(actor,{x:point.x,y:point.y,z:point.z,lastValid:{x:point.x,y:point.y,z:point.z}});
  }
}
