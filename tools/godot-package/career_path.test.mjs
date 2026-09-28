import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,writeFileSync,statSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {spawn} from 'node:child_process';
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
   const credentialFile=career.env.COCS_CAREER_CREDENTIALS_PATH;
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
    assert.equal(statSync(join(paths.root,'identities')).mode&0o777,0o700);
    assert.equal(statSync(credentialFile).mode&0o777,0o600);
  }
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('owned authority and external guest coexist; only the same authority scope contends',()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root},local=acquireCareer(owned,env);
 try{
  assert.equal(local.env.COCS_CAREER_SCOPE,'owned:source-v3');
  assert.deepEqual(Object.keys(local.env).sort(),['COCS_CAREER_CREDENTIALS_PATH','COCS_CAREER_ENDPOINT','COCS_CAREER_SCOPE']);
  assert.ok(local.env.COCS_CAREER_CREDENTIALS_PATH.startsWith(join(careerPaths(env).root,'identities')));
  assert.throws(()=>acquireCareer(owned,env),/busy/);
  const a=acquireCareer({endpoint:'ws://example.org:1234/'},env);
  try{
   assert.equal(a.progressionPath,null);
   assert.equal(a.env.COCS_CAREER_SCOPE,'external:ws://example.org:1234/');
   assert.notEqual(a.env.COCS_CAREER_CREDENTIALS_PATH,local.env.COCS_CAREER_CREDENTIALS_PATH);
   assert.throws(()=>acquireCareer({endpoint:'ws://example.org:1234/'},env),/busy/);
   const b=acquireCareer({endpoint:'ws://example.net:1234/'},env);
   try{
    assert.notEqual(b.env.COCS_CAREER_SCOPE,a.env.COCS_CAREER_SCOPE);
    assert.notEqual(b.env.COCS_CAREER_CREDENTIALS_PATH,a.env.COCS_CAREER_CREDENTIALS_PATH);
   }finally{b.release();}
  }finally{a.release();}
 }finally{local.release();rmSync(root,{recursive:true,force:true});}
});
test('malformed existing store blocks minting and releases lease; stale crash lease is reclaimable',()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root};
 try{
   const paths=careerPaths(env),first=acquireCareer(owned,env);
   const scopedFile=first.env.COCS_CAREER_CREDENTIALS_PATH;
  first.release();
  writeFileSync(paths.progressionPath,'{bad');
  assert.throws(()=>acquireCareer(owned,env),/malformed/);
  writeFileSync(paths.progressionPath,JSON.stringify({version:2,players:[]}));
   writeFileSync(`${scopedFile}.lease`,'99999999');
  const recovered=acquireCareer(owned,env);
  assert.equal(recovered.progressionPath,paths.progressionPath);
  recovered.release();
  assert.deepEqual(JSON.parse(readFileSync(paths.progressionPath,'utf8')).players,[]);
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('shared legacy credentials migrate only the requested scope without deleting the original',()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root},paths=careerPaths(env);
 const ownedPair={playerId:'11111111-1111-4111-8111-111111111111',progressToken:'0123456789abcdef0123456789abcdef'};
 const guestPair={playerId:'22222222-2222-4222-8222-222222222222',progressToken:'abcdef0123456789abcdef0123456789'};
 const guestScope='external:ws://guest.example:3456/';
 try{
  writeFileSync(paths.legacyCredentialsPath,JSON.stringify({version:1,scopes:{'owned:source-v3':ownedPair,[guestScope]:guestPair}}));
  const local=acquireCareer(owned,env);
  const guest=acquireCareer({endpoint:'ws://guest.example:3456/'},env);
  try{
   assert.deepEqual(JSON.parse(readFileSync(local.env.COCS_CAREER_CREDENTIALS_PATH,'utf8')).scopes,{'owned:source-v3':ownedPair});
   assert.deepEqual(JSON.parse(readFileSync(guest.env.COCS_CAREER_CREDENTIALS_PATH,'utf8')).scopes,{[guestScope]:guestPair});
   assert.notEqual(local.env.COCS_CAREER_CREDENTIALS_PATH,guest.env.COCS_CAREER_CREDENTIALS_PATH);
   assert.equal(Object.keys(JSON.parse(readFileSync(paths.legacyCredentialsPath,'utf8')).scopes).length,2);
   writeFileSync(paths.legacyCredentialsPath,'{broken');
   assert.throws(()=>acquireCareer({endpoint:'ws://different.example:3456/'},env),/malformed/);
  }finally{guest.release();local.release();}
 }finally{rmSync(root,{recursive:true,force:true});}
});
test('competing process cannot open an owned store; crashed owner lease is recovered',async()=>{
 const root=temp(),env={COCS_CAREER_ROOT:root};
 const child=spawn(process.execPath,['--input-type=module','-e',`import {acquireCareer} from ${JSON.stringify(new URL('./career_path.mjs',import.meta.url).href)};acquireCareer({experience:'deathmatch'},process.env);console.log('READY');setInterval(()=>{},1000);`],{env:{...process.env,...env},stdio:['ignore','pipe','pipe']});
 try{
  await new Promise((resolve,reject)=>{child.stdout.once('data',data=>data.toString().includes('READY')?resolve():reject(Error('child failed to acquire lease')));child.once('error',reject);child.once('exit',()=>reject(Error('child exited before acquiring lease')));});
  assert.throws(()=>acquireCareer(owned,env),/busy/);
  child.kill('SIGKILL');
  await new Promise(resolve=>child.once('exit',resolve));
  const next=acquireCareer(owned,env);
  next.release();
 }finally{child.kill('SIGKILL');rmSync(root,{recursive:true,force:true});}
});
