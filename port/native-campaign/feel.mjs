// Campaign-owned policy around source combat primitives. No client hit invention.
export const DIFFICULTY = Object.freeze({
  easy:{health:160,armor:80,pressure:2,incoming:.75,burst:26,recovery:2.5},
  normal:{health:140,armor:60,pressure:3,incoming:1,burst:34,recovery:3},
  hard:{health:120,armor:40,pressure:4,incoming:1.2,burst:46,recovery:4},
});
export const ROBOT_FEEL = Object.freeze({
  scrapper:{health:24,armor:0,stagger:12,range:3.2},
  skirmisher:{health:42,armor:0,stagger:18,range:3.5},
  sentinel:{health:78,armor:18,stagger:26,range:22},
  mortar:{health:52,armor:0,stagger:20,range:38},
  bulwark:{health:110,armor:20,stagger:35,range:18},
  warden:{health:360,armor:40,stagger:65,range:24},
});
export function tuneRobot(actor, time) {
  const tune=ROBOT_FEEL[actor.npcModel];
  actor.health=actor.maxHealth=tune.health; actor.armor=tune.armor;
  actor.npcProfile={...actor.npcProfile,health:tune.health,armor:tune.armor};
  actor.campaignReady=time+.7+(actor.id%3)*.2;
  actor.campaignStagger=0; actor.campaignGuard=0;
  if(actor.npcShield)actor.npcShield={...actor.npcShield,reduction:.45,flankBonus:1.65};
  if(actor.npcPhalanx)actor.npcPhalanx={...actor.npcPhalanx,shield:16,cap:24,interval:6,cooldown:6,telegraph:.9};
  if(actor.npcArtillery)actor.npcArtillery={...actor.npcArtillery,damage:30,telegraph:1.4,cooldown:6.5,maxRange:38};
  if(actor.npcFlank)actor.npcFlank={...actor.npcFlank,telegraph:.8,damageBonus:.15,speedBonus:.3};
}
export function createFeel(difficulty) {
  const tuning=DIFFICULTY[difficulty];
  let lastDamage=-Infinity, burstStart=-Infinity, burstDamage=0;
  const lanes=new Map();
  function attack(match,actor,kind='gun') {
    if(!actor.isNpc)return true;
    if(actor.npcModel==='mortar'&&kind==='gun')return false;
    if(match.time<(actor.campaignStaggerUntil??0)||match.time<(actor.campaignExposedUntil??0))return false;
    const player=match.actors[0], range=ROBOT_FEEL[actor.npcModel].range;
    if(Math.hypot(actor.x-player.x,actor.z-player.z)>range)return false;
    for(const [id,end] of lanes)if(end<match.time||match.actors[id]?.health<=0){lanes.delete(id);if(match.actors[id])match.actors[id].campaignReady=match.time+1.5;}
    if(match.time<(actor.campaignReady??0))return false;
    if(!lanes.has(actor.id)) {
      if(lanes.size>=tuning.pressure)return false;
      const windup=kind==='melee'?.38:.55;
      actor.campaignFireAt=match.time+windup;
      lanes.set(actor.id,match.time+windup+(kind==='melee'?.15:.65));
      match.emit('enemy-telegraph',{kind:'attack',actor:actor.id,x:actor.x,z:actor.z,radius:.8,duration:windup});
      return false;
    }
    if(match.time<actor.campaignFireAt)return false;
    return true;
  }
  return {
    tuning, attack,
    outgoing(match,target,amount,source) {
      // The locked multiplayer primitive caps a direct hit at 90% max HP.
      // Light campaign chassis rupture on a decisive hit: remove that last
      // sliver through the authoritative damage path, without lifting PvP caps.
      if(source?.id===0&&['scrapper','skirmisher','mortar'].includes(target.npcModel)&&
        target.armor<=0&&(target.temporaryShield||0)<=0&&amount>=target.maxHealth*.5&&amount>=target.health*.9)return Math.max(amount,target.health);
      if(source?.id===0&&target.npcModel==='warden'&&match.time<(target.campaignExposedUntil??0))return amount*1.35;
      return amount;
    },
    afterAttack(match,actor,kind) {
      if(!actor.isNpc)return;
      if(kind==='melee'||match.time+.15>lanes.get(actor.id)) {
        lanes.delete(actor.id); actor.campaignReady=match.time+(kind==='melee'?1.1:1.5);
      }
    },
    incoming(match,target,amount,source) {
      if(target.id!==0||!source?.isNpc)return amount;
      if(match.time-burstStart>=.3){burstStart=match.time;burstDamage=0;}
      const multiplier=source.damageMultiplier||1;
      const accepted=Math.min(amount*multiplier*tuning.incoming,Math.max(0,tuning.burst-burstDamage));
      burstDamage+=accepted;
      return accepted/multiplier;
    },
    damaged(match,target,source,actual,amount) {
      if(actual<=0)return;
      if(target.id===0){lastDamage=match.time;return;}
      if(!target.isNpc||source?.id!==0)return;
      const tune=ROBOT_FEEL[target.npcModel];
      if(target.npcModel==='bulwark'&&target.npcShield) {
        target.campaignGuard+=amount;
        if(target.campaignGuard>=60){target.campaignGuard=0;target.campaignSavedShield=target.npcShield;target.npcShield=null;target.campaignExposedUntil=match.time+2.2;match.emit('campaign-guard-break',{actor:target.id,duration:2.2});}
      }
      target.campaignStagger+=actual;
      if(target.health>0&&target.campaignStagger>=tune.stagger&&match.time>=(target.campaignStaggerCooldown??0)) {
        target.campaignStagger=0;target.campaignStaggerUntil=match.time+.32;target.campaignStaggerCooldown=match.time+1.2;
        target.phalanxWindup=undefined;
        match.emit('campaign-stagger',{actor:target.id,duration:.32});
      }
      if(target.health<=0&&Math.hypot(target.x-source.x,target.z-source.z)<=16) {
        const health=Math.min(8,source.maxHealth-source.health),armor=Math.min(6,Math.max(0,tuning.armor-source.armor));
        source.health+=health;source.armor+=armor;
        match.emit('campaign-salvage',{actor:source.id,health,armor});
      }
    },
    update(match,dt) {
      const player=match.actors[0];
      if(player.health>0&&match.time-lastDamage>tuning.recovery)player.health=Math.min(player.maxHealth,player.health+16*dt);
      if(player.health>0&&match.time-lastDamage>5)player.armor=Math.min(Math.max(player.armor,40),player.armor+8*dt);
      for(const actor of match.actors)if(actor.campaignSavedShield&&match.time>=actor.campaignExposedUntil){actor.npcShield=actor.campaignSavedShield;actor.campaignSavedShield=null;}
    },
    event(match,type,event) {
      const actor=match.actors?.[event.actor];
      if(type==='damage'&&actor?.npcShield&&event.source===0&&event.amount>0) {
        const source=match.actors[0],dx=source.x-actor.x,dz=source.z-actor.z,length=Math.hypot(dx,dz);
        if(length>0&&(-Math.sin(actor.yaw||0)*dx-Math.cos(actor.yaw||0)*dz)/length>=Math.cos(actor.npcShield.arc??.6)) {
          actor.campaignShieldHitUntil=match.time+.18;event.shieldBlocked=true;
        }
      }
      if(type==='enemy-telegraph'&&event.kind==='boss'&&actor){event.duration=Math.max(1.15,event.duration,(event.radius||0)/8.6+.35);actor.bossStompWindup=event.duration;actor.campaignSlamDuration=event.duration;}
      if(type==='boss-slam'&&actor){actor.campaignExposedUntil=match.time+1.6;match.emit('campaign-exposed',{actor:actor.id,duration:1.6});}
    },
  };
}
