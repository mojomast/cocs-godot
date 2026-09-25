/** Privileged direct-source Match rules experiment. Not ordinary-seat evidence. */
import {writeFileSync,mkdirSync,readFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {Match} from '../../../game/core.mjs';
import {cocsSnapshot,cocsOutcome} from '../../../game/cocs.mjs';
import {cocsRungPlan,cocsRoleAllowed} from '../../../game/config.mjs';

const root=resolve(fileURLToPath(new URL('../../../',import.meta.url)));
const lock=JSON.parse(readFileSync(join(root,'port/contracts/source-lock.json')));
const DT=1/60, maps=['asterion-relay','monsoon-foundry'], rungs=['4v4','8v8'];
const seeded=seed=>()=>{seed|=0;seed=(seed+0x6D2B79F5)|0;let t=Math.imul(seed^(seed>>>15),1|seed);t=(t+Math.imul(t^(t>>>7),61|t))^t;return ((t^(t>>>14))>>>0)/4294967296;};
const step=(m,n)=>{for(let i=0;i<n&&!m.over;i++)m.step(DT,{inputs:{}});};
const make=(map,rung,extra={})=>new Match('l5-human','l5-opponent',seeded(5105),map,{mode:'cocs',rung,humanCount:8,botCount:0,timeLimit:900,cocsPolicy:()=>[],...extra});
const nodes=s=>s.nodes.filter(n=>!['hq','array'].includes(n.archetype));
const captureSetup=(state,count,team=0)=>nodes(state).forEach((n,i)=>{n.owner=i<count?team:null;});
function record(map,rung,name,fn){const item={map,rung,case:name,evidence_class:'direct-sim',observed:null,failures:[]};try{item.observed=fn();item.passed=true;}catch(e){item.failures.push(String(e?.stack||e));item.passed=false;}return item;}
const cases=[];
for(const map of maps)for(const rung of rungs){
 cases.push(record(map,rung,'dominance-ratchet-reset',()=>{
  const m=make(map,rung),s=m.objectiveState;captureSetup(s,3);step(m,30);const three=cocsSnapshot(m).dominance;
  if(three.counts[0]!==3||three.team!==0||three.progress<=0||three.breakCount!==1)throw Error(`3/5 failed: ${JSON.stringify(three)}`);
  captureSetup(s,4);step(m,1);const four=cocsSnapshot(m).dominance;
  if(four.counts[0]!==4||!four.fast||four.breakCount!==2)throw Error(`4/5 failed: ${JSON.stringify(four)}`);
  // Below bare majority (2/5) is a reset; a 3/2 contest is not a flip.
  nodes(s).forEach((n,i)=>n.owner=i<2?0:i<4?1:null);step(m,1);const loss=cocsSnapshot(m).dominance;
  if(loss.team!==null||loss.progress!==0||loss.counts[0]!==2||loss.counts[1]!==2)throw Error(`below-majority reset failed: ${JSON.stringify(loss)}`);
  captureSetup(s,3,0);nodes(s).slice(3).forEach(n=>n.owner=1);step(m,1);const contest=cocsSnapshot(m).dominance;
  if(contest.team!==0||contest.counts[0]!==3||contest.counts[1]!==2)throw Error(`contest flipped/lost: ${JSON.stringify(contest)}`);
  return {three,four,loss,contest,source_methods:['Match.step','cocsSnapshot','dominance update in game/cocs.mjs']};
 }));
 cases.push(record(map,rung,'role-floor-bot-fill',()=>{
  const allow=['fighter','harvester','builder'].every(x=>cocsRoleAllowed(rung,x))&&((rung==='4v4')===!cocsRoleAllowed(rung,'saboteur'));
  const floor=[7,8].map(h=>({humans:h,plan:cocsRungPlan(rung,h)}));
  if(!allow||floor[0].plan.meetsMinimum!==false||floor[1].plan.meetsMinimum!==true||floor[1].plan.botFill!==(rung==='4v4'?0:8))throw Error(JSON.stringify({allow,floor}));
  return {roleAllowlist:allow,roleAllow:['fighter','harvester','builder',...(rung==='8v8'?['scout','saboteur']:[])],floor,api:'cocsRoleAllowed/cocsRungPlan (config source APIs; Match constructor uses rung)'};
 }));
 cases.push(record(map,rung,'deadline-tiebreak',()=>{
  const m=make(map,rung);const s=m.objectiveState;
  // Privileged score/time setup, explicitly direct-sim; resolution remains source cocsOutcome.
  s.scores[0]=12;s.scores[1]=12;m.config.timeLimit=1;m.time=1;const result=cocsOutcome(m);
  if(result.reason!=='time'||result.winner!==null)throw Error(JSON.stringify({result,time:m.time,over:m.over}));
  return {scores:{...s.scores},time:m.time,over:m.over,result,api:'cocsOutcome (source deadline resolver); privileged Match time setup'};
 }));
}
const gaps=[
 {case:'adjacency-versus-supply capture',status:'UNAVAILABLE',why:'Owner assignment is privileged direct mutation, not capture. Match.step accepts player inputs and cocs action queues, but no exported privileged capture action exists; natural capture requires actor position/combat and authored capture interactions.',refs:['game/cocs.mjs:capturableBy','game/cocs.mjs:stepCocs','game/core.mjs:Match.step']},
 {case:'remote order / idle no-decay',status:'UNAVAILABLE',why:'The public cocs order queue is command/task policy, not a direct source control for node ownership or decay; idle/no-decay requires ordinary strategic behavior/clock coverage outside this short controlled experiment.',refs:['game/cocs.mjs:cocsCommandAction','game/cocs.mjs:stepCocs']},
];
const out=join(root,'port/native-lattice/evidence/flagship',`direct-match-${Date.now()}-${process.pid}`);mkdirSync(out,{recursive:true});
writeFileSync(join(out,'results.json'),JSON.stringify({schema_version:2,evidence_class:'direct-sim',source_commit:lock.source_commit,experiment:'seeded privileged source Match short-step matrix',cases,gaps},null,2));
const failed=cases.filter(c=>!c.passed);console.log(`${out}: ${failed.length?'FAIL':'PASS'} (${cases.length} assertions; ${gaps.length} explicit gaps)`);if(failed.length)process.exitCode=1;
