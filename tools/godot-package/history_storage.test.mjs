import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,statSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {WebSocket} from 'ws';
import {createGameServer} from '../../server/game-server.mjs';
import {acquireCareer,careerPaths} from './career_path.mjs';

const owned={experience:'combat'};
async function readHistory(game){
 const socket=new WebSocket(`ws://127.0.0.1:${game.server.address().port}`);
 let timer;
 try{
  return await new Promise((resolve,reject)=>{
   timer=setTimeout(()=>reject(Error('History response timed out')),3000);
   socket.once('error',reject);
   socket.once('open',()=>socket.send(JSON.stringify({type:'history'})));
   socket.on('message',bytes=>{
    const frame=JSON.parse(bytes);
    if(frame.type==='history')resolve(frame.matches);
   });
  });
 }finally{clearTimeout(timer);socket.terminate();}
}

test('source-owned recent history survives authority restart and retains source ordering/cap',async()=>{
 const root=mkdtempSync(join(tmpdir(),'cocs-history-'));
 const env={COCS_CAREER_ROOT:root};
 let career,game;
 try{
  career=acquireCareer(owned,env);
  game=createGameServer({historyPath:career.historyPath,progressionPath:career.progressionPath});
  await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
  // Controlled persistence fixture: records go through MatchHistory, not an
  // invented native archive. Full match/award acceptance is a separate journey.
  for(let i=0;i<53;i++)game.history.record({roomId:`room-${i}`,mapId:'meridian-exchange',config:{mode:'deathmatch',fragLimit:10,timeLimit:60},time:60,
   actors:[{id:0,name:'Same display name',character:'chatgpt',harness:'openclaw',frags:i,deaths:1}],endingReason:'time'});
  assert.equal(await game.history.whenPersisted(),true);
  const expected=await readHistory(game);
  assert.equal(expected.length,50);
  assert.equal(expected[0].roomId,'room-52');
  assert.equal(expected[49].roomId,'room-3');
  assert.ok(expected.every(match=>match.players.every(player=>!Object.hasOwn(player,'playerId'))),'wire history cannot establish personal career participation');
  await game.close();game=null;career.release();career=null;
  const paths=careerPaths(env);
  if(process.platform!=='win32')assert.equal(statSync(paths.historyPath).mode&0o777,0o600);
  career=acquireCareer(owned,env);
  game=createGameServer({historyPath:career.historyPath,progressionPath:career.progressionPath});
  await new Promise(resolve=>game.server.listen(0,'127.0.0.1',resolve));
  assert.deepEqual(await readHistory(game),expected);
  assert.deepEqual(JSON.parse(readFileSync(paths.historyPath,'utf8')),expected);
 }finally{
  if(game){for(const socket of game.wss.clients)socket.terminate();await game.close();}
  career?.release();rmSync(root,{recursive:true,force:true});
 }
});

test('corrupt local history blocks overwrite, releases its lease, and never affects external guests',()=>{
 const root=mkdtempSync(join(tmpdir(),'cocs-history-corrupt-'));
 const env={COCS_CAREER_ROOT:root},paths=careerPaths(env);
 try{
  for(const malformed of ['{bad','null','{}','[null]','[{"players":"bad"}]','[{"players":[null]}]']){
   writeFileSync(paths.historyPath,malformed);
   assert.throws(()=>acquireCareer(owned,env),/history store/);
   assert.equal(readFileSync(paths.historyPath,'utf8'),malformed);
   const guest=acquireCareer({endpoint:'ws://history.example:1234/'},env);
   try{assert.equal(guest.historyPath,null);assert.equal(guest.progressionPath,null);}finally{guest.release();}
  }
  writeFileSync(paths.historyPath,'[]');
  const local=acquireCareer(owned,env);
  try{
   assert.equal(local.historyPath,paths.historyPath);
   assert.throws(()=>acquireCareer(owned,env),/busy/);
  }finally{local.release();}
 }finally{rmSync(root,{recursive:true,force:true});}
});
