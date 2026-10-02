// Bounded source fixtures: intentionally position/damage actors to isolate rules.
// These are NOT normal-input or native-client acceptance evidence.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Match} from '../../../game/core.mjs';
import {modeRule} from '../../../game/config.mjs';
import {WEAPONS} from '../../../game/data.mjs';
import {options,EXPERIENCES} from '../../../tools/godot-package/options.mjs';
import {launchOptions} from '../../../tools/godot-dev/launch_options.mjs';
const catalog=JSON.parse(readFileSync(new URL('../../contracts/map-selection.json',import.meta.url)));
const pairs=EXPERIENCES['mode-expansion'].maps;
const make=(mode,map,extra={})=>new Match('chatgpt','openclaw',()=>.5,map,{mode,botCount:0,humanCount:3,timeLimit:120,...extra});
const unprotect=a=>Object.assign(a,{protection:0,armor:0,temporaryShield:0,juggernautShield:0});

test('all eight map/mode routes are source-supported, preserve identity and agree across launchers',()=>{
 let count=0;
 for(const [map,modes] of Object.entries(pairs))for(const mode of modes){
  const args=['--experience=mode-expansion',`--map=${map}`,`--mode=${mode}`];
  const pack=options(args,catalog),dev=launchOptions(args,catalog),match=make(mode,map);
  assert.deepEqual(dev.sessionOptions,pack.userArgs);
  assert.equal(pack.scene,'res://mode_expansion/demo.tscn');
  assert.equal(match.snapshot().mapId,map);assert.equal(match.config.mode,mode);
  assert.ok(catalog.maps.find(x=>x.id===map).supported_modes.includes(mode));count++;
 }
 assert.equal(count,8);
 for(const parser of [options,launchOptions]){
  assert.throws(()=>parser(['--experience=mode-expansion','--map=tidal-citadel','--mode=vip-escort'],catalog));
  assert.throws(()=>parser(['--experience=mode-expansion','--join-room=room'],catalog));
  assert.throws(()=>parser(['--experience=mode-expansion','--endpoint=ws://127.0.0.1:4000','--join-room=room','--bots=0'],catalog));
  assert.doesNotThrow(()=>parser(['--experience=mode-expansion','--endpoint=ws://127.0.0.1:4000','--join-room=room'],catalog));
  for(const target of [4,51])assert.throws(()=>parser(['--experience=mode-expansion','--mode=arsenal',`--round-target=${target}`],catalog));
  for(const target of [5,50])assert.doesNotThrow(()=>parser(['--experience=mode-expansion','--mode=arsenal',`--round-target=${target}`],catalog));
 }
});
test('Arsenal grants all exact weapon identities with unlimited ammo on every spawn',()=>{
 for(const map of Object.keys(pairs).slice(0,3)){
  const m=make('arsenal',map),a=m.actors[0];
  assert.equal(a.ammo.length,WEAPONS.length);assert.ok(a.ammo.every(n=>n===Infinity));
  assert.deepEqual(m.snapshot().actors[0].ammo,WEAPONS.map(()=> '∞'));
  for(let weapon=0;weapon<WEAPONS.length;weapon++){
   m.step(1/60,{inputs:{0:{weapon}}});assert.equal(a.weapon,weapon);
  }
  m.spawn(a);assert.ok(a.ammo.every(n=>n===Infinity));
 }
});
test('Juggernaut buffer, damage, survival credit, transfer bounty and source winner',()=>{
 const m=make('juggernaut','meridian-exchange'),[a,b]=m.actors,r=modeRule('juggernaut');
 assert.equal(a.juggernautShield,r.juggernautShield);assert.equal(a.juggernautDamage,1.4);
 m.updateObjectives(2);assert.equal(m.objectiveState.points[a.id],1.5);
 unprotect(a);a.health=1;m.damage(a,999,b);
 assert.equal(m.objectiveState.juggernautId,b.id);assert.equal(a.juggernaut,false);
 assert.equal(a.juggernautDamage,1);assert.equal(b.juggernautShield,175);
 assert.equal(m.objectiveState.points[b.id],3);
 assert.ok(m.events.some(e=>e.type==='juggernaut-transfer'&&e.to===b.id));
 m.updateObjectives(40);assert.equal(m.over,true);assert.equal(m.objectiveState.winner,b.id);
});
test('frozen Juggernaut damage flag is serialized but unused by source combat (known source discrepancy)',()=>{
 const source=readFileSync(new URL('../../../game/core.mjs',import.meta.url),'utf8');
 // All occurrences are initialization/assignment. No aura implementation is
 // manufactured by the native adapter; this is explicitly not a damage buff claim.
 assert.ok(!source.includes('*a.juggernautDamage')&&!source.includes('*source.juggernautDamage'));
 const m=make('juggernaut','meridian-exchange'),[carrier,target]=m.actors;
 unprotect(target);const health=target.health;m.damage(target,10,carrier);
 assert.equal(health-target.health,10);assert.equal(carrier.juggernautDamage,1.4);
});
test('Elimination friendly fire spends no tickets, enemy/self deaths do; paid respawn and zero-ticket outcome',()=>{
 const m=make('team-elimination','tidal-citadel',{fragLimit:2}),[red,blue,ally]=m.actors;
 assert.equal(red.team,ally.team);assert.notEqual(red.team,blue.team);
 // Friendly-fire filtering is owned by attack resolution, not damage().
 unprotect(ally);const health=ally.health;m.detonate({x:ally.x,y:ally.y,z:ally.z},3,999,red);m.updateObjectives(1/60);
 assert.equal(ally.health,health);assert.equal(m.objectiveState.lives[red.team],2);
 unprotect(blue);m.damage(blue,999,red);m.updateObjectives(1/60);
 assert.equal(m.objectiveState.lives[blue.team],1);assert.equal(blue.dead,3);assert.equal(m.over,false);
 for(let i=0;i<190;i++)m.step(1/60,{});
 assert.ok(blue.health>0,'source permits paid respawn while tickets remain');
 unprotect(blue);m.damage(blue,999,blue);m.updateObjectives(1/60);
 assert.equal(m.over,true);assert.equal(m.objectiveState.lives[blue.team],0);assert.equal(m.objectiveState.winner,red.team);
 const deaths=blue.deaths;for(let i=0;i<240;i++)m.step(1/60,{});
 assert.equal(blue.deaths,deaths);assert.ok(blue.health<=0,'no post-results respawn');
});
test('VIP proximity movement, extraction hold/decay, death and timeout use source results',()=>{
 const m=make('vip-escort','sunscar-convoy');m.updateObjectives(1/60);
 const s=m.objectiveState,vip=m.actors.find(a=>a.id===s.vipId),escort=m.actors.find(a=>!a.isVip&&a.team===s.escortTeam);
 assert.equal(vip.maxHealth,260);assert.equal(s.captureSeconds,4);assert.equal(s.escortRadius,7);
 for(const a of m.actors)if(a!==vip){a.x=-150;a.z=70;}
 const before=vip.x;m.updateObjectives(1);assert.equal(vip.x,before);
 Object.assign(escort,{x:vip.x,y:vip.y,z:vip.z});m.updateObjectives(1);assert.notEqual(vip.x,before);
 Object.assign(vip,s.extract);m.updateObjectives(2);assert.equal(s.progress,2);
 vip.x-=30;m.updateObjectives(1);assert.equal(s.progress,1,'outside the beacon progress decays, not instant reset');
 Object.assign(vip,s.extract);m.updateObjectives(3);assert.equal(m.over,true);assert.equal(s.winner,s.escortTeam);
 const fail=make('vip-escort','sunscar-convoy');fail.updateObjectives(1/60);
 const target=fail.actors.find(a=>a.isVip);unprotect(target);fail.damage(target,999,fail.actors.find(a=>a.team!==target.team));fail.updateObjectives(1/60);
 assert.equal(fail.objectiveState.vipDead,true);assert.equal(fail.objectiveState.winner,fail.objectiveState.defenderTeam);assert.equal(fail.over,true);
 const timeout=make('vip-escort','sunscar-convoy');timeout.time=120;timeout.updateObjectives(1/60);
 assert.equal(timeout.over,true);assert.equal(timeout.objectiveState.winner,timeout.objectiveState.defenderTeam);
});
