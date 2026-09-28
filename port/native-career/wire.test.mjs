// Genuine source authority frames, no local profile fixture or fabricated token.
import test from 'node:test';
import assert from 'node:assert/strict';
import WebSocket from 'ws';
import {createGameServer} from '../../server/game-server.mjs';

test('source room issues owned welcome, profile read, start and progression update', {timeout:15000}, async()=>{
 const game=createGameServer({port:0});
 await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
 const ws=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);
 const queue=[]; const waiters=[];
 ws.on('message', data=>{const frame=JSON.parse(data);const index=waiters.findIndex(w=>w.type===frame.type);if(index>=0)waiters.splice(index,1)[0].resolve(frame);else queue.push(frame);});
 const next=type=>{const index=queue.findIndex(f=>f.type===type);if(index>=0)return Promise.resolve(queue.splice(index,1)[0]);return new Promise((resolve,reject)=>{const entry={type,resolve};waiters.push(entry);setTimeout(()=>{const i=waiters.indexOf(entry);if(i>=0){waiters.splice(i,1);reject(Error(`missing ${type}`));}},8000).unref();});};
 const send=frame=>ws.send(JSON.stringify(frame));
 try{
  await new Promise((resolve,reject)=>{ws.once('open',resolve);ws.once('error',reject);});
  send({type:'create',name:'Career fixture',playerName:'Career fixture',character:'chatgpt',harness:'openclaw',v:3,delta:0});
  const welcome=await next('welcome');
  assert.equal(welcome.v,3);
  assert.equal(typeof welcome.profile?.id,'string');
  assert.equal(typeof welcome.progressToken,'string');
  assert.equal(welcome.profile.level,1);
  send({type:'profile',playerId:welcome.profile.id,progressToken:welcome.progressToken});
  const owned=await next('profile');
  assert.equal(owned.profile.id,welcome.profile.id);
  send({type:'gear',gear:{},attachments:{optic:'red-dot'}});
  const updated=await next('progression');
  assert.equal(updated.profile.id,welcome.profile.id);
  assert.equal(updated.profile.attachments.optic,'red-dot');
  send({type:'host',mapId:'meridian-exchange',config:{mode:'deathmatch',botCount:0}});
  send({type:'start'});
  const start=await next('start');
  assert.equal(start.mapId,'meridian-exchange');
 }finally{ws.close();await game.close();}
});
