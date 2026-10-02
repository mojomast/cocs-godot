import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { CHARACTERS, HARNESSES } from '../../../game/data.mjs';
import { schema, validateShape } from './schema.mjs';
import { expandTrace } from './trace.mjs';
const root=fileURLToPath(new URL('../../../',import.meta.url));
export const readJSON=path=>JSON.parse(readFileSync(root+path,'utf8'));
export const commonMoves=['stand_l','stand_m','stand_h','crouch_l','crouch_m','crouch_h','air_l','air_m','air_h','throw_f','throw_b','special1','special2','special3','super'];
const kinds=['strike','projectile','mobility','throw','counter','super'];
const movementKinds=['reel','rush','glide','super_jump','slam','double_jump','hover','air_dash','blink','anchor'];
export function fingerprint(move){
 const presentation=new Set(['name','description','counterplay','animation','effect']);
 const canonical=value=>Array.isArray(value)?value.map(canonical):value!==null&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])])):value;
 return JSON.stringify(canonical(Object.fromEntries(Object.entries(move).filter(([key])=>!presentation.has(key)))));
}
export function validate(roster,rules){
 const errors=[...validateShape(roster,schema.$defs.roster,'roster'),...validateShape(rules,schema.$defs.rules,'rules')];
 if(errors.length)return errors; // Malformed dictionaries must produce diagnostics, never throw.
 const check=(yes,message)=>{if(!yes)errors.push(message);};
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
 const targets=readJSON('tools/fighting/content/balance_targets.json');
 check(JSON.stringify(Object.keys(targets.operators).sort())===JSON.stringify([...ids].sort()),'balance target IDs differ from runtime roster');
 for(const op of roster.operators){
  const prefix=op.id;check(typeof op.name==='string'&&op.name.length>0,`${prefix} name`);
  integer(op.stats.hp,900,1100,`${prefix} hp`);integer(op.stats.walk_speed,40,62,`${prefix} walk`);integer(op.stats.weight,85,120,`${prefix} weight`);integer(op.stats.jump_velocity,150,255,`${prefix} jump`);
  const target=targets.operators[prefix];
  check(!!target&&['hp','walk_speed','weight'].every(key=>op.stats[key]===target[key]),`${prefix} exact initial balance targets`);
  const resource=op.resource;
  integer(resource.min,0,0,`${prefix} resource min`);integer(resource.max,1,100,`${prefix} resource max`);integer(resource.initial,resource.min,resource.max,`${prefix} resource initial`);
  check(resource.reset_on_round===true,`${prefix} resource round reset`);
  for(const key of commonMoves)check(!!op.moves[key],`${prefix} missing ${key}`);
  check(Object.keys(op.moves).length>=15,`${prefix} requires 15 moves`);
  for(const [key,m] of Object.entries(op.moves)){
   const label=`${prefix}.${key}`,total=m.startup+m.active+m.recovery;
   check(commonMoves.includes(key)||prefix==='gemini'&&['palm_l','palm_m','palm_h'].includes(key),`${label} unknown move key`);
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
   check(Object.hasOwn(m.input,'charge_frames')===Object.hasOwn(m.input,'charge_axis'),`${label} charge requires frames and axis together`);
   check(m.air_ok||m.ground_ok,`${label} cannot disable both air/ground use`);
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
   if(m.movement){const p=m.movement;check(!(p.air_only&&p.ground_only),`${label} contradictory movement air/ground restrictions`);check(!p.air_only||m.air_ok,`${label} airborne movement requires air_ok`);check(!p.ground_only||m.ground_ok,`${label} grounded movement requires ground_ok`);if(p.invulnerable_from===-1||p.invulnerable_to===-1)check(p.invulnerable_from===-1&&p.invulnerable_to===-1,`${label} invulnerability disabled pair`);else{integer(p.invulnerable_from,0,total-1,`${label} invulnerability from`);integer(p.invulnerable_to,p.invulnerable_from,total-1,`${label} invulnerability to`);}if(p.type==='reel')check(p.on==='hit'&&Number.isSafeInteger(p.pull_speed),`${label} reel requires contact pull`);if(['reel','anchor'].includes(p.type))check(Number.isSafeInteger(p.pull_speed),`${label} missing pull_speed`);if(Object.hasOwn(p,'pull_speed'))check(['reel','anchor'].includes(p.type),`${label} pull_speed only belongs to pull movement`);for(const field of ['anchor_life','trigger_range','max_count'])if(Object.hasOwn(p,field))check(p.type==='anchor',`${label} ${field} only belongs to anchor`);if(Object.hasOwn(p,'on'))check(p.type==='reel',`${label} on only belongs to reel`);for(const field of ['air_uses','reset_on_land'])if(Object.hasOwn(p,field))check(['air_dash','double_jump'].includes(p.type),`${label} ${field} only belongs to air movement`);}
   if(m.throw){const p=m.throw;integer(p.range,500,1100,`${label} throw range`);integer(p.tech_frames,0,10,`${label} tech`);check(p.tech_frames===(p.command?0:10),`${label} correct throw tech`);integer(p.damage_frame,m.startup+p.tech_frames,total-1,`${label} throw damage time`);integer(p.release_frame,p.damage_frame,total-1,`${label} release time`);integer(p.knockdown_frames,24,60,`${label} knockdown`);}
   if(m.counter){const p=m.counter;integer(p.from,m.startup,m.startup+m.active-1,`${label} counter from`);integer(p.to,p.from,m.startup+m.active-1,`${label} counter to`);integer(p.damage_frame,p.to,total-1,`${label} counter damage`);integer(p.release_frame,p.damage_frame,total-1,`${label} counter release`);check(p.reflect===true,`${label} genuine reflect`);}
   if(m.throw)check(!m.throw.ground_only||m.ground_ok,`${label} ground-only throw requires ground_ok`);
   if(m.counter)check(m.counter.reflect||m.counter.strike,`${label} counter must respond to a contact category`);
   if(m.armor){integer(m.armor.from,0,total-1,`${label} armor from`);integer(m.armor.to,m.armor.from,total-1,`${label} armor to`);integer(m.armor.hits,1,2,`${label} armor hits`);integer(m.armor.damage_percent,1,100,`${label} armor damage`);}
   if(m.resource_effect){const p=m.resource_effect;check(p.resource===resource.id,`${label} resource reference`);integer(p.cost,0,resource.max,`${label} resource cost`);integer(p.gain,0,resource.max,`${label} resource gain`);check(['start','hit'].includes(p.on),`${label} resource trigger`);}
   if(m.movement&&['air_dash','double_jump'].includes(m.movement.type)){check(m.movement.air_uses===1&&m.movement.reset_on_land===true,`${label} bounded air uses`);}
   if(m.stance){check(m.stance.resource===resource.id,`${label} stance resource`);integer(m.stance.set,resource.min,resource.max,`${label} stance bound`);integer(m.stance.duration,1,180,`${label} stance duration`);for(const [base,variant] of Object.entries(m.stance.variants))check(!!op.moves[base]&&!!op.moves[variant],`${label} stance variant mapping`);}
   const fp=fingerprint(m);check(!allFingerprints.has(fp),`${label} duplicate copied gameplay fingerprint`);allFingerprints.add(fp);
  }
  // Reject any cancel cycle, including self-chains. Finite windows alone cannot stop a cycle.
  const active=new Set(),done=new Set();function visit(key){if(active.has(key)){check(false,`${prefix} cyclic cancels`);return;}if(done.has(key))return;active.add(key);for(const c of op.moves[key].cancels)if(op.moves[c.to])visit(c.to);active.delete(key);done.add(key);}Object.keys(op.moves).forEach(visit);
  check(op.combos.length===3,`${prefix} three combo traces`);
  if(commonMoves.some(key=>!op.moves[key]))continue;
  for(const combo of op.combos){check(combo.status==='proposed'||combo.status==='core_verified',`${prefix} honest combo status`);check(combo.inputs.length===combo.route.length&&combo.route.length>=2,`${prefix} full combo trace`);check(combo.name==='Basic confirm'||combo.route.length>=3,`${prefix} signature/air routes retain three attacks`);combo.inputs.forEach((sample,i)=>{integer(sample.tick,0,600,`${prefix} combo tick`);check(sample.move===combo.route[i]&&!!op.moves[sample.move],`${prefix} combo move resolves`);integer(sample.held,1,511,`${prefix} combo held`);integer(sample.pressed,1,511,`${prefix} combo pressed`);if(i)check(sample.tick>combo.inputs[i-1].tick,`${prefix} ordered trace`);});
   try{expandTrace(combo);}catch(error){check(false,`${prefix} ${combo.name}: ${error.message}`);}
   if(combo.defender_setup_inputs){try{expandTrace(combo,1,'defender');}catch(error){check(false,`${prefix} defender setup: ${error.message}`);}for(const sample of combo.defender_setup_inputs)check(sample.tick+(sample.duration??1)<=combo.inputs[0].tick&&sample.held===0&&(sample.axis_y===0||combo.setup_kind==='paired_jump'&&sample.axis_y===1),`${prefix} defender setup uses ordinary grounded movement only before first attack`);}
   if(combo.setup_kind==='paired_jump'){check(combo.preconditions.attacker_y===0&&combo.preconditions.defender_y===0&&combo.preconditions.corner&&combo.inputs[0].tick===8,`${prefix} paired jump starts grounded corner with ascent attack at tick8`);const expected=[{tick:0,axis_x:0,axis_y:1,held:0,pressed:0}];check(JSON.stringify(combo.setup_inputs)===JSON.stringify(expected)&&JSON.stringify(combo.defender_setup_inputs)===JSON.stringify(expected),`${prefix} paired jump uses identical ordinary up edges, no state injection`);check(combo.route.every(key=>key.startsWith('air_')),`${prefix} paired jump retains air normals`);}
   const pre=combo.preconditions;
   if(pre.attacker_y===0&&pre.defender_y===0)check(pre.distance>=rules.pushbox.w,`${prefix} ground fixture distance below legal pushbox width ${rules.pushbox.w}`);
   const firstMove=op.moves[combo.route[0]],defenderHurt=pre.defender_y===0?rules.hurtboxes.stand:rules.hurtboxes.air;
   if(firstMove?.hitboxes.length)check(firstMove.hitboxes.some(box=>box.x+box.w>pre.distance+defenderHurt.x&&box.x<pre.distance+defenderHurt.x+defenderHurt.w),`${prefix} first-contact horizontal reach candidate misses fixture hurtbox`);
   if(combo.route.includes('special1')&&op.moves.special1.input.charge_frames){const charge=combo.setup_inputs.find(s=>s.axis_x===-1);check(charge?.duration>=op.moves.special1.input.charge_frames,`${prefix} real charge setup`);try{const attack=expandTrace(combo),defend=expandTrace(combo,1,'defender');for(let tick=0;tick<combo.inputs[0].tick;tick++){const a=attack[tick],b=defend[tick]??{axis_x:0,axis_y:0,held:0,pressed:0};check(b.axis_x===a.axis_x&&b.axis_y===0&&b.held===0,`${prefix} charge defender must follow through ordinary same-direction inputs tick ${tick}`);}}catch(error){check(false,`${prefix} defender setup: ${error.message}`);}}
   for(let i=1;i<combo.route.length;i++){const a=op.moves[combo.route[i-1]],b=op.moves[combo.route[i]];if(!a||!b)continue;const edge=a.cancels.find(c=>c.to===combo.route[i]&&c.on.includes('hit'));check(!!edge,`${prefix} proposed combo requires hit cancel`);if(edge){const elapsed=combo.inputs[i].tick-combo.inputs[i-1].tick-a.hitstop;check(elapsed>=edge.from&&elapsed<=edge.until,`${prefix} estimated cancel window`);check(elapsed-a.startup+b.startup<=a.hitstun-rules.combo_limits.hitstun_deterioration_per_hit*(i-1),`${prefix} estimated hitstun gap`);}}
  }
 }
 return errors;
}
export function validateManifest(roster,manifest){
 const errors=validateShape(manifest,schema.$defs.manifest,'manifest');
 if(errors.length)return errors;
 const check=(yes,message)=>{if(!yes)errors.push(message);};
 const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
 const sameSet=(a,b)=>a.length===new Set(a).size&&same([...a].sort(),[...b].sort());
 const states=readJSON('tools/fighting/content/state_keys.json').states;
 check(sameSet(manifest.operators.map(r=>r.id),roster.operators.map(op=>op.id)),'manifest exact operator coverage');
 const expectedPairs=roster.operators.flatMap(op=>Object.entries(op.moves).filter(([,m])=>m.throw||m.counter).map(([key,m])=>({op,key,m,clip:`victim_${op.id}_${key}`})));
 check(sameSet(manifest.paired_timelines.map(p=>p.clip),expectedPairs.map(p=>p.clip)),'manifest exact paired timeline coverage');
 for(const op of roster.operators){
  const row=manifest.operators.find(r=>r.id===op.id);
  if(!row){check(false,`${op.id} missing animation manifest`);continue;}
  check(row.glb===`res://fighting/assets/operators/${op.id}.glb`,`${op.id} unique GLB path`);
  check(sameSet(row.states,states),`${op.id} exact known state clip keys`);
  check(sameSet(row.combat.map(c=>c.clip),Object.keys(op.moves)),`${op.id} exact combat clip coverage`);
  check(sameSet(row.victim_clips,expectedPairs.map(p=>p.clip)),`${op.id} exact victim clip coverage`);
  for(const [key,m]of Object.entries(op.moves)){
   const clip=row.combat.find(c=>c.clip===m.animation),label=`${op.id}.${key}`;
   if(!clip){check(false,`${label} clip duration/coverage`);continue;}
   check(clip.frames===m.startup+m.active+m.recovery,`${label} clip duration/coverage`);
   check(same(clip.contact_windows,m.hitboxes.map(b=>[b.from,b.to])),`${label} contact_windows match data`);
   check(clip.projectile_spawn===(m.projectile?.spawn_frame??null),`${label} projectile_spawn matches data`);
   check(same(clip.movement_window,m.movement?[m.movement.from,m.movement.to]:null),`${label} movement_window matches data`);
   check(same(clip.counter_window,m.counter?[m.counter.from,m.counter.to]:null),`${label} counter_window matches data`);
   check(clip.effect===m.effect,`${label} effect matches data`);
  }
 }
 for(const {op,key,m,clip}of expectedPairs){
  const pair=manifest.paired_timelines.find(p=>p.clip===clip);
  if(!pair)continue;
  const total=m.startup+m.active+m.recovery;
  check(pair.attacker===op.id&&pair.move===key,`${clip} attacker/move mapping`);
  check(pair.contact===m.startup&&pair.damage===(m.throw?.damage_frame??m.counter.damage_frame)&&pair.release===(m.throw?.release_frame??m.counter.release_frame),`${clip} paired timing matches move`);
  check(pair.contact<=pair.damage&&pair.damage<=pair.release&&pair.release<total,`${clip} contact/damage/release chronology`);
  check(pair.victim_x===(m.throw?.victim_x??600)&&pair.victim_y===(m.throw?.victim_y??0)&&pair.side_swap===(m.throw?.side_swap??false),`${clip} victim placement matches move`);
  check(pair.socket_attacker==='Socket_GripR'&&pair.socket_victim==='Socket_Chest',`${clip} paired socket contract`);
 }
 return errors;
}
export function verifyFreeze(freeze){return Object.entries(freeze.source_files).filter(([path,expected])=>createHash('sha256').update(readFileSync(root+path)).digest('hex')!==expected).map(([path])=>`freeze changed: ${path}`);}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const roster=readJSON('godot/fighting/data/roster.json'),rules=readJSON('godot/fighting/data/rules.json');
 const errors=[...validate(roster,rules),...validateManifest(roster,readJSON('port/fighting/content/ANIMATION_COVERAGE.json')),...verifyFreeze(readJSON('port/fighting/content/FREEZE.json'))];
 if(errors.length){console.error(errors.join('\n'));process.exitCode=1;}else console.log(JSON.stringify({status:'source_valid',operators:roster.operators.length,moves:roster.operators.reduce((n,o)=>n+Object.keys(o.moves).length,0),proposed_combos:27,source_harnesses:HARNESSES.length,runtime_combo_proof:false,native_art_proof:false}));
}
