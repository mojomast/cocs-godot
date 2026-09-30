import {spawnGroup} from '../../game/singleplayer.mjs';
import {floorAt, obstructed, walkEdge} from './core.generated.mjs';

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
// Main chassis plus central sensor housing. Feet-relative boxes deliberately
// exclude thin moving limbs, barrels and antennas. Width/depth come from the
// separately declared scaled art chassis; vertical tops include its sensor.
export function robotHitVolume(model) {
  const robot=ROBOTS[model];
  if(!robot)throw new TypeError(`Unknown robot: ${model}`);
  const top={scrapper:.63,skirmisher:1.372,sentinel:1.12,mortar:1.28225,bulwark:2.3925,warden:1.784}[model];
  return {width:robot.chassis[0],depth:robot.chassis[2],bottom:robot.chassisY-robot.chassis[1]/2,top};
}
export function deploymentReachable(match,anchor,point) {
  const length=Math.hypot(point.x-anchor.x,point.z-anchor.z),steps=Math.max(1,Math.ceil(length/4));
  let previous={x:anchor.x,y:floorAt(anchor.x,anchor.z,match.arena),z:anchor.z};
  if(!Number.isFinite(previous.y))return false;
  for(let i=1;i<=steps;i++) {
    const x=anchor.x+(point.x-anchor.x)*i/steps,z=anchor.z+(point.z-anchor.z)*i/steps;
    const next={x,y:floorAt(x,z,match.arena),z};
    if(!Number.isFinite(next.y)||!walkEdge(previous,next,match.arena))return false;
    previous=next;
  }
  return true;
}
function supportedClearance(match,point,radius) {
  if(obstructed(point.x,point.y,point.z,radius,match.arena))return false;
  for(const [dx,dz] of [[radius,0],[-radius,0],[0,radius],[0,-radius]]) {
    const y=floorAt(point.x+dx,point.z+dz,match.arena);
    if(!Number.isFinite(y)||Math.abs(y-point.y)>.65)return false;
  }
  return true;
}
function placeEncounter(match,actors,anchor) {
  // navigation() keeps only its largest component. Authored campaign routes
  // can be physically traversable without belonging to that sampled component.
  // Start with reviewed map spawns, then bounded local candidates; every used
  // point must be supported and walkEdge-reachable from the actual anchor.
  const raw=match.spawns.filter(p=>Math.hypot(p.x-anchor.x,p.z-anchor.z)<=24);
  for(let z=-18;z<=18;z+=3)for(let x=-18;x<=18;x+=3)if(Math.hypot(x,z)<=18)raw.push({x:anchor.x+x,z:anchor.z+z});
  const candidates=raw.map(p=>({x:p.x,y:floorAt(p.x,p.z,match.arena),z:p.z}))
    .filter(p=>Number.isFinite(p.y)&&deploymentReachable(match,anchor,p));
  const placed=[{...match.actors[0],radius:.52}];
  for(const actor of [...actors].sort((a,b)=>Number(b.npcModel==='warden')-Number(a.npcModel==='warden'))) {
    const radius=actor.npcModel==='warden'?1.65:.7;
    const point=candidates.find(p=>supportedClearance(match,p,radius)&&
      placed.every(other=>Math.hypot(other.x-p.x,other.z-p.z)>radius+other.radius));
    if(!point)throw new Error(`Encounter ${stateLabel(anchor)} lacks supported reachable deployment clearance for ${actor.npcModel}`);
    Object.assign(actor,{...point,vx:0,vy:0,vz:0,grounded:true,lastValid:{...point}});
    placed.push({...point,radius});
  }
}
const stateLabel=anchor=>`${anchor.x},${anchor.z}`;
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
      actor.npcHitVolume=robotHitVolume(model);
    }
  }
  placeEncounter(match,match.actors.filter(actor=>state.enemies.includes(actor.id)),anchor);
}
