import test from 'node:test';
import assert from 'node:assert/strict';
import {validate} from './validate.mjs';
function fixture(){
 const wire=[{type:'start',mapId:'sunscar-convoy'}],native=[];
 for(let seq=1;seq<=12;seq++){
  const p={position:{x:seq,y:2,z:3},distance:Math.min(seq,8),pushing:seq<10?0:null,contested:false};
  const actor={id:0,team:0,x:seq,y:0,z:0};
  wire.push({type:'snapshot',seq,state:{actors:[actor],objectives:{payload:p}}});
  native.push({snapshot_seq:seq,actor_id:0,actor:{...actor},ack:seq,rendered:{cart:{...p.position}},hud:seq<10?'PUSHING':'IDLE'});
  wire.push({type:'input_received',seq,input:{x:1,z:0}});
 }
 return {wire,native};
}
test('explicitly synthetic valid push/idle correlation',()=>{const f=fixture();assert.equal(validate(f.wire,f.native,'sunscar-convoy').status,'PASS');});
for(const [name,mutate] of [
 ['wrong actor',f=>f.native[0].actor_id=3],
 ['wrong height',f=>f.native[0].rendered.cart.y=77],
 ['missing render',f=>delete f.native[0].rendered.cart],
 ['wrong sequence',f=>f.native[0].snapshot_seq=999],
 ['missing movement receipt',f=>f.wire=f.wire.filter(r=>r.type!=='input_received')],
 ['incorrect HUD',f=>f.native.forEach(r=>r.hud='unknown')],
 ['short evidence',f=>f.native=f.native.slice(0,2)]
])test('reject '+name,()=>{const f=fixture();mutate(f);assert.throws(()=>validate(f.wire,f.native,'sunscar-convoy'));});
