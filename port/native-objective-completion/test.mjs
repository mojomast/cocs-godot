import test from 'node:test';
import assert from 'node:assert/strict';
import {load,validate} from './validate.mjs';
const payload='port/native-objective-completion/evidence/2d6b7e66-6adc-43f2-b29e-9d26fed86387';
const fixture=()=>load(payload);
const run=f=>validate(f.wire,f.stdout,f.summary.map,f.summary.seconds);
const host=f=>f.wire.filter(r=>r.connection===0);
const result=f=>host(f).find(r=>r.type==='results');
const rollback=f=>host(f).find(r=>r.type==='snapshot'&&r.round===1&&r.state.objectives.payload.pushing===1&&!r.state.objectives.payload.contested);
function rewrite(f,prefix,mutate){let changed=false;f.stdout=f.stdout.split('\n').map(line=>{if(!line.startsWith(prefix))return line;const row=JSON.parse(line.slice(prefix.length));changed=mutate(row,changed)||changed;return prefix+JSON.stringify(row);}).join('\n');}
function reject(name,mutate,pattern){test('reject '+name,()=>{const f=fixture();mutate(f);assert.throws(()=>run(f),pattern);});}
test('replay archived genuine rollback, bank, resumed push, delivery result and restart',()=>assert.equal(run(fixture()).status,'PASS'));
reject('missing delivered source event',f=>{for(const r of f.wire)if(r.type==='events')r.items=r.items.filter(e=>e.type!=='payload-delivered');},/source delivered event/);
reject('time-limit hold relabeled delivery',f=>{result(f).state.time=180;},/delivery ended before time limit/);
reject('wrong actual winner',f=>{result(f).state.winner=1;});
reject('accelerated authority',f=>{result(f).wall=host(f).find(r=>r.type==='start').wall+1000;},/normal wall elapsed/);
reject('rollback crossing banked checkpoint',f=>{const r=rollback(f);r.state.objectives.payload.distance=r.state.objectives.zones[0].distance-.1;},/bank never crossed/);
reject('rollback without ordinary defender',f=>{const r=rollback(f);r.state.actors.find(a=>a.team===1).health=0;});
reject('wrong source-root cart height',f=>rewrite(f,'OBJECTIVE_NATIVE ',(r,changed)=>{if(changed)return false;r.rendered.cart.y+=.1;return true;}),/source-root cart y/);
reject('missing displayed rolling-back model',f=>rewrite(f,'COMPLETION_HUD ',r=>{r.model.title=r.model.title.replace('ROLLING BACK','IDLE');return true;}));
reject('result retains native capture',f=>rewrite(f,'COMPLETION_RESULT ',r=>{r.captured=true;return true;}));
reject('stale checkpoint after round clear',f=>rewrite(f,'COMPLETION_BOUNDARY ',r=>{if(r.round===2)r.dynamic=['cp_cp1'];return true;}));
reject('completion marker duplicated',f=>{f.stdout+='\n'+f.stdout.split('\n').find(l=>l.startsWith('COMPLETION_DONE '));});
reject('ACK without an input receipt',f=>{for(const r of f.wire)if(r.connection===0&&r.type==='snapshot'&&r.round===1)r.acks['0']=999999;},/prior same-peer receipt/);
