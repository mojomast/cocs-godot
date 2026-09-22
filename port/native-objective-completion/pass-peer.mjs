import WebSocket from 'ws';
// Two ordinary peers, ordered by welcome: Blue observer then Red receiver.
export function passPeer(endpoint,roomId,friendly,record){
 const socket=new WebSocket(endpoint);
 let peerId,actorId,seq=0,round=0,index=0,carried=false;
 const outward=[[-72,0],[-54,0],[-26,0],[0,8],[26,0],[54,0],[62,2]],home=[[54,0],[26,0],[0,8],[-26,0],[-54,0],[-72,0]];
 socket.on('open',()=>socket.send(JSON.stringify({type:'join',roomId,name:friendly?'Friendly flag receiver':'Blue observer',v:3,delta:0})));
 socket.on('error',error=>record({type:'peer_error',message:error.message}));
 socket.on('message',data=>{
  const f=JSON.parse(String(data));
  if(f.type==='welcome')peerId=f.peerId;
  if(f.type==='lobby')actorId=f.players.find(p=>p.peerId===peerId)?.actorId;
  if(f.type==='start'){round++;seq=0;}
  if(f.type!=='snapshot')return;
  const a=f.state.actors.find(a=>a.id===actorId);if(!a)return;
  let target=null;
  if(round===1){
   if(friendly){
    if(a.team!==0)throw Error('Expected source-assigned teammate');
    if(a.carryingFlag&&!carried){carried=true;index=0;record({type:'peer_pass_carrier',actorId,time:f.state.time});}
    const route=carried?home:outward;
    if(index<route.length-1&&Math.hypot(a.x-route[index][0],a.z-route[index][1])<.7)index++;
    target=route[index];
   }else target=[72,-5];
  }
  const dx=target?target[0]-a.x:0,dz=target?target[1]-a.z:0,d=Math.hypot(dx,dz),move=d>.5;
  socket.send(JSON.stringify({type:'input',seq:++seq,input:{x:move?dx/d:0,z:move?dz/d:0,yaw:Math.atan2(-dx,-dz),pitch:0,fire:false,interact:false}}));
 });
 return socket;
}
