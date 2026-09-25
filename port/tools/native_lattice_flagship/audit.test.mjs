import {test} from 'node:test';
import assert from 'node:assert/strict';
import {audit} from './audit.mjs';

function fixture() {
 const base = {direction:'recipient',elapsed_ms:0};
 const wrap = (kind,elapsed_ms,frame) => ({...base,kind,elapsed_ms,frame});
 return {manifest:{source_commit:'pin',input_sha256:{board:'hash'},evidence_class:'ordinary-wire',map:'asterion-relay',mode:'cocs'},
  wire:[wrap('welcome',10,{type:'welcome',peerId:4}),wrap('lobby',20,{type:'lobby',players:[{peerId:4,actorId:2}]}),
   wrap('start',100,{type:'start',mapId:'asterion-relay',roundRevision:1,config:{mode:'cocs',timeLimit:900}}),
    wrap('snapshot',200,{type:'snapshot',state:{mapId:'asterion-relay',time:1,cocs:{roundRevision:1,nodes:[{id:'front-0',owner:null}]},actors:[{id:2,team:0}]}}),
   wrap('events',300,{type:'events',items:[{type:'cocs-capture',participants:[2]}]}),
    wrap('snapshot',400,{type:'snapshot',state:{mapId:'asterion-relay',time:5,cocs:{roundRevision:1,nodes:[{id:'front-0',owner:0}]},actors:[{id:2,team:0}]}}),
   wrap('results',500,{type:'results',state:{mapId:'asterion-relay',time:10,over:true,overReason:'dominance',winner:0}}),
   wrap('start',600,{type:'start',mapId:'asterion-relay',roundRevision:2,config:{mode:'cocs',timeLimit:900}}),
   wrap('snapshot',700,{type:'snapshot',state:{mapId:'asterion-relay',time:1,cocs:{roundRevision:2,nodes:[]},actors:[]}})],
  native:[{event:'input_queue',method:'engine',source_revision:1,actor_id:2,queued:true},{kind:'ui',source_revision:1,round_revision:1,actor_id:2,observed:true,reviewer:'reviewer@example.test',screenshot:'reviewed.png'}],
  cleanup:{children_waited:true,server_closed:true,temp_removed:true}};
}
test('synthetic complete shape (not natural evidence)',()=>assert.equal(audit(fixture()).claim,'PASS'));
test('ordinary source order is recorded; privileged state mutation is rejected',()=>{const f=fixture();f.wire.push({direction:'client',kind:'order',elapsed_ms:250,frame:{type:'order',verb:'HOLD',target:'front-0'}});assert.equal(audit(f).checks.ordinary_outgoing,true);f.wire.at(-1).frame.type='set-node-owner';assert.equal(audit(f).checks.ordinary_outgoing,false)});
test('defeat remains a distinct claim and is not gated by capture',()=>{const f=fixture();f.wire[6].frame.state.winner=1;f.wire.splice(4,1);const a=audit(f);assert.equal(a.claims.natural_defeat,'PASS');assert.equal(a.claims.positive_capture,'BLOCKED')});
test('defeat is relative to the recipient-published local team',()=>{const f=fixture();f.wire[3].frame.state.actors[0].team=1;f.wire[5].frame.state.actors[0].team=1;assert.equal(audit(f).claims.natural_defeat,'PASS');f.wire[6].frame.state.winner=1;assert.equal(audit(f).claims.natural_defeat,'BLOCKED')});
test('Operations loss is distinguishable from absent fifth-wave clear',()=>{const f=fixture();f.manifest.mode='cocs-coop';f.wire[2].frame.config.mode='cocs-coop';f.wire[6].frame.state.winner=1;f.wire[6].frame.state.cocs={outcome:{waves:{cleared:4}}};const a=audit(f);assert.equal(a.checks.fifth_wave,false);assert.equal(a.claims.natural_defeat,'PASS');assert.equal(a.claims.positive_capture,'BLOCKED')});
test('exact source order completion can attribute a useful ground capture without physical participation',()=>{
 const f=fixture();f.wire[4].frame.items[0]={type:'cocs-capture',node:'front-0',team:0,participants:[99]};
 f.wire.push({kind:'order',direction:'client',elapsed_ms:250,frame:{type:'order',roundRev:1,cardId:'native-card',target:'front-0'}});
 f.wire.push({kind:'events',direction:'recipient',elapsed_ms:310,frame:{type:'events',items:[{type:'cocs-order-complete',peerId:'2',cardId:'native-card',node:'front-0',team:0}]}});
 const result=audit(f);assert.equal(result.checks.attributed_capture,false);assert.equal(result.checks.attributed_order_effect,true);assert.equal(result.claims.positive_capture,'PASS');
 for(const mutate of [e=>e.cardId='other',e=>e.peerId='99',e=>e.node='other']){const bad=fixture();bad.wire[4].frame.items[0]={type:'cocs-capture',node:'front-0',team:0,participants:[99]};bad.wire.push(f.wire.at(-2));bad.wire.push(structuredClone(f.wire.at(-1)));mutate(bad.wire.at(-1).frame.items[0]);assert.equal(audit(bad).checks.attributed_order_effect,false)}
 const wrongRound=structuredClone(f);wrongRound.wire.at(-2).frame.roundRev=2;assert.equal(audit(wrongRound).checks.attributed_order_effect,false);
});
test('UI observation without reviewer and screenshot provenance is rejected',()=>{const f=fixture();delete f.native[1].reviewer;delete f.native[1].screenshot;assert.equal(audit(f).checks.native_ui,false)});
for(const [name,mutate,gate] of [
 ['no owner flip',f=>f.wire[5].frame.state.cocs.nodes[0].owner=null,'capture'],
 ['wrong participant',f=>f.wire[4].frame.items[0].participants=[99],'attributed_capture'],
 ['wrong revision',f=>f.native[0].source_revision=9,'native_input'],
 ['ACK instead of result',f=>f.wire[6].frame={type:'ack'},'natural_result'],
 ['missing cleanup',f=>f.cleanup.server_closed=false,'cleanup'],
 ['wrong card-only event',f=>f.wire[4].frame.items[0].type='cocs-order-complete','capture'],
 ['bot-only rung',f=>{f.wire[2].frame.config.rung='4v4';f.manifest.participants=[{kind:'automated'}]},'human_rung'],
 ['wave four',f=>{f.manifest.mode='cocs-coop';f.wire[2].frame.config.mode='cocs-coop';f.wire[6].frame.state.cocs={outcome:{waves:{cleared:4}}}},'fifth_wave'],
 ['no next round',f=>f.wire.splice(7),'restart']
]) test(`negative mutation: ${name}`,()=>{const f=fixture();mutate(f);assert.equal(audit(f).checks[gate],false)});
