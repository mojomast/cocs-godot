import {Match, floorAt, obstructed} from './core.generated.mjs';
import {navigation as sourceNavigation} from '../../game/core.mjs';
import {updateEnemyRoles} from '../../game/singleplayer.mjs';
import {createFeel} from './feel.mjs';
import {playerWeapon,projectileWeapon,trackingInput} from './targeting.mjs';
import {loadCampaignMap} from './maps.mjs';
import {missionForCampaign, completionPolicyFor, objectivePresentationFor, OBJECTIVE_COMPLETION, DEFAULT_OBJECTIVE_COMPLETION} from './missions.mjs';
import {deployEncounter, beginEncounterWithdrawal, tickEncounterWithdrawal, withdrawInput} from './enemies.mjs';
import {createCampaignStory} from './story.mjs';
import {createCampaignInterludes} from './interludes.mjs';
import {createStructureRay} from '../edge-effects/structure-rays.mjs';

const primedSourceSurfaces=new WeakMap();
/** Source bots import the original core's private floor-query cache. Bake that
 * cache explicitly as well as the generated Match cache. Retrying the same
 * immutable arena does no work; terrain edits replacing surfaces must re-prime.
 * Store only after success so a failed initialization remains retryable. */
export function primeCampaignSourceNavigation(arena) {
  if (!arena?.terrain) return false;
  const surfaces=arena.terrain.surfaces;
  if (primedSourceSurfaces.has(arena)&&primedSourceSurfaces.get(arena)===surfaces) return false;
  sourceNavigation(arena);
  primedSourceSurfaces.set(arena,surfaces);
  return true;
}

const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const place = (actor, point) => Object.assign(actor, {x:point.x,y:point.y,z:point.z,
  vx:0,vy:0,vz:0,grounded:true,lastValid:{x:point.x,y:point.y,z:point.z}});

// Checkpoint inventory carry (F11): a claimed one-time reward must survive a
// death/Retry. The snapshot is versioned, bounded to the actor's own weapon
// belt and validated fail-closed before it is applied; invalid carry falls back
// to the ordinary spawn inventory instead of replaying or duplicating rewards.
const CARRY_VERSION = 1;
function playerCarrySnapshot(match) {
  const player = match.actors[0];
  if (!player) return null;
  return {version:CARRY_VERSION, weapon:player.weapon,
    ammo:Array.isArray(player.ammo)?[...player.ammo]:null,
    armor:Number.isFinite(player.armor)?player.armor:null};
}
function sanitizePlayerCarry(carry, match) {
  if (!carry || typeof carry!=='object' || carry.version!==CARRY_VERSION) return null;
  const player = match.actors[0];
  const count = Array.isArray(player?.ammo) ? player.ammo.length : 0;
  if (!count) return null;
  if (!Number.isInteger(carry.weapon) || carry.weapon < 0 || carry.weapon >= count) return null;
  if (!Array.isArray(carry.ammo) || carry.ammo.length !== count) return null;
  const ammo = [];
  for (const [index, amount] of carry.ammo.entries()) {
    if (amount === Infinity) { ammo.push(Infinity); continue; }
    if (!Number.isFinite(amount) || amount < 0) return null;
    const cap = match.weaponForIndex(player, index)?.cap;
    ammo.push(Number.isFinite(cap) ? Math.min(amount, cap) : amount);
  }
  if (!Number.isFinite(carry.armor)) return null;
  return {version:CARRY_VERSION, weapon:carry.weapon, ammo, armor:Math.min(100, Math.max(0, carry.armor))};
}
function applyPlayerCarry(match, carry) {
  const player = match.actors[0];
  player.weapon = carry.weapon;
  player.ammo = [...carry.ammo];
  player.armor = carry.armor;
}
export function createCampaignMatch({mapId='rootfall-verge', difficulty='normal', random=Math.random,
  mapData, checkpoint=0, elapsed=0, totalElapsed=0, kills=0, checkpointPoint, storyCarry, interludeCarry, playerCarry: carryInput=null,
  objectiveCompletion=DEFAULT_OBJECTIVE_COMPLETION} = {}) {
  const mission = missionForCampaign(mapId);
  if (!['easy','normal','hard'].includes(difficulty)) throw new TypeError('Unsupported difficulty');
  if (typeof random !== 'function') throw new TypeError('RNG must be a function');
  if (!Number.isInteger(checkpoint) || checkpoint < 0 || checkpoint > 5) throw new TypeError('Invalid checkpoint');
  // Fail closed on an unknown policy name, at the constructor, once per match.
  completionPolicyFor(mapId, 0, objectiveCompletion);
  const data = mapData ?? loadCampaignMap(mapId);
  if (data.id !== mapId) throw new TypeError('Campaign map identity mismatch');
  const anchors = data.campaign.anchors;
  const story=createCampaignStory(data,storyCarry);
  const interludes=createCampaignInterludes(data,interludeCarry);
  let storySnapshot;
  // Closure state is ready before super() invokes the virtual initializer.
  const state = {kind:'campaign', playerId:0, phase:'playing', stepIndex:checkpoint,
    checkpoint, checkpointPoint:checkpointPoint ?? anchors.start, elapsed, totalElapsed,
    bankedKills:kills, nextId:1, enemies:[], allies:[], groups:{}, steps:[],
     holdProgress:0, restoring:false, bypassed:false, deployed:false, boss:null, bossPhase:1, summonCount:0,
     // F10 experiment: ids of guards currently retreating, the match-time
     // deadline at which they are despawned regardless, and the contested
     // position the relevance test measures from. Empty and inert unless an
     // opted-in encounter completes under the restore-and-withdraw policy.
     withdrawn:[], withdrawUntil:0, withdrawAnchor:null,
    transmission:{speaker:'ECHO',text:mission.brief}};
  let controls = {}, arenaAssigned = false;
  const feel=createFeel(difficulty);
  const structureRay=createStructureRay(data);
  const remaining = match => match.actors.filter(a => a.isNpc && a.health > 0).length;
  // F10 experiment: guards that are mid-withdrawal no longer belong to any
  // encounter, so they must not count toward the live-guard completion gate.
  // Without this, a withdrawal still in flight stalls the NEXT encounter for
  // the rest of its grace window -- a dead beat after the player has already
  // earned that objective. Inert while `withdrawn` is empty, so the control
  // gate is bit-for-bit the same `remaining()` it always was.
  const encounterAlive = match => remaining(match)
    - state.withdrawn.filter(id => (match.actors[id]?.health ?? 0) > 0).length;
  // Same exclusion, applied to every PRESENTATION count. A guard that is walking
  // off is no longer part of the encounter, so the HUD threat count, the
  // objective line and the story must stop reporting it while it is still on
  // screen; `campaign.withdrawing` carries the honest number instead. Also inert
  // while `withdrawn` is empty, so every control-facing number is unchanged.
  const engaged = match => encounterAlive(match);
  const withdrawingCount = match => state.withdrawn.filter(id => (match.actors[id]?.health ?? 0) > 0).length;
  const currentAnchor = () => anchors[state.stepIndex < 5 ? `encounter-${state.stepIndex + 1}` : 'exit'];
  const checkpointPosition = (match, player) => {
    const y=floorAt(player.x,player.z,match.arena);
    return Number.isFinite(y)&&!obstructed(player.x,y,player.z,undefined,match.arena)
      ? {x:player.x,y,z:player.z} : {...state.checkpointPoint};
  };
  const finish = (match, phase) => {
    // Nothing may outlive the match: drain any in-flight withdrawal here so a
    // dead or completed match never reports a guard still standing.
    tickEncounterWithdrawal(match,state,true);
    state.phase=phase; state.winner=phase==='dead'?1:0; match.over=true; match.overReason=phase;};
  class CampaignMatch extends Match {

    rayWorld(origin,direction,max) {return structureRay(origin,direction,max);}
    visible(a,b) {
      if(!a||!b||!['x','y','z'].every(k=>Number.isFinite(a[k])&&Number.isFinite(b[k])))return false;
      const d={x:b.x-a.x,y:b.y-a.y,z:b.z-a.z},length=Math.hypot(d.x,d.y,d.z);
      if(length<=1e-9)return true;
      for(const k of ['x','y','z'])d[k]/=length;
      return structureRay(a,d,length)>=length-.08; // existing source visibility tolerance
    }
    weaponForIndex(actor,index) {return playerWeapon(actor,super.weaponForIndex(actor,index),Number.isInteger(index)?index:actor.weapon);}
    projectileWeapon(projectile) {return projectileWeapon(this,projectile);}
    emit(type,event) {feel.event(this,type,event);return super.emit(type,event);}
    damage(target,amount,source,ability=false) {
      const adjusted=feel.incoming(this,target,feel.outgoing(this,target,amount,source),source);
      if(adjusted<=0)return 0;
      const actual=super.damage(target,adjusted,source,ability);
      feel.damaged(this,target,source,actual,adjusted);
      return actual;
    }
    fire(actor,direction) {
      if(!feel.attack(this,actor))return false;
      const fired=super.fire(actor,direction);
      if(fired)feel.afterAttack(this,actor,'gun');
      return fired;
    }
    altFire(actor) {return actor.isNpc?false:super.altFire(actor);}
    throwGrenade(actor) {return actor.isNpc?false:super.throwGrenade(actor);}
    power(actor) {return actor.isNpc?false:super.power(actor);}
    botInput(actor,dt) {
      // F10 experiment: a guard mid-withdrawal is driven by the retreat, not by
      // the combat policy. This is the whole additive branch -- the core still
      // resolves walls, slopes, gravity and the gait from vx/vz exactly as it
      // does for every other actor, and the tracking speed budget below still
      // applies. Bypassing the policy is what guarantees no target reacquire, no
      // reacquired telegraph, no melee and no zone leash: the guard can only walk.
      if (actor.campaignWithdrawn && actor.campaignRetreat)
        return trackingInput(this,actor,withdrawInput(this,actor,dt),difficulty);
      const input=super.botInput(actor,dt);
      if(input.melee){input.melee=feel.attack(this,actor,'melee');if(input.melee)feel.afterAttack(this,actor,'melee');}
      if(this.time<(actor.campaignStaggerUntil??0)||this.time<(actor.campaignExposedUntil??0)){input.x=0;input.z=0;input.melee=false;}
      return trackingInput(this,actor,input,difficulty);
    }
    spawn(actor) {
      // Retry/restart construct fresh actors; base automatic respawn is barred.
      // F10 experiment: a guard drained by a withdrawal carries that marker
      // permanently, so the invariant does not rest on the `dead` pin alone.
      if (this.modeState===state && (actor.deaths>0 || actor.campaignWithdrawn)) return;
      super.spawn(actor);
    }
    endMatch(reason) {if(reason==='time')return;super.endMatch(reason);}
    get arena() {return data.arena;}
    set arena(_fallback) {if (arenaAssigned) throw new Error('Arena reassignment'); arenaAssigned=true;}
    get config() {return this._campaignConfig;}
    set config(value) {this._campaignConfig={...value,mode:'campaign',mission:mapId,botCount:0,timeLimit:Number.MAX_SAFE_INTEGER};}
    initializeSinglePlayer() {
      this.modeState=state; this.humanCount=1; this.actors=this.actors.filter(a => a.id===0);
      this.actors[0].team=0; place(this.actors[0], state.checkpointPoint);
      this.actors[0].health=this.actors[0].maxHealth=feel.tuning.health;this.actors[0].armor=feel.tuning.armor;
      this.objectiveState={kind:'campaign',zones:[],winner:null,singleplayer:true};
      return state;
    }
    step(dt, input={}) {
      if (!Number.isFinite(dt) || dt <= 0 || dt > .1) throw new TypeError('Invalid campaign tick');
      if (state.phase !== 'playing') return;
      controls=input.inputs?.[0] ?? {};
      for (const actor of this.actors) if (actor.health<=0) actor.dead=1e9;
      if (this.actors[0].health<=0) {finish(this,'dead'); return;}
      super.step(dt,input);
    }
    updateSinglePlayer(dt) {
      state.elapsed+=dt; state.totalElapsed+=dt;
      const player=this.actors[0];
      if (player.health<=0) {finish(this,'dead'); return;}
      const boss=this.actors.find(a => a.id===state.boss);
      if (boss?.health>0) {
        const phase=boss.health/boss.maxHealth>.66?1:boss.health/boss.maxHealth>.33?2:3;
        if (phase!==state.bossPhase) this.emit('boss-phase',{actor:boss.id,phase});
        state.bossPhase=phase;
      }
      updateEnemyRoles(this,state,dt); feel.update(this,dt);
      // F10 experiment: the withdrawal tick runs unconditionally every tick, so
      // a retreat completes even when the player has already run ahead to the
      // next anchor or the level has closed. It is anchored on match time and on
      // the guard's own position, never on the player or the next step.
      tickEncounterWithdrawal(this,state);
      if (player.health<=0) {finish(this,'dead'); return;}
      const anchor=currentAnchor(), near=distance(player,anchor)<=anchor.radius && Math.abs(player.y-anchor.y)<3;
      const encounterForStory=mission.encounters[state.stepIndex];
      storySnapshot=story.update({stepIndex:state.stepIndex,totalElapsed:state.totalElapsed,
        encounter:encounterForStory,deployed:state.deployed,
        enemiesRemaining:engaged(this),marker:anchor},player,controls.interact===true,this.arena);
      interludes.update(this,state,controls,near||!!storySnapshot.prompt);
      if (state.stepIndex===5) {
        if (near) {state.transmission={speaker:'ECHO',text:mission.outro}; this.objectiveState.winner=0; finish(this,'level-complete');}
        else tickEncounterWithdrawal(this,state,true);
        return;
      }
      const encounter=mission.encounters[state.stepIndex];
      if (!state.deployed && distance(player,anchor)<=Math.max(36,anchor.radius+20)) {
        state.checkpoint=state.stepIndex; state.checkpointPoint=checkpointPosition(this,player);
        state.deployed=true;
        // F10 experiment: under the control rule this resolves to the authored
        // encounter text verbatim. Under the opted-in policy the shipped brief
        // is stale -- it was written for a rule that only ends when the patrol
        // is dead -- so the experiment shows copy that describes the transfer as
        // the completion and the survivors as retreating.
        const brief=(objectivePresentationFor(mapId,state.stepIndex,objectiveCompletion)?.brief ?? encounter.text);
        state.transmission={speaker:'ECHO',text:brief.replace(/^ECHO: /,'').replace(/hold Interact/gi,'press Interact, then remain nearby')};
        deployEncounter(this,state,encounter,anchor);
        this.emit('campaign-checkpoint',{step:state.checkpoint});
      }
      if (!state.deployed) return;
      const alive=encounterAlive(this);
      // Hold progress belongs to the contested position, not a post-clear wait.
      // Leaving pauses progress; living guards still block completion below.
      if (encounter.mechanic==='hold' && near) {
        state.holdProgress=Math.min(encounter.seconds,state.holdProgress+dt);
      }
       // Let the player choose a risky console rush to dismantle the formation.
       // Completion still requires every guard; bypass never skips a checkpoint.
       if(encounter.mechanic==='interact'&&near&&controls.interact===true&&!state.bypassed) {
         state.bypassed=true;
         for(const actor of this.actors)if(state.enemies.includes(actor.id)) {
           actor.npcPhalanx=null;actor.phalanxWindup=undefined;actor.temporaryShield=0;
           actor.npcShield=null;actor.campaignSavedShield=null;
           actor.campaignExposedUntil=this.time+2.2;
         }
         this.emit('campaign-bypass',{step:state.stepIndex});
         state.transmission={speaker:'ECHO',text:'Security bypassed. Their guard network is down.'};
       }
       if(encounter.mechanic==='restore') {
         if(near&&controls.interact===true)state.restoring=true;
         if(near&&state.restoring)state.holdProgress=Math.min(encounter.seconds,state.holdProgress+dt);
       }
       // F10 experiment: how a single encounter decides it is finished.
      // CONTROL (default, `require-all-guards`): the shared `alive>0` gate below
      // stays exactly where it was: every objective label -- clear, interact,
      // restore, hold, guardian -- resolves through "every deployed guard is
      // dead". This is the behaviour under audit (F10: different objective
      // labels converge on eliminating all guards).
      // EXPERIMENT (`restore-and-withdraw`): an authored transfer/hold may
      // complete on its own terms, and the guards it left standing withdraw
      // through the same transition instead of blocking it. The relaxation is
      // deliberately narrow: the encounter's OWN completion condition must
      // already be satisfied, so the policy can never complete an objective
      // that the control rule rejected for any other reason, and it is inert
      // for every encounter that did not explicitly opt in.
      const policy=completionPolicyFor(mapId,state.stepIndex,objectiveCompletion);
      const transferComplete=encounter.seconds>0&&state.holdProgress>=encounter.seconds
        &&(encounter.mechanic==='restore'||encounter.mechanic==='hold');
      const withdraws=alive>0&&policy===OBJECTIVE_COMPLETION.restoreAndWithdraw&&transferComplete;
      if (alive>0 && !withdraws) return;
      let done=(encounter.mechanic==='clear'||encounter.mechanic==='guardian')&&near;
      if (encounter.mechanic==='interact') done=near && controls.interact===true;
       if (encounter.mechanic==='restore') {
         done=near&&state.holdProgress>=encounter.seconds;
      }
      if (encounter.mechanic==='hold') done=near&&state.holdProgress>=encounter.seconds;
      if (!done) return;
      this.emit('campaign-objective-complete',{step:state.stepIndex});
      // Bank the guards that actually died, BEFORE any withdrawal: the drain
      // zeroes survivor health, so counting afterwards would pay out kills that
      // were never earned and could be farmed by retrying the same encounter.
      state.bankedKills+=state.enemies.filter(id=>this.actors[id]?.health<=0).length;
      // Remaining encounter guards break off through the same transition the
      // objective itself just used: they disengage in the same tick, walk a
      // bounded retreat away from the contested position on the existing
      // locomotion, and despawn on arrival, out of relevance, or on the fixed
      // deadline. `anchor` is the position they were defending, which is what
      // the relevance test measures from.
      const withdrawing=withdraws?beginEncounterWithdrawal(this,state,anchor):[];
      state.enemies=[]; state.boss=null;
      if (withdrawing.length) this.emit('campaign-guard-withdrawal',{step:state.stepIndex,count:withdrawing.length});
       state.stepIndex++; state.deployed=false; state.holdProgress=0; state.restoring=false;state.bypassed=false;
      state.checkpoint=state.stepIndex; state.checkpointPoint=checkpointPosition(this,player);
      player.health=Math.max(player.health,player.maxHealth*.8); player.armor=Math.max(player.armor,40);
      player.ammo.forEach((amount,i)=>{const cap=this.weaponForIndex(player,i)?.cap;
        if ((amount>0||i===player.weapon)&&Number.isFinite(cap)) player.ammo[i]=Math.max(amount,Math.ceil(cap*.8));});
      state.transmission={speaker:'ECHO',text:state.stepIndex===5?mission.outro:'Relay secured. Follow the service route; side paths carry supplies. Recover before the next contact.'};
      storySnapshot=story.update({stepIndex:state.stepIndex,totalElapsed:state.totalElapsed,
        encounter:mission.encounters[state.stepIndex],deployed:false,enemiesRemaining:engaged(this),
        marker:currentAnchor()},player,controls.interact===true,this.arena);
    }
    campaignCheckpoint() {return {mapId,difficulty,checkpoint:state.checkpoint,checkpointPoint:{...state.checkpointPoint},
      elapsed:state.elapsed,totalElapsed:state.totalElapsed,kills:state.bankedKills,storyCarry:story.continuity(),interludeCarry:interludes.continuity(),
      playerCarry:playerCarrySnapshot(this)};}
    campaignStoryContinuity() {return story.continuity();}
    completeCampaign() {if (state.phase==='level-complete' && data.campaign.nextMapId===null) finish(this,'campaign-complete');}
    snapshot() {
      const snapshot=super.snapshot(), encounter=mission.encounters[state.stepIndex], marker=currentAnchor();
      for(const actor of snapshot.actors){const source=this.actors[actor.id];if(!source?.isNpc)continue;
        actor.campaignAttackWindup=Math.max(0,(source.campaignFireAt??0)-this.time);
        actor.campaignSlamDuration=source.campaignSlamDuration??1.15;
        actor.campaignStagger=Math.max(0,(source.campaignStaggerUntil??0)-this.time);
        actor.campaignShieldHit=Math.max(0,(source.campaignShieldHitUntil??0)-this.time);
        actor.campaignExposed=Math.max(0,(source.campaignExposedUntil??0)-this.time);
        // F10 experiment: additive, and present ONLY while a guard is actually
        // walking off. The field is omitted entirely when no guard is
        // withdrawing, so every control snapshot -- actor objects included --
        // serializes to the exact same bytes it did before this experiment. A
        // consumer that does read it can present a retreat instead of a threat.
        if(source.campaignWithdrawn&&source.campaignRetreat&&source.health>0)actor.campaignWithdrawing=1;}
      const mechanic=encounter?.mechanic;
      // F10 experiment: only the opted-in encounter has experiment copy, and only
      // while the experiment policy is requested. The control path falls through
      // to the shipped mechanic strings untouched.
      const copy=objectivePresentationFor(mapId,state.stepIndex,objectiveCompletion);
      snapshot.campaign={id:'quiet-relay',mapId,index:data.campaign.index,title:mission.title,
        stepIndex:state.stepIndex,stepCount:6,objective:encounter?.title??'Follow the service route to the exit',
        detail:!state.deployed&&encounter?'Follow the waypoint. Optional supply routes branch from the service path.':
          mechanic==='restore'?(copy?.detail??'Press Interact to start the transfer. Defend nearby; dodge without losing progress.'):
          mechanic==='interact'?(state.bypassed?'Guard network disabled. Finish the guards and return to the console.':'Clear the guards, or rush the console and press Interact to disable their guards.'): 
          mechanic==='hold'?(engaged(this)>0?'Hold the relay and eliminate its guards':'Remain inside the relay marker to finish synchronization. Progress is retained when you dodge.'):
          encounter?(state.deployed&&engaged(this)===0?'Area clear—reach the relay marker':'Eliminate the deployed security robots.'):'Reach the exit to continue.',
        marker:state.phase==='playing'?{x:marker.x,y:marker.y,z:marker.z,radius:marker.radius}:null,
        phase:state.phase,checkpoint:state.checkpoint,elapsed:state.elapsed,totalElapsed:state.totalElapsed,
        kills:state.bankedKills+state.enemies.filter(id=>this.actors[id]?.health<=0).length,enemiesRemaining:engaged(this),
         holdProgress:encounter?.seconds?state.holdProgress/encounter.seconds:0,transmission:{...state.transmission},nextMapId:data.campaign.nextMapId,
         interludes:interludes.snapshot(state.phase==='playing'),
         story:state.phase==='dead'?{...(storySnapshot??=story.update({stepIndex:state.stepIndex,totalElapsed:state.totalElapsed,
           encounter,deployed:state.deployed,enemiesRemaining:engaged(this),marker},this.actors[0],false,this.arena)),prompt:null}:
           storySnapshot??=story.update({stepIndex:state.stepIndex,totalElapsed:state.totalElapsed,
           encounter,deployed:state.deployed,enemiesRemaining:engaged(this),marker},this.actors[0],false,this.arena)};
      // F10 experiment: the honest count of guards leaving, so a HUD that knows
      // the field can say "withdrawing" instead of silently dropping them out of
      // `enemiesRemaining`. Added only while a withdrawal is actually in flight,
      // so every control snapshot serializes byte-identically to the shipped one.
      const withdrawing=withdrawingCount(this);
      if(withdrawing>0)snapshot.campaign.withdrawing=withdrawing;
      return snapshot;
    }
  }
  primeCampaignSourceNavigation(data.arena);
  const match=new CampaignMatch('chatgpt','openclaw',random,mapId,{mode:'campaign',difficulty,botCount:0,humanCount:1});
  const carry=sanitizePlayerCarry(carryInput,match);
  if(carry)applyPlayerCarry(match,carry);
  return match;
}
