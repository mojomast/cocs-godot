// Pre-registry fixture: identical arena getter/setter seam to worldMatchClass.
// No actor, score, objective, physics or source-registry writes.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {canonical} from '../../multiplayer-worlds/catalog.mjs';
import {Match,nearest,visible} from '../../multiplayer-worlds/derived/core.mjs';
const {recipe}=await import(process.env.FOUNDRY_CANDIDATE ? '../../../tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/recipe.mjs' : '../../../tools/godot-multiplayer/new-maps/gravemill-foundry/recipe.mjs');
const started=performance.now(),results=[];
function make(mode){const arena=recipe();let assigned=false;class FoundryMatch extends Match{get arena(){return arena;}set arena(_){assert.ok(!assigned);assigned=true;}}let seed=193;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};return new FoundryMatch('chatgpt','openclaw',random,arena.id,{mode,botCount:0,humanCount:2,fragLimit:mode==='payload'||mode==='assault'?3:mode==='combined-arms'?50:mode==='domination'?10:1,timeLimit:600});}
function path(match,a,b){const from=nearest(a,match.nav),to=nearest(b,match.nav),queue=[from],prev=new Map([[from,-1]]);for(let i=0;i<queue.length&&!prev.has(to);i++)for(const n of match.edges[queue[i]])if(!prev.has(n)){prev.set(n,queue[i]);queue.push(n);}assert.ok(prev.has(to));const out=[b];for(let at=to;at!==-1;at=prev.get(at))out.push(match.nav[at]);return out.reverse();}
function travel(match,actor,target){const points=path(match,actor,target);return ()=>{while(points.length>1&&Math.hypot(actor.x-points[0].x,actor.z-points[0].z)<.65)points.shift();const p=points[0],dx=p.x-actor.x,dz=p.z-actor.z;return Math.hypot(dx,dz)>.45?{x:dx,z:dz}:{};};}
const modes=process.argv.slice(2).length?process.argv.slice(2):['payload','assault','domination','combined-arms','deathmatch','teamdeathmatch'];
for(const mode of modes){
 const match=make(mode),a=match.actors[0],enemy=match.actors[1],initial={x:a.x,z:a.z};let controller=null,key='',steps=0,distance=0,mounted=false,exited=false,driveDistance=0,driveSector=0;
 const enemyRetreat=travel(match,enemy,{x:166,y:12,z:25+.14*166});
 const vehicle=match.vehicles.find(v=>v.spawn?.x<0)??match.vehicles[0];
 const driveLine=match.arena.payloadPath.slice(0,3);
 while(!match.over&&steps++<26000){
  let input={},target=null,nextKey='';
  if(mode==='combined-arms'&&!exited){
   if(!mounted){target={...vehicle.position};nextKey='vehicle';if(Math.hypot(a.x-target.x,a.z-target.z)<2.2){input={interact:true};target=null;}}
   else if(a.vehicleId!==null){
    const v=match.vehicleById(a.vehicleId),p=driveLine[driveSector+1],dx=p.x-v.position.x,dz=p.z-v.position.z;
    if(Math.hypot(dx,dz)<5){driveSector++;if(driveSector>=driveLine.length-1)input={interact:true};}
    if(!input.interact){const desired=Math.atan2(dx,dz),error=Math.atan2(Math.sin(desired-v.heading),Math.cos(desired-v.heading)),steer=Math.max(-1,Math.min(1,error*1.5)),throttle=v.speed<7?1:0,yaw=v.heading-Math.PI;input={x:-Math.sin(yaw)*throttle-Math.cos(yaw)*steer,z:-Math.cos(yaw)*throttle+Math.sin(yaw)*steer,yaw,jump:v.speed>9};}
   }else{exited=true;key='';}
  }else if(mode==='payload'){target=match.objectiveState.position;nextKey=Math.hypot(a.x-target.x,a.z-target.z)>5?'cart-approach':'cart-follow';}
  else if(mode==='assault'){target=match.objectiveState.zones[match.objectiveState.active]??match.objectiveState.zones.at(-1);nextKey=`sector-${match.objectiveState.active}`;}
  else if(mode==='domination'||mode==='combined-arms'){target=match.objectiveState.zones[0];nextKey='zone';}
  else {target=enemy;nextKey=`combat-${enemy.health>0}`;}
  if(target){
   if(mode==='payload'&&nextKey==='cart-follow'){const dx=target.x-a.x,dz=target.z-a.z;input=Math.hypot(dx,dz)>.65?{x:dx,z:dz}:{};}
   else {if(nextKey!==key){key=nextKey;controller=travel(match,a,target);}input=controller();}
   if(['deathmatch','teamdeathmatch'].includes(mode)&&Math.hypot(enemy.x-a.x,enemy.z-a.z)<25&&visible({x:a.x,y:a.y+1.45,z:a.z},{x:enemy.x,y:enemy.y+1,z:enemy.z},match.arena)){const dx=enemy.x-a.x,dz=enemy.z-a.z,dy=enemy.y-a.y-.45;input={yaw:Math.atan2(-dx,-dz),pitch:Math.atan2(dy,Math.hypot(dx,dz)),fire:true,reload:a.ammo[a.weapon]===0};}
  }
  const old={x:a.x,z:a.z};match.step(.025,{inputs:{[a.id]:input,[enemy.id]:['deathmatch','teamdeathmatch'].includes(mode)?{}:enemyRetreat()}});const moved=Math.hypot(a.x-old.x,a.z-old.z);distance+=moved;if(a.vehicleId!==null){mounted=true;driveDistance+=moved;}
 }
 assert.ok(match.over,`${mode} did not finish: ${JSON.stringify({a:{x:a.x,z:a.z},key,state:match.objectiveState,driveSector,mounted,exited})}`);
 if(mode==='payload')assert.ok(match.objectiveState.delivered,JSON.stringify({time:match.time,a:{x:a.x,z:a.z,team:a.team},distance:match.objectiveState.distance,total:match.objectiveState.total,contested:match.objectiveState.contested}));
 if(mode==='assault')assert.equal(match.objectiveState.winner,a.team);
 if(mode==='combined-arms'){assert.ok(mounted&&exited&&driveDistance>60);assert.ok(match.objectiveState.zones.some(z=>z.owner===a.team));}
 if(mode==='domination')assert.ok(match.objectiveState.zones.some(z=>z.owner===a.team));
 if(['deathmatch','teamdeathmatch'].includes(mode))assert.ok(match.stats.kills>0);
 const result={mode,label:'two-seat source full-round normal-input fixture; passive opponent',seconds:match.time,steps,distance,initial,teamScores:match.teamScores,kills:match.stats.kills,mounted,exited,driveDistance,objective:mode==='payload'?{delivered:match.objectiveState.delivered,checkpoints:match.objectiveState.checkpointsReached}:mode==='assault'?{winner:match.objectiveState.winner}:null};results.push(result);console.log(JSON.stringify(result));
}
const report={geometryHash:createHash('sha256').update(canonical(recipe())).digest('hex'),milliseconds:performance.now()-started,results,native:false};if(process.env.FOUNDRY_EVIDENCE){fs.mkdirSync(process.env.FOUNDRY_EVIDENCE,{recursive:true});fs.writeFileSync(`${process.env.FOUNDRY_EVIDENCE}/round-check-${modes.join('-')}.json`,JSON.stringify(report,null,2)+'\n');}
