// Horde-only presentation identity. npcType remains the source brain, score,
// damage and death identity; no actor stats or collision volumes are rewritten.
export const ROBOT_FOR_ROLE=Object.freeze({
 husk:'scrapper',sapper:'scrapper',lancer:'skirmisher',spitter:'skirmisher',
 mender:'sentinel',overseer:'sentinel',sentinel:'sentinel',
 mortar:'mortar',brute:'bulwark',bulwark:'bulwark',
 warden:'warden',harbinger:'warden',
});

export function hordeRobotState(snapshot){
 if(!snapshot||!Array.isArray(snapshot.actors))return snapshot;
 return {...snapshot,actors:snapshot.actors.map(actor=>{
  if(actor?.isNpc!==true || !Object.hasOwn(ROBOT_FOR_ROLE,actor.npcType))return actor;
  return {...actor,npcModel:ROBOT_FOR_ROLE[actor.npcType]};
 })};
}
