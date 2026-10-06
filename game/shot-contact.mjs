// Explicit shot contact classification (audit F08).
//
// The source `shot` event states what the round actually contacted: a shot
// whose muzzle ray is blocked before the camera candidate emits
// `blocked:true, contact:'blocked'`; a clear shot emits
// `contact:'actor'|'vehicle'|'sentry'|'world'` plus `blocked:!clear`. The
// `hit` field still names the camera candidate on a blocked shot, which is the
// audit counterexample (cover between muzzle and target reads as an actor hit
// with zero damage), so presentation reads these fields instead.
//
// `shotActorContact` returns `true` for an actor/vehicle/sentry contact, `false`
// for a world or blocked surface contact, and `null` when the producer made no
// claim at all (older cores, recorded captures, flak shrapnel). Callers keep
// their own existing `hit` fallback for that `null` case, so an unlabelled
// event is classified exactly as it was before this field existed.
export function shotActorContact(event){
 if(!event)return null;
 if(event.blocked===true)return false;
 const contact=event.contact;
 if(typeof contact!=='string'||!contact)return null;
 return contact==='actor'||contact==='vehicle'||contact==='sentry';
}