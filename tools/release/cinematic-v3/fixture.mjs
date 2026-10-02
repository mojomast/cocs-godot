import {createTrailerFixture} from '../../godot-campaign/trailer-fixture.mjs';
import {createCampaignMatch} from '../../../port/native-campaign/match.mjs';
import {loadCampaignMap} from '../../../port/native-campaign/maps.mjs';
import {deployEncounter} from '../../../port/native-campaign/enemies.mjs';
import {floorAt,obstructed,visible} from '../../../port/native-campaign/core.generated.mjs';
import {validateCampaignInput} from '../../../port/native-campaign/authority.mjs';
import {InputBuffer} from '../../../port/native-arenas/input-buffer.mjs';
import {EventCursor} from '../../../port/native-arenas/event-cursor.mjs';

export function createFixture(shot,seed) {
  if(!['traverse','played-combat'].includes(shot.kind)) {
    const fixture=createTrailerFixture(shot,seed);
    fixture.header.setup={placement:'supported source staging',opposition:'locomotion AI disabled per frame by legacy staged fixture',
      inputs:'validated fire / melee / interact; not network or human input'};
    return fixture;
  }
  const data=loadCampaignMap(shot.map),random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
  const match=createCampaignMatch({mapId:shot.map,mapData:data,difficulty:'easy',random});
  const player=match.actors[0],buffer=new InputBuffer(),cursor=new EventCursor();
  const route=data.routes.find(r=>r.id===shot.route)?.points.slice();
  for(const id of shot.continuation??[]) {
    const part=data.routes.find(r=>r.id===id)?.points.slice();
    if(!part||!route)throw Error('Missing route continuation');
    const end=route.at(-1),distance=p=>Math.hypot(p.x-end.x,p.z-end.z);
    if(distance(part.at(-1))<distance(part[0]))part.reverse();
    if(distance(part[0])>.01)throw Error('Disconnected optional route');
    route.push(...part.slice(1));
  }
  const place=(a,p)=>Object.assign(a,{x:p.x,y:p.y,z:p.z,vx:0,vy:0,vz:0,grounded:true,lastValid:{x:p.x,y:p.y,z:p.z}});
  if(shot.kind==='traverse'&&shot.route!=='critical-path')place(player,route[0]);
  if(shot.kind==='played-combat') {
    const anchor=data.campaign.anchors['encounter-1'];
    deployEncounter(match,match.modeState,{roster:{scrapper:1,skirmisher:1,sentinel:1}},anchor);
    match.modeState.deployed=true;
    const target=match.actors.find(a=>a.npcModel);
    let point;
    for(let i=0;i<64;i++) {
      const x=target.x+Math.sin(i*Math.PI/32)*10,z=target.z+Math.cos(i*Math.PI/32)*10,y=floorAt(x,z,data.arena);
      if(Number.isFinite(y)&&!obstructed(x,y,z,.65,data.arena)&&visible({x,y:y+1.45,z},{x:target.x,y:target.y+.8,z:target.z},data.arena)){point={x,y,z};break;}
    }
    if(!point)throw Error(`${shot.id}: no supported combat start`);
    place(player,point);
  }
  // From here, only validated input and match.step mutate the match. Normal enemy AI stays active.
  let next=1,seq=0;
  return {header:{shot,geometryHash:data.geometryHash,focus:{x:player.x,y:player.y,z:player.z},
    setup:{placement:shot.kind==='played-combat'?'supported encounter deployment':shot.route==='critical-path'?'default spawn':'authored optional-route start',
      opposition:'production AI active',inputs:'ordinary validated controls after setup; offline scripted, not human/network'}},
    step(frame,fps) {
      const input={yaw:player.yaw,pitch:player.pitch};
      if(route) {
        while(next<route.length&&Math.hypot(route[next].x-player.x,route[next].z-player.z)<1.2)next++;
        if(next<route.length){const p=route[next],dx=p.x-player.x,dz=p.z-player.z,d=Math.hypot(dx,dz);
          Object.assign(input,{x:dx/d,z:dz/d,yaw:Math.atan2(-dx,-dz),pitch:-.04,sprint:shot.route==='critical-path',jump:!!shot.jump&&frame===fps/2});}
      } else {
        const targets=match.actors.filter(a=>a.npcModel&&a.health>0&&visible({x:player.x,y:player.y+1.45,z:player.z},{x:a.x,y:a.y+.8,z:a.z},data.arena));
        targets.sort((a,b)=>Math.hypot(a.x-player.x,a.z-player.z)-Math.hypot(b.x-player.x,b.z-player.z));
        const target=targets[0];
        if(target){const h=target.npcHitVolume,chest=h?(h.bottom+h.top)/2:.8;
          input.yaw=Math.atan2(-(target.x-player.x),-(target.z-player.z));
          input.pitch=Math.atan2(target.y+chest-player.y-(player.eyeHeight??1.45),Math.hypot(target.x-player.x,target.z-player.z));
          input.fire=frame>=fps;}
      }
      const envelope={type:'input',seq:++seq,inputEpoch:1,input};
      buffer.receive(seq,validateCampaignInput(envelope),frame*1000/fps);
      const applied=buffer.take(),ticks=Math.floor((frame+1)*60/fps)-Math.floor(frame*60/fps);
      for(let t=0;t<ticks;t++)match.step(1/60,{inputs:{0:t===0?applied.input:buffer.take().input}});
      buffer.stepped(applied.seq);
      return {frame,input:envelope,acks:{0:buffer.applied},state:match.snapshot(),events:cursor.take(match)};
    }};
}
