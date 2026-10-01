// Offline, fixed-step AUTHORITATIVE replay fixture. Not organic/network footage.
// Uses production match + input validation/FIFO; only composition/AI is staged.
import {createCampaignMatch} from '../../port/native-campaign/match.mjs';
import {loadCampaignMap} from '../../port/native-campaign/maps.mjs';
import {deployEncounter} from '../../port/native-campaign/enemies.mjs';
import {floorAt, obstructed, visible} from '../../port/native-campaign/core.generated.mjs';
import {validateCampaignInput} from '../../port/native-campaign/authority.mjs';
import {InputBuffer} from '../../port/native-arenas/input-buffer.mjs';
import {EventCursor} from '../../port/native-arenas/event-cursor.mjs';

export function createTrailerFixture(shot, seed) {
  const data=loadCampaignMap(shot.map);
  const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  const match=createCampaignMatch({mapId:shot.map,mapData:data,difficulty:'easy',random});
  const player=match.actors[0], buffer=new InputBuffer(), cursor=new EventCursor();
  player.protection=0;
  let seq=0, target=null;
  const place=(a,p)=>Object.assign(a,{x:p.x,y:p.y,z:p.z,vx:0,vy:0,vz:0,grounded:true,lastValid:{...p}});
  const supported=(x,z)=>{const y=floorAt(x,z,data.arena);return Number.isFinite(y)&&!obstructed(x,y,z,.45,data.arena)?{x,y,z}:null;};
  function nearby(p,r,sight=false) {
    for(let i=0;i<32;i++){const t=i*Math.PI/16,q=supported(p.x+Math.sin(t)*r,p.z+Math.cos(t)*r);
      if(q&&Math.abs(q.y-p.y)<1&&(!sight||(!obstructed(q.x,q.y,q.z,2.2,data.arena)&&[-1,0,1].every(dx=>visible({x:q.x+dx,y:q.y+1.35,z:q.z},{x:p.x,y:p.y+.7,z:p.z},data.arena)))))return q;}
    throw Error(`No supported staging position: ${shot.id}`);
  }
  function aim(p) {
    player.yaw=Math.atan2(-(p.x-player.x),-(p.z-player.z));
    const h=p.npcHitVolume, chest=h?(h.bottom+h.top)/2:.7;
    player.pitch=Math.atan2(p.y+chest-player.y-(player.eyeHeight??1.45),Math.hypot(p.x-player.x,p.z-player.z));
  }
  if(['npc','pet'].includes(shot.kind)) {
    target=match.snapshot().campaign.story.entities.find(e=>e.id===shot.subject);
    if(!target)throw Error(`Story entity missing: ${shot.subject}`);
    place(player,nearby(target,shot.kind==='pet'?1.5:4));aim(target);
  } else if(['combat','melee','artillery','warden'].includes(shot.kind)) {
    const anchor=data.campaign.anchors['encounter-1'];
    const roster=shot.kind==='warden'?{warden:1}:shot.kind==='melee'?{bulwark:1}:shot.kind==='artillery'?{mortar:1}:{scrapper:1,skirmisher:1,sentinel:1};
    deployEncounter(match,match.modeState,{roster},anchor);
    match.modeState.deployed=true;
    const robots=match.actors.filter(a=>a.npcModel);
    robots.forEach((a,i)=>{place(a,nearby(anchor,2+i*3));a.protection=0;});
    target=robots[0];place(player,nearby(target,shot.kind==='melee'?2.1:10,true));aim(target);
    if(shot.kind==='warden')target.bodyYaw=target.yaw=Math.atan2(-(player.x-target.x),-(player.z-target.z));
    if(shot.kind==='artillery')target.artilleryCooldown=.75;
    player.protection=0;
  }
  const focal=shot.kind==='artillery'?{x:(target.x+player.x)/2,y:(target.y+player.y)/2,z:(target.z+player.z)/2}:
    target??data.campaign.anchors['encounter-1'];
  return {
    header:{shot,geometryHash:data.geometryHash,focus:{x:focal.x,y:focal.y,z:focal.z},vantage:{x:player.x,y:player.y,z:player.z},start:data.campaign.anchors.start},
    step(frame,fps) {
      // Logical E/F/fire inputs traverse the same validator and FIFO as the local
      // server; ACK here means fixed-step input application, NOT a network ACK.
      const input={yaw:player.yaw,pitch:player.pitch,interact:shot.kind==='pet'&&frame===fps,
        fire:shot.kind==='combat'&&frame>=fps&&frame<fps*4,
        melee:shot.kind==='melee'&&frame===fps};
      if(target?.npcModel){
        if(target.health<=0)target=match.actors.find(a=>a.npcModel&&a.health>0)??target;
        aim(target);
      }
      input.yaw=player.yaw;input.pitch=player.pitch;
      const envelope={type:'input',seq:++seq,inputEpoch:1,input};
      buffer.receive(seq,validateCampaignInput(envelope),frame*1000/fps);
      const applied=buffer.take();
      // Stop locomotion/aim AI for composed fire/melee shots. Production attack,
      // collision, damage, knockback and story update functions still execute.
      for(const a of match.actors.filter(a=>a.npcModel)) {
        a.bot=null;
      }
      // Two output frames cover exactly five production 60 Hz ticks. Pulses
      // appear on the first tick only; held fire/look persist on later ticks.
      const ticks=Math.floor((frame+1)*60/fps)-Math.floor(frame*60/fps);
      for(let tick=0;tick<ticks;tick++){
        match.step(1/60,{inputs:{0:tick===0?applied.input:buffer.take().input}});
      }
      buffer.stepped(applied.seq);
      const state=match.snapshot(),events=cursor.take(match);
      return {frame,input:envelope,acks:{0:buffer.applied},state,events};
    }
  };
}
