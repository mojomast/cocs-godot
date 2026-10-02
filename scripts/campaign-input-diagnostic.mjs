// Read-only bounded observer; importing this module starts no authority or engine.
const pick=(value,keys)=>Object.fromEntries(keys.filter(k=>value?.[k]!==undefined).map(k=>[k,value[k]]));
const fields=['x','z','yaw','pitch','fire','jump','sprint','crouch','interact','cancel'];
export function campaignInputDiagnostic(limit=16384) {
  const rows=[];let dropped=0;
  return {
    observe(row) {
      let data;
      if(row.direction==='step')data={kind:'applied',...pick(row,['inputEpoch','inputSeq','sourceTime','appliedSeq','receivedSeq','cancelledThrough','queueDepth']),controls:pick(row.controls,fields)};
      else if(row.direction==='in'&&row.frame?.type==='input')data={kind:'received',...pick(row.frame,['seq','inputEpoch','cancel']),controls:pick(row.frame.input,fields)};
      else if(row.direction==='out'&&row.frame?.type==='snapshot')data={kind:'snapshot',...pick(row.frame,['seq','ack','inputEpoch']),sourceTime:row.frame.state?.time,
        fifo:pick(row.frame.nativeArenaInput,['receivedSeq','appliedSeq','cancelledThrough','queueDepth']),
        actors:(row.frame.state?.actors??[]).filter(a=>a.isNpc!==true).map(a=>pick(a,['id','x','y','z','health','dead']))};
      if(!data)return;
      if(rows.length>=limit){dropped++;return;}
      rows.push({round:row.round,observedMs:row.observedMs,...data});
    },
    result:()=>({schema:1,limit,dropped,complete:dropped===0,rows}),
  };
}
