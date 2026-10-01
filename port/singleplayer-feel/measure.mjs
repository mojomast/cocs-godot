import {createCampaignMatch} from '../native-campaign/match.mjs';
import {Match} from '../native-campaign/core.generated.mjs';
import {loadCampaignMap} from '../native-campaign/maps.mjs';
import {ROBOTS,deployEncounter} from '../native-campaign/enemies.mjs';
import {ENEMY_TYPES} from '../../game/enemy-types.mjs';
import {WEAPONS} from '../../game/data.mjs';
import {clampSingleHit} from '../../game/operator-verbs.mjs';
import {MISSION_IDS,MISSIONS} from '../native-campaign/missions.mjs';
import {pathToFileURL} from 'node:url';

// Ideal connected-hit bench: source cap + armor/shield/death primitives, all
// pellets connected, zero spread/falloff, center splash; no travel/reload/aim.
// This is a repeatable balance envelope, NOT a playthrough or observed human TTK.
export function measureBalance() {
  const mapData=loadCampaignMap('rootfall-verge'),rows=[];
  for(const baseline of [true,false])for(const model of Object.keys(ROBOTS)) {
    const match=createCampaignMatch({mapData,random:()=>.5});
    if(baseline)match.damage=Match.prototype.damage.bind(match);
    deployEncounter(match,match.modeState,{roster:{[model]:1}},mapData.campaign.anchors['encounter-1']);
    const enemy=match.actors[1],player=match.actors[0],old=ENEMY_TYPES[ROBOTS[model].npcType];
    const start={health:enemy.health,armor:enemy.armor,shield:enemy.npcShield?{...enemy.npcShield}:null};
    for(const [index,weapon] of WEAPONS.entries())for(const facing of model==='bulwark'?['front','rear']:['front']) {
      Object.assign(enemy,{health:baseline?old.health:start.health,maxHealth:baseline?old.health:start.health,armor:baseline?old.armor:start.armor,
        temporaryShield:0,protection:0,npcShield:baseline?(old.shield?{...old.shield}:null):(start.shield?{...start.shield}:null),
        campaignSavedShield:null,campaignGuard:0,campaignExposedUntil:0,campaignStaggerCooldown:0,campaignStagger:0,x:0,z:0,yaw:0});
      Object.assign(player,{x:0,z:facing==='front'?-10:10,weapon:index,streak:0,frags:0,damageMultiplier:1,health:player.maxHealth});
      let shots=0;match.time=0;
      while(enemy.health>0&&shots<200) {
        for(let pellet=0;pellet<(weapon.pellets||1)&&enemy.health>0;pellet++)match.damage(enemy,clampSingleHit(weapon.damage,{targetHealth:enemy.maxHealth}),player);
        if(weapon.speed&&weapon.splash&&enemy.health>0)match.damage(enemy,clampSingleHit(weapon.splash,{targetHealth:enemy.maxHealth}),player);
        shots++;match.time+=weapon.interval;
        if(!baseline&&enemy.campaignSavedShield&&match.time>=enemy.campaignExposedUntil){enemy.npcShield=enemy.campaignSavedShield;enemy.campaignSavedShield=null;}
      }
      rows.push({variant:baseline?'before':'after',model,facing,weapon:index,name:weapon.name,shots,seconds:Number(((shots-1)*weapon.interval).toFixed(3))});
    }
  }
  const routes=MISSION_IDS.map(mapId=>{
    const data=loadCampaignMap(mapId),points=data.campaign.criticalPath;
    const meters=points.slice(1).reduce((total,p,i)=>total+Math.hypot(p.x-points[i].x,p.y-points[i].y,p.z-points[i].z),0);
    return {mapId,criticalPathMeters:Math.round(meters),unopposedSecondsAt8_6mps:Math.round(meters/8.6),targetSeconds:data.campaign.targetSeconds,
      rosters:MISSIONS[mapId].encounters.map(e=>({title:e.title,count:Object.values(e.roster).reduce((a,b)=>a+b,0),mechanic:e.mechanic,seconds:e.seconds}))};
  });
  return {method:'Ideal connected primary-hit damage envelope; not human accuracy or measured completion time',rows,routes};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href)console.log(JSON.stringify(measureBalance(),null,2));
