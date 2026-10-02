import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { CHARACTERS, HARNESSES } from '../../../game/data.mjs';
const root=fileURLToPath(new URL('../../../',import.meta.url));
export const readJSON=path=>JSON.parse(readFileSync(root+path,'utf8'));
export const commonMoves=['stand_l','stand_m','stand_h','crouch_l','crouch_m','crouch_h','air_l','air_m','air_h','throw_f','throw_b','special1','special2','special3','super'];
const kinds=['strike','projectile','mobility','throw','counter','super'];
const movementKinds=['reel','rush','glide','super_jump','slam','double_jump','hover','air_dash','blink','anchor'];
export function fingerprint(move){
 return JSON.stringify([move.kind,move.startup,move.active,move.recovery,move.damage,move.hitstun,move.blockstun,move.hitboxes,move.projectile,move.movement,move.throw,move.counter,move.armor,move.stance]);
}
export function validate(roster,rules){
 const errors=[];const check=(yes,message)=>{if(!yes)errors.push(message);};
 const integer=(n,min,max,label)=>check(Number.isSafeInteger(n)&&n>=min&&n<=max,`${label}: integer ${min}..${max}`);
 check(roster.version===1&&rules.version===1,'version must be 1');
 const ids=roster.operators.map(op=>op.id);
 check(new Set(ids).size===ids.length,'duplicate operator');
 check(JSON.stringify([...ids].sort())===JSON.stringify(CHARACTERS.map(c=>c.id).sort()),'roster differs from imported source CHARACTERS');
 check(ids.length===9&&HARNESSES.length===7,'nine operators and seven source harnesses');
 for(const key of ['tick_rate','units_per_meter','round_seconds','rounds_to_win','stage_half_width','seed','buffer_frames','throw_tech_frames','meter_max'])integer(rules[key],1,2147483647,`rules.${key}`);
 check(rules.tick_rate===60&&rules.units_per_meter===1000&&rules.meter_max===1000,'60Hz/mm/1000 meter contract');
 check(rules.buffer_frames===6&&rules.throw_tech_frames===10,'buffer/tech contract');
 const limits=rules.combo_limits;
 integer(limits.max_hits,1,16,'max_hits');integer(limits.juggle_budget,1,12,'juggle_budget');
 integer(limits.hitstun_deterioration_per_hit,1,5,'deterioration');integer(limits.damage_floor_percent,1,30,'scaling floor');
 check(limits.damage_scaling_percent.length>=limits.max_hits,'scaling curve covers combo cap');
 limits.damage_scaling_percent.forEach((n,i)=>{integer(n,limits.damage_floor_percent,100,'scaling');if(i)check(n<=limits.damage_scaling_percent[i-1],'scaling cannot increase');});
 for(const key of ['wall_bounces','ground_bounces','otg_hits'])integer(limits[key],0,1,key);
 const allFingerprints=new Set();
 const design=readFileSync(root+'port/fighting/DESIGN.md','utf8');
 for(const op of roster.operators){
  const prefix=op.id;check(typeof op.name==='string'&&op.name.length>0,`${prefix} name`);
  integer(op.stats.hp,900,1100,`${prefix} hp`);integer(op.stats.walk_speed,40,62,`${prefix} walk`);integer(op.stats.weight,85,120,`${prefix} weight`);integer(op.stats.jump_velocity,150,255,`${prefix} jump`);
  const target=design.match(new RegExp(`\\| ${prefix} \\| (\\d+) \\| (\\d+) \\| (\\d+) \\|`));
  check(!!target&&[op.stats.hp,op.stats.walk_speed,op.stats.weight].every((n,i)=>n===Number(target[i+1])),`${prefix} exact DESIGN stat targets`);
  const resource=op.resource;
  integer(resource.min,0,0,`${prefix} resource min`);integer(resource.max,1,100,`${prefix} resource max`);integer(resource.initial,resource.min,resource.max,`${prefix} resource initial`);
  check(resource.reset_on_round===true,`${prefix} resource round reset`);
  for(const key of commonMoves)check(!!op.moves[key],`${prefix} missing ${key}`);
  check(Object.keys(op.moves).length>=15,`${prefix} requires 15 moves`);
  for(const [key,m] of Object.entries(op.moves)){
   const label=`${prefix}.${key}`,total=m.startup+m.active+m.recovery;
   check(typeof m.name==='string'&&m.name.length>3,`${label} original name`);
   for(const field of ['description','counterplay'])check(typeof m[field]==='string'&&m[field].length>=20,`${label} player-facing ${field}`);
   check(kinds.includes(m.kind),`${label} unknown kind`);
   integer(m.startup,1,45,`${label} startup`);integer(m.active,1,30,`${label} active`);integer(m.recovery,1,60,`${label} recovery`);
   for(const field of ['damage','hitstun','blockstun','hitstop','meter_cost','meter_gain','pushback','launch_velocity','juggle_cost','chip'])integer(m[field],0,field==='meter_cost'?1000:1000,`${label} ${field}`);
   check(m.meter_cost===(key==='super'?1000:0),`${label} super cost`);
   if(commonMoves.indexOf(key)<9&&commonMoves.includes(key))integer(m.damage,45,130,`${label} normal damage`);
   if(key.startsWith('throw_'))integer(m.damage,120,180,`${label} throw damage`);
   if(key==='super')integer(m.damage,220,300,`${label} super damage`);
   check(['mid','low','overhead','unblockable'].includes(m.level),`${label} level`);
   check(m.animation===key,`${label} animation common key`);check(m.effect===`${prefix}:${key}`,`${label} qualified effect`);
   check(m.input&&['L','M','H','GRAB','BACK_GRAB','SPECIAL','MOBILITY','SPECIAL_GRAB','SUPER'].includes(m.input.simple),`${label} input reachability`);
   if(m.input?.charge_frames)integer(m.input.charge_frames,1,60,`${label} charge`);
   check(Array.isArray(m.hitboxes)&&Array.isArray(m.cancels),`${label} boxes/cancels arrays`);
   for(const b of m.hitboxes){integer(b.from,m.startup,m.startup+m.active-1,`${label} box from`);integer(b.to,b.from,m.startup+m.active-1,`${label} box to`);integer(b.x,-2000,4000,`${label} box x`);integer(b.y,-1800,3000,`${label} box y`);integer(b.w,1,3500,`${label} box width`);integer(b.h,1,2000,`${label} box height`);check(b.x+b.w<=3500,`${label} bounded melee reach`);}
   if(['strike','super','throw'].includes(m.kind))check(m.hitboxes.length>0,`${label} damaging contact missing`);
   for(const c of m.cancels){check(!!op.moves[c.to],`${label} cancel target ${c.to}`);integer(c.from,m.startup,total-1,`${label} cancel from`);integer(c.until,c.from,total-1,`${label} cancel until`);check(c.on.length>0&&c.on.every(n=>['hit','block','whiff'].includes(n)),`${label} cancel conditions`);}
   if(m.kind==='projectile')check(!!m.projectile,`${label} missing projectile mechanics`);
   if(m.kind==='mobility')check(!!m.movement,`${label} missing mobility mechanics`);
   if(m.kind==='throw')check(!!m.throw,`${label} missing throw mechanics`);
   if(m.kind==='counter')check(!!m.counter,`${label} missing counter mechanics`);
   if(m.projectile){const p=m.projectile;integer(p.spawn_frame,m.startup,m.startup+m.active-1,`${label} spawn`);integer(p.range,1000,7000,`${label} projectile range`);integer(p.life,1,120,`${label} projectile life`);integer(p.max_count,1,2,`${label} projectile count`);integer(p.vx,1,350,`${label} projectile speed`);integer(p.w,1,700,`${label} projectile width`);integer(p.h,1,700,`${label} projectile height`);integer(p.clash_strength,1,3,`${label} clash`);}
   if(m.movement){const p=m.movement;check(movementKinds.includes(p.type),`${label} unknown movement`);integer(p.from,0,total-1,`${label} movement from`);integer(p.to,p.from,total-1,`${label} movement to`);integer(p.distance,1,2600,`${label} movement distance`);integer(p.duration,1,90,`${label} duration`);integer(p.cooldown,1,180,`${label} cooldown`);if(p.type==='anchor'){integer(p.anchor_life,1,180,`${label} anchor lifetime`);integer(p.max_count,1,1,`${label} anchor count`);integer(p.trigger_range,1,1000,`${label} anchor range`);}}
   if(m.throw){const p=m.throw;integer(p.range,500,1100,`${label} throw range`);integer(p.tech_frames,0,10,`${label} tech`);check(p.tech_frames===(p.command?0:10),`${label} correct throw tech`);integer(p.damage_frame,m.startup+p.tech_frames,total-1,`${label} throw damage time`);integer(p.release_frame,p.damage_frame,total-1,`${label} release time`);integer(p.knockdown_frames,24,60,`${label} knockdown`);}
   if(m.counter){const p=m.counter;integer(p.from,m.startup,m.startup+m.active-1,`${label} counter from`);integer(p.to,p.from,m.startup+m.active-1,`${label} counter to`);integer(p.damage_frame,p.to,total-1,`${label} counter damage`);integer(p.release_frame,p.damage_frame,total-1,`${label} counter release`);check(p.reflect===true,`${label} genuine reflect`);}
   if(m.armor){integer(m.armor.from,0,total-1,`${label} armor from`);integer(m.armor.to,m.armor.from,total-1,`${label} armor to`);integer(m.armor.hits,1,2,`${label} armor hits`);integer(m.armor.damage_percent,1,100,`${label} armor damage`);}
   if(m.resource_effect){const p=m.resource_effect;check(p.resource===resource.id,`${label} resource reference`);integer(p.cost,0,resource.max,`${label} resource cost`);integer(p.gain,0,resource.max,`${label} resource gain`);check(['start','hit'].includes(p.on),`${label} resource trigger`);}
   if(m.movement&&['air_dash','double_jump'].includes(m.movement.type)){check(m.movement.air_uses===1&&m.movement.reset_on_land===true,`${label} bounded air uses`);}
   if(m.stance){check(m.stance.resource===resource.id,`${label} stance resource`);integer(m.stance.set,resource.min,resource.max,`${label} stance bound`);integer(m.stance.duration,1,180,`${label} stance duration`);for(const [base,variant] of Object.entries(m.stance.variants))check(!!op.moves[base]&&!!op.moves[variant],`${label} stance variant mapping`);}
   const fp=fingerprint(m);check(!allFingerprints.has(fp),`${label} duplicate copied gameplay fingerprint`);allFingerprints.add(fp);
  }
  // Reject any cancel cycle, including self-chains. Finite windows alone cannot stop a cycle.
  const active=new Set(),done=new Set();function visit(key){if(active.has(key)){check(false,`${prefix} cyclic cancels`);return;}if(done.has(key))return;active.add(key);for(const c of op.moves[key].cancels)if(op.moves[c.to])visit(c.to);active.delete(key);done.add(key);}Object.keys(op.moves).forEach(visit);
  check(op.combos.length===3,`${prefix} three combo traces`);
  for(const combo of op.combos){check(combo.status==='proposed'||combo.status==='core_verified',`${prefix} honest combo status`);check(combo.inputs.length===combo.route.length&&combo.route.length>=3,`${prefix} full combo trace`);combo.inputs.forEach((sample,i)=>{integer(sample.tick,0,600,`${prefix} combo tick`);check(sample.move===combo.route[i]&&!!op.moves[sample.move],`${prefix} combo move resolves`);integer(sample.held,1,511,`${prefix} combo held`);integer(sample.pressed,1,511,`${prefix} combo pressed`);if(i)check(sample.tick>combo.inputs[i-1].tick,`${prefix} ordered trace`);});
   if(combo.route.includes('special1')&&op.moves.special1.input.charge_frames){const charge=combo.setup_inputs.find(s=>s.axis_x===-1);check(charge?.duration>=op.moves.special1.input.charge_frames,`${prefix} real charge setup`);}
   for(let i=1;i<combo.route.length;i++){const a=op.moves[combo.route[i-1]],b=op.moves[combo.route[i]];if(!a||!b)continue;const edge=a.cancels.find(c=>c.to===combo.route[i]&&c.on.includes('hit'));check(!!edge,`${prefix} proposed combo requires hit cancel`);if(edge){const elapsed=combo.inputs[i].tick-combo.inputs[i-1].tick-a.hitstop;check(elapsed>=edge.from&&elapsed<=edge.until,`${prefix} estimated cancel window`);check(elapsed-a.startup+b.startup<=a.hitstun-rules.combo_limits.hitstun_deterioration_per_hit*(i-1),`${prefix} estimated hitstun gap`);}}
  }
 }
 return errors;
}
export function validateManifest(roster,manifest){
 const errors=[];for(const op of roster.operators){const row=manifest.operators.find(r=>r.id===op.id);if(!row){errors.push(`${op.id} missing animation manifest`);continue;}for(const [key,m] of Object.entries(op.moves)){const clip=row.combat.find(c=>c.clip===m.animation);if(!clip||clip.frames!==m.startup+m.active+m.recovery)errors.push(`${op.id}.${key} clip duration/coverage`);}for(const p of manifest.paired_timelines)if(!row.victim_clips.includes(p.clip))errors.push(`${op.id} missing victim ${p.clip}`);}return errors;
}
export function verifyFreeze(freeze){return Object.entries(freeze.source_files).filter(([path,expected])=>createHash('sha256').update(readFileSync(root+path)).digest('hex')!==expected).map(([path])=>`freeze changed: ${path}`);}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const roster=readJSON('godot/fighting/data/roster.json'),rules=readJSON('godot/fighting/data/rules.json');
 const errors=[...validate(roster,rules),...validateManifest(roster,readJSON('port/fighting/content/ANIMATION_COVERAGE.json')),...verifyFreeze(readJSON('port/fighting/content/FREEZE.json'))];
 if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log(JSON.stringify({status:'source_valid',operators:roster.operators.length,moves:roster.operators.reduce((n,o)=>n+Object.keys(o.moves).length,0),proposed_combos:27,source_harnesses:HARNESSES.length,runtime_combo_proof:false,native_art_proof:false}));
}
