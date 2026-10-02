// Read-only native evidence condensation. Does not step/reimplement combat.
import { readFileSync,writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root=fileURLToPath(new URL('../../../',import.meta.url));
const path=process.argv[2];if(!path)throw new Error('Supply native-03 actual_content-detail.json');
const bytes=readFileSync(path),report=JSON.parse(bytes);
const baseline=JSON.parse(execFileSync('git',['show','a84f6961:godot/fighting/data/roster.json'],{cwd:root,encoding:'utf8'}));
const candidates=JSON.parse(readFileSync(root+'godot/fighting/data/roster.json','utf8'));
const results=report.results.map(row=>{
 const old=baseline.operators.find(op=>op.id===row.operator).combos.find(c=>c.name===row.name);
 const proposed=candidates.operators.find(op=>op.id===row.operator).combos.find(c=>c.name===row.name);
 const actor=row.facing===1?0:1,defender=1-actor;
 const starts=row.trace.flatMap(frame=>frame.events.filter(e=>e.type==='move_start'&&e.actor===actor).map(e=>({move:e.move_id,tick:frame.tick})));
 const sample=row.trace.find(frame=>frame.tick===old.inputs[2].tick);
 const a=sample.fighters[actor],b=sample.fighters[defender];
 let cause='native_pass_unchanged',correction='Preserve this candidate exactly.';
 if(!row.passed){
  if(row.name==='Air corner chain'){cause='third_input_after_landing';correction=['chatgpt','gemini','kimi','qwen'].includes(row.operator)?'Retain original harder projectile finisher and physical fixture. Delay third input four ticks to cover landing recovery; Astra landing-timer repair is explicitly required before native certification.':'Grounded legal corner setup, paired ordinary jumps at tick0, three air normals beginning tick8; core landing-left latch separately reported.';}
  else if(['meta','qwen'].includes(row.operator)){cause='crouch_motion_recognized_as_mobility';correction='Keep down held continuously through crouch L/M. Basic becomes two-hit confirm; signature keeps its third special.';}
  else if(row.operator==='mistral'){cause='third_crouch_motion_recognized_as_mobility';correction='Retain observed L/M contacts as a two-hit basic confirm; retain existing passing three-hit special and air candidates.';}
  else if(row.name==='Signature special confirm'){cause='projectile_contact_after_stun_reset';correction='Grok grenade remains third hit in a documented grounded-corner pressure candidate; avoid midscreen late projectile travel/apex contact.';}
  else{cause='third_normal_whiffs_after_pushback';correction='Use the two observed continuous L/M contacts as a basic confirm; keep signature/air routes as three attacks.';}
 }
 const heavy=baseline.operators.find(op=>op.id===row.operator).moves[old.route[2]];
 const active=row.trace.find(frame=>frame.fighters[actor].move_id===old.route[2]&&frame.fighters[actor].move_frame>=heavy.startup&&frame.fighters[actor].move_frame<heavy.startup+heavy.active);
 const witness=frame=>({tick:frame.tick,attacker:{x:frame.fighters[actor].x,y:frame.fighters[actor].y,move:frame.fighters[actor].move_id,frame:frame.fighters[actor].move_frame,landing_left:frame.fighters[actor].landing_left,hitboxes:frame.fighters[actor].boxes.hit},defender:{x:frame.fighters[defender].x,y:frame.fighters[defender].y,stun:frame.fighters[defender].stun,hurtbox:frame.fighters[defender].boxes.hurt}});
 return {operator:row.operator,name:row.name,facing:row.facing,original_passed:row.passed,replay_equal:row.replay_equal,cause,contacts:row.contacts,move_starts:starts,third_input_witness:witness(sample),third_active_witness:active?witness(active):null,correction,new_route:proposed.route,new_preconditions:proposed.preconditions,unchanged_candidate:JSON.stringify(old)===JSON.stringify(proposed),actual_rerun:'pending'};
});
const summary={version:1,evidence_file:path,evidence_sha256:createHash('sha256').update(bytes).digest('hex'),tested_core_commit:'a84f6961',tested_source_repair:'065d78a5',tested_roster_sha256:'a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748',cases:results.length,original_passed:results.filter(r=>r.original_passed).length,original_failed:results.filter(r=>!r.original_passed).length,replays_equal:results.filter(r=>r.replay_equal).length,cause_counts:Object.fromEntries([...new Set(results.map(r=>r.cause))].map(cause=>[cause,results.filter(r=>r.cause===cause).length])),results};
if(summary.cases!==54||summary.original_failed!==38||summary.replays_equal!==54)throw new Error('Unexpected evidence inventory');
if(results.some(row=>row.original_passed&&!row.unchanged_candidate))throw new Error('A native passing candidate changed');
writeFileSync(root+'port/fighting/content/NATIVE_03_DIAGNOSIS.json',JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify({cases:summary.cases,failed:summary.original_failed,passed_preserved:summary.original_passed,replay_equal:summary.replays_equal,cause_counts:summary.cause_counts}));
