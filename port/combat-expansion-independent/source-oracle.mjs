// Independent, private source execution. Explicit setup; never connects to a server.
import assert from 'node:assert/strict';
import {mkdirSync, writeFileSync} from 'node:fs';
import {Match} from '../../game/core.mjs';
import {WEAPONS} from '../../game/data.mjs';
import {applyEnemyFields} from '../../game/enemy-types.mjs';
import {EventCursor} from '../native-horde/authority.mjs';
import {adsFieldOfView, resolveActiveSight} from '../../game/reticle.mjs';

const clone = value => JSON.parse(JSON.stringify(value));
const cases = [];
function scenario(label, setup, damage = 40, expectedHealthLoss = 40) {
  const match = new Match('chatgpt', 'openclaw', () => .37, 'meridian-exchange', {mode:'deathmatch',botCount:1});
  const [target, source] = match.actors; // Deliberately exercise actor zero as REMOTE.
  for (const actor of [target, source]) Object.assign(actor, {bot:null,protection:0,armor:0,temporaryShield:0,juggernautShield:0,health:500,maxHealth:500,x:0,y:0,z:0,yaw:0});
  source.z = -5;
  setup(target, source, match);
  const cursor = new EventCursor(); cursor.take(match);
  const before = clone(match.snapshot());
  match.damage(target, damage, source);
  const after = clone(match.snapshot());
  const events = clone(cursor.take(match));
  const loss = before.actors[0].health - after.actors[0].health;
  assert(Math.abs(loss - expectedHealthLoss) < 1e-8, `${label}: ${loss}`);
  cases.push({label,before,after,events,healthLoss:loss});
}
scenario('spawn-immunity', a => a.protection=1, 40, 0);
scenario('active-is-not-immunity', a => a.active=1);
scenario('expired-overshield-pool', a => a.powerups.overshield=10);
scenario('temporary-absorb', a => a.temporaryShield=25, 40, 15);
scenario('armor-is-partial', a => a.armor=100, 40, 16);
scenario('juggernaut-absorb', a => a.juggernautShield=25, 40, 15);
scenario('bulwark-front', a => applyEnemyFields(a,'bulwark'),40,12);
scenario('bulwark-rear', (a,s) => {applyEnemyFields(a,'bulwark');s.z=5;},40,56);
scenario('bulwark-yaw-quarter', (a,s) => {applyEnemyFields(a,'bulwark');a.yaw=Math.PI/2;s.x=-5;s.z=0;},40,12);
scenario('armor-depleted', a => a.armor=10,40,30);
const weapons = [];
for (let id=0; id<10; id++) {
  const match = new Match('chatgpt','openclaw',()=>.37,'meridian-exchange',{mode:'deathmatch',botCount:0});
  const actor = match.actors[0];
  Object.assign(actor,{weapon:id,shotWait:0,weaponSwitch:0,protection:0,bot:null});
  actor.ammo[id] = WEAPONS[id].cap;
  const cursor = new EventCursor(); cursor.take(match);
  const before = clone(match.snapshot().actors[0]);
  match.fire(actor);
  const fire = clone(cursor.take(match));
  assert(fire.some(e => e.type==='shot' || e.type==='launch'), `weapon ${id} actually fired`);
  const reloadAccepted = match.startReload(actor);
  assert.equal(reloadAccepted, id !== 0, 'Pulse is infinite-ammo/no-reload in source');
  const reload = clone(match.snapshot().actors[0]);
  weapons.push({id,before,fire,reload,reloadAccepted,fov:[55,75,95].map(base=>({base,expected:adsFieldOfView(base,resolveActiveSight({weapon:id,aiming:true}))}))});
}
const output = {provenance:'Independent explicit private Match setup; executed damage/fire/startReload and production EventCursor. No gameplay implementation modified.',cases,weapons};
mkdirSync(new URL('../../godot/tests/combat_expansion_independent/',import.meta.url),{recursive:true});
writeFileSync(new URL('../../godot/tests/combat_expansion_independent/oracle.json',import.meta.url),JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({cases:cases.map(({label,healthLoss,events})=>({label,healthLoss,events:events.map(e=>({type:e.type,amount:e.amount,shield:e.shield,shieldBreak:e.shieldBreak}))})),weapons:weapons.map(w=>({id:w.id,fireEvents:w.fire.length,reloadDuration:w.reload.reloadDuration}))},null,2));
