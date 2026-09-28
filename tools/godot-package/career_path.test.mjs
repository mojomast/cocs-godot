import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,statSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../server/game-server.mjs';
import {acquireCareer,careerPaths} from './career_path.mjs';

const owned={experience:'deathmatch',endpoint:null};
const temp=()=>mkdtempSync(join(tmpdir(),'cocs-career-test-'));
async function welcome(game,fields={}){
 const ws=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);
 return await new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>reject(Error('welcome timed out')),3000);
  ws.on('open',()=>ws.send(JSON.stringify({type:'create',v:3,name:'Career',playerName:'Tester',...fields})));
  ws.on('message',data=>{const frame=JSON.parse(data);if(frame.type==='welcome'){clearTimeout(timer);ws.close();resolve(frame);}});
  ws.on('error',reject);
 });
}
test('source authority survives close and recreation with the same profile, award and gear',async()=>{
 const root=temp(), env={COCS_CAREER_ROOT:root};
 try{
  let career=acquireCareer(owned,env),game=createGameServer({progressionPath:career.progressionPath});
  try{
   await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
   const first=await welcome(game);
   assert.ok(first.profile.id&&first.progressToken);
   game.progression.setGearOwned(first.profile.id,first.progressToken,{primary:'pulse-rifle'});
   game.progression.awardOwned(first.profile.id,first.progressToken,{mode:'deathmatch',win:true,actor:{frags:4,deaths:1,scoreStats:{}},time:100});
   assert.equal(await game.progression.whenPersisted(),true);
   const before=game.progression.getOwned(first.profile.id,first.progressToken);
   await game.close();career.release();
   career=acquireCareer(owned,env);game=createGameServer({progressionPath:career.progressionPath});
   await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
   const second=await welcome(game,{playerId:first.profile.id,progressToken:first.progressToken});
   assert.equal(second.profile.id,first.profile.id);
   assert.equal(second.profile.xp,before.xp);
   assert.deepEqual(second.profile.gear,before.gear);
  }finally{await game.close();career.release();}
  const paths=careerPaths(env);
  if(process.platform!=='win32'){
   assert.equal(statSync(paths.root).mode&0o777,0o700);
   assert.equal(statSync(paths.progressionPath).mode&0o777,0o600);
   assert.equal(statSync(paths.credentialsPath).mode&0o777,0o600);
  }
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('external endpoints are scoped separately; no owned credential is sent to another authority',()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root},local=acquireCareer(owned,env);
 try{
  assert.equal(local.env.COCS_CAREER_SCOPE,'owned:source-v3');
  assert.throws(()=>acquireCareer(owned,env),/busy/);
 }finally{local.release();}
 try{
  const a=acquireCareer({endpoint:'ws://example.org:1234/'},env);
  assert.equal(a.progressionPath,null);
  assert.equal(a.env.COCS_CAREER_SCOPE,'external:ws://example.org:1234/');
  a.release();
  const b=acquireCareer({endpoint:'ws://example.net:1234/'},env);
  assert.notEqual(b.env.COCS_CAREER_SCOPE,a.env.COCS_CAREER_SCOPE);
  b.release();
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('malformed existing store blocks minting and releases lease; stale crash lease is reclaimable',()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root};
 try{
  const paths=careerPaths(env),first=acquireCareer(owned,env);
  first.release();
  writeFileSync(paths.progressionPath,'{bad');
  assert.throws(()=>acquireCareer(owned,env),/malformed/);
  writeFileSync(paths.progressionPath,JSON.stringify({version:2,players:[]}));
  writeFileSync(`${paths.credentialsPath}.lease`,'99999999');
  const recovered=acquireCareer(owned,env);
  assert.equal(recovered.progressionPath,paths.progressionPath);
  recovered.release();
  assert.deepEqual(JSON.parse(readFileSync(paths.progressionPath,'utf8')).players,[]);
 }finally{rmSync(root,{recursive:true,force:true});}
});
