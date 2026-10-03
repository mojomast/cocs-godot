import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {latticeCaption,latticeSoundCue} from '../../../game/lattice-feedback.mjs';
import {cocsBoard} from '../../../game/hud.mjs';
import {cocsOrderNextAction} from '../../../game/cocs-orders.mjs';

const events=[
 ...['collect','return'].map(action=>({type:'cocs-terminal-shard',action,team:0})),
 ...['cocs-capture','cocs-depot-capture','cocs-depot-vehicle-spawn','cocs-depot-purchase'].map(type=>({type,node:'relay-2',depot:'depot-0',item:'puma',team:0})),
 {type:'cocs-device-use',kind:'zipline',actor:0},
 ...['director-wave','director-wave-cleared','director-spawn'].map(type=>({type,wave:4})),
 {type:'director-init',tier:'D2'},
 ...['boss','scout'].map(kind=>({type:'director-spawn-telegraph',kind})),
 {type:'director-modifier',name:'hard-shell'}, {type:'director-escalation',kind:'siege'},
 {type:'director-boss',phase:2},{type:'director-phase',phase:3},
 ...['director-retarget','director-denial','director-reinforce'].map(type=>({type,node:'front-1'})),
 {type:'director-retire',count:7},
 ...['cocs-order-complete','cocs-order-rejected','coop-spend-rejected'].map(type=>({type,verb:'hold',team:0})),
 {type:'coop-bonus',state:'done',label:'Convoy'},
 {type:'cocs-terminal-sabotage',terminal:'terminal-1',team:0},
 {type:'cocs-sapper',node:'relay-2',denied:2,team:0},
 {type:'cocs-siphon',flux:8.7,team:0},
 ...[0,3].map(marked=>({type:'cocs-scan',marked,team:0})),
 ...['cocs-role-spawn','cocs-role-killed','cocs-role-expire'].map(type=>({type,role:'saboteur',refund:8.7,team:0})),
 {type:'cocs-role-rally',targets:[0,1],actor:0},
 {type:'cocs-role-repair',repaired:['device:a','terminal:b'],actor:0},
 {type:'cocs-role-spot',targets:[3,4,5],actor:0},
 ...['cocs-prime-start','cocs-prime','cocs-prime-interrupt'].map(type=>({type,node:'siphon-0'})),
 ...['take','release'].map(action=>({type:'cocs-command',action,team:0})),
 {type:'cocs-command',action:'mutiny-vote',votes:2,needed:3,seat:false,team:0},
 {type:'cocs-command',action:'mutiny-vote',seat:'0',team:0},
 ...['ASSAULT',null].map(policy=>({type:'cocs-command',action:'policy',policy,team:0})),
 ...['front-1',null].map(value=>({type:'cocs-command',action:'set-route',value,team:0})),
];
const captions=events.map(event=>({event,text:latticeCaption(event),
 sourceCue:{own:!!latticeSoundCue(event,{id:0,team:0}),other:!!latticeSoundCue(event,{id:1,team:1})}}));
assert.ok(captions.every(c=>typeof c.text==='string'&&c.text.length));
assert.equal(captions.find(c=>c.event.type==='cocs-siphon').text,'Flux siphoned · 9 FLUX');
assert.equal(captions.find(c=>c.event.type==='cocs-scan'&&c.event.marked===3).sourceCue.other,false);
assert.equal(captions.find(c=>c.event.type==='cocs-command').sourceCue.other,false);
assert.equal(captions.find(c=>c.event.type==='cocs-device-use').sourceCue.other,false);
assert.equal(latticeCaption({type:'not-an-event'}),null);
const nodes=[[0,0],[0.625,0.2],[0.1,0.83],[1.1,-1]].map((progress,i)=>({id:`front-${i}`,x:3,z:4,r:10,owner:null,contested:i===2,live:true,progress}));
const progress=cocsBoard({cocs:{nodes}},{id:0,team:0}).nodes.map((n,i)=>({node:nodes[i],percent:n.progressPercent}));
assert.deepEqual(progress.map(n=>n.percent),[0,63,83,100]);
const hash=path=>createHash('sha256').update(readFileSync(new URL(path,import.meta.url))).digest('hex');
const derivative=JSON.parse(readFileSync(new URL('../../../port/contracts/lattice-catalog-derivative.json',import.meta.url)));
assert.equal(derivative.source_commit,'515daf07589150dd3241f4ae1425cc1b093912f5');
assert.equal(derivative.derivative_commit,'0326b435a2fdd88e6e7a01b8a7325feccc4d15cb');
// Preserve the historical catalog contract; current source is an explicit
// candidate overlay, not a rewrite of historical source or acceptance evidence.
const candidate=JSON.parse(readFileSync(new URL('../../../port/contracts/movement-candidate-derivative.json',import.meta.url)));
assert.equal(candidate.source_commit,derivative.source_commit);
assert.equal(candidate.parent_derivative_commit,derivative.derivative_commit);
assert.equal(candidate.derivative_commit,'91f58a1c5dcd85544574ba9cd11fcecd0d50d522');
const runtime={...derivative.runtime_files,...Object.fromEntries(Object.entries(candidate.runtime_overrides).map(([path,entry])=>[path,entry.after]))};
assert.equal(runtime['game/core.mjs'],'655f112934b7b4a4f1d9f043a8c545511e7284f557e4c9586dfd72d3e5a8e7a3');
for(const [path,expected] of Object.entries(runtime))assert.equal(hash('../../../'+path),expected,path+' reviewed candidate hash');
const output={schema:1,evidence:'direct frozen source function calls, not received events',
 hashes:{feedback:hash('../../../game/lattice-feedback.mjs'),hud:hash('../../../game/hud.mjs')},captions,progress,
 recovery:['contested','no-relay','flux','out-of-flux','slice','executor','thread','no-thread','dependency','target','no-response','blocked','wrong-team'].map(reason=>({reason,text:cocsOrderNextAction(reason,'HOLD')}))};
const file=new URL('../../../godot/tests/lattice/fixtures/expansion_feedback.json',import.meta.url);
if(process.argv.includes('--write'))writeFileSync(file,JSON.stringify(output,null,2)+'\n');
else assert.deepEqual(JSON.parse(readFileSync(file)),output,'checked-in oracle matches current frozen source');
console.log(JSON.stringify({captions:captions.length,progress:progress.length,recovery:output.recovery.length,coreHash:'verified',candidateCommit:candidate.derivative_commit,derivativeHashes:Object.keys(runtime).length,fixture:file.pathname}));
