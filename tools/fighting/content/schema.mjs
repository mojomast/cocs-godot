// The emitted JSON Schema is the machine-readable accepted content shape.
// Semantic cross-field rules remain in validate.mjs. No coercion or implicit keys.
const int=(minimum,maximum)=>({type:'integer',minimum,maximum});
const text={type:'string',minLength:1};
const bool={type:'boolean'};
const choice=(...values)=>({type:'string',enum:values});
const list=(items,minItems=0,maxItems=1000)=>({type:'array',items,minItems,maxItems});
const object=(properties,optional=[])=>({type:'object',properties,required:Object.keys(properties).filter(k=>!optional.includes(k)),additionalProperties:false});
const map=items=>({type:'object',additionalProperties:items,minProperties:1});
const time=int(0,135),velocity=int(-350,350),coord=int(-3500,3500);
const box=object({from:time,to:time,x:coord,y:coord,w:int(1,3500),h:int(1,2000)});
const input=object({simple:choice('L','M','H','GRAB','BACK_GRAB','SPECIAL','MOBILITY','SPECIAL_GRAB','SUPER'),motion:text,charge_frames:int(1,60),charge_axis:choice('back','down')},['charge_frames','charge_axis']);
const projectile=object({spawn_frame:time,x:coord,y:coord,vx:int(1,350),vy:velocity,gravity:int(0,30),w:int(1,700),h:int(1,700),life:int(1,120),range:int(1000,7000),max_count:int(1,2),clash_strength:int(1,3),pierce:bool});
const movement=object({type:choice('reel','rush','glide','super_jump','slam','double_jump','hover','air_dash','blink','anchor'),from:time,to:time,vx:velocity,vy:velocity,distance:int(1,2600),duration:int(1,90),air_only:bool,ground_only:bool,cooldown:int(1,180),invulnerable_from:int(-1,135),invulnerable_to:int(-1,135),on:choice('hit'),pull_speed:int(1,350),air_uses:int(1,1),reset_on_land:bool,anchor_life:int(1,180),trigger_range:int(1,1000),max_count:int(1,1)},['on','pull_speed','air_uses','reset_on_land','anchor_life','trigger_range','max_count']);
const pairedThrow=object({range:int(500,1100),tech_frames:int(0,10),damage_frame:time,release_frame:time,victim_x:int(-1100,1100),victim_y:int(0,1800),side_swap:bool,command:bool,ground_only:bool,knockdown_frames:int(24,60)});
const counter=object({from:time,to:time,reflect:bool,strike:bool,range:int(1,1100),damage_frame:time,release_frame:time});
const resourceEffect=object({resource:text,cost:int(0,100),gain:int(0,100),on:choice('start','hit'),reset_on_land:bool});
const armor=object({from:time,to:time,hits:int(1,2),damage_percent:int(1,100)});
const stance=object({resource:text,set:int(0,100),duration:int(1,180),variants:map(text)});
const cancel=object({to:text,from:time,until:time,on:list(choice('hit','block','whiff'),1,3)});
const move=object({name:text,kind:choice('strike','projectile','mobility','throw','counter','super'),startup:int(1,45),active:int(1,30),recovery:int(1,60),damage:int(0,1000),hitstun:int(0,1000),blockstun:int(0,1000),hitstop:int(0,1000),level:choice('mid','low','overhead','unblockable'),animation:text,effect:text,hitboxes:list(box,0,16),cancels:list(cancel,0,16),meter_cost:int(0,1000),meter_gain:int(0,1000),chip:int(0,1000),pushback:int(0,1000),launch_velocity:int(0,1000),juggle_cost:int(0,1000),air_ok:bool,ground_ok:bool,input,description:text,counterplay:text,projectile,movement,throw:pairedThrow,counter,resource_effect:resourceEffect,armor,stance,knockdown_frames:int(1,60)},['projectile','movement','throw','counter','resource_effect','armor','stance','knockdown_frames']);
const sample=object({tick:int(0,600),axis_x:int(-1,1),axis_y:int(-1,1),held:int(0,511),pressed:int(0,511),duration:int(1,600),move:text},['duration','move']);
const combo=object({name:text,route:list(text,3,12),setup_inputs:list(sample,0,16),inputs:list(sample,3,12),status:choice('proposed','core_verified'),preconditions:object({distance:int(0,16000),attacker_y:int(0,5000),defender_y:int(0,5000),corner:bool,meter:int(0,1000),charge_back_ticks:int(0,60)}),notes:text});
const operator=object({id:text,name:text,archetype:text,stats:object({hp:int(900,1100),walk_speed:int(40,62),weight:int(85,120),jump_velocity:int(150,255),height:int(1800,1800)}),resource:object({id:text,min:int(0,0),max:int(1,100),initial:int(0,100),regen_ground_per_tick:int(0,1),regen_interval:int(0,180),reset_on_round:bool}),moves:map(move),combos:list(combo,3,3)});
const rect=object({x:coord,y:coord,w:int(1,2000),h:int(1,2000)});
const limits=object({max_hits:int(1,16),juggle_budget:int(1,12),wall_bounces:int(0,1),ground_bounces:int(0,1),otg_hits:int(0,1),damage_scaling_percent:list(int(1,100),1,16),damage_floor_percent:int(1,30),hitstun_deterioration_per_hit:int(1,5),min_hitstun:int(1,60)});
const rules=object({version:int(1,1),tick_rate:int(60,60),units_per_meter:int(1000,1000),round_seconds:int(1,999),rounds_to_win:int(1,5),stage_half_width:int(1000,16000),seed:int(1,2147483647),buffer_frames:int(6,6),throw_tech_frames:int(10,10),meter_max:int(1000,1000),gravity:int(1,30),terminal_velocity:int(1,350),jump_startup:int(1,30),landing_recovery:int(1,30),spawn_distance:int(1,16000),round_intro_frames:int(1,600),round_over_frames:int(1,600),guard_release_frames:int(0,30),air_guard:bool,socd:choice('neutral_both_axes'),negative_edge:bool,wakeup_invulnerability_frames:int(0,60),throw_invulnerability_frames:int(0,60),combo_limits:limits,hurtboxes:object({stand:rect,crouch:rect,air:rect}),pushbox:rect,input_help:object({notation:text,simple:text,guard:text})});
const nullable=definition=>({anyOf:[definition,{type:'null'}]});
const window=list(time,2,2);
const combatClip=object({clip:text,frames:int(1,135),contact_windows:list(window,0,16),projectile_spawn:nullable(time),movement_window:nullable(window),counter_window:nullable(window),authored_motion:text,effect:text});
const pair=object({attacker:text,move:text,clip:text,contact:time,damage:time,release:time,victim_x:int(-1100,1100),victim_y:int(0,1800),side_swap:bool,socket_attacker:text,socket_victim:text,contact_tolerance_mm:int(1,100)});
const manifest=object({version:int(1,1),status:text,fps:int(60,60),root_policy:text,operators:list(object({id:text,glb:text,motion_brief:text,states:list(text,1,100),combat:list(combatClip,15,30),victim_clips:list(text,1,100)}),9,9),paired_timelines:list(pair,1,100)});
export const schema={$schema:'https://json-schema.org/draft/2020-12/schema',title:'Operator Clash content schema v1',$defs:{roster:object({version:int(1,1),operators:list(operator,9,9)}),rules,move,projectile,movement,throw:pairedThrow,counter,resource_effect:resourceEffect,input,sample,manifest}};

// Deliberately small interpreter for the exact emitted keywords above. Integers
// must also be JS-safe/finite, matching the bounded native-int authoring contract.
export function validateShape(value,definition,path='content',errors=[]){
 const fail=message=>errors.push(`${path}: ${message}`);
 if(definition.anyOf){if(!definition.anyOf.some(option=>validateShape(value,option,path,[]).length===0))fail('value does not match any accepted shape');return errors;}
 const type=definition.type;
 const valid=type==='null'?value===null:type==='integer'?Number.isSafeInteger(value):type==='object'?value!==null&&typeof value==='object'&&!Array.isArray(value):type==='array'?Array.isArray(value):typeof value===type;
 if(!valid){fail(`expected ${type}`);return errors;}
 if(definition.enum&&!definition.enum.includes(value))fail(`unknown enum ${String(value)}`);
 if(type==='integer'&&(value<definition.minimum||value>definition.maximum))fail(`integer ${definition.minimum}..${definition.maximum}`);
 if(type==='string'&&value.length<(definition.minLength??0))fail('nonempty string required');
 if(type==='array'){
  if(value.length<definition.minItems||value.length>definition.maxItems)fail(`array size ${definition.minItems}..${definition.maxItems}`);
  value.forEach((item,i)=>validateShape(item,definition.items,`${path}[${i}]`,errors));
 }
 if(type==='object'){
  for(const key of definition.required??[])if(!Object.hasOwn(value,key))fail(`missing ${key}`);
  if(Object.keys(value).length<(definition.minProperties??0))fail('nonempty map required');
  for(const [key,item]of Object.entries(value)){
   const child=definition.properties?.[key]??definition.additionalProperties;
   if(!child){errors.push(`${path}.${key}: unknown key`);continue;}
   validateShape(item,child,`${path}.${key}`,errors);
  }
 }
 return errors;
}
