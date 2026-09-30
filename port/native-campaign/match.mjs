import {Match, floorAt, obstructed} from './core.generated.mjs';
import {updateEnemyRoles, updateHealthRegen} from '../../game/singleplayer.mjs';
import {loadCampaignMap} from './maps.mjs';
import {missionForCampaign} from './missions.mjs';
import {deployEncounter} from './enemies.mjs';

const distance = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const place = (actor, point) => Object.assign(actor, {x:point.x,y:point.y,z:point.z,
  vx:0,vy:0,vz:0,grounded:true,lastValid:{x:point.x,y:point.y,z:point.z}});
export function createCampaignMatch({mapId='rootfall-verge', difficulty='normal', random=Math.random,
  mapData, checkpoint=0, elapsed=0, totalElapsed=0, kills=0, checkpointPoint} = {}) {
  const mission = missionForCampaign(mapId);
  if (!['easy','normal','hard'].includes(difficulty)) throw new TypeError('Unsupported difficulty');
  if (typeof random !== 'function') throw new TypeError('RNG must be a function');
  if (!Number.isInteger(checkpoint) || checkpoint < 0 || checkpoint > 5) throw new TypeError('Invalid checkpoint');
  const data = mapData ?? loadCampaignMap(mapId);
  if (data.id !== mapId) throw new TypeError('Campaign map identity mismatch');
  const anchors = data.campaign.anchors;
  // Closure state is ready before super() invokes the virtual initializer.
  const state = {kind:'campaign', playerId:0, phase:'playing', stepIndex:checkpoint,
    checkpoint, checkpointPoint:checkpointPoint ?? anchors.start, elapsed, totalElapsed,
    bankedKills:kills, nextId:1, enemies:[], allies:[], groups:{}, steps:[],
    holdProgress:0, restoring:false, deployed:false, boss:null, bossPhase:1, summonCount:0,
    transmission:{speaker:'ECHO',text:mission.brief}};
  let controls = {}, arenaAssigned = false;
  const remaining = match => match.actors.filter(a => a.isNpc && a.health > 0).length;
  const currentAnchor = () => anchors[state.stepIndex < 5 ? `encounter-${state.stepIndex + 1}` : 'exit'];
  const checkpointPosition = (match, player) => {
    const y=floorAt(player.x,player.z,match.arena);
    return Number.isFinite(y)&&!obstructed(player.x,y,player.z,undefined,match.arena)
      ? {x:player.x,y,z:player.z} : {...state.checkpointPoint};
  };
  const finish = (match, phase) => {state.phase=phase; state.winner=phase==='dead'?1:0; match.over=true; match.overReason=phase;};
  class CampaignMatch extends Match {
    spawn(actor) {
      // Retry/restart construct fresh actors; base automatic respawn is barred.
      if (this.modeState===state && actor.deaths>0) return;
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
      updateEnemyRoles(this,state,dt); updateHealthRegen(this,state,dt);
      if (player.health<=0) {finish(this,'dead'); return;}
      const anchor=currentAnchor(), near=distance(player,anchor)<=anchor.radius && Math.abs(player.y-anchor.y)<3;
      if (state.stepIndex===5) {
        if (near) {state.transmission={speaker:'ECHO',text:mission.outro}; this.objectiveState.winner=0; finish(this,'level-complete');}
        return;
      }
      const encounter=mission.encounters[state.stepIndex];
      if (!state.deployed && distance(player,anchor)<=Math.max(36,anchor.radius+20)) {
        state.checkpoint=state.stepIndex; state.checkpointPoint=checkpointPosition(this,player);
        state.deployed=true; state.transmission={speaker:'ECHO',text:encounter.text.replace(/^ECHO: /,'').replace(/hold Interact/gi,'press Interact, then remain nearby')};
        deployEncounter(this,state,encounter,anchor);
        this.emit('campaign-checkpoint',{step:state.checkpoint});
      }
      if (!state.deployed) return;
      const alive=remaining(this);
      if (encounter.mechanic==='hold' && near) state.holdProgress=Math.min(encounter.seconds,state.holdProgress+dt);
      if (alive>0) return;
      let done=(encounter.mechanic==='clear'||encounter.mechanic==='guardian')&&near;
      if (encounter.mechanic==='interact') done=near && controls.interact===true;
      if (encounter.mechanic==='restore') {
        if (near && controls.interact===true) state.restoring=true;
        if (near && state.restoring) state.holdProgress=Math.min(encounter.seconds,state.holdProgress+dt);
        done=state.holdProgress>=encounter.seconds;
      }
      if (encounter.mechanic==='hold') done=state.holdProgress>=encounter.seconds;
      if (!done) return;
      this.emit('campaign-objective-complete',{step:state.stepIndex});
      state.bankedKills+=state.enemies.filter(id=>this.actors[id]?.health<=0).length;
      state.enemies=[]; state.boss=null;
      state.stepIndex++; state.deployed=false; state.holdProgress=0; state.restoring=false;
      state.checkpoint=state.stepIndex; state.checkpointPoint=checkpointPosition(this,player);
      player.health=Math.max(player.health,player.maxHealth*.8); player.armor=Math.max(player.armor,40);
      player.ammo.forEach((amount,i)=>{const cap=this.weaponForIndex(player,i)?.cap;
        if ((amount>0||i===player.weapon)&&Number.isFinite(cap)) player.ammo[i]=Math.max(amount,Math.ceil(cap*.8));});
      state.transmission={speaker:'ECHO',text:state.stepIndex===5?mission.outro:'Relay secured. Follow the service route; side paths carry supplies. Recover before the next contact.'};
    }
    campaignCheckpoint() {return {mapId,difficulty,checkpoint:state.checkpoint,checkpointPoint:{...state.checkpointPoint},
      elapsed:state.elapsed,totalElapsed:state.totalElapsed,kills:state.bankedKills};}
    completeCampaign() {if (state.phase==='level-complete' && data.campaign.nextMapId===null) finish(this,'campaign-complete');}
    snapshot() {
      const snapshot=super.snapshot(), encounter=mission.encounters[state.stepIndex], marker=currentAnchor();
      const mechanic=encounter?.mechanic;
      snapshot.campaign={id:'quiet-relay',mapId,index:data.campaign.index,title:mission.title,
        stepIndex:state.stepIndex,stepCount:6,objective:encounter?.title??'Follow the service route to the exit',
        detail:!state.deployed&&encounter?'Follow the waypoint. Optional supply routes branch from the service path.':
          mechanic==='restore'?'Clear guards, press Interact to begin, then stay inside the marker.':
          mechanic==='interact'?'Clear the guards, then press Interact inside the marker.':
          mechanic==='hold'?'Remain inside the marker and clear all guards. Progress is retained when you dodge.':
          encounter?(state.deployed&&remaining(this)===0?'Area clear—reach the relay marker':'Eliminate the deployed security robots.'):'Reach the exit to continue.',
        marker:state.phase==='playing'?{x:marker.x,y:marker.y,z:marker.z,radius:marker.radius}:null,
        phase:state.phase,checkpoint:state.checkpoint,elapsed:state.elapsed,totalElapsed:state.totalElapsed,
        kills:state.bankedKills+state.enemies.filter(id=>this.actors[id]?.health<=0).length,enemiesRemaining:remaining(this),
        holdProgress:encounter?.seconds?state.holdProgress/encounter.seconds:0,transmission:{...state.transmission},nextMapId:data.campaign.nextMapId};
      return snapshot;
    }
  }
  return new CampaignMatch('chatgpt','openclaw',random,mapId,{mode:'campaign',difficulty,botCount:0,humanCount:1});
}
