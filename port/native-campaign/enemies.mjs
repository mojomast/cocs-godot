import {spawnGroup} from '../../game/singleplayer.mjs';
import {floorAt, obstructed, walkEdge} from './core.generated.mjs';
import {tuneRobot} from './feel.mjs';

// Visual identity plus campaign tuning; navigation/aim and damage primitives
// remain source-owned, with campaign attack/recovery policy in feel.mjs.
export const ROBOTS = Object.freeze({
  scrapper:{npcType:'husk', name:'Scrapper', hitScale:.72, chassis:[.5184,.288,.648], chassisY:.3456},
  skirmisher:{npcType:'lancer', name:'Skirmisher', hitScale:.86, chassis:[.3268,.473,.4472], chassisY:.9632},
  sentinel:{npcType:'sentinel', name:'Sentinel', hitScale:1.28, chassis:[.9216,.384,1.0496], chassisY:.6144},
  mortar:{npcType:'mortar', name:'Mortar', hitScale:1.15, chassis:[.828,.345,.943], chassisY:.828},
  bulwark:{npcType:'bulwark', name:'Bulwark', hitScale:1.5, chassis:[1.08,.72,.72], chassisY:1.68},
  warden:{npcType:'warden', name:'Quarantine Warden', hitScale:2, chassis:[1.68,.64,1.44], chassisY:1.152},
});
export const MAX_ACTIVE_ENEMIES = 10;
// Imported main chassis plus sensor housing, feet-relative and yaw-local.
// Excludes moving limbs, weapon barrels and the separately articulated shield.
export function robotHitVolume(model) {
  const robot=ROBOTS[model];
  if(!robot)throw new TypeError(`Unknown robot: ${model}`);
  // Measured imported L0_Chassis + sensor housing, not procedural fallback.
  // Feet-relative, yaw-local; 6 cm per edge absorbs bounded gait/recoil motion.
  const [left,right,back,front,bottom,top]={
    scrapper:[-.292,.292,-.375,.303,.176,.742],
    skirmisher:[-.379,.214,-.340,.241,.629,1.690],
    sentinel:[-.519,.519,-.538,.538,.313,1.396],
    mortar:[-.466,.466,-.483,.483,.557,1.461],
    bulwark:[-.608,.608,-.592,.420,1.327,2.626],
    warden:[-.976,.976,-.720,.720,.776,2.552],
  }[model];
  return {width:right-left+.12,depth:front-back+.12,offsetX:(left+right)/2,
    offsetZ:(back+front)/2,bottom:bottom-.06,top:top+.06,
    ...(model==='bulwark'?{shield:{width:1.05,depth:.54,offsetX:-.69,offsetZ:-.69,bottom:.81,top:2.52}}:{})};
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
  const player=match.actors[0],length=Math.hypot(anchor.x-player.x,anchor.z-player.z);
  const forward=length>1?{x:(anchor.x-player.x)/length,z:(anchor.z-player.z)/length}:{x:0,z:1};
  for(const actor of [...actors].sort((a,b)=>Number(b.npcModel==='warden')-Number(a.npcModel==='warden'))) {
    const radius=actor.npcModel==='warden'?1.65:.7;
    // Keep a readable front, flanking runners and a rear artillery position.
    // Rank supported/reachable sites rather than teleporting to unchecked art.
    const side=actor.npcModel==='skirmisher'?(actor.id%2?9:-9):(actor.id%2?3:-3);
    const depth=actor.npcModel==='mortar'?12:actor.npcModel==='warden'?9:actor.npcModel==='scrapper'?-5:4;
    const goal={x:anchor.x+forward.x*depth+forward.z*side,z:anchor.z+forward.z*depth-forward.x*side};
    const score=p=>Math.hypot(p.x-goal.x,p.z-goal.z)-(actor.npcModel==='warden'&&match.spawns.some(s=>s.x===p.x&&s.z===p.z)?1000:0);
    const point=[...candidates].sort((a,b)=>score(a)-score(b)).find(p=>
      Math.hypot(p.x-player.x,p.z-player.z)>=7&&supportedClearance(match,p,radius)&&
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
      tuneRobot(actor,match.time);
    }
  }
  placeEncounter(match,match.actors.filter(actor=>state.enemies.includes(actor.id)),anchor);
}

// F10 experiment (objective completion): bounded withdrawal for the guards an
// encounter left standing.
//
// A withdrawal is NOT a kill. It must reach the same terminal state the source
// already uses for a guard that stops mattering (singleplayer's sapper
// detonation: `health=0; dead=NPC_DEAD`), but it deliberately skips
// match.damage(), so no frag, kill-feed entry, stats.kills increment or banked
// reward is produced. Rewards are banked by the caller BEFORE this runs.
//
// Two bounded halves, neither of which can wedge the objective:
//  1. disengage now -- the same campaignStaggerUntil/campaignExposedUntil
//     suppression the interact bypass already uses, so the survivors stop
//     shooting, stop meleeing and stop walking in the same tick;
//  2. despawn at a fixed deadline measured in match time -- unconditional, not
//     tied to the player, the anchor, the objective or the next step.
export const WITHDRAW_GRACE = 1.2;

// `force` drains immediately regardless of the deadline. Used when the match is
// closing (level complete / dead) so a finished match can never report a
// standing guard.
export function beginEncounterWithdrawal(match, state, seconds = WITHDRAW_GRACE) {
  const surviving = state.enemies.filter(id => (match.actors[id]?.health ?? 0) > 0);
  if (!surviving.length) return [];
  // Merge, never replace: a second encounter can complete while an earlier
  // withdrawal is still draining. Keeping the set intact and the latest
  // deadline bounds the whole drain to `seconds` from the newest completion,
  // and leaves no survivor behind to block a later step.
  state.withdrawn = [...new Set([...state.withdrawn, ...surviving])];
  state.withdrawUntil = Math.max(state.withdrawUntil, match.time + seconds);
  for (const id of surviving) {
    const actor = match.actors[id];
    actor.campaignWithdrawn = true;
    // Disengage in the same tick. feel.attack() refuses while exposed/staggered
    // (so no gun or melee), botInput zeroes movement and melee, and the role
    // pass in singleplayer runs off state.enemies, which the caller has already
    // cleared -- so no artillery telegraph can outlive the objective.
    const until = state.withdrawUntil + 1;
    actor.campaignExposedUntil = until;
    actor.campaignStaggerUntil = until;
    actor.vx = 0; actor.vy = 0; actor.vz = 0;
    actor.phalanxWindup = undefined;
    actor.artilleryMark = null; actor.artilleryWindup = undefined;
    actor.npcPhalanx = null; actor.npcSummon = null;
  }
  return surviving;
}

export function tickEncounterWithdrawal(match, state, force = false) {
  if (!state.withdrawn.length) return 0;
  if (!force && match.time < state.withdrawUntil) return 0;
  const drained = state.withdrawn;
  state.withdrawn = [];
  for (const id of drained) {
    const actor = match.actors[id];
    if (!actor) continue;
    actor.campaignWithdrawn = true;
    // Direct health zero, not damage(): no source kill path, no frag, no
    // kill-feed entry, no stats.kills, no banked reward.
    actor.health = 0;
    actor.armor = 0;
    // `dead` pins the corpse slot and match.step re-pins it every tick, so the
    // base respawn branch is unreachable; `campaignWithdrawn` is kept set as a
    // durable marker that CampaignMatch.spawn also refuses on. The indexed
    // actor slot is deliberately preserved: source projectiles and bots index
    // actors[id].
    actor.dead = 1e9;
    actor.vx = 0; actor.vy = 0; actor.vz = 0;
    actor.melee = 0; actor.burstLeft = 0; actor.shotWait = 0;
    actor.temporaryShield = 0; actor.npcShield = null; actor.campaignSavedShield = null;
    if (actor.bot) { actor.bot.target = -1; actor.bot.route = []; actor.bot.fired = false; }
  }
  return drained.length;
}
