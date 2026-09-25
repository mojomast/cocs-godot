// Career unlock/upgrade authority and roadmap. These tests pin the single
// unlock gate (`isUnlocked`), the ownership-aware loadout normalisers, the
// applied-effect upgrade planner, and the resolved-vector catalog audit. They
// are the behaviour gate for the hydration lane; the older progression /
// gear-dominance / attachment suites remain the declared-vector gate.
import test from 'node:test';
import assert from 'node:assert/strict';
import {ATTACHMENTS,ATTACHMENT_SLOTS,normalizeAttachments,resolveAttachmentItem,resolveAttachments} from './attachments.mjs';
import {
 GEAR,
 GEAR_SLOTS,
 MAX_LEVEL,
 catalogAudit,
 defaultProgression,
 isUnlocked,
 nextUnlockFor,
 nextUnlocksFor,
 normalizeGear,
 normalizeProgression,
 resolveGear,
 resolveGearItem,
 totalXpForLevel,
 unlockPlan,
} from './progression.mjs';

const EPS=1e-9;
const close=(actual,expected)=>assert.ok(Math.abs(actual-expected)<EPS,`${actual} !== ${expected}`);

test('isUnlocked is the single authority for every catalogue family',()=>{
 assert.equal(isUnlocked('gear-scope',1),false);
 assert.equal(isUnlocked('gear-scope',2),true);
 assert.equal(isUnlocked('gear-scope',1,{'gear-scope':true}),true);
 assert.equal(isUnlocked('attachment-marksman-optic',27),false);
 assert.equal(isUnlocked('attachment-marksman-optic',28),true);
 assert.equal(isUnlocked('attachment-marksman-optic',1,{'attachment-marksman-optic':true}),true);
 assert.equal(isUnlocked('finish-crimson',21),false);
 assert.equal(isUnlocked('finish-crimson',22),true);
 assert.equal(isUnlocked('split',15),false);
 assert.equal(isUnlocked('split',16),true);
 assert.equal(isUnlocked('cross',1),true);
 assert.equal(isUnlocked('not-real',MAX_LEVEL),false);
 assert.equal(isUnlocked(null,MAX_LEVEL),false);
 assert.equal(isUnlocked('gear-scope',NaN),false,'a non-finite level never unlocks');
});

test('normalizeGear honours explicit ownership above the recomputed level',()=>{
 assert.deepEqual(normalizeGear({primary:'command-kit'},49),{});
 assert.deepEqual(normalizeGear({primary:'command-kit'},49,{'gear-command-kit':true}),{primary:'command-kit'});
 assert.deepEqual(normalizeGear({primary:'command-kit'},50),{primary:'command-kit'});
 // Ownership never bypasses the slot check.
 assert.deepEqual(normalizeGear({armor:'command-kit'},60,{'gear-command-kit':true}),{});
 const value={primary:'command-kit'},normalized=normalizeGear(value,1,{'gear-command-kit':true});
 normalized.primary='mutated';
 assert.equal(value.primary,'command-kit','the input is not mutated');
});

test('normalizeAttachments honours explicit ownership above the recomputed level',()=>{
 assert.deepEqual(normalizeAttachments({optic:'marksman-optic'},27),{});
 assert.deepEqual(normalizeAttachments({optic:'marksman-optic'},27,{'attachment-marksman-optic':true}),{optic:'marksman-optic'});
 assert.deepEqual(normalizeAttachments({optic:'marksman-optic'},28),{optic:'marksman-optic'});
 assert.deepEqual(normalizeAttachments({optic:'marksman-optic'},1,{'attachment-nope':true}),{});
 assert.deepEqual(normalizeAttachments({optic:'not-real'},60,{'attachment-not-real':true}),{});
});

test('normalizeProgression keeps granted gear and gates cosmetics by unlock level',()=>{
 const granted=normalizeProgression({xp:0,unlocks:{'gear-command-kit':true,'attachment-marksman-optic':true,'finish-crimson':true,'split':true},gear:{primary:'command-kit'},attachments:{optic:'marksman-optic'},finish:'finish-crimson',crosshair:'split'});
 assert.equal(granted.level,1);
 assert.deepEqual(granted.gear,{primary:'command-kit'});
 assert.deepEqual(granted.attachments,{optic:'marksman-optic'});
 assert.equal(granted.finish,'finish-crimson');
 assert.equal(granted.crosshair,'split');
 // The same snapshot without the explicit grants is level-gated on every field.
 const locked=normalizeProgression({xp:0,gear:{primary:'command-kit'},attachments:{optic:'marksman-optic'},finish:'finish-crimson',crosshair:'split'});
 assert.deepEqual(locked.gear,{});
 assert.deepEqual(locked.attachments,{});
 assert.equal(locked.finish,null);
 assert.equal(locked.crosshair,null);
 // Reaching the cosmetic level unlocks it without a separate grant.
 const reached=normalizeProgression({xp:totalXpForLevel(22),finish:'finish-crimson',crosshair:'split'});
 assert.equal(reached.finish,'finish-crimson');
 assert.equal(reached.crosshair,'split');
 // A granted loadout round-trips byte-for-byte through persistence.
 const round=normalizeProgression(JSON.parse(JSON.stringify(granted)));
 assert.deepEqual(round.gear,granted.gear);
 assert.deepEqual(round.attachments,granted.attachments);
 assert.equal(round.finish,granted.finish);
 assert.equal(round.crosshair,granted.crosshair);
 assert.deepEqual(round,normalizeProgression(JSON.parse(JSON.stringify(round))),'normalisation is idempotent');
});

test('single-item resolvers agree with the batch resolvers for every shipped item',()=>{
 for(const item of GEAR){
  const solo=resolveGearItem(item),batch=resolveGear([item.id]).modifiers;
  for(const axis of ['health','armor','speed','damage','spread'])close(solo[axis],batch[axis]);
  assert.ok(Object.isFrozen(solo));
 }
 for(const item of ATTACHMENTS){
  const solo=resolveAttachmentItem(item).modifiers,batch=resolveAttachments([item.id]).modifiers;
  for(const axis of Object.keys(batch))close(solo[axis],batch[axis]);
  assert.equal(resolveAttachmentItem(item).behaviors.length,resolveAttachments([item.id]).behaviors.length);
 }
 // A synthetic definition resolves with the same defaults and clamps.
 const synthetic=resolveAttachmentItem({slot:'optic',modifiers:{spread:999,cap:-5}}).modifiers;
 assert.equal(synthetic.spread,2);
 assert.equal(synthetic.cap,0);
});

test('unlockPlan reports per-slot applied deltas and skips a dead capstone',()=>{
 const fresh=unlockPlan(defaultProgression(),{limit:2});
 assert.equal(fresh.level,1);
 assert.deepEqual(fresh.gear.map(entry=>entry.slot),GEAR_SLOTS.map(slot=>slot.id));
 assert.deepEqual(fresh.attachments.map(entry=>entry.slot),ATTACHMENT_SLOTS.map(slot=>slot.id));
 for(const entry of [...fresh.gear,...fresh.attachments]){
  assert.equal(entry.current,null,'a fresh profile has an empty slot');
  assert.equal(entry.upcoming.length,2);
  for(const candidate of entry.upcoming){
   assert.equal(candidate.owned,false);
   assert.equal(candidate.slot,entry.slot);
   assert.equal(candidate.gap,candidate.level-1);
   assert.equal(candidate.actionable,candidate.verdict!=='downgrade'&&candidate.verdict!=='duplicate');
   for(const change of candidate.changes)assert.ok(change.before!==change.after);
  }
 }
 // The flat unlock chip is unchanged and still consistent with the plan.
 assert.deepEqual(fresh.nextUnlock,nextUnlockFor(defaultProgression()));
 assert.deepEqual(fresh.nextUnlocks,nextUnlocksFor(defaultProgression(),2));
 assert.ok(fresh.nextUpgrade&&fresh.nextUpgrade.verdict!=='downgrade');
 // With the level-8 light frame fitted, the level-50 command kit is a pure
 // downgrade once resolveGear clamps its negative armour. The roadmap must skip
 // it while the ordinary unlock chip still announces it.
 const fitted=normalizeProgression({xp:totalXpForLevel(20),gear:{primary:'light-frame'}});
 const plan=unlockPlan(fitted,{limit:GEAR.length});
 const primary=plan.gear.find(entry=>entry.slot==='primary');
 assert.equal(primary.current,'light-frame');
 const command=primary.upcoming.find(entry=>entry.ref==='command-kit');
 assert.ok(command,'the capstone is still a future unlock');
 assert.equal(command.verdict,'downgrade');
 assert.equal(command.actionable,false);
 assert.deepEqual(command.changes.map(change=>change.axis).sort(),['speed','spread']);
 assert.deepEqual(command.before,{health:0,armor:0,speed:1,damage:1.08,spread:.9});
 assert.deepEqual(command.after,{health:0,armor:0,speed:.95,damage:1.08,spread:.95});
 assert.notEqual(plan.nextUpgrade.ref,'command-kit');
 assert.notEqual(plan.nextActionable.ref,'command-kit');
 assert.equal(nextUnlockFor(fitted).id,'gear-brace-satchel','the ordinary chip still lists the next locked item');
});

test('catalogAudit pins the shipped catalogue and detects duplicate/dead upgrades',()=>{
 const audit=catalogAudit();
 assert.equal(audit.ok,false,'the resolved catalogue has one known dead capstone');
 assert.equal(audit.issues.length,1);
 const [issue]=audit.issues;
 assert.equal(issue.kind,'dead-upgrade');
 assert.equal(issue.family,'gear');
 assert.equal(issue.a,'light-frame');
 assert.equal(issue.b,'command-kit');
 assert.equal(issue.slot,'primary');
 // Synthetic fixtures prove the detector rather than only the current data.
 const gear=[
  {id:'alpha',slot:'primary',level:1,modifiers:{damage:1.1}},
  {id:'beta',slot:'primary',level:1,modifiers:{damage:1.1}},
  {id:'gamma',slot:'primary',level:4,modifiers:{damage:1.05}},
 ];
 const synthetic=catalogAudit({gear,attachments:[]});
 assert.deepEqual(synthetic.issues.map(entry=>`${entry.kind}:${entry.a}->${entry.b}`),['duplicate:alpha->beta','dead-upgrade:alpha->gamma','dead-upgrade:beta->gamma']);
 // A weapon-locked mod never dominates a universal one, and a behaviour
 // parameter change is a real change rather than a duplicate.
 const attachments=[
  {id:'wide',slot:'optic',level:2,weapons:[],modifiers:{spread:.95},behavior:{}},
  {id:'locked',slot:'optic',level:1,weapons:[0],modifiers:{spread:.9},behavior:{}},
  {id:'burst3',slot:'underbarrel',level:1,weapons:[],modifiers:{},behavior:{mode:'burst',burst:3}},
  {id:'burst2',slot:'underbarrel',level:2,weapons:[],modifiers:{},behavior:{mode:'burst',burst:2}},
 ];
 assert.deepEqual(catalogAudit({gear:[],attachments}).issues,[]);
});
