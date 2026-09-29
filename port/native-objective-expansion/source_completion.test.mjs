import test from 'node:test';
import assert from 'node:assert/strict';
import {Match} from '../../game/core.mjs';
import {rankTuple} from '../../game/outcome.mjs';

const cases = [
  ...['meridian-exchange','verdant-reliquary','ember-crucible'].flatMap(map=>[['uplink',map],['holdout',map]]),
  ...['tidal-citadel','sunscar-convoy'].map(map=>['assault',map]),
];
const rate=1/60;

// Controlled placement is intentionally NOT a natural native-input walking claim.
// All capture rules, scoreStats, winner and snapshots are source Match code.
for (const [mode,map] of cases) test(`arranged source completion ${mode}/${map} (controlled fixture placement)`,()=>{
  const match=new Match('chatgpt','openclaw',()=>.5,map,{mode,botCount:0,humanCount:1,timeLimit:900,fragLimit:mode==='assault'?3:100});
  const actor=match.actors[0];
  assert.equal(match.config.mode,mode);
  assert.equal(match.snapshot().mapId,map);
  const stand=zone=>Object.assign(actor,{team:0,x:zone.x,y:zone.y,z:zone.z,health:100,dead:0,vehicleId:null});
  const tick=(seconds)=>{for(let i=0;i<Math.ceil(seconds/rate) && !match.over;i++)match.updateObjectives(rate);};
  if(mode==='uplink') {
    for(let stage=0;stage<3;stage++) {
      stand(match.objectiveState.zones[0]);
      tick(4.5);
      assert.equal(match.objectiveState.stage,stage+1,`source stage ${stage+1}`);
    }
    assert.equal(match.objectiveState.stageCaptures[0],3);
    assert.ok(match.events.some(e=>e.type==='uplink-win'));
  } else if(mode==='holdout') {
    for(const zone of match.objectiveState.zones.slice(0,2)) {stand(zone);tick(6.5);assert.equal(zone.owner,0);}
    tick(31);
    assert.equal(match.objectiveState.holdTeam,0);
    assert.ok(match.events.some(e=>e.type==='holdout-win'));
  } else {
    for(let stage=0;stage<3;stage++) {
      stand(match.objectiveState.sectors[stage]);
      tick(6.5);
      assert.equal(match.objectiveState.active,stage+1);
    }
    assert.equal(match.objectiveState.breached,true);
    assert.ok(match.events.some(e=>e.type==='assault-breach'));
    assert.ok(match.vehicles.length>0,'Assault source keeps authored vehicles');
  }
  assert.equal(match.over,true);
  const snapshot=match.snapshot();
  assert.equal(snapshot.winner,0);
  assert.equal(snapshot.objectives.winner,0);
  assert.equal(snapshot.overReason,'objective');
  assert.equal(snapshot.objectives.kind,mode==='uplink'?'koth':mode==='holdout'?'domination':'assault');
  assert.ok(rankTuple(snapshot.actors[0],mode)[0]>=0);
});
