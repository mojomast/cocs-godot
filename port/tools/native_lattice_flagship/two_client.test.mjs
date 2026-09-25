import {test} from 'node:test';
import assert from 'node:assert/strict';
import {evaluatePair,classifyTerminal,evaluateFullRound} from './two_client.mjs';

const rec=(direction,type,frame={})=>({direction,frame:{type,...frame}});
test('pre-start gate uses two ordinary peers; post-start requires distinct actor assignments and both starts',()=>{
  const players=[{peerId:1,actorId:null,connected:true,spectate:false},{peerId:2,actorId:null,connected:true,spectate:false}];
  const s={host:[rec('recipient','welcome',{roomId:'ABCD',peerId:1}),rec('recipient','lobby',{roomId:'ABCD',config:{mode:'cocs'},players})],guest:[rec('recipient','welcome',{roomId:'ABCD',peerId:2}),rec('recipient','lobby',{roomId:'ABCD',players})]};
  const before=evaluatePair(s);assert.equal(before.two_distinct_peers,true);assert.equal(before.host_config_echoed,true);assert.equal(before.two_distinct_actors,false);
  const assigned=players.map((p,i)=>({...p,actorId:10+i}));
  for(const who of ['host','guest'])s[who].push(rec('recipient','lobby',{roomId:'ABCD',players:assigned}),rec('recipient','start'));
  assert.deepEqual(evaluatePair(s),{room_match:true,host_config_echoed:true,guest_published_presence:true,two_distinct_peers:true,two_distinct_actors:true,host_start_observed:true,guest_start_observed:true,guest_start_messages:0});
});
test('no actors or mismatched room never opens host start gate; outgoing guest start is explicitly counted',()=>{
 const s={host:[rec('recipient','welcome',{roomId:'ABCD',peerId:1})],guest:[rec('recipient','lobby',{roomId:'OTHER',players:[{peerId:2,actorId:20}]}),rec('client','start')]};
  const gate=evaluatePair(s);assert.equal(gate.room_match,false);assert.equal(gate.guest_published_presence,false);assert.equal(gate.two_distinct_peers,false);assert.equal(gate.two_distinct_actors,false);assert.equal(gate.guest_start_messages,1);
});

// Full-round fixtures. Every terminal/restart fact is a recipient frame; no
// helper fabricates an authoritative event.
const welcome=(peerId,ms=1)=>({direction:'recipient',elapsed_ms:ms,frame:{type:'welcome',peerId,roomId:'ABCD'}});
const lobby=(peerId,actorId,ms=11,revision=1)=>({direction:'recipient',elapsed_ms:ms,frame:{type:'lobby',roomId:'ABCD',roundRevision:revision,players:[{peerId,actorId,connected:true,spectate:false}]}});
const started=(rev,ms=10)=>({direction:'recipient',elapsed_ms:ms,frame:{type:'start',roundRevision:rev}});
const terminal=(ms=100,state={})=>({direction:'recipient',elapsed_ms:ms,frame:{type:'results',state:{over:true,winner:0,overReason:'time',time:120,...state}}});
const pvp={cocs:{outcome:{mode:'pvp',waves:null,hq:null}}};
const bothRevs={host:[1,2],guest:[1,2]};

test('full round needs both recipient terminals and a clean restart on both sockets',()=>{
 const host=[welcome(1),lobby(1,10),started(1),terminal(100,{winner:0,overReason:'dominance',...pvp})];
 const guest=[welcome(2),lobby(2,20),started(1),terminal(100,{winner:0,overReason:'dominance',...pvp})];
 const before=evaluateFullRound({host,guest},{snapshotRevisions:{host:[1],guest:[1]}});
 assert.equal(before.both_terminal,true);assert.equal(before.both_restarted,false);assert.equal(before.witness_status,'INCOMPLETE');
 assert.ok(before.failures.some(f=>f.includes('no clean restart')));
 host.push(started(2,150));guest.push(started(2,150));
 const after=evaluateFullRound({host,guest},{snapshotRevisions:bothRevs});
 assert.equal(after.witness_status,'ROUND_OBSERVED');assert.equal(after.claim,'ENGINE_FULL_ROUND_OBSERVED');
 assert.equal(after.terminal_class,'source-winner-team-0');assert.equal(after.operations_outcome,'not-operations');
 assert.equal(after.claims.source_winner,true);
 assert.equal(after.claims.five_wave_win,false);assert.equal(after.claims.human_identity,false);assert.equal(after.claims.scripted_input,true);
});

const terminalReport=(who,actor,peer,winner)=>({status:'terminal',engine_input:true,human_input:false,actor,peer,result_present:true,result_winner:winner});
const restartReport=(actor,peer)=>({status:'restarted',engine_input:true,human_input:false,actor,peer});

test('independent native reports must match each recipient socket identity and winner',()=>{
 const complete=(peer,actor)=>[welcome(peer),lobby(peer,actor),started(1),terminal(100,{...pvp}),started(2,150)];
 const sockets={host:complete(1,10),guest:complete(2,20)};
 const good={host:[terminalReport('host',10,1,0),restartReport(10,1)],guest:[terminalReport('guest',20,2,0),restartReport(20,2)]};
 const observed=evaluateFullRound(sockets,{snapshotRevisions:bothRevs,reports:good});
 assert.equal(observed.native_correlated,true);assert.equal(observed.witness_status,'ROUND_OBSERVED');
 const swapped={host:[terminalReport('host',10,1,0),restartReport(10,1)],guest:[terminalReport('guest',20,1,0),restartReport(20,2)]};
 const mismatch=evaluateFullRound(sockets,{snapshotRevisions:bothRevs,reports:swapped});
 assert.equal(mismatch.native_correlated,false);assert.equal(mismatch.witness_status,'INCOMPLETE');
 assert.ok(mismatch.failures.some(f=>f.startsWith('guest: native terminal report identity')));
 const human={host:[{status:'terminal',engine_input:true,human_input:true,actor:10,peer:1,result_present:true,result_winner:0},restartReport(10,1)],guest:[terminalReport('guest',20,2,0),restartReport(20,2)]};
 const scripted=evaluateFullRound(sockets,{snapshotRevisions:bothRevs,reports:human});
 assert.ok(scripted.failures.some(f=>f.includes('not scripted engine input')));
});

test('missing one recipient terminal result is never an observed round',()=>{
 const host=[welcome(1),lobby(1,10),started(1),terminal(100,{...pvp}),started(2,150)];
 const guest=[welcome(2),lobby(2,20),started(1),started(2,150)];
 const r=evaluateFullRound({host,guest},{snapshotRevisions:bothRevs});
 assert.equal(r.both_terminal,false);assert.equal(r.witness_status,'INCOMPLETE');
 assert.ok(r.failures.some(f=>f.startsWith('guest: no recipient terminal')));
});

test('missing restart on one recipient socket blocks the round',()=>{
 const host=[welcome(1),lobby(1,10),started(1),terminal(100,{...pvp}),started(2,150)];
 const guest=[welcome(2),lobby(2,20),started(1),terminal(100,{...pvp})];
 const r=evaluateFullRound({host,guest},{snapshotRevisions:bothRevs});
 assert.equal(r.both_terminal,true);assert.equal(r.both_restarted,false);assert.equal(r.witness_status,'INCOMPLETE');
 assert.ok(r.failures.some(f=>f.startsWith('guest: no clean restart')));
});

test('a capped wire can never be an observed full round',()=>{
 const complete=s=>[welcome(s),lobby(s,s===1?10:20),started(1),terminal(100,{...pvp}),started(2,150)];
 const r=evaluateFullRound({host:complete(1),guest:complete(2)},{dropped:3,snapshotRevisions:bothRevs});
 assert.equal(r.witness_status,'CAPTURE_CAPPED');assert.equal(r.claim,'CAPTURE_CAPPED');
 assert.equal(r.claims.source_winner,false);
 assert.ok(r.failures.some(f=>f.startsWith('capture capacity')));
});

test('a shared recipient actor or an unsnapshotted terminal round is an identity mismatch',()=>{
 const complete=(peer,actor)=>[welcome(peer),lobby(peer,actor),started(1),terminal(100,{...pvp}),started(2,150)];
 const shared=evaluateFullRound({host:complete(1,10),guest:complete(2,10)},{snapshotRevisions:bothRevs});
 assert.equal(shared.distinct_actors,false);assert.equal(shared.witness_status,'INCOMPLETE');
 assert.ok(shared.failures.includes('two distinct recipient-assigned actors not observed'));
 const unconfirmed=evaluateFullRound({host:complete(1,10),guest:complete(2,20)},{snapshotRevisions:{host:[2],guest:[2]}});
 assert.equal(unconfirmed.sockets.host.identity,false);assert.equal(unconfirmed.witness_status,'INCOMPLETE');
});

test('pre-start null actor assignment cannot hide or replace the sourced round assignment',()=>{
 const complete=(peer,actor)=>[welcome(peer),lobby(peer,null,2,0),started(1),lobby(peer,actor),terminal(100,{...pvp}),started(2,150)];
 const valid=evaluateFullRound({host:complete(1,10),guest:complete(2,20)},{snapshotRevisions:bothRevs});
 assert.equal(valid.witness_status,'ROUND_OBSERVED');
 assert.equal(valid.sockets.host.actorId,10);
 const hostOnlyPrestart=[welcome(1),lobby(1,null,2,0),started(1),terminal(100,{...pvp}),started(2,150)];
 const missing=evaluateFullRound({host:hostOnlyPrestart,guest:complete(2,20)},{snapshotRevisions:bothRevs});
 assert.equal(missing.witness_status,'INCOMPLETE');
 assert.equal(missing.sockets.host.identity,false);
});

test('operations terminal distinguishes completion from failure and never earns a five-wave or human claim',()=>{
 const failed=classifyTerminal({state:{over:true,winner:1,overReason:'operation-failed',cocs:{outcome:{mode:'operations',waves:{cleared:4,total:5},hq:{health:60,max:100}}}}});
 assert.equal(failed.operations_outcome,'operations-failure');assert.equal(failed.terminal_class,'source-winner-team-1');assert.equal(failed.waves_cleared,4);
 assert.equal(failed.claims.five_wave_win,false);assert.equal(failed.claims.human_identity,false);
 const won=classifyTerminal({state:{over:true,winner:0,overReason:'operation-complete',cocs:{outcome:{mode:'operations',waves:{cleared:5,total:5},hq:{health:100,max:100}}}}});
 assert.equal(won.operations_outcome,'operations-complete');assert.equal(won.waves_cleared,5);
 assert.equal(won.claims.five_wave_win,false,'scripted input never earns a five-wave claim even at 5/5');
 const demolished=classifyTerminal({state:{over:true,winner:1,overReason:'hq-destroyed',cocs:{outcome:{mode:'operations',waves:{cleared:2,total:5},hq:{health:0,max:100}}}}});
 assert.equal(demolished.operations_outcome,'operations-failure');assert.equal(demolished.hq_health,0);
 assert.equal(classifyTerminal({state:{over:false}}),null);
 assert.equal(classifyTerminal({state:{over:true,winner:null,overReason:'time',...pvp}}).terminal_class,'draw');
});
