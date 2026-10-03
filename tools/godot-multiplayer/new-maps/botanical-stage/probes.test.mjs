import test from 'node:test';
import assert from 'node:assert/strict';
import {support} from './probes.mjs';
const floor=y=>({id:'floor'+y,vertices:[[-2,y,-2],[-2,y,2],[2,y,2],[2,y,-2]],triangles:[[0,1,2],[0,2,3]],walkable:true});
test('authored layer survives a higher floor and missing intended support fails',()=>{
  const a={terrain:{surfaces:[floor(0),floor(8)],walls:[]}};
  assert.equal(support(a,0,0,0),0);
  assert.equal(support(a,0,0,8),8);
  assert.throws(()=>support(a,0,0,4),/Unsupported intended/);
  assert.throws(()=>support(a,20,20),/No ground/);
});
