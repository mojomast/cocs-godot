// Bounded pure-source comparison; no authority process or engine required.
// stdout is the small evidence JSON. Baseline imports share unchanged data modules.
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import * as current from '../game/core.mjs';
const baselineRef='90be2af7';
const source=execFileSync('git',['show',`${baselineRef}:game/core.mjs`],{encoding:'utf8'});
const rewritten=source.replace(/from '(\.\/[^']+)'/g,(_,path)=>`from '${new URL(path,new URL('../game/core.mjs',import.meta.url)).href}'`);
const baseline=await import(`data:text/javascript;base64,${Buffer.from(rewritten).toString('base64')}`);
const arena={blocks:[],bounds:{minX:-10000,maxX:10000,minZ:-10000,maxZ:10000}};
const actor=(extra={})=>({x:0,y:0,z:0,vx:0,vy:0,vz:0,grounded:true,moveSpeed:8,coyote:0,jumpBuffer:0,...extra});
const speed=a=>Math.hypot(a.vx,a.vz),dt=1/60;
function measure({moveActor,MOVE}){
 const step=(a,input={})=>moveActor(a,input,dt,arena);
 const start=actor();let startTicks=0;while(speed(start)<8-1e-9&&startTicks<100){step(start,{x:1});startTicks++;}
 const coast=actor({vx:8});let coastTicks=0;while(speed(coast)>1e-9&&coastTicks<100){step(coast);coastTicks++;}
 const reverse=actor({vx:8,grounded:false,y:100});let reverseTicks=0;while(reverse.vx>-MOVE.airCap+1e-9&&reverseTicks<100){step(reverse,{x:-1});reverseTicks++;}
 const hop=actor({vx:8});step(hop,{jump:true});let hopTicks=1;while(!hop.grounded&&hopTicks<120){step(hop,{z:1,jump:true});hopTicks++;}
 const strafe=actor({vx:8});let maxSpeed=0,landings=0,firstOverCapTick=null;const samples=[];
 for(let i=0;i<9600;i++){
  const s=speed(strafe),wasGrounded=strafe.grounded;step(strafe,{x:-strafe.vz/s,z:strafe.vx/s,jump:true});
  maxSpeed=Math.max(maxSpeed,speed(strafe));if(!wasGrounded&&strafe.grounded)landings++;
  if(firstOverCapTick===null&&speed(strafe)>8*MOVE.terminal+1e-8)firstOverCapTick=i;
  if((i+1)%600===0)samples.push({seconds:(i+1)*dt,speed:speed(strafe)});
 }
 const impulse=actor({vx:24});step(impulse,{z:1,jump:true});
 const tap=actor({vx:8,y:.12,vy:-2,grounded:false});step(tap,{crouch:true,sprint:true});let tapTicks=1;
 while(!tap.grounded&&tapTicks<120){step(tap);tapTicks++;}step(tap);
 return {airAccel:MOVE.airAccel,airCap:MOVE.airCap,startTicks,coastTicks,airReverseTicks:reverseTicks,lateralHopMetres:hop.z,hopTicks,strafe:{seconds:160,maxSpeed,landings,firstOverCapTick,samples},incoming24AfterTakeoff:speed(impulse),landingTap:{landingTick:tapTicks,slideOnTick:tap.sliding?tapTicks+1:null,speed:speed(tap)}};
}
const result={baselineRef,dt,sourceSha256:createHash('sha256').update(readFileSync(new URL('../game/core.mjs',import.meta.url))).digest('hex'),baseline:measure(baseline),implemented:measure(current)};
const saved={airAccel:current.MOVE.airAccel,airCap:current.MOVE.airCap};
Object.assign(current.MOVE,{airAccel:3.5,airCap:1.6});result.capAndBufferOnly=measure(current);Object.assign(current.MOVE,saved);
console.log(JSON.stringify(result,null,2));
