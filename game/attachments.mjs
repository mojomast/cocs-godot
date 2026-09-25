// Weapon attachments: slot-based modifiers and behavior modules for the FPS loadout.
// Kept self-contained so callers can resolve a {slot:id} map into an applied weapon
// without touching the base WEAPONS table.
//
// This is the persistent career mod catalogue: a fitted attachment is chosen
// before a match and stays on the weapon across modes until it is cleared. It
// is separate from the round-scoped personal REQ store the COCS economy layer
// resolves during a match. Every entry here changes a field
// `applyAttachmentsToWeapon` actually writes, so the UI can surface real
// numbers instead of cosmetic promises. The launch items keep their ids,
// levels and modifiers so old profiles and presets still round-trip.
export const ATTACHMENT_SLOTS=Object.freeze([
 Object.freeze({id:'optic',name:'Optic'}),
 Object.freeze({id:'barrel',name:'Barrel'}),
 Object.freeze({id:'magazine',name:'Magazine'}),
 Object.freeze({id:'underbarrel',name:'Underbarrel'}),
]);
const SLOT_IDS=ATTACHMENT_SLOTS.map(slot=>slot.id);
export const ATTACHMENTS=Object.freeze([
 Object.freeze({id:'extended-mag',slot:'magazine',name:'Extended Magazine',description:'A longer magazine and a slightly slower swap. More rounds between “oops.”',level:1,weapons:[0,3,4,6,8,9],modifiers:Object.freeze({cap:12,reload:1.1}),behavior:Object.freeze({}),visual:Object.freeze({magazine:'extended'})}),
 Object.freeze({id:'holo-sight',slot:'optic',name:'Holo Sight',description:'A holographic reticle that tightens close-range spread. Looks cool, aims cooler.',level:2,weapons:[0,3,4,6,7,9],modifiers:Object.freeze({spread:.9}),behavior:Object.freeze({}),visual:Object.freeze({optic:'holo'})}),
 Object.freeze({id:'long-barrel',slot:'barrel',name:'Long Barrel',description:'A longer barrel for reach and striking power. Compensating for something? Correct.',level:3,weapons:[0,2,4,6,8,9],modifiers:Object.freeze({range:1.25,spread:.92,damage:1.06}),behavior:Object.freeze({}),visual:Object.freeze({barrel:'long'})}),
 Object.freeze({id:'quickdraw-grip',slot:'underbarrel',name:'Quickdraw Grip',description:'A forward grip that speeds handling and steadiness. Just grip it and rip it.',level:4,weapons:[],modifiers:Object.freeze({reload:.82,spread:.94,interval:.96}),behavior:Object.freeze({}),visual:Object.freeze({color:'#4a5a62'})}),
 Object.freeze({id:'scope',slot:'optic',name:'Precision Scope',description:'Magnified optics trade field of view for accuracy at range. Patience, glass, profit.',level:5,weapons:[0,2,4,8],modifiers:Object.freeze({spread:.8,range:1.2}),behavior:Object.freeze({}),visual:Object.freeze({optic:'scope'})}),
 Object.freeze({id:'suppressor',slot:'barrel',name:'Suppressor',description:'A quiet barrel that tames kick but softens damage and reach. Sneaky, but not free.',level:6,weapons:[0,4,6,8,9],modifiers:Object.freeze({damage:.92,spread:.9,recoilKick:.82,range:.95}),behavior:Object.freeze({}),visual:Object.freeze({barrel:'long',color:'#2f3a3f'})}),
 Object.freeze({id:'burst-module',slot:'underbarrel',name:'Burst Module',description:'A fire-control module that groups each trigger pull into a tidy burst. Discipline, automated.',level:8,weapons:[0,4,9],modifiers:Object.freeze({burst:3,interval:1.05}),behavior:Object.freeze({mode:'burst',burst:3,burstDelay:.16}),visual:Object.freeze({color:'#8affc1'})}),
 Object.freeze({id:'charge-coil',slot:'barrel',name:'Charge Coil',description:'Stores energy for a charged shot with doubled impact. Patience, weaponized.',level:10,weapons:[4,6],modifiers:Object.freeze({damage:1.15,interval:1.25}),behavior:Object.freeze({mode:'charge',chargeTime:.5,chargeDamage:2.2}),visual:Object.freeze({barrel:'heavy',color:'#72cfff'})}),
 Object.freeze({id:'drum-mag',slot:'magazine',name:'Drum Magazine',description:'A high-capacity drum for sustained automatic fire. Feed the belt, fear nothing.',level:12,weapons:[0,4,9],modifiers:Object.freeze({cap:45,reload:1.35,spread:1.05}),behavior:Object.freeze({}),visual:Object.freeze({magazine:'drum',color:'#3b4a52'})}),
 Object.freeze({id:'piercing-rounds',slot:'magazine',name:'Piercing Rounds',description:'Hardened rounds that punch through a line of targets. One shot, several problems.',level:14,weapons:[2,8],modifiers:Object.freeze({damage:.92,range:1.1}),behavior:Object.freeze({mode:'pierce',pierce:2}),visual:Object.freeze({magazine:'stock',color:'#bb9aff'})}),
 Object.freeze({id:'grenade-launcher',slot:'underbarrel',name:'Grenade Launcher',description:'An underbarrel tube that lobs a small explosive on each shot. Surprise geometry.',level:15,weapons:[0,9],modifiers:Object.freeze({damage:.96,spread:1.06}),behavior:Object.freeze({mode:'explosive',explosiveRadius:3.2,explosiveDamage:.5}),visual:Object.freeze({color:'#ff806b'})}),
 Object.freeze({id:'explosive-tips',slot:'magazine',name:'Explosive Tips',description:'Impact-fused rounds that detonate for area damage. Everything is a grenade if you believe.',level:16,weapons:[1,4,5],modifiers:Object.freeze({damage:1.05,spread:1.08}),behavior:Object.freeze({mode:'explosive',explosiveRadius:2.6,explosiveDamage:.45}),visual:Object.freeze({magazine:'stock',color:'#ffad61'})}),
 Object.freeze({id:'homing-beacon',slot:'underbarrel',name:'Homing Beacon',description:'A targeting beacon that steers projectiles toward the target. Aiming is now a suggestion.',level:18,weapons:[1,4],modifiers:Object.freeze({spread:.95}),behavior:Object.freeze({mode:'homing',homing:.6,turnRate:3}),visual:Object.freeze({color:'#ffd166'})}),
 Object.freeze({id:'chain-capacitor',slot:'underbarrel',name:'Chain Capacitor',description:'Arcs residual energy from a hit into a nearby second target. Sharing is caring.',level:20,weapons:[4,6],modifiers:Object.freeze({damage:.95,spread:.95}),behavior:Object.freeze({mode:'chain',chain:2,chainRange:6}),visual:Object.freeze({color:'#8ce8ff'})}),
 // --- Career expansion (v7.x): fills the low career with honest starter mods
 // and the high career with specialised ones. Each reuses modifiers/behaviours
 // the resolver and core already apply; no item is cosmetic-only.
 Object.freeze({id:'red-dot',slot:'optic',name:'Red Dot Sight',description:'A zero-magnification dot that clears the sight picture. The honest first upgrade.',level:1,weapons:[],modifiers:Object.freeze({spread:.94}),behavior:Object.freeze({}),visual:Object.freeze({optic:'holo',color:'#7ce0ff'})}),
 Object.freeze({id:'marksman-optic',slot:'optic',name:'Marksman Optic',description:'A high-magnification optic for rail and marksman work. Slower to settle, but it reaches.',level:28,weapons:[2,6,8],modifiers:Object.freeze({spread:.78,range:1.22,interval:1.06}),behavior:Object.freeze({}),visual:Object.freeze({optic:'scope',color:'#b79bff'})}),
 Object.freeze({id:'short-barrel',slot:'barrel',name:'Short Barrel',description:'A stubby barrel that snaps up fast and trades reach and kick for speed. CQC, no apologies.',level:5,weapons:[3,7,9],modifiers:Object.freeze({range:.82,spread:1.08,interval:.95,recoilKick:1.12}),behavior:Object.freeze({}),visual:Object.freeze({barrel:'short'})}),
 Object.freeze({id:'muzzle-brake',slot:'barrel',name:'Muzzle Brake',description:'Ports that tame kick and tighten follow-up shots at a sliver of damage. Control over sting.',level:7,weapons:[],modifiers:Object.freeze({spread:.96,recoilKick:.78,damage:.97}),behavior:Object.freeze({}),visual:Object.freeze({barrel:'short',color:'#8a9aa2'})}),
 Object.freeze({id:'quick-mag',slot:'magazine',name:'Quick Magazine',description:'A sprung magazine that drops fast for a faster reload. Sprinting hands group a little looser.',level:4,weapons:[0,3,4,6,9],modifiers:Object.freeze({reload:.8,spread:1.04}),behavior:Object.freeze({}),visual:Object.freeze({magazine:'stock',color:'#c9d4dc'})}),
 Object.freeze({id:'match-ammo',slot:'magazine',name:'Match Ammunition',description:'Hand-loaded rounds for reach and stopping power, cycled a touch slower. For long team-elimination trades.',level:12,weapons:[2,8],modifiers:Object.freeze({damage:1.06,range:1.12,interval:1.04}),behavior:Object.freeze({}),visual:Object.freeze({magazine:'stock',color:'#ffd166'})}),
 Object.freeze({id:'vertical-grip',slot:'underbarrel',name:'Vertical Grip',description:'A forward grip that steadies the muzzle while nudging the reload slower. Brace and hold.',level:3,weapons:[],modifiers:Object.freeze({spread:.95,reload:1.06}),behavior:Object.freeze({}),visual:Object.freeze({color:'#5a6a72'})}),
 Object.freeze({id:'salvo-module',slot:'underbarrel',name:'Salvo Module',description:'A two-round burst module that turns each pull into a disciplined pair, at the cost of a slower cycle and a touch more scatter.',level:22,weapons:[0,4,9],modifiers:Object.freeze({interval:1.08,spread:1.04}),behavior:Object.freeze({mode:'burst',burst:2,burstDelay:.18}),visual:Object.freeze({color:'#8affc1'})}),
]);
const BY_ID=new Map(ATTACHMENTS.map(item=>[item.id,item]));
const MULTIPLICATIVE=['damage','spread','interval','range','bloomPerShot','bloomMax','recoilKick','reload'];
const ADDITIVE=['cap','pellets','burst'];
const MODIFIER_RANGES={damage:[.25,3],spread:[.2,2],interval:[.2,2],range:[.4,3],bloomPerShot:[.2,2],bloomMax:[.2,2],recoilKick:[.2,2],reload:[.3,2],cap:[0,200],pellets:[0,20],burst:[0,8]};
export function attachmentById(id){return BY_ID.get(id)||null;}
// Presentation-only spec chips for a definition. Every chip is derived from the
// same modifier/behaviour fields `resolveAttachments`/`applyAttachmentsToWeapon`
// consume, so a card can never advertise an effect the simulation will not
// apply. The order is fixed for deterministic tests and stable rendering.
const specPct=value=>{const delta=Math.round((value-1)*100);return `${delta>0?'+':''}${delta}%`;};
const specCount=value=>`${value>0?'+':''}${Math.round(value)}`;
export function attachmentSpec(item){
 const mods=item?.modifiers||{},beh=item?.behavior||{},chips=[];
 if(Number.isFinite(mods.damage)&&mods.damage!==1)chips.push(`${specPct(mods.damage)} DMG`);
 if(Number.isFinite(mods.range)&&mods.range!==1)chips.push(`${specPct(mods.range)} RNG`);
 if(Number.isFinite(mods.spread)&&mods.spread!==1)chips.push(`${specPct(mods.spread)} SPREAD`);
 if(Number.isFinite(mods.interval)&&mods.interval!==1)chips.push(`${specPct(mods.interval)} CYCLE`);
 if(Number.isFinite(mods.reload)&&mods.reload!==1)chips.push(`${specPct(mods.reload)} RELOAD`);
 if(Number.isFinite(mods.recoilKick)&&mods.recoilKick!==1)chips.push(`${specPct(mods.recoilKick)} KICK`);
 if(Number.isFinite(mods.bloomPerShot)&&mods.bloomPerShot!==1)chips.push(`${specPct(mods.bloomPerShot)} BLOOM`);
 if(Number.isFinite(mods.bloomMax)&&mods.bloomMax!==1)chips.push(`${specPct(mods.bloomMax)} MAX BLOOM`);
 if(Number.isFinite(mods.cap)&&mods.cap!==0)chips.push(`${specCount(mods.cap)} ROUNDS`);
 if(Number.isFinite(mods.pellets)&&mods.pellets!==0)chips.push(`${specCount(mods.pellets)} PELLETS`);
 if(beh.mode==='burst')chips.push(`BURST ×${Math.round(beh.burst??mods.burst??0)}`);
 else if(beh.mode==='charge')chips.push('CHARGE SHOT');
 else if(beh.mode==='pierce')chips.push(`PIERCE ×${Math.round(beh.pierce??0)}`);
 else if(beh.mode==='explosive')chips.push('EXPLOSIVE');
 else if(beh.mode==='homing')chips.push('HOMING');
 else if(beh.mode==='chain')chips.push(`CHAIN ×${Math.round(beh.chain??0)}`);
 return chips;
}
// True when a definition fits a weapon index. Mirrors the fit filter the match
// applies in `Match.weaponForIndex`: an empty list means the attachment is
// universal, otherwise the weapon index must be listed.
export function attachmentFits(item,weapon){
 const list=Array.isArray(item?.weapons)?item.weapons:[];
 return list.length===0||list.includes(Number(weapon));
}
// `owned` is the profile's unlocks map (id -> true) keyed by the career unlock
// id (`attachment-<id>`). It lets a mod the profile explicitly owns stay fitted
// when its level sits above the level recomputed from xp, while the historical
// level-only gate still applies when it is omitted.
const attachmentUnlocked=(item,level,owned)=>item.level<=level||Boolean(owned&&typeof owned==='object'&&owned[`attachment-${item.id}`]===true);
export function normalizeAttachments(value,level=1,owned=null){
 const source=value&&typeof value==='object'?value:{},l=Math.max(1,Math.round(Number(level)||1)),out={};
 for(const slot of SLOT_IDS){const item=attachmentById(source[slot]);if(!item||item.slot!==slot||!attachmentUnlocked(item,l,owned))continue;out[slot]=item.id;}
 return out;
}
function resolveList(value){
 const chosen=new Map();
 if(Array.isArray(value))for(const id of value){const item=attachmentById(id);if(item)chosen.set(item.slot,item);}
 else if(value&&typeof value==='object')for(const slot of SLOT_IDS){const item=attachmentById(value[slot]);if(item&&item.slot===slot)chosen.set(slot,item);}
 return SLOT_IDS.map(slot=>chosen.get(slot)).filter(Boolean);
}
export function resolveAttachments(ids){
 const items=resolveList(ids),modifiers={};
 for(const key of MULTIPLICATIVE)modifiers[key]=1;
 for(const key of ADDITIVE)modifiers[key]=0;
 const behaviors=[],visual={optic:'none',barrel:'stock',magazine:'stock',underbarrel:'none'};
 for(const item of items){
  for(const [key,value] of Object.entries(item.modifiers)){
   if(ADDITIVE.includes(key))modifiers[key]+=value;
   else if(MULTIPLICATIVE.includes(key))modifiers[key]*=value;
  }
  if(item.behavior?.mode)behaviors.push({slot:item.slot,...item.behavior});
  if(item.visual)Object.assign(visual,item.visual);
  if(item.slot==='underbarrel')visual.underbarrel=item.id;
 }
 for(const [key,[min,max]] of Object.entries(MODIFIER_RANGES))modifiers[key]=ADDITIVE.includes(key)?Math.round(Math.max(min,Math.min(max,modifiers[key]))):Math.max(min,Math.min(max,modifiers[key]));
 return {items,modifiers,behaviors,visual};
}
// Resolve one definition (real or synthetic) exactly as a one-mod loadout: the
// same defaults, additive/multiplicative split and range clamps `resolveAttachments`
// applies. Exported so the career upgrade planner and catalog audit compare the
// *applied* effect, and so a test can pin single-item agreement with
// `resolveAttachments([id])` for every shipped mod.
export function resolveAttachmentItem(item){
 const modifiers={};
 for(const key of MULTIPLICATIVE)modifiers[key]=1;
 for(const key of ADDITIVE)modifiers[key]=0;
 for(const [key,value] of Object.entries(item?.modifiers||{})){
  if(ADDITIVE.includes(key))modifiers[key]+=value;
  else if(MULTIPLICATIVE.includes(key))modifiers[key]*=value;
 }
 for(const [key,[min,max]] of Object.entries(MODIFIER_RANGES))modifiers[key]=ADDITIVE.includes(key)?Math.round(Math.max(min,Math.min(max,modifiers[key]))):Math.max(min,Math.min(max,modifiers[key]));
 const behaviors=item?.behavior?.mode?[{slot:item.slot,...item.behavior}]:[];
 return {item:item??null,modifiers,behaviors};
}
export function applyAttachmentsToWeapon(weapon,resolved){
 const w={...weapon,recoil:weapon.recoil?{...weapon.recoil,pattern:weapon.recoil.pattern?.map(step=>[...step])}:weapon.recoil,bloom:weapon.bloom?{...weapon.bloom}:weapon.bloom,feel:weapon.feel?{...weapon.feel}:weapon.feel};
 const m=resolved?.modifiers||{},behaviors=resolved?.behaviors||[];
 if(typeof w.damage==='number')w.damage*=m.damage??1;
 if(typeof w.interval==='number')w.interval*=m.interval??1;
 if(typeof w.range==='number')w.range*=m.range??1;
 if(typeof w.reload==='number')w.reload*=m.reload??1;
 if(typeof w.spread==='number')w.spread*=m.spread??1;
 else if(w.bloom&&typeof w.bloom.base==='number')w.bloom.base*=m.spread??1;
 if(w.bloom){w.bloom.perShot*=m.bloomPerShot??1;w.bloom.max*=m.bloomMax??1;}
 if(w.recoil&&typeof w.recoil.kick==='number')w.recoil.kick*=m.recoilKick??1;
 const cap=Math.round(m.cap??0);if(cap&&typeof w.cap==='number')w.cap=Number.isFinite(w.cap)?w.cap+cap:Infinity;
 if(typeof w.pellets==='number'||(m.pellets??0)!==0)w.pellets=Math.max(1,Math.round((w.pellets||1)+(m.pellets??0)));
 const burstBehavior=behaviors.find(behavior=>behavior.mode==='burst');
 w.burst=Math.max(0,Math.round(burstBehavior?.burst??(m.burst??0)));
 w.autoBurst=Boolean(burstBehavior)||w.burst>0;w.burstDelay=0;w.chargeTime=0;w.chargeDamage=1;w.pierce=0;w.explosiveRadius=0;w.explosiveDamage=0;w.homing=0;w.homingTurnRate=0;w.chain=0;w.chainRange=0;
 for(const behavior of behaviors){
  if(behavior.mode==='burst')w.burstDelay=behavior.burstDelay??.16;
  else if(behavior.mode==='charge'){w.chargeTime=behavior.chargeTime??.5;w.chargeDamage=behavior.chargeDamage??1;}
  else if(behavior.mode==='pierce')w.pierce=Math.max(0,behavior.pierce??0);
  else if(behavior.mode==='explosive'){w.explosiveRadius=behavior.explosiveRadius??0;w.explosiveDamage=behavior.explosiveDamage??0;}
  else if(behavior.mode==='homing'){w.homing=behavior.homing??0;w.homingTurnRate=behavior.turnRate??0;}
  else if(behavior.mode==='chain'){w.chain=behavior.chain??0;w.chainRange=behavior.chainRange??0;}
 }
 return w;
}
