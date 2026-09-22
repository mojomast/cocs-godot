import assert from 'node:assert/strict';
// Receipt, applied high-water ACK and gameplay outcome are separate witnesses.
// An ACK does not establish that every superseded input was simulated.
export function inputEvidence(wire,native){
 const counts=[];
 for(const connection of [...new Set(wire.filter(r=>r.type==='welcome').map(r=>r.connection))]){
  const welcome=wire.find(r=>r.connection===connection&&r.type==='welcome');
  const player=wire.filter(r=>r.connection===connection&&r.type==='lobby').flatMap(r=>r.players).find(p=>p.peerId===welcome.peerId&&p.actorId!==null);
  assert.ok(player,'ordinary peer-to-actor identity');
  const rows=wire.filter(r=>r.connection===connection&&r.round===1);
  const receipts=rows.filter(r=>r.type==='received'&&r.frame.type==='input');
  const bySeq=new Map(receipts.map(r=>[r.frame.seq,r]));
  let previous=0,appliedSamples=0;
  for(const frame of rows.filter(r=>r.type==='snapshot')){
   const ack=frame.acks[String(player.actorId)];assert.ok(Number.isInteger(ack)&&ack>=previous,'monotone application high-water');
   if(ack>0){const receipt=bySeq.get(ack);assert.ok(receipt&&receipt.wall<=frame.wall,'applied ACK has prior same-peer receipt');appliedSamples++;}
   previous=ack;
  }
  assert.ok(appliedSamples>10);
  counts.push({connection,actorId:player.actorId,receipts:receipts.length,appliedSamples,appliedHighWater:previous});
 }
 let highWater=0,round=0;
 for(const row of native){
  if(row.round!==round){round=row.round;highWater=0;}
  const frame=wire.find(r=>r.connection===0&&r.round===row.round&&r.type==='snapshot'&&r.seq===row.snapshot_seq);
  highWater=Math.max(highWater,frame.acks[String(row.actor_id)]??0);
  assert.equal(row.ack,highWater,'native applied ACK matches recipient snapshot high-water');
 }
 const result=wire.find(r=>r.connection===0&&r.type==='results'),restart=wire.find(r=>r.connection===0&&r.type==='start'&&r.round===2);
 assert.ok(!wire.some(r=>r.connection===0&&r.type==='received'&&r.frame.type==='input'&&r.wall>result.wall+100&&r.wall<restart.wall),'result stops primary input transmission');
 return{peers:counts,meaning:'receipt and applied high-water only; source objective events/states establish gameplay outcomes'};
}
