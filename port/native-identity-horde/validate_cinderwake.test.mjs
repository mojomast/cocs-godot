import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyStageSequence} from './validate_cinderwake.mjs';

const packet=(stage,wave=2)=>({frame:{state:{singleplayer:{wave,stage}}}});
function fixture(){
  const events=[
    {type:'horde-wave-cleared',wave:2,time:20,sourceId:42},
    {type:'horde-transit-begin',id:43,sourceId:1,from:'B',to:'C',causeEventId:42,time:20},
    {type:'horde-gate-open',transitId:1,gateMask:1,time:23},
    {type:'horde-stage-entered',transitId:1,stageId:'C',causeEventId:42,arrivalTicks:30,time:26},
  ];
  const snapshots=[...Array.from({length:25},()=>packet({stageId:'B',gateMask:0,geometryRevision:0,transit:null},1)),
    packet({stageId:'B',gateMask:1,geometryRevision:1,transit:{phase:'travel'}}),
    packet({stageId:'C',gateMask:1,geometryRevision:1,transit:null}),
    packet({stageId:'C',gateMask:1,geometryRevision:1,transit:null},3)];
  const gates=[{revision:0,gateMask:0,nativeGateVisible:[true,true]},
    {revision:1,gateMask:1,nativeGateVisible:[false,true]}];
  return {events,snapshots,gates};
}
test('source-causal wave-2 transition and native open slab pass',()=>{
  const {events,snapshots,gates}=fixture();
  assert.equal(verifyStageSequence(events,snapshots,gates,'waves').causeEventId,42);
});
test('wrong cause, early opening, no arrival hold or stale native mask each fail',()=>{
  for(const mutate of [
    f=>f.events[1].causeEventId=33,
    f=>f.events[2].time=21,
    f=>f.events[3].arrivalTicks=0,
    f=>f.gates[1].nativeGateVisible=[true,true],
    f=>f.snapshots.at(-1).frame.state.singleplayer.stage.stageId='B',
  ]){
    const f=fixture();mutate(f);
    assert.throws(()=>verifyStageSequence(f.events,f.snapshots,f.gates,'waves'));
  }
});
test('second source-causal transition demands CD gate, destination hold and wave-5 clear',()=>{
  const f=fixture();
  f.events.push({type:'horde-wave-cleared',wave:5,time:50,sourceId:77},
    {type:'horde-transit-begin',id:78,sourceId:2,from:'C',to:'D',causeEventId:77,time:50},
    {type:'horde-gate-open',transitId:2,gateMask:3,time:53},
    {type:'horde-stage-entered',transitId:2,stageId:'D',causeEventId:77,arrivalTicks:32,time:58});
  f.snapshots.push(packet({stageId:'D',gateMask:3,geometryRevision:2,transit:null},5));
  f.gates.push({revision:2,gateMask:3,nativeGateVisible:[false,false]});
  assert.deepEqual(verifyStageSequence(f.events,f.snapshots,f.gates,'stages').stages,['B','C','D']);
  f.gates[2].nativeGateVisible=[false,true];
  assert.throws(()=>verifyStageSequence(f.events,f.snapshots,f.gates,'stages'),/native CD slab/);
});
