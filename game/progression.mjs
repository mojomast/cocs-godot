import {ATTACHMENTS,ATTACHMENT_SLOTS,attachmentById,normalizeAttachments as normalizeAttachmentLoadout,resolveAttachmentItem,resolveAttachments} from './attachments.mjs';
import {WEAPON_FINISHES,CROSSHAIR_STYLES,FINISH_IDS,CROSSHAIR_IDS} from './cosmetics.mjs';
export const PROGRESSION_VERSION=1;
export const MAX_LEVEL=60;
export const GEAR_SLOTS=[{id:'primary',name:'Weapon Kit'},{id:'armor',name:'Armour'},{id:'utility',name:'Utility'}];
// §4.8 asymmetric-but-testable gear. Every item names one power axis and one
// different cost axis, spends within its slot's net budget, and resolves
// through the §4.8 envelope caps below. Points are unitless: one point is +1%
// on a multiplier (damage, speed, spread) or +1 flat point of health/armour.
//
// This is the persistent career catalogue: gear is chosen before a match and
// carries across every mode until it is changed, unlike the round-scoped
// personal REQ buys resolved by the COCS economy layer. Levels order
// acquisition across the whole 1..MAX_LEVEL career; the eight launch items are
// kept byte-identical so old profiles and presets still round-trip.
export const GEAR_AXES=Object.freeze(['offense','mobility','ehp','handling']);
export const GEAR_BUDGET=Object.freeze({primary:15,armor:25,utility:24});
export const GEAR_CAPS=Object.freeze({offense:1.15,mobility:1.1,ehp:15,spread:.85,handling:.9});
export const GEAR=[
 {id:'scope',slot:'primary',name:'Precision Scope',level:2,powerAxis:'handling',costAxis:'mobility',budget:GEAR_BUDGET.primary,description:'Tighter spread and a harder first shot for ranged duels. The glass is heavy, and the footwork pays for it.',modifiers:{spread:.85,damage:1.1,speed:.9}},
 {id:'heavy-barrel',slot:'primary',name:'Heavy Barrel',level:5,powerAxis:'offense',costAxis:'handling',budget:GEAR_BUDGET.primary,description:'The hardest-hitting barrel in the pool, at the cost of muzzle control and a little footwork. Subtlety is for other operators.',modifiers:{damage:1.15,spread:1.1,speed:.97}},
 {id:'light-frame',slot:'primary',name:'Light Frame',level:8,powerAxis:'offense',costAxis:'ehp',budget:GEAR_BUDGET.primary,description:'A fast-handling build with reduced armour. Travel light, hit hard.',modifiers:{damage:1.08,spread:.9,armor:-5}},
 {id:'plating',slot:'armor',name:'Composite Plating',level:3,powerAxis:'ehp',costAxis:'mobility',budget:GEAR_BUDGET.armor,description:'A pre-fight slab of extra spawn armour. Because the best offense is not dying.',modifiers:{armor:25,speed:.98}},
 {id:'reactive',slot:'armor',name:'Reactive Weave',level:6,powerAxis:'ehp',costAxis:'mobility',budget:GEAR_BUDGET.armor,description:'Balanced armour and health for long slogs. Designed for “just one more round.”',modifiers:{armor:15,health:10}},
 {id:'stim',slot:'utility',name:'Combat Stim',level:4,powerAxis:'ehp',costAxis:'mobility',budget:GEAR_BUDGET.utility,description:'Extra health and a sliver of speed on every spawn. Performance-enhancing, but legal here.',modifiers:{health:20,speed:1.04}},
 {id:'servo',slot:'utility',name:'Servo Assist',level:7,powerAxis:'mobility',costAxis:'handling',budget:GEAR_BUDGET.utility,description:'The fastest rig in the pool for objective sprints. The servos jitter your aim; your W key says thank you.',modifiers:{speed:1.1,spread:1.07}},
 {id:'mag',slot:'utility',name:'Stabiliser Mag',level:9,powerAxis:'handling',costAxis:'mobility',budget:GEAR_BUDGET.utility,description:'Steadies the muzzle with a tiny speed trade. Poetry, in full auto.',modifiers:{spread:.92,speed:.99}},
 // --- Career expansion: every added item declares a real power axis and
 // a different, strictly-paid cost axis, and stays under its slot budget so it
 // competes rather than replaces. Levels are spread across the 1..60 curve.
 {id:'runner-frame',slot:'primary',name:'Skeleton Frame',level:12,powerAxis:'mobility',costAxis:'offense',budget:GEAR_BUDGET.primary,description:'A stripped receiver that moves like a scout and hits like a trainer. Built for flag routes and flank rotations in capture and race modes; the reduced mass softens every round.',modifiers:{speed:1.08,damage:.95}},
 {id:'match-trigger',slot:'primary',name:'Match Trigger',level:15,powerAxis:'handling',costAxis:'offense',budget:GEAR_BUDGET.primary,description:'A tuned trigger group that groups shots at the cost of punch. Hold a lane, not a record. A holdout and long-sightline pick.',modifiers:{spread:.86,damage:.91}},
 {id:'breacher-kit',slot:'primary',name:'Breacher Kit',level:23,powerAxis:'offense',costAxis:'mobility',budget:GEAR_BUDGET.primary,description:'A short, angry primary for assault and uplink entries. The heaviest hit in the pool, but it drags your footwork and muzzle control.',modifiers:{damage:1.12,speed:.92,spread:1.03}},
 {id:'siege-kit',slot:'primary',name:'Siege Kit',level:26,powerAxis:'offense',costAxis:'handling',budget:GEAR_BUDGET.primary,description:'An overpressure receiver with the hardest single hit in the pool, at the cost of violent muzzle climb and loose groups. Plant it, then delete.',modifiers:{damage:1.13,spread:1.10}},
 {id:'marksman-kit',slot:'primary',name:'Marksman Kit',level:40,powerAxis:'handling',costAxis:'offense',budget:GEAR_BUDGET.primary,description:'A precision rig for overwatch and team elimination. Puts the first shot where you meant it and gives up raw damage to do it. Steady pays.',modifiers:{spread:.85,damage:.90}},
 {id:'command-kit',slot:'primary',name:'Command Kit',level:50,powerAxis:'offense',costAxis:'mobility',budget:GEAR_BUDGET.primary,description:'The career capstone: a command receiver that adds real punch and a tighter hold for a small rotate cost. Fits any mode that asks you to lead.',modifiers:{damage:1.08,spread:.95,speed:.95}},
 {id:'scout-plate',slot:'armor',name:'Scout Plate',level:5,powerAxis:'mobility',costAxis:'offense',budget:GEAR_BUDGET.armor,description:'A light forward plate with spawn armour and pace, paid for with a softer round. An infantry capture-route opener.',modifiers:{speed:1.06,armor:4,damage:.94}},
 {id:'gunner-harness',slot:'armor',name:'Gunner Harness',level:10,powerAxis:'handling',costAxis:'offense',budget:GEAR_BUDGET.armor,description:'A stabilised harness that tightens your hold and adds a little plating at the cost of punch. For roles that shoot more than they soak.',modifiers:{spread:.88,armor:5,damage:.91}},
 {id:'assault-plate',slot:'armor',name:'Assault Plate',level:18,powerAxis:'offense',costAxis:'mobility',budget:GEAR_BUDGET.armor,description:'Offensive plates that carry more punch and less sprint. A point-take and holdout pick: trade the rotate for the kill.',modifiers:{damage:1.1,speed:.93}},
 {id:'field-medic-rig',slot:'utility',name:'Field Medic Rig',level:8,powerAxis:'ehp',costAxis:'handling',budget:GEAR_BUDGET.utility,description:'Spawn health and a little armour for holdout and horde runs. The bulky rig opens your groups; sustain beats precision once the wave stops ending.',modifiers:{health:12,armor:3,spread:1.11}},
 {id:'overcharge-cell',slot:'utility',name:'Overcharge Cell',level:13,powerAxis:'offense',costAxis:'mobility',budget:GEAR_BUDGET.utility,description:'A hot cell that feeds every weapon a heavier shot and taxes your sprint. For last-stand defences and boss lanes.',modifiers:{damage:1.09,speed:.94}},
 {id:'route-servo',slot:'utility',name:'Route Servo',level:17,powerAxis:'mobility',costAxis:'handling',budget:GEAR_BUDGET.utility,description:'A compact servo for faster infantry objective rotations. The extra hardware jitters your aim on the way in.',modifiers:{speed:1.07,spread:1.05}},
 {id:'brace-satchel',slot:'utility',name:'Brace Satchel',level:21,powerAxis:'handling',costAxis:'offense',budget:GEAR_BUDGET.utility,description:'A braced rig that steadies follow-up shots at a small damage cost. For long duels where the third burst matters.',modifiers:{spread:.90,damage:.93}},
 {id:'targeting-uplink',slot:'utility',name:'Targeting Uplink',level:50,powerAxis:'handling',costAxis:'mobility',budget:GEAR_BUDGET.utility,description:'The career capstone: a personal targeting link that steadies every burst at a real sprint cost.',modifiers:{spread:.88,speed:.92}},
 {id:'fortress-plate',slot:'armor',name:'Fortress Plate',level:35,powerAxis:'ehp',costAxis:'handling',budget:GEAR_BUDGET.armor,description:'The heaviest spawn-EHP slab in the pool, paid for with a slower, looser hold. Win the long fight, not the first duel.',modifiers:{health:11,armor:4,spread:1.09}},
];
export const COSMETICS=[
 ...WEAPON_FINISHES.map(item=>({id:item.id,kind:'finish',name:item.name,level:item.level,description:item.description})),
 ...CROSSHAIR_STYLES.map(item=>({id:item.id,kind:'crosshair',name:item.name,level:item.level??1,description:item.description})),
];
export const UNLOCKS=[...GEAR.map(item=>({id:`gear-${item.id}`,kind:'gear',ref:item.id,name:item.name,level:item.level,description:item.description})),...ATTACHMENTS.map(item=>({id:`attachment-${item.id}`,kind:'attachment',ref:item.id,name:item.name,level:item.level,description:item.description})),...COSMETICS];
export const RANK_TITLES=[{level:1,name:'Recruit',blurb:'Fresh weights and no idea what a strafe jump is.'},{level:5,name:'Operator',blurb:'Can hold a lane without panic-firing.'},{level:10,name:'Veteran',blurb:'Knows every map by its sightlines.'},{level:20,name:'Elite',blurb:'Wins duels before you finish reloading.'},{level:35,name:'Legend',blurb:'The bots whisper your callsign to each other.'},{level:50,name:'Mythic',blurb:'The scoreboard renders your name in a special font.'}];

// ---------------------------------------------------------------------------
// Unlock authority. `UNLOCKS` is the single source of truth for what a profile
// may own and equip: every gear item, attachment, weapon finish and crosshair
// appears once with its unlock level. `isUnlocked` is the one gate the profile
// normaliser, the loadout normalisers and the server store consult, so an item
// can never be *shown* as locked while being *equipped*, or vice versa. A
// profile that stored an explicit unlock (a granted reward, a season drop, or a
// legacy profile whose xp curve moved under it) keeps that entry regardless of
// the level recomputed from xp — the `owned` argument carries those grants.
const UNLOCK_BY_ID=new Map(UNLOCKS.map(item=>[item.id,item]));
export function isUnlocked(entryId,level=1,owned=null){
 const item=UNLOCK_BY_ID.get(entryId);
 if(!item)return false;
 if(owned&&typeof owned==='object'&&owned[entryId]===true)return true;
 const l=Math.max(1,Number.isFinite(Number(level))?Math.round(Number(level)):1);
 return item.level<=l;
}

// ---------------------------------------------------------------------------
// Prestige: the long-term layer that begins once the level cap is reached.
// Every PRESTIGE_XP of overflow XP banks one prestige rank, and each rank maps
// to a named tier with a deterministic reward. Pure, so the panel, the server
// mirror and the tests all derive the same rank from the same total XP.
export const PRESTIGE_XP=6000;
export const PRESTIGE_TIERS=Object.freeze([
 {level:1,name:'Bronze',color:'#d08a4e',reward:'Bronze prestige emblem',perk:'+5% match XP'},
 {level:2,name:'Silver',color:'#c9d4dc',reward:'Silver prestige emblem',perk:'+10% match XP'},
 {level:3,name:'Gold',color:'#ffd166',reward:'Gold prestige emblem',perk:'+15% match XP'},
 {level:4,name:'Platinum',color:'#8fe0ff',reward:'Platinum prestige emblem',perk:'+20% match XP'},
 {level:5,name:'Diamond',color:'#b79bff',reward:'Diamond prestige emblem',perk:'+25% match XP'},
 {level:6,name:'Apex',color:'#ff9f6b',reward:'Apex prestige emblem',perk:'+30% match XP'},
]);
export const PRESTIGE_MAX_TIER=PRESTIGE_TIERS.length;

// ---------------------------------------------------------------------------
// Achievements: deterministic, idempotent career milestones. Each definition
// checks a derived context object, so unlocking is a pure function of the
// profile (plus campaign/challenge counts passed in by the caller). Unlocks are
// stored once and pay a flat XP bounty.
export const ACHIEVEMENTS=Object.freeze([
 {id:'first-blood',name:'First Blood',description:'Win your first match.',xp:100,check:ctx=>ctx.wins>=1},
 {id:'veteran',name:'Veteran',description:'Finish 25 matches.',xp:200,check:ctx=>ctx.matches>=25},
 {id:'gladiator',name:'Gladiator',description:'Win 10 matches.',xp:300,check:ctx=>ctx.wins>=10},
 {id:'centurion',name:'Centurion',description:'Score 100 career eliminations.',xp:250,check:ctx=>ctx.kills>=100},
 {id:'sharpshooter',name:'Sharpshooter',description:'Score 25 eliminations in a single match.',xp:250,check:ctx=>ctx.bestKills>=25},
 {id:'flawless',name:'Flawless',description:'Win a match without dying.',xp:250,check:ctx=>ctx.flawless>=1},
 {id:'streak-master',name:'Streak Master',description:'Reach a 10 killstreak.',xp:300,check:ctx=>ctx.bestStreak>=10},
 {id:'mode-explorer',name:'Mode Explorer',description:'Play 5 different modes.',xp:200,check:ctx=>ctx.modes>=5},
 {id:'collector',name:'Collector',description:'Claim 20 unlocks.',xp:200,check:ctx=>ctx.unlocked>=20},
 {id:'challenger',name:'Challenger',description:'Complete 10 daily or weekly challenges.',xp:250,check:ctx=>ctx.challenges>=10},
 {id:'campaign-clear',name:'Campaign Clear',description:'Complete every campaign mission.',xp:500,check:ctx=>ctx.campaignTotal>0&&ctx.campaignDone>=ctx.campaignTotal},
 {id:'ascendant',name:'Ascendant',description:'Reach your first prestige rank.',xp:500,check:ctx=>ctx.prestige>=1},
]);

export function xpForLevel(level){const l=Math.max(1,Math.min(MAX_LEVEL-1,Math.round(level)));return 500+(l-1)*250;}
export function totalXpForLevel(level){
 const l=Math.max(1,Math.min(MAX_LEVEL,Math.round(Number(level)||1)));
 let total=0;for(let i=1;i<l;i++)total+=xpForLevel(i);
 return total;
}
// Overflow XP past the level cap, split into prestige ranks. Deterministic and
// monotonic: every PRESTIGE_XP banks exactly one rank, capped at the last tier.
export function prestigeFromXp(xp){
 const total=Math.max(0,Math.floor(Number.isFinite(Number(xp))?Number(xp):0));
 const capXp=totalXpForLevel(MAX_LEVEL);
 const overflow=Math.max(0,total-capXp);
 const raw=Math.floor(overflow/PRESTIGE_XP);
 const rank=Math.min(PRESTIGE_MAX_TIER,raw);
 const into=raw>=PRESTIGE_MAX_TIER?PRESTIGE_XP:overflow-rank*PRESTIGE_XP;
 const tier=rank>0?PRESTIGE_TIERS[rank-1]:null;
 return {rank,overflow,into,needed:PRESTIGE_XP,progress:rank>=PRESTIGE_MAX_TIER?1:Math.min(1,into/PRESTIGE_XP),toNext:rank>=PRESTIGE_MAX_TIER?0:Math.max(0,PRESTIGE_XP-into),tier:tier?{...tier}:null,maxed:rank>=PRESTIGE_MAX_TIER};
}
export function prestigeTier(rank){
 const r=Math.max(0,Math.min(PRESTIGE_MAX_TIER,Math.round(Number(rank)||0)));
 return r>0?{...PRESTIGE_TIERS[r-1]}:null;
}
export function prestigeXpBonus(rank){
 const tier=prestigeTier(rank);
 if(!tier)return 0;
 return .05*tier.level;
}
export function levelFromXp(xp){
 let remaining=Math.max(0,Math.floor(Number.isFinite(Number(xp))?Number(xp):0)),level=1;
 while(level<MAX_LEVEL&&remaining>=xpForLevel(level)){remaining-=xpForLevel(level);level++;}
 const needed=xpForLevel(level),capped=level>=MAX_LEVEL;
 return {level,into:remaining,needed,total:Math.max(0,Math.floor(Number.isFinite(Number(xp))?Number(xp):0)),progress:capped?1:Math.min(1,remaining/needed),toNext:capped?0:Math.max(0,needed-remaining)};
}
export function rankTitle(level){let title='Recruit';for(const rank of RANK_TITLES)if(level>=rank.level)title=rank.name;return title;}
export function rankBlurb(level){let blurb=RANK_TITLES[0].blurb;for(const rank of RANK_TITLES)if(level>=rank.level)blurb=rank.blurb;return blurb;}
export function gearById(id){return GEAR.find(item=>item.id===id)||null;}
export function unlockedItems(level){const l=Math.max(1,Math.round(level));return UNLOCKS.filter(item=>item.level<=l);}
const round3=value=>Math.round(value*1000)/1000;
const clampNumber=(value,min,max)=>Math.max(min,Math.min(max,Number.isFinite(value)?value:min));
// Budget points for a modifier set, oriented so a positive value is a benefit:
// offense = +damage %, mobility = +speed %, handling = tighter spread %,
// ehp = flat health + armour points.
export function gearPoints(modifiers){
 const m=modifiers&&typeof modifiers==='object'?modifiers:{},num=value=>Number.isFinite(value)?value:1;
 return Object.freeze({
  offense:round3((num(m.damage)-1)*100),
  mobility:round3((num(m.speed)-1)*100),
  handling:round3((1-num(m.spread))*100),
  ehp:round3((Number(m.health)||0)+(Number(m.armor)||0)),
 });
}
// Splits an item's declared power and cost axes out of its modifier points and
// reports the §4.8 cost ratio (must be ≥0.6 for upgraded items). `net` is the
// item's total signed points, which the slot budget caps.
export function gearBudget(item){
 const points=gearPoints(item?.modifiers),power=round3(Math.max(0,Number(points[item?.powerAxis])||0)),cost=round3(Math.max(0,-(Number(points[item?.costAxis])||0)));
 const net=round3(Object.values(points).reduce((sum,value)=>sum+value,0));
 return Object.freeze({budget:Number(item?.budget)||0,points,power,cost,net,ratio:power>0?round3(cost/power):0});
}
// §4.8 envelope caps, applied once at the end of resolution so no caller can
// bypass them: offense/damage ≤1.15×, mobility/speed ≤1.10×, pooled EHP
// (health + armour) ≤ +15 points, spread ≥0.85× and spread ≤ 1/0.90 (the
// handling ≥0.90× floor). EHP over the cap scales both pools down
// proportionally so a full loadout cannot stack past the envelope.
function poolEhp(health,armor){
 const total=health+armor;
 if(!(total>GEAR_CAPS.ehp))return {health,armor};
 const scale=GEAR_CAPS.ehp/total;let h=round3(health*scale),a=round3(armor*scale);
 const drift=round3(h+a-GEAR_CAPS.ehp);
 if(drift>0){
  if(a>=h)a=round3(Math.max(0,a-drift));
  else h=round3(Math.max(0,h-drift));
 }
 return {health:h,armor:a};
}
export function resolveGear(ids){
 const list=(Array.isArray(ids)?ids:Object.values(ids||{})).map(gearById).filter(Boolean),modifiers={health:0,armor:0,speed:1,damage:1,spread:1};
 for(const item of list)for(const [key,value] of Object.entries(item.modifiers)){if(key==='health'||key==='armor')modifiers[key]+=value;else modifiers[key]*=value;}
 modifiers.speed=clampNumber(modifiers.speed,.5,GEAR_CAPS.mobility);
 modifiers.damage=clampNumber(modifiers.damage,.5,GEAR_CAPS.offense);
 modifiers.spread=clampNumber(modifiers.spread,GEAR_CAPS.spread,1/GEAR_CAPS.handling);
 modifiers.armor=Math.max(0,Number(modifiers.armor)||0);
 modifiers.health=Math.max(0,Number(modifiers.health)||0);
 const pooled=poolEhp(modifiers.health,modifiers.armor);
 modifiers.health=pooled.health;modifiers.armor=pooled.armor;
 return Object.freeze({items:Object.freeze(list),modifiers:Object.freeze(modifiers)});
}
// Resolve a single gear definition (real or synthetic) through the same §4.8
// envelope `resolveGear` applies to a one-item loadout: negative pools collapse
// to zero, each multiplier is clamped, then pooled EHP is trimmed. Exported so
// the upgrade planner and the catalog audit measure the *applied* vector rather
// than the declared one, and so a test can pin that they agree with
// `resolveGear([id])` for every shipped item.
export function resolveGearItem(item){
 const m=item?.modifiers||{},num=(value,fallback)=>Number.isFinite(value)?value:fallback;
 const pooled=poolEhp(Math.max(0,num(m.health,0)),Math.max(0,num(m.armor,0)));
 return Object.freeze({
  health:pooled.health,armor:pooled.armor,
  speed:clampNumber(num(m.speed,1),.5,GEAR_CAPS.mobility),
  damage:clampNumber(num(m.damage,1),.5,GEAR_CAPS.offense),
  spread:clampNumber(num(m.spread,1),GEAR_CAPS.spread,1/GEAR_CAPS.handling),
 });
}
// `owned` is the profile's unlocks map (id -> true). Passing it lets an entry
// the profile explicitly owns stay equipped even when its level sits above the
// level recomputed from xp; omitting it keeps the historical level-only gate.
export function normalizeGear(value,level=MAX_LEVEL,owned=null){
 const source=value&&typeof value==='object'?value:{},out={};
 for(const slot of GEAR_SLOTS){
  const requested=source[slot.id],item=gearById(requested);
  if(!item||item.slot!==slot.id||!isUnlocked(`gear-${item.id}`,level,owned))continue;
  out[slot.id]=item.id;
 }
 return out;
}
// Horde/campaign runs bank `score`/`bestWave` in the singleplayer snapshot,
// which the normal match result never carries. This rider pays a capped XP
// bounty for that run so a deep endless score cannot dwarf the match reward.
// Pure, bounded and monotonic in both score and best wave.
export const HORDE_XP_CAP=250;
export const HORDE_XP_SCORE_DIVISOR=25;
export const HORDE_XP_PER_WAVE=5;
export function hordeMatchXp(record=null){
 const source=record&&typeof record==='object'?record:null;
 if(!source)return 0;
 const score=Math.max(0,Math.floor(Number(source.score)||0)),bestWave=Math.max(0,Math.floor(Number(source.bestWave??source.wave)||0));
 if(!(score>0)&&!(bestWave>0))return 0;
 return Math.max(0,Math.min(HORDE_XP_CAP,Math.round(score/HORDE_XP_SCORE_DIVISOR)+bestWave*HORDE_XP_PER_WAVE));
}
export function matchXp({win=false,actor=null,bonusXp=0,singleplayer=null,horde=null,...rest}={}){
 const stats=actor?.scoreStats||{},frags=Number(actor?.frags)||0;
 const objective=(Number(stats.objectiveTime)||0)*1.5+(Number(stats.objectiveCaptures)||0)*30+(Number(stats.captures)||0)*120+(Number(stats.flagPickups)||0)*15+(Number(stats.flagReturns)||0)*10;
 const bonus=Math.max(0,Math.round(Number(bonusXp)||0));
 // The award path already hands `matchXp` the whole result object: prefer the
 // snapshot's `singleplayer` record, accept an explicit `horde` record, and
 // fall back to flat direct fields only for the single-player modes.
 const mode=typeof rest.mode==='string'?rest.mode:'';
 const rider=singleplayer??horde??(mode==='horde'||mode==='campaign'?rest:null);
 return Math.max(10,Math.round(40+frags*12+objective+(win?80:0)))+hordeMatchXp(rider)+bonus;
}
export function modeKey(mode){return typeof mode==='string'&&mode.trim()?mode.trim().slice(0,40):'unknown';}
const count=value=>Math.max(0,Math.floor(Number(value)||0));
export function normalizeByMode(value){
 const source=value&&typeof value==='object'?value:{},out={};
 for(const [mode,raw] of Object.entries(source)){
  if(typeof mode!=='string'||!mode.trim())continue;
  const entry=raw&&typeof raw==='object'?raw:{};
  out[modeKey(mode)]={matches:count(entry.matches),wins:count(entry.wins),kills:count(entry.kills),best:count(entry.best)};
 }
 return out;
}
export function normalizeAchievements(value){
 const source=value&&typeof value==='object'?value:{},out={};
 for(const item of ACHIEVEMENTS)if(source[item.id]===true)out[item.id]=true;
 return out;
}
export function defaultProgression(){return normalizeProgression({});}
export function normalizeProgression(value){
 const source=value&&typeof value==='object'?value:{},xp=Math.max(0,Math.floor(Number.isFinite(Number(source.xp))?Number(source.xp):0)),calculated=levelFromXp(xp),rawUnlocks=source.unlocks&&typeof source.unlocks==='object'?source.unlocks:{},unlocks={};
 for(const item of UNLOCKS)if(rawUnlocks[item.id]===true||item.level<=calculated.level)unlocks[item.id]=true;
 const prestige=prestigeFromXp(xp);
 return {version:PROGRESSION_VERSION,xp,level:calculated.level,matches:Math.max(0,Math.floor(Number(source.matches)||0)),wins:Math.max(0,Math.floor(Number(source.wins)||0)),kills:Math.max(0,Math.floor(Number(source.kills)||0)),flawlessWins:Math.max(0,Math.floor(Number(source.flawlessWins)||0)),bestStreak:Math.max(0,Math.floor(Number(source.bestStreak)||0)),challengesCompleted:Math.max(0,Math.floor(Number(source.challengesCompleted)||0)),byMode:normalizeByMode(source.byMode),gear:normalizeGear(source.gear,calculated.level,unlocks),attachments:normalizeAttachmentLoadout(source.attachments,calculated.level,unlocks),finish:FINISH_IDS.includes(source.finish)&&isUnlocked(source.finish,calculated.level,unlocks)?source.finish:null,crosshair:CROSSHAIR_IDS.includes(source.crosshair)&&isUnlocked(source.crosshair,calculated.level,unlocks)?source.crosshair:null,unlocks,achievements:normalizeAchievements(source.achievements),prestige:prestige.rank,prestigeTier:prestige.tier?prestige.tier.name:null};
}
// Derived context for achievement checks. Everything comes from the profile
// plus optional campaign counts supplied by the caller, so unlocking is a pure
// function of stored state and never depends on wall-clock time.
export function achievementContext(profile,extra={}){
 const p=profile&&typeof profile==='object'?profile:{},byMode=p.byMode||{};
 const bestKills=Object.values(byMode).reduce((max,stats)=>Math.max(max,count(stats?.best)),0);
 return {
  matches:count(p.matches),wins:count(p.wins),kills:count(p.kills),
  bestKills,modes:Object.keys(byMode).length,unlocked:Object.keys(p.unlocks||{}).length,
  flawless:count(p.flawlessWins),bestStreak:count(p.bestStreak),
  challenges:count(p.challengesCompleted),prestige:prestigeFromXp(p.xp).rank,
  campaignDone:count(extra.campaignDone),campaignTotal:count(extra.campaignTotal),
 };
}
export function unlockedAchievements(profile,extra={}){
 const ctx=achievementContext(profile,extra);
 return ACHIEVEMENTS.filter(item=>{try{return item.check(ctx)===true;}catch{return false;}});
}
export function achievementStatus(profile,extra={}){
 const unlocked=normalizeAchievements(profile?.achievements),ctx=achievementContext(profile,extra);
 return ACHIEVEMENTS.map(item=>({id:item.id,name:item.name,description:item.description,xp:item.xp,unlocked:unlocked[item.id]===true,eligible:item.check(ctx)===true}));
}
export function awardMatch(profile,result={}){
 const next=normalizeProgression(profile),before=next.level;
 const base=matchXp(result);
 const prestigeBonus=Math.round(base*prestigeXpBonus(prestigeFromXp(next.xp).rank));
 next.xp+=base+prestigeBonus;
 next.matches+=1;if(result.win===true)next.wins+=1;
 const kills=Math.max(0,Math.floor(Number(result.actor?.frags)||0));next.kills+=kills;
 if(result.win===true&&Math.max(0,Math.floor(Number(result.actor?.deaths)||0))===0)next.flawlessWins+=1;
 next.bestStreak=Math.max(next.bestStreak,Math.max(0,Math.floor(Number(result.bestStreak)||0)));
 next.challengesCompleted+=Math.max(0,Math.floor(Number(result.challengesCompleted)||0));
 const mode=modeKey(result.mode),byMode={...next.byMode},modeStats={matches:0,wins:0,kills:0,best:0,...(byMode[mode]||{})};
 modeStats.matches+=1;if(result.win===true)modeStats.wins+=1;modeStats.kills+=kills;modeStats.best=Math.max(modeStats.best,kills);
 byMode[mode]=modeStats;next.byMode=byMode;
 const achievements=[];
 for(const item of unlockedAchievements(next,{campaignDone:result.campaignDone,campaignTotal:result.campaignTotal})){
  if(next.achievements[item.id]!==true){next.achievements[item.id]=true;achievements.push(item);}
 }
 const achievementXp=achievements.reduce((sum,item)=>sum+item.xp,0);
 next.xp+=achievementXp;
 const level=levelFromXp(next.xp);
 next.level=level.level;next.prestige=prestigeFromXp(next.xp).rank;next.prestigeTier=prestigeFromXp(next.xp).tier?.name??null;
 const unlocked=[];
 for(const item of unlockedItems(level.level))if(!next.unlocks[item.id]){next.unlocks[item.id]=true;unlocked.push(item);}
 return {profile:next,gained:base+prestigeBonus+achievementXp,baseGained:base,prestigeBonus,achievementXp,levelUp:level.level>before,prestigeUp:prestigeFromXp(next.xp).rank>prestigeFromXp(profile?.xp).rank,unlocked,achievements,progress:level.progress,toNext:level.toNext};
}
export function nextUnlockFor(profile){
 const unlocked=(profile&&typeof profile.unlocks==='object'&&profile.unlocks)||{};
 return UNLOCKS.filter(item=>unlocked[item.id]!==true).sort((a,b)=>a.level-b.level||String(a.name).localeCompare(String(b.name)))[0]||null;
}
// Discovery list for the selection/results surfaces: the next few locked items
// in the same level order as the single next-unlock chip. Pure and bounded, so
// the career strip can show "what is close" without re-deriving unlock math.
export function nextUnlocksFor(profile,limit=3){
 const unlocked=(profile&&typeof profile.unlocks==='object'&&profile.unlocks)||{};
 const count=Math.max(0,Math.floor(Number(limit)||0));
 return UNLOCKS.filter(item=>unlocked[item.id]!==true).sort((a,b)=>a.level-b.level||String(a.name).localeCompare(String(b.name))).slice(0,count).map(item=>({id:item.id,kind:item.kind,name:item.name,level:item.level,description:item.description}));
}
// ---------------------------------------------------------------------------
// Upgrade planning. The flat level order above answers "what unlocks next";
// this layer answers "what would change, and is it an upgrade over what I have".
// Every delta is resolved through the same `resolveGear`/`resolveAttachments` the
// live match applies, so a roadmap can never advertise an effect the simulation
// will not use. A candidate's verdict compares it against the item the profile
// currently has in that slot:
//   new        the slot is empty
//   upgrade    no resolved axis regresses and at least one improves
//   sidegrade  a real change with both gains and losses (or a new behaviour)
//   downgrade  no axis improves and at least one regresses
//   duplicate  the resolved effect is identical
const UPGRADE_LOWER_IS_BETTER=new Set(['spread','interval','reload','recoilKick','bloomPerShot','bloomMax']);
const GEAR_AXES_ORDER=['damage','speed','spread','health','armor'];
const ATTACHMENT_AXES_ORDER=['damage','spread','interval','range','recoilKick','reload','bloomPerShot','bloomMax','cap','pellets','burst'];
function effectVerdict(before,after,axes,behaviorChanged=false){
 let better=false,worse=false;
 for(const axis of axes){
  const direction=UPGRADE_LOWER_IS_BETTER.has(axis)?-1:1;
  const delta=((Number(after?.[axis])||0)-(Number(before?.[axis])||0))*direction;
  if(delta>1e-9)better=true;else if(delta<-1e-9)worse=true;
 }
 if(!better&&!worse)return behaviorChanged?'sidegrade':'duplicate';
 if(behaviorChanged)return worse&&!better?'downgrade':'sidegrade';
 if(better&&!worse)return 'upgrade';
 if(worse&&!better)return 'downgrade';
 return 'sidegrade';
}
function effectChanges(before,after,axes){
 const changes=[];
 for(const axis of axes){
  const a=Number(before?.[axis])||0,b=Number(after?.[axis])||0;
  if(Math.abs(b-a)>1e-9)changes.push({axis,before:round3(a),after:round3(b)});
 }
 return changes;
}
// Full behaviour fingerprint (mode plus every parameter the weapon builder
// writes), so a burst-3 module and a burst-2 module are a real change rather
// than a mechanical downgrade of the same effect.
const BEHAVIOR_KEYS=['mode','burst','burstDelay','chargeTime','chargeDamage','pierce','explosiveRadius','explosiveDamage','homing','turnRate','chain','chainRange'];
const behaviorSignature=behavior=>{const b=behavior||{};return b.mode?BEHAVIOR_KEYS.map(key=>`${key}:${b[key]??''}`).join('|'):'';};
const resolvedBehaviorSignature=resolved=>resolved.behaviors.map(behaviorSignature).join('||');
const slotLabel=(slots,id)=>{const slot=slots.find(entry=>entry.id===id);return slot?slot.name:id;};
function gearUpgradeEntry(profile,item){
 const slot=item.slot,currentId=profile.gear?.[slot]??null,current=currentId?gearById(currentId):null;
 const before=resolveGearItem(current),after=resolveGearItem(item);
 const verdict=current?effectVerdict(before,after,GEAR_AXES_ORDER):'new';
 return {
  id:`gear-${item.id}`,kind:'gear',ref:item.id,name:item.name,level:item.level,
  slot,slotName:slotLabel(GEAR_SLOTS,slot),owned:false,gap:Math.max(0,item.level-profile.level),
  replaces:current?current.id:null,verdict,
  actionable:verdict!=='downgrade'&&verdict!=='duplicate',
  powerAxis:item.powerAxis,costAxis:item.costAxis,
  changes:effectChanges(before,after,GEAR_AXES_ORDER),
  before:Object.freeze({...before}),after:Object.freeze({...after}),
  description:item.description,
 };
}
function attachmentUpgradeEntry(profile,item){
 const slot=item.slot,currentId=profile.attachments?.[slot]??null,current=currentId?attachmentById(currentId):null;
 const before=resolveAttachmentItem(current),after=resolveAttachmentItem(item);
 const behaviorChanged=resolvedBehaviorSignature(before)!==resolvedBehaviorSignature(after);
 const verdict=current?effectVerdict(before.modifiers,after.modifiers,ATTACHMENT_AXES_ORDER,behaviorChanged):'new';
 const weapons=Array.isArray(item.weapons)?[...item.weapons]:[];
 return {
  id:`attachment-${item.id}`,kind:'attachment',ref:item.id,name:item.name,level:item.level,
  slot,slotName:slotLabel(ATTACHMENT_SLOTS,slot),owned:false,gap:Math.max(0,item.level-profile.level),
  replaces:current?current.id:null,verdict,
  actionable:verdict!=='downgrade'&&verdict!=='duplicate',
  universal:weapons.length===0,compatibleWeapons:weapons,behaviorChanged,
  changes:effectChanges(before.modifiers,after.modifiers,ATTACHMENT_AXES_ORDER),
  before:Object.freeze({...before.modifiers}),after:Object.freeze({...after.modifiers}),
  description:item.description,
 };
}
// Pure, loadout-aware career roadmap. `upcoming` is bounded per slot for a UI
// strip; `nextUpgrade`/`nextActionable` scan the whole remaining catalogue so a
// distant real upgrade is not hidden behind a nearer cosmetic or a dead upgrade.
export function unlockPlan(profile,{limit=3}={}){
 const p=normalizeProgression(profile),cap=Math.max(0,Math.floor(Number(limit)||0)),unlocks=p.unlocks||{};
 const byLevel=(a,b)=>a.level-b.level||String(a.name).localeCompare(String(b.name));
 const gearEntries=GEAR.filter(item=>unlocks[`gear-${item.id}`]!==true).sort(byLevel).map(item=>gearUpgradeEntry(p,item));
 const attachmentEntries=ATTACHMENTS.filter(item=>unlocks[`attachment-${item.id}`]!==true).sort(byLevel).map(item=>attachmentUpgradeEntry(p,item));
 const entries=[...gearEntries,...attachmentEntries];
 const firstOf=predicate=>[...entries].filter(predicate).sort(byLevel)[0]??null;
 return {
  level:p.level,
  nextUnlock:nextUnlockFor(p),
  nextUnlocks:nextUnlocksFor(p,cap),
  nextUpgrade:firstOf(entry=>entry.verdict==='new'||entry.verdict==='upgrade'),
  nextActionable:firstOf(entry=>entry.actionable),
  gear:GEAR_SLOTS.map(slot=>({slot:slot.id,slotName:slot.name,current:p.gear?.[slot.id]??null,upcoming:gearEntries.filter(entry=>entry.slot===slot.id).slice(0,cap)})),
  attachments:ATTACHMENT_SLOTS.map(slot=>({slot:slot.id,slotName:slot.name,current:p.attachments?.[slot.id]??null,upcoming:attachmentEntries.filter(entry=>entry.slot===slot.id).slice(0,cap)})),
 };
}
// ---------------------------------------------------------------------------
// Catalog integrity audit for the unlock/upgrade pool. It catches the two real
// authoring mistakes a level-ordered catalogue can make: two same-slot entries
// that resolve to the same effect (a duplicate), and a higher-level entry that
// is strictly worse on every axis than a same-slot entry that unlocks no later
// (a dead upgrade — a slot a player is told to anticipate but should never
// take). Attachment dominance also requires the earlier entry to fit a superset
// of weapons, so a universal mod is never called dominated by a weapon-locked
// one. `gear`/`attachments` are injectable so the detector itself is testable.
export function catalogAudit({gear=GEAR,attachments=ATTACHMENTS}={}){
 const issues=[];
 const within=(a,b,epsilon=1e-9)=>Math.abs(a-b)<epsilon;
 const gearVector=item=>{const r=resolveGearItem(item);return {health:r.health,armor:r.armor,speed:r.speed,damage:r.damage,handling:-r.spread};};
 const gearAxes=['health','armor','speed','damage','handling'];
 const dominates=(a,b,axes)=>axes.every(axis=>a[axis]>=b[axis]-1e-9)&&axes.some(axis=>a[axis]>b[axis]+1e-9);
 const identical=(a,b,axes)=>axes.every(axis=>within(a[axis],b[axis]));
 for(const slot of GEAR_SLOTS){
  const items=gear.filter(item=>item?.slot===slot.id);
  for(const first of items)for(const second of items){
   if(first===second)continue;
   const a=gearVector(first),b=gearVector(second);
   if(identical(a,b,gearAxes)){if(String(first.id)<String(second.id))issues.push({kind:'duplicate',family:'gear',slot:slot.id,a:first.id,b:second.id,detail:`${first.id} and ${second.id} declare the same effect axes`});continue;}
   if(first.level<=second.level&&dominates(a,b,gearAxes))issues.push({kind:'dead-upgrade',family:'gear',slot:slot.id,a:first.id,b:second.id,detail:`${first.id} (level ${first.level}) strictly dominates later ${second.id} (level ${second.level})`});
  }
 }
 const attAxes=['damage','spread','interval','range','recoilKick','reload','bloomPerShot','bloomMax','cap','pellets','burst'];
 const attVector=item=>{const m=resolveAttachmentItem(item).modifiers,out={};for(const axis of attAxes)out[axis]=UPGRADE_LOWER_IS_BETTER.has(axis)?-m[axis]:m[axis];return out;};
 const attFit=item=>{const list=Array.isArray(item?.weapons)?item.weapons:[];return list.length?new Set(list):null;};
 const fitsSuperset=(first,second)=>{const a=attFit(first),b=attFit(second);if(a===null)return true;if(b===null)return false;for(const index of b)if(!a.has(index))return false;return true;};
 for(const slot of ATTACHMENT_SLOTS.map(entry=>entry.id)){
  const items=attachments.filter(item=>item?.slot===slot);
  for(const first of items)for(const second of items){
   if(first===second)continue;
   if(behaviorSignature(first?.behavior)!==behaviorSignature(second?.behavior))continue;
   const a=attVector(first),b=attVector(second);
   if(identical(a,b,attAxes)){if(String(first.id)<String(second.id))issues.push({kind:'duplicate',family:'attachment',slot,a:first.id,b:second.id,detail:`${first.id} and ${second.id} share modifiers and behaviour`});continue;}
   if(first.level<=second.level&&fitsSuperset(first,second)&&dominates(a,b,attAxes))issues.push({kind:'dead-upgrade',family:'attachment',slot,a:first.id,b:second.id,detail:`${first.id} (level ${first.level}) strictly dominates later ${second.id} (level ${second.level})`});
  }
 }
 return {ok:issues.length===0,issues};
}
// Compact post-match summary card. Pure composition of the snapshot, the
// reward strip and the career tracks so the results screen can surface
// achievements and prestige progress without re-deriving them in JSX.
/** @param {{hud?:any,reward?:any,profile?:any,achievements?:any[],historyEntry?:any,result?:any}} [input] */
export function matchSummaryCard({hud=null,reward=null,profile=null,achievements=[],historyEntry=null,result=null}={}){
 const p=profile&&typeof profile==='object'?profile:defaultProgression();
 const level=levelFromXp(p.xp),prestige=prestigeFromXp(p.xp);
 const list=Array.isArray(achievements)?achievements:[];
 const unlocked=list.filter(a=>a?.unlocked===true);
 const actors=Array.isArray(hud?.actors)?hud.actors:[];
 const local=actors.find(a=>a&&a.id===(hud?.actorId??0))||actors[0]||result?.actor||null;
 const kills=Number(local?.frags)||Number(historyEntry?.kills)||0;
 const deaths=Number(local?.deaths)||Number(historyEntry?.deaths)||0;
 const duration=Math.round(Number(hud?.time)||Number(historyEntry?.duration)||0);
 const outcome=historyEntry?.result||result||(reward?.levelUp?'win':null);
 return {
  modeName:hud?.modeName||historyEntry?.modeName||null,
  mapName:hud?.mapName||historyEntry?.mapName||null,
  result:outcome,
  kills,deaths,
  kd:deaths>0?Math.round((kills/deaths)*100)/100:kills,
  duration,
  xp:Math.max(0,Math.floor(Number(reward?.gained)||0)),
  level:level.level,
  progress:level.progress,
  toNext:level.toNext,
  levelUp:reward?.levelUp===true,
  prestige:prestige.rank,
  prestigeTier:prestige.tier?prestige.tier.name:null,
  prestigeProgress:prestige.progress,
  prestigeToNext:prestige.toNext,
  prestigeMaxed:prestige.maxed,
  achievements:unlocked.map(a=>({id:a.id,name:a.name,description:a.description,xp:Math.max(0,Math.floor(Number(a.xp)||0))})),
  achievementCount:unlocked.length,
  nextUnlock:reward?.nextUnlock||nextUnlockFor(p),
  nextUnlocks:Array.isArray(reward?.nextUnlocks)?reward.nextUnlocks:nextUnlocksFor(p,3),
 };
}

export function matchRewardSummary(award={}){
 const profile=award&&award.profile?award.profile:defaultProgression(),level=levelFromXp(profile.xp),next=nextUnlockFor(profile),prestige=prestigeFromXp(profile.xp);
 return {
  gained:Math.max(0,Math.floor(Number(award?.gained)||0)),
  baseGained:Math.max(0,Math.floor(Number(award?.baseGained)||0)),
  prestigeBonus:Math.max(0,Math.floor(Number(award?.prestigeBonus)||0)),
  achievementXp:Math.max(0,Math.floor(Number(award?.achievementXp)||0)),
  xp:level.total,level:level.level,into:level.into,needed:level.needed,
  progress:level.progress,toNext:level.toNext,levelUp:award?.levelUp===true,
  unlocked:Array.isArray(award?.unlocked)?award.unlocked:[],
  achievements:Array.isArray(award?.achievements)?award.achievements:[],
  prestige:prestige.rank,prestigeTier:prestige.tier?{...prestige.tier}:null,prestigeProgress:prestige.progress,prestigeToNext:prestige.toNext,prestigeMaxed:prestige.maxed,
  nextUnlock:next?{id:next.id,kind:next.kind,name:next.name,level:next.level}:null,
  nextUnlocks:nextUnlocksFor(profile,3),
 };
}
