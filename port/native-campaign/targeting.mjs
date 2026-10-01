import {WEAPONS} from '../../game/data.mjs';

// Primary projectiles only. Keep gravity, splash, lifetime, ammo and fire cadence.
export const PLAYER_PROJECTILE_SPEED=Object.freeze({1:60,4:138,5:36});
export function playerWeapon(actor,base,index) {
  return actor?.id===0&&actor.isNpc!==true&&PLAYER_PROJECTILE_SPEED[index]
    ? {...base,speed:PLAYER_PROJECTILE_SPEED[index]} : base;
}
export function projectileWeapon(match,projectile) {
  const index=projectile.weapon??1,base=WEAPONS[index];
  return projectile.alt===true?base:playerWeapon(match.actors[projectile.owner],base,index);
}

export const TRACKING=Object.freeze({
  scrapper:{speed:3.2,commit:.9,plant:.35},skirmisher:{speed:3.5,commit:1.15,plant:.5},
  sentinel:{speed:2.1,commit:1.4,plant:.8},mortar:{speed:1.8,commit:1.6,plant:1.1},
  bulwark:{speed:1.7,commit:1.6,plant:.9},warden:{speed:2.0,commit:1.5,plant:.8},
});
export function trackingInput(match,actor,input,difficulty) {
  if(!actor.isNpc||!TRACKING[actor.npcModel])return input;
  const tune=TRACKING[actor.npcModel],factor={easy:.85,normal:1,hard:1.12}[difficulty];
  // Cancel role aura/flank acceleration in the speed budget, retaining role tells.
  actor.moveSpeed=tune.speed*factor/((actor.gearSpeed||1)*(actor.speedMultiplier||1));
  input.sprint=false;
  const plant=()=>{input.x=0;input.z=0;input.jump=false;if(actor.grounded){actor.vx=0;actor.vz=0;}return input;};
  if(match.time<(actor.campaignStaggerUntil??0)||match.time<(actor.campaignExposedUntil??0)) {
    actor.campaignMoveUntil=0;return plant();
  }
  // Source bots can still strafe/shoot while their state says seek/cover/flank.
  const fighting=['engage','hold'].includes(actor.bot?.state)||
    (Number.isInteger(actor.bot?.target)&&actor.bot.target>=0&&actor.bot.memory>0);
  const windup=match.time<(actor.campaignFireAt??0)||Number.isFinite(actor.artilleryWindup)||Number.isFinite(actor.bossStompWindup);
  if(!fighting&&!windup){actor.campaignMoveUntil=0;return input;}
  input.jump=false;
  if(windup||match.time<(actor.campaignPlantUntil??0)) {
    return plant();
  }
  if(match.time>=(actor.campaignMoveUntil??0)) {
    if(actor.campaignMoveUntil>0) {
      actor.campaignMoveUntil=0;actor.campaignPlantUntil=match.time+tune.plant;
      return plant();
    }
    actor.campaignMoveUntil=match.time+tune.commit;
    actor.campaignMove={x:input.x||0,z:input.z||0};
  }
  // Source movement still resolves walls, slopes and voids; no position writes.
  input.x=actor.campaignMove.x;input.z=actor.campaignMove.z;
  return input;
}
