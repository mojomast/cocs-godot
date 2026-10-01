// Horde-only presentation identity. npcType remains the source brain, score,
// damage and death identity; no actor stats or collision volumes are rewritten.
export const ROBOT_FOR_ROLE=Object.freeze({
 husk:'scrapper',sapper:'scrapper',lancer:'skirmisher',spitter:'skirmisher',
 mender:'sentinel',overseer:'sentinel',sentinel:'sentinel',
 mortar:'mortar',brute:'bulwark',bulwark:'bulwark',
 warden:'warden',harbinger:'warden',
});
// The frozen source's actorHit uses .85 × 1.8 × hitScale. Apply its built-in
// hit-volume control on NPC spawn only, alongside the Horde-only presentation
// scale. Width is weighted toward the weapon-facing armored chassis, not the
// animating leg tips; no attack/radius/health rules are changed.
export const ROBOT_SILHOUETTE=Object.freeze({
 husk:{scale:.72,hitScale:1.15},sapper:{scale:.76,hitScale:1.2},
 lancer:{scale:.86,hitScale:1},spitter:{scale:.9,hitScale:1},
 mender:{scale:.86,hitScale:1.25},overseer:{scale:1,hitScale:1.45},sentinel:{scale:1.08,hitScale:1.6},
 mortar:{scale:1.02,hitScale:1.55},brute:{scale:1.06,hitScale:1.65},bulwark:{scale:1.15,hitScale:1.85},
 warden:{scale:1.18,hitScale:2},harbinger:{scale:1.18,hitScale:2},
});

export function applyRobotHitVolume(actor){
 if(actor?.isNpc===true&&Object.hasOwn(ROBOT_SILHOUETTE,actor.npcType))
  actor.hitScale=ROBOT_SILHOUETTE[actor.npcType].hitScale;
 return actor;
}

export function hordeRobotState(snapshot){
 if(!snapshot||!Array.isArray(snapshot.actors))return snapshot;
 return {...snapshot,actors:snapshot.actors.map(actor=>{
  if(actor?.isNpc!==true || !Object.hasOwn(ROBOT_FOR_ROLE,actor.npcType))return actor;
  return {...actor,npcModel:ROBOT_FOR_ROLE[actor.npcType],
   npcProfile:{...actor.npcProfile,scale:ROBOT_SILHOUETTE[actor.npcType].scale}};
 })};
}
