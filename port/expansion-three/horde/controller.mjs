// Test-only automated keyboard/mouse planner; not a production assist or balance test.
import {readFileSync} from 'node:fs';
import {controlsFromState} from '../../../game/input.mjs';
import {visible} from '../../../game/core.mjs';
import {readBlackwater} from '../../native-horde/blackwater-schema.mjs';
const graphs=JSON.parse(readFileSync(new URL('../../../godot/tests/horde/blackwater_fixture_routes.json',import.meta.url))).graphs;
const base=readBlackwater().arena;
const arenas=new Map();
const distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z);
const point=row=>({x:row[0],y:row[1],z:row[2]});
function arenaFor(mask){
 if(!arenas.has(mask))arenas.set(mask,{...base,blocks:[...base.blocks,...base.hordeStagePlan.gates.filter((_,i)=>!(mask&(1<<i)))]});
 return arenas.get(mask);
}
export function routeBetween(player,target,mask){
 const {nodes,edges}=graphs[mask];
 let start=-1,end=-1,a=Infinity,b=Infinity;
 nodes.forEach((row,i)=>{const p=point(row),d=distance(p,player),t=distance(p,target);
  if(Math.abs(p.y-player.y)<1&&d<a){a=d;start=i;}if(t<b){b=t;end=i;}});
 if(start<0||end<0)return [];
 const costs=new Float64Array(nodes.length).fill(Infinity),previous=new Int32Array(nodes.length).fill(-1),open=new Set([start]);costs[start]=0;
 while(open.size){
  let current=-1,best=Infinity;
  for(const i of open){const rank=costs[i]+distance(point(nodes[i]),target);if(rank<best){best=rank;current=i;}}
  open.delete(current);if(current===end)break;
  for(const next of edges[current]){const c=costs[current]+distance(point(nodes[current]),point(nodes[next]));if(c>=costs[next])continue;costs[next]=c;previous[next]=current;open.add(next);}
 }
 if(!Number.isFinite(costs[end]))return [];
 const result=[];for(let i=end;i>=0;i=previous[i]){result.unshift(point(nodes[i]));if(i===start)break;}
 result.push(target);return result;
}
export class JourneyController{
 constructor(){this.path=[];this.key='';this.nextPlan=0;this.nextInteract=0;this.nextPower=0;this.nextReload=0;this.offered=-1;this.yaw=0;this.pitch=0;}
 sample(snapshot){
  const player=snapshot.actors.find(a=>a.id===0),state=snapshot.singleplayer,mission=snapshot.blackwater;
  if(!player||player.health<=0||snapshot.over)return {input:{},keys:[],mouse:{fire:false},intent:null};
  const stage=state.stage,mask=stage.gateMask,arena=arenaFor(mask),now=snapshot.time;
  const eye={x:player.x,y:player.y+1.45,z:player.z};
  const enemies=snapshot.actors.filter(a=>a.isNpc&&a.health>0).sort((a,b)=>distance(a,player)-distance(b,player));
  const canSee=a=>visible(eye,{x:a.x,y:a.y+1.2,z:a.z},arena);
  // Visibility is a combat preference only inside our existing fire window.
  // A distant slit of visibility must not reverse a route toward nearer cover.
  const enemy=enemies.find(a=>distance(a,player)<65&&canSee(a))??enemies[0];
  const station=mission.stations.find(s=>s.id===mission.active)??mission.stations.filter(s=>s.available&&!mission.completed.includes(s.id)).sort((a,b)=>distance(a,player)-distance(b,player))[0];
  let target=station,key=station?.id??'',interact=false;
  if(stage.transit){target={x:stage.transit.to==='B'?0:170,z:0};key='transit-'+stage.transit.to;}
  else if(station&&distance(station,player)<4.0){target=null;if(mission.active!==station.id&&now>=this.nextInteract){interact=true;this.nextInteract=now+.75;}}
  else if(!station&&enemy){target=enemy;key='combat-'+enemy.id;if(canSee(enemy)&&distance(enemy,player)<24)target=null;}
  if(target&&(key!==this.key||now>=this.nextPlan)){
   this.path=routeBetween(player,target,mask);this.key=key;this.nextPlan=now+3;
  }
  while(this.path.length>1&&distance(this.path[0],player)<1.3)this.path.shift();
  let move=target?this.path[0]??target:null;
  // Stop charging point-blank hostiles. Holding a station remains higher priority.
  if(!station&&!stage.transit&&enemy&&canSee(enemy)&&distance(enemy,player)<10){
   const d=distance(enemy,player)||1,candidate={x:player.x+(player.x-enemy.x)/d*3,y:player.y,z:player.z+(player.z-enemy.z)/d*3};
   // Only use an already generated neighbouring walk node, never teleport.
   const graph=graphs[mask];move=graph.nodes.map(point).filter(p=>Math.abs(p.y-player.y)<.5&&distance(p,player)<3).sort((a,b)=>distance(a,candidate)-distance(b,candidate))[0]??null;
  }
  const aim=enemy??move??station;
  if(aim){this.yaw=Math.atan2(-(aim.x-player.x),-(aim.z-player.z));this.pitch=Math.atan2((aim.y??player.y)+1.2-eye.y,distance(aim,player));}
  const keys=new Set();
  if(move&&distance(move,player)>.8){
   const d=distance(move,player),dx=(move.x-player.x)/d,dz=(move.z-player.z)/d;
   const f=-Math.sin(this.yaw)*dx-Math.cos(this.yaw)*dz,r=Math.cos(this.yaw)*dx-Math.sin(this.yaw)*dz;
   if(f>.35)keys.add('KeyW');if(f<-.35)keys.add('KeyS');if(r>.35)keys.add('KeyD');if(r<-.35)keys.add('KeyA');
   if(!enemy||distance(enemy,player)>30)keys.add('ShiftLeft');
  }
  const fire=!!enemy&&canSee(enemy)&&distance(enemy,player)<65&&!stage.transit;
  const power=!!enemy&&distance(enemy,player)<5.5&&now>=this.nextPower;
  if(power){keys.add('KeyQ');this.nextPower=now+.5;}
  if(interact)keys.add('KeyE');
  // This source reload replenishes the equipped finite ammo pool. There is no
  // separate magazine field in its snapshot. Source validates the R pulse.
  const reload=player.ammo?.[player.weapon]===0&&now>=this.nextReload;
  if(reload){keys.add('KeyR');this.nextReload=now+.5;}
  let intent=null;
  if(state.upgrades?.length&&state.upgradeWave!==this.offered){
   const choices=state.upgrades;const index=Math.max(0,choices.findIndex(c=>c.id==='overshield'));
   intent={index:index+1,choice:choices[index].id,wave:state.upgradeWave};this.offered=state.upgradeWave;
  }
  const input=controlsFromState({keys,yaw:this.yaw,pitch:this.pitch,fire,interact,power,reload});
  return {input,keys:[...keys],mouse:{yaw:this.yaw,pitch:this.pitch,fire},intent,route:key,position:[player.x,player.y,player.z],
   decision:{target:enemy?.id??null,distance:enemy?distance(enemy,player):null,visible:enemy?canSee(enemy):false,
    weapon:player.weapon,ammo:player.ammo?.[player.weapon],waypoint:move??null,transit:!!stage.transit,station:station?.id??null}};
 }
}
