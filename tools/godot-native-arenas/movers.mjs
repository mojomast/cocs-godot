import fs from 'node:fs';
import assert from 'node:assert/strict';
import {floorAt,moveActor} from '../../game/core.mjs';
import {readNativeArena} from '../../port/native-arenas/schema.mjs';
import {createNativeMatch} from '../../port/native-arenas/match.mjs';

const results=[];
for(const id of ['prism-foundry','aurora-basin','cinder-array']){
  const data=readNativeArena(id),started=performance.now();
  const match=createNativeMatch({mapId:id,config:{botCount:3,timeLimit:60}}),arena=match.arena;
  const constructionMs=performance.now()-started,errors=[],routes=[];
  for(const route of data.routes){
    const actor={...route.points[0],vx:0,vy:0,vz:0,grounded:true,coyote:0,jumpBuffer:0,moveSpeed:4};
    let ticks=0,finished=true;
    for(const [i,target] of route.points.entries()){
      let reached=false;
      for(let step=0;step<180;step++){
        const dx=target.x-actor.x,dz=target.z-actor.z,distance=Math.hypot(dx,dz);
        if(distance<.12){reached=true;break;}
        const magnitude=Math.min(1,distance*4);
        moveActor(actor,{x:dx/distance*magnitude,z:dz/distance*magnitude},1/60,arena);
        ticks++;
        if(!Number.isFinite(actor.y)||actor.y<arena.voidY){errors.push(`${route.id} fell before point ${i}`);break;}
      }
      if(!reached){errors.push(`${route.id} did not reach ${i}: actor=${JSON.stringify({x:actor.x,y:actor.y,z:actor.z})} target=${JSON.stringify(target)}`);finished=false;break;}
      const support=floorAt(actor.x,actor.z,arena);
      if(support===null||Math.abs(actor.y-support)>.3){errors.push(`${route.id} support drift at ${i}`);finished=false;break;}
    }
    routes.push({id:route.id,finished,ticks});
  }
  const result={id,geometryHash:data.geometryHash,constructionMs:Math.round(constructionMs),navNodes:match.nav.length,routes,errors};
  results.push(result);console.log(JSON.stringify(result));
}
fs.writeFileSync('port/native-arena-geometry/movers.json',JSON.stringify(results,null,2)+'\n');
assert.equal(results.flatMap(r=>r.errors).length,0,'Actual source moveActor route failure');
