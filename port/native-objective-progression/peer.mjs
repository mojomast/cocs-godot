import WebSocket from 'ws';
// A second ordinary protocol client. Reads only its received snapshots and sends inputs.
export function opposingPeer(endpoint, roomId, map, record) {
 const socket = new WebSocket(endpoint);
 let peerId, actorId, seq = 0, round = 0, targetIndex = 0, contestAt = null, leave = null, returned = false;
 let route = null;
 socket.on('open', () => socket.send(JSON.stringify({type:'join',roomId,name:'Objective defender',v:3,delta:0})));
 socket.on('error', error => record({type:'peer_error',message:error.message}));
 socket.on('message', data => {
  const f = JSON.parse(String(data));
  if (f.type === 'welcome') peerId = f.peerId;
  if (f.type === 'lobby') actorId = f.players.find(p => p.peerId === peerId)?.actorId;
  if (f.type === 'start') { round++; seq=0; }
  if (f.type === 'events' && f.items.some(e=>e.type==='flag-return')) returned=true;
  if (f.type !== 'snapshot') return;
  const a = f.state.actors.find(a=>a.id===actorId);
  if (!a || a.team!==1) return;
  let target = null;
  if (round === 1 && map === 'tidal-citadel') {
   const flag=f.state.flags.find(f=>f.team===a.team);
   target=flag.state==='dropped' && !returned ? [flag.x,flag.z] : [72,-5];
  } else if (round === 1) {
   // Sun Gate arch posts sit at x=78,z=-8/-28; use the clear east side.
   route ??= [[82,a.z],[82,-18],[78,-18],[54,-18],[14,-18],[0,18],[-44,18],[-54,-10],[-78,-10]];
   const p=f.state.objectives.payload;
   if(p.contested && contestAt===null) {contestAt=f.state.time;record({type:'peer_contest',time:contestAt});}
   if(contestAt!==null && f.state.time>contestAt+2) {
    leave ??= [a.x,a.z+12]; target=leave;
   } else {
    // Follow the authored freight road from the defender spawn; then approach live cart.
    if(targetIndex<route.length && Math.hypot(a.x-route[targetIndex][0],a.z-route[targetIndex][1])<1) targetIndex++;
    target=targetIndex<route.length ? route[targetIndex] : [p.position.x,p.position.z];
    if(Math.hypot(a.x-p.position.x,a.z-p.position.z)<8) target=[p.position.x,p.position.z];
   }
  }
  const dx=target ? target[0]-a.x : 0, dz=target ? target[1]-a.z : 0, distance=Math.hypot(dx,dz), move=distance>.6;
  socket.send(JSON.stringify({type:'input',seq:++seq,input:{x:move?dx/distance:0,z:move?dz/distance:0,yaw:Math.atan2(-dx,-dz),pitch:0,fire:false,interact:false}}));
 });
 return socket;
}
