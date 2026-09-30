// Trusted, in-process VISUAL FIXTURE ONLY. Never imported by production launchers.
// Actors/poses and mission state are staged; these captures do not prove combat
// balance, route traversal, or organic progression. All frames use real authority.
import {createCampaignMatch} from '../native-campaign/match.mjs';
import {deployEncounter} from '../native-campaign/enemies.mjs';
import {floorAt, obstructed} from '../native-campaign/core.generated.mjs';

export const LONG_SUBTITLE = 'This is ECHO. The archive is intact, but the quarantine still controls the service corridor. Keep the pylons between you and the mortar, follow the marked route around the ridge, and wait for the warning ring to fade before crossing. I can hold the signal; I cannot hold the bridge for you.';
export function createCaptureScenarios() {
  let match, data, sourceStep, stage = 'gameplay', tellUntil = 0;
  const place = (actor, point) => Object.assign(actor, {x:point.x,y:point.y,z:point.z,vx:0,vy:0,vz:0,grounded:true,lastValid:{...point}});
  function supported(point) {
    const y = floorAt(point.x,point.z,data.arena);
    return Number.isFinite(y) && !obstructed(point.x,y,point.z,undefined,data.arena) ? {x:point.x,y,z:point.z} : null;
  }
  function gameplay(long = false) {
    const anchor = data.campaign.anchors['encounter-1'];
    const candidates = [...data.campaign.criticalPath, ...data.arena.navNodes]
      .filter(p => Math.hypot(p.x-anchor.x,p.z-anchor.z)>=10 && Math.hypot(p.x-anchor.x,p.z-anchor.z)<=24)
      .sort((a,b) => Math.abs(Math.hypot(a.x-anchor.x,a.z-anchor.z)-15)-Math.abs(Math.hypot(b.x-anchor.x,b.z-anchor.z)-15));
    const point = candidates.map(supported).find(Boolean);
    if (!point) throw Error('Capture fixture cannot find supported encounter camera feet');
    const player = match.actors[0];
    place(player,point);
    player.yaw = Math.atan2(-(anchor.x-point.x),-(anchor.z-point.z));
    player.pitch = Math.atan2(anchor.y+.8-(point.y+(player.eyeHeight??1.45)),Math.hypot(anchor.x-point.x,anchor.z-point.z));
    player.health = player.maxHealth; player.dead = 0;
    if (!match.actors.some(a=>a.npcModel)) {
      deployEncounter(match,match.modeState,{roster:{mortar:1,bulwark:1,skirmisher:1}},anchor);
      // Use supported authored/nav positions near the focal anchor; source role
      // spawning supplies real actors/profiles, this fixture only composes them.
      // Sparse nav vertices can leave no candidates inside nine metres. Include
      // a bounded supported-ground grid instead of retaining source spawnGroup's
      // unrelated initial spawn height when placeGroup has no local nav node.
      const grid=[];
      for(let x=-8;x<=8;x+=2)for(let z=-8;z<=8;z+=2)grid.push({x:anchor.x+x,z:anchor.z+z});
      const positions = [...data.arena.navNodes,...grid].filter(p=>Math.hypot(p.x-anchor.x,p.z-anchor.z)<=9)
        .map(supported).filter(Boolean).sort((a,b)=>Math.hypot(a.x-anchor.x,a.z-anchor.z)-Math.hypot(b.x-anchor.x,b.z-anchor.z));
      const used=[];
      for (const actor of match.actors.filter(a=>a.npcModel)) {
        const target=positions.find(p=>used.every(q=>Math.hypot(p.x-q.x,p.z-q.z)>2));
        if(!target)throw Error('No distinct supported robot pose for capture');
        place(actor,target);used.push(target);
        // Scripted poses do not tick combat timers. Clear only fixture robots'
        // spawn protection so frozen bubbles cannot obscure chassis acceptance.
        actor.protection=0;
        actor.yaw=Math.atan2(-(point.x-actor.x),-(point.z-actor.z));actor.bodyYaw=actor.yaw;
      }
    }
    match.modeState.deployed=true;
    match.modeState.transmission={speaker:'ECHO',text:long?LONG_SUBTITLE:'Mortar signal detected. Clear the amber ring before impact.'};
    const mortar=match.actors.find(a=>a.npcModel==='mortar');
    if(!mortar)throw Error('Capture fixture mortar missing');
    const mark={x:point.x+(anchor.x-point.x)*.48,z:point.z+(anchor.z-point.z)*.48};
    tellUntil=match.time+25;
    mortar.artilleryWindup=25; mortar.artilleryMark=mark;
    mortar.npcArtillery={...mortar.npcArtillery,telegraph:25};
    match.emit('enemy-telegraph',{actor:mortar.id,kind:'artillery',x:mark.x,z:mark.z,radius:2.8,duration:25});
  }
  function select(next) {
    if(!match)throw Error('Capture authority has no match yet');
    if(!['gameplay','long-subtitle','death','result'].includes(next))throw Error('Unknown scripted capture scenario');
    if(match.over)throw Error('Use normal retry/start before staging another scenario');
    stage=next;
    if(next==='gameplay'||next==='long-subtitle')gameplay(next==='long-subtitle');
    if(next==='death')match.actors[0].health=0;
    if(next==='result'){
      // Staged checkpoint/placement only; the actual campaign update emits its
      // normal level-complete results. Final Continue is never synthesized here.
      match.modeState.stepIndex=5;match.modeState.checkpoint=5;
      place(match.actors[0],data.campaign.anchors.exit);
    }
    return {scenario:stage,scripted:true,mapId:data.id,actors:match.actors.length};
  }
  return {
    select,
    matchFactory(options) {
      data=options.mapData;match=createCampaignMatch(options);sourceStep=match.step.bind(match);
      stage='gameplay';gameplay();
      match.step=(dt,input)=>{
        if(stage==='death'||stage==='result')return sourceStep(dt,input);
        // Freeze fixture actor poses for repeatable visual review, while the real
        // authority keeps normal-rate frames, epochs, ACKs and event transport.
        match.time+=dt;match.modeState.elapsed+=dt;match.modeState.totalElapsed+=dt;
        const mortar=match.actors.find(a=>a.npcModel==='mortar');
        if(mortar)mortar.artilleryWindup=Math.max(.01,tellUntil-match.time);
      };
      return match;
    },
  };
}
