import {inputs,RUNS} from './movement.mjs';
import {floorAt} from '../../../../game/core.mjs';
const maps=inputs(),groups={};
for(const variant of ['accepted','candidate'])for(const name of ['civic','roof']){
 if(variant==='accepted'&&name==='roof')continue; // not an accepted authored roof route; source counterexample retained
 for(const radius of [.35,.42]){
  const id=`${variant}-${name}-r${radius===.35?'035':'042'}`;
  groups[id]={variant,run:name,radius,height:1.8,controller:radius===.35?'unmodified exploration walker':'exploration walker with test-only authoritative-radius envelope',trials:[]};
  for(const x of RUNS[name].lanes)for(const direction of [-1,1]){
   const [z0,z1]=direction===1?RUNS[name].ends:[...RUNS[name].ends].reverse();
   groups[id].trials.push({id:`${name}:${x}:${direction}`,start:[x,floorAt(x,z0,maps[variant].arena),z0],goal:[x,floorAt(x,z1,maps[variant].arena),z1]});
  }
 }
}
console.log(JSON.stringify({status:'source-only; engine parsing and all native journeys pending',groups}));
