// A fresh running source Match, advanced only after each native receipt. Private
// explicit setup/damage stimulus, NOT a natural multiplayer input-only match.
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {WebSocketServer} from 'ws';
import {Match} from '../../game/core.mjs';
import {EventCursor} from '../native-horde/authority.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const evidence=fileURLToPath(new URL('./evidence/',import.meta.url));
mkdirSync(evidence,{recursive:true});
const stamp=Date.now();
const server=new WebSocketServer({host:'127.0.0.1',port:0,maxPayload:65536,perMessageDeflate:false});
await new Promise(resolve=>server.once('listening',resolve));
const match=new Match('chatgpt','openclaw',()=>.37,'meridian-exchange',{mode:'deathmatch',botCount:1});
const [source,target]=match.actors;
Object.assign(source,{x:2,y:0,z:5,protection:0,bot:null});
Object.assign(target,{x:0,y:0,z:0,health:300,maxHealth:300,armor:24,protection:0,bot:null});
const cursor=new EventCursor(); cursor.take(match);
const wire=[],receipts=[];
let expected,seq=0,error=null,lastDamage=null;
const send=(ws,frame)=>{
  const text=JSON.stringify(frame); wire.push({direction:'out',frame}); ws.send(text); return text;
};
const snapshot=ws=>{
  const frame={type:'snapshot',seq:++seq,acks:{0:0},state:match.snapshot()};
  const text=send(ws,frame);
  expected={seq,hash:createHash('sha256').update(text).digest('hex'),actor:JSON.parse(text).state.actors[1]};
};
const events=ws=>{
  const items=cursor.take(match);
  if(items.length)send(ws,{type:'events',items});
  return items;
};
server.on('connection',ws=>{
  snapshot(ws);
  ws.on('message',raw=>{
    try {
      const row=JSON.parse(String(raw)); receipts.push(row);
      assert.equal(row.seq,expected.seq); assert.equal(row.sha256,expected.hash);
      for(const key of ['armor','health','temporaryShield','protection'])assert.equal(row[key],expected.actor[key],key);
      assert.equal(row.controller.visible_shells,row.kind?1:0);
      if(seq===1){assert.equal(row.kind,'armor energy'); assert(match.applyPowerup(target,'overshield'));}
      else if(seq===2){assert.equal(row.kind,'temporary shield'); match.damage(target,35,source);}
      else if(seq===3){
        assert.equal(row.controller.counters.ripples,1);
        assert.equal(row.armor,24);
        assert.equal(lastDamage.shield,35);
        // Duplicate the real damage batch. Distinct payload source IDs are not
        // relevant; only the numeric adapter event ID suppresses the replay.
        send(ws,{type:'events',items:[lastDamage]});
        match.damage(target,target.temporaryShield+80,source);
      }
      else if(seq===4){
        assert.equal(row.armor,0); assert.equal(row.temporaryShield,0); assert.equal(row.kind,'');
        assert.equal(row.controller.counters.shatters,1); assert.equal(row.controller.counters.ripples,2);
        assert.equal(lastDamage.shieldBreak,true);
        match.collect(target,{kind:'health',wait:0});
      }
      else if(seq===5){assert.equal(row.controller.counters.recovery,1); match.spawn(target);}
      else if(seq===6){assert.equal(row.kind,'spawn protection'); assert.equal(row.controller.counters.phase,1); send(ws,{type:'test-end'}); return;}
      const batch=events(ws); lastDamage=batch.find(e=>e.type==='damage')??lastDamage;
      snapshot(ws);
    } catch(e){error=e;ws.terminate();}
  });
});
const child=spawn('/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64',[
  '--headless','--path','godot','--script','res://tests/combat_shields/live.gd','--',`--endpoint=ws://127.0.0.1:${server.address().port}`
],{cwd:root,stdio:['ignore','pipe','pipe']});
let output=''; child.stdout.on('data',x=>output+=x);child.stderr.on('data',x=>output+=x);
const timeout=setTimeout(()=>{error??=Error('live oracle timeout');child.kill('SIGKILL');},25000);
const exit=await new Promise(resolve=>child.on('exit',resolve));
clearTimeout(timeout);
for(const ws of server.clients)ws.terminate();
await new Promise(resolve=>server.close(resolve));
writeFileSync(`${evidence}/live-${stamp}.log`,output);
writeFileSync(`${evidence}/live-${stamp}.json`,JSON.stringify({provenance:'Fresh source Match over loopback to pinned Godot, scripted private source damage stimulus; not natural multiplayer play',exit,error:error?.stack??null,receipts,wire},null,2)+'\n');
if(error)throw error;
assert.equal(exit,0);assert.equal(receipts.length,6);assert(output.includes('COMBAT_SHIELDS_LIVE_DONE {"clean":true}'));
assert(!/SCRIPT ERROR|ERROR:|instances leaked|resources still in use/.test(output));
console.log(`COMBAT_SHIELDS_LIVE_OK snapshots=${receipts.length} hash_correlated=6 source_shield_damage=35 source_armor_depleted=24 one_shatter=true materials_released=true`);
