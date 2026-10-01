import test from 'node:test';
import assert from 'node:assert/strict';
import {ENEMY_TYPE_IDS} from '../../game/enemy-types.mjs';
import {ROBOT_FOR_ROLE,hordeRobotState} from './robot-roles.mjs';

test('every Horde source brain receives one of the six authored robot identities',()=>{
 assert.deepEqual(ENEMY_TYPE_IDS.sort(),Object.keys(ROBOT_FOR_ROLE).sort());
 assert.deepEqual(new Set(Object.values(ROBOT_FOR_ROLE)),new Set(['scrapper','skirmisher','sentinel','mortar','bulwark','warden']));
});
test('presentation identity never overwrites source behavior, player or source snapshot',()=>{
 const player={id:0,isNpc:false,npcType:'warden',npcModel:'operator',health:90};
 const enemy={id:2,isNpc:true,npcType:'mortar',health:70,npcArtillery:{damage:36},npcModel:'previous'};
 const state={actors:[player,enemy],singleplayer:{wave:7}};
 const adapted=hordeRobotState(state);
 assert.strictEqual(adapted.actors[0],player);
 assert.deepEqual(adapted.actors[1],{...enemy,npcModel:'mortar'});
 assert.strictEqual(state.actors[1].npcModel,'previous');
 assert.strictEqual(adapted.singleplayer,state.singleplayer);
});
