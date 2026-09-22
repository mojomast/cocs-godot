import WebSocket from 'ws';
// Ordinary opposing peer: checkpoint-1 rollback, then leave the escort route.
export function opposingPeer(endpoint,roomId,map,record){
 const socket=new WebSocket(endpoint);
 let peerId,actorId,seq=0,round=0,index=0,route=null,bankAt=null,leave=null;
 socket.on('open',()=>socket.send(JSON.stringify({type:'join',roomId,name:'Banked rollback defender',v:3,delta:0})));
 socket.on('error',error=>record({type:'peer_error',message:error.message}));
 socket.on('message',data=>{
  const f=JSON.parse(String(data));
  if(f.type==='welcome')peerId=f.peerId;
  if(f.type==='lobby')actorId=f.players.find(p=>p.peerId===peerId)?.actorId;
  if(f.type==='start'){round++;seq=0;}
  if(f.type!=='snapshot')return;
  const a=f.state.actors.find(a=>a.id===actorId);if(!a||a.team!==1)return;
  let target=null;
  if(round===1){
   const p=f.state.objectives.payload,bank=f.state.objectives.zones[0].distance;
   route??=[[82,a.z],[82,-18],[78,-18],[54,-18],[14,-18],[0,18],[-22,14]];
   if(p.pushing===1&&p.checkpointsReached===1&&Math.abs(p.distance-bank)<.002&&bankAt===null){bankAt=f.state.time;record({type:'peer_banked',time:bankAt,distance:p.distance});}
   if(bankAt!==null&&f.state.time>bankAt+2){leave??=[a.x,a.z+12];target=leave;}
   else if(p.distance>bank+3||bankAt!==null||p.pushing===1)target=[p.position.x,p.position.z];
   else{if(index<route.length&&Math.hypot(a.x-route[index][0],a.z-route[index][1])<.8)index++;target=route[Math.min(index,route.length-1)];}
  }
  const dx=target?target[0]-a.x:0,dz=target?target[1]-a.z:0,d=Math.hypot(dx,dz),move=d>.5;
  socket.send(JSON.stringify({type:'input',seq:++seq,input:{x:move?dx/d:0,z:move?dz/d:0,yaw:Math.atan2(-dx,-dz),pitch:0,fire:false,interact:false}}));
 });
 return socket;
}
