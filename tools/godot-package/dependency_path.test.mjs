import {test} from 'node:test';
import assert from 'node:assert/strict';
import {win32,posix} from 'node:path';
import {dependencyPath} from './dependency_path.mjs';
test('win32 and POSIX synthetic dependency graphs produce identical inventory identities',()=>{
  const graph={'server/game-server.mjs':['../game/ranked.mjs','./room.mjs'],'server/room.mjs':['../game/data.mjs'],'game/ranked.mjs':['./data.mjs'],'game/data.mjs':[]};
  const walk=(root,paths)=>{
    const todo=['server/game-server.mjs'],seen=new Set();
    while(todo.length){const p=todo.pop();if(seen.has(p))continue;seen.add(p);assert.ok(graph[p],p);for(const s of graph[p])todo.push(dependencyPath(root,p,s,paths));}
    return [...seen].sort();
  };
  assert.deepEqual(walk('C:\\checkout with spaces\\café',win32),walk('/checkout with spaces/café',posix));
  assert.equal(dependencyPath('C:\\repo','game/data.mjs','../server/room.mjs',win32),'server/room.mjs');
  for(const paths of [win32,posix])for(const spec of ['../../outside.mjs','..\\outside.mjs','./%2e%2e/out.mjs','./x.mjs?query'])
    assert.throws(()=>dependencyPath(paths===win32?'C:\\repo':'/repo','game/data.mjs',spec,paths));
  assert.throws(()=>dependencyPath('C:\\repo','../outside/main.mjs','./data.mjs',win32));
});
