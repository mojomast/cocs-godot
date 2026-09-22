// Explicit positive field lists: welcome/token/progressToken and raw packets
// are never passed to retention. Projection is also the native observer contract.
export const actorKeys=['id','x','y','z','yaw','pitch','eyeHeight','health','maxHealth','armor','dead','temporaryShield','juggernautShield','protection','active','braceTimer','braceMitigation','cocsArrival','damageMultiplier','gearDamage','gearSpread','character','harness','verbState','powerups','npcShield','weapon','shots'];
export const pickupKeys=['id','kind','x','y','z','wait'];
export const eventKeys=['id','time','type','actor','source','amount','shield','shieldBreak','kind','killer','weapon','hit','falloff'];
export const project=(value,keys)=>value?Object.fromEntries(keys.map(k=>[k,value[k]??null])):null;
export const actor=a=>project(a,actorKeys);
export const pickup=p=>project(p,pickupKeys);
export const event=e=>project(e,eventKeys);
