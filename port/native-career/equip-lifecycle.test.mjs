import test from 'node:test';
import assert from 'node:assert/strict';
import {Room} from '../../server/room.mjs';
import {ProgressionStore} from '../../server/progression.mjs';

test('GEAR saves the career profile but an existing actor keeps its loadout until next match',()=>{
 const store=new ProgressionStore(null),room=new Room('career-lifecycle',()=>.5,{progression:store});
 room.join(1,'Host','chatgpt','openclaw','',false,'player-0001');
 room.host(1,{mode:'deathmatch',botCount:0,timeLimit:60,fragLimit:5},'crosswire');
 room.start(1);
 const actor=room.match.actors[0];
 const initial=structuredClone(actor.attachments);
 assert.equal(initial.items.length,0);
 room.setGear(1,{}, {optic:'red-dot'}, 1000);
 const reply=room.drain().find(item=>item.to===1&&item.msg.type==='progression'&&item.msg.attachments);
 assert.equal(reply?.msg.profile.attachments.optic,'red-dot');
 assert.deepEqual(actor.attachments,initial,'live actor is not updated');
 room.match.spawn(actor);
 assert.deepEqual(actor.attachments,initial,'respawn does not re-read career profile');
 room.roundOver=true;
 room.start(1);
 assert.equal(room.match.actors[0].attachments.items[0].id,'red-dot','new match receives saved mod');
});
