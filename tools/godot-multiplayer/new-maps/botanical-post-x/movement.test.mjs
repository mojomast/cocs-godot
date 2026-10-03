import test from 'node:test';
import assert from 'node:assert/strict';
import {campaign,inputs,trial,RUNS} from './movement.mjs';
test('production movement crosses both full stair runs across five lanes both directions at walk and sprint',()=>{
 const result=campaign();assert.equal(result.trials.length,80);assert.equal(result.trials.filter(t=>t.required).length,60);
 assert.equal(result.rules.radius,.42);assert.equal(result.rules.height,1.8);assert.equal(result.rules.eye,1.45);assert.equal(result.rules.terminal,2.2);
});
test('production mover stops on a genuine raised obstruction rather than waiving staircase contacts',()=>{
 const arena=structuredClone(inputs().candidate.arena);
 arena.blocks.push({id:'negative-real-wall',x:32,z:40,w:4,d:1,baseY:0,h:30});
 const r=trial(arena,RUNS.civic,32,1);
 assert.equal(r.reached,false);assert.ok(r.blockedFrames>100);
});
