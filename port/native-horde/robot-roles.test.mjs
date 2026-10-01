import test from 'node:test';
import assert from 'node:assert/strict';
import {ENEMY_TYPE_IDS} from '../../game/enemy-types.mjs';
import {ROBOT_FOR_ROLE,ROBOT_SILHOUETTE,applyRobotHitVolume,hordeRobotState} from './robot-roles.mjs';

test('every Horde source brain receives one of the six authored robot identities',()=>{
 assert.deepEqual(ENEMY_TYPE_IDS.sort(),Object.keys(ROBOT_FOR_ROLE).sort());
 assert.deepEqual(new Set(Object.values(ROBOT_FOR_ROLE)),new Set(['scrapper','skirmisher','sentinel','mortar','bulwark','warden']));
 assert.deepEqual(Object.keys(ROBOT_FOR_ROLE).sort(),Object.keys(ROBOT_SILHOUETTE).sort());
});
test('presentation identity never overwrites source behavior, player or source snapshot',()=>{
 const player={id:0,isNpc:false,npcType:'warden',npcModel:'operator',health:90};
 const enemy={id:2,isNpc:true,npcType:'mortar',health:70,npcArtillery:{damage:36},npcModel:'previous'};
 const state={actors:[player,enemy],singleplayer:{wave:7}};
 const adapted=hordeRobotState(state);
 assert.strictEqual(adapted.actors[0],player);
 assert.deepEqual(adapted.actors[1],{...enemy,npcModel:'mortar',npcProfile:{scale:1.02}});
 assert.strictEqual(state.actors[1].npcModel,'previous');
 assert.strictEqual(adapted.singleplayer,state.singleplayer);
});
test('source hitScale is assigned to enemies only; combat identity, health and boss phases survive',()=>{
 const player={id:0,isNpc:false,hitScale:1,health:100};
 const boss={id:19,isNpc:true,npcType:'warden',hitScale:1,health:450,maxHealth:450,bossPhase:2,npcProfile:{scale:1.6}};
 applyRobotHitVolume(player);applyRobotHitVolume(boss);
 assert.equal(player.hitScale,1);
 assert.equal(boss.hitScale,2);
 assert.equal(boss.health,450);
 assert.equal(boss.bossPhase,2);
 const shown=hordeRobotState({actors:[boss]}).actors[0];
 assert.equal(shown.npcProfile.scale,1.18);
 assert.equal(boss.npcProfile.scale,1.6);
});
