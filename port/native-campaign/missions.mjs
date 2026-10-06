const encounter = (title, mechanic, roster, text, seconds = 0) => ({title, mechanic, roster, text, seconds});
export const MISSIONS = Object.freeze({
  'rootfall-verge': {title:'Rootfall Verge', brief:'Follow the surviving archive signal through the fallen forest relay.', encounters:[
    encounter('Clear the fallen relay', 'clear', {scrapper:3}, 'ECHO: Maintenance signature accepted. Those cutters cannot distinguish you from the quarantine.'),
    encounter('Recover the archive fragment', 'interact', {scrapper:4, skirmisher:2}, 'ECHO: Keep moving around the runners. Clear the terminal, then press Interact to copy my archive.'),
    encounter('Restore the forest repeater', 'restore', {scrapper:3, skirmisher:2}, 'ECHO: Start the repeater while you fight. Break away to dodge; the connection remembers your progress.', 6),
    encounter('Break the shield formation', 'clear', {sentinel:1, skirmisher:4}, 'ECHO: That tripod broadcasts a shield pulse. Separate its escorts before the pulse lands.'),
    encounter('Secure the canyon access key', 'interact', {sentinel:1, scrapper:3}, 'ECHO: Rush the console to cut the shield network, or clear its guards first. Then take the rescue archive to the riverworks.')], outro:'Archive recovered. The signal leads across the canyon.'},
  'siltwake-crossing': {title:'Siltwake Crossing', brief:'Restore the riverworks relays and open the canyon crossing.', encounters:[
    encounter('Take the river intake', 'clear', {skirmisher:5, sentinel:1}, 'ECHO: The bridge relays still have power. We need a clear approach.'),
    encounter('Restart the west pump', 'restore', {scrapper:3, sentinel:1}, 'ECHO: A small maintenance patrol. Start the pump and use its platform to catch your breath.', 5),
    encounter('Silence the mortar overlook', 'clear', {mortar:2, skirmisher:4}, 'ECHO: Artillery marks your last position before firing. Leave the marked circle; cover alone will not save you.'),
    encounter('Hold the bridge synchronizer', 'hold', {mortar:1, scrapper:5}, 'ECHO: Stay in the relay circle to synchronize. Step out to dodge shells; accumulated progress is retained.', 12),
    encounter('Authorize the crossing', 'interact', {mortar:2, sentinel:2, skirmisher:4}, 'ECHO: The bridge is stable. Clear its security lock and press Interact. I remember people waiting on the other side.')], outro:'Crossing restored. Climb toward the uplink works.'},
  'emberline-ascent': {title:'Emberline Ascent', brief:'Climb the basalt works and isolate the corrupted uplink.', encounters:[
    encounter('Clear the cooling terrace', 'clear', {mortar:2, skirmisher:5}, 'ECHO: The uplink repeats a quarantine order that should have expired years ago.'),
    encounter('Disable the armoured lock', 'interact', {bulwark:1, scrapper:5}, 'ECHO: The slab unit absorbs frontal fire. Use the side route and strike its back.'),
    encounter('Restore the maintenance bus', 'restore', {skirmisher:3}, 'ECHO: The repair bus is lightly guarded. Start the transfer, recover, then choose your weapons for the isolator.', 5),
    encounter('Hold the uplink isolator', 'hold', {bulwark:2, mortar:2, scrapper:4}, 'ECHO: Hold the isolation circle. Keep circling the armour and move when artillery marks the ground.', 14),
    encounter('Release the Crown service lift', 'interact', {bulwark:1, sentinel:1, skirmisher:3}, 'ECHO: Bypass the lift console to drop their guards. The command was never a weapon. Take the repair key to the Crown.')], outro:'Uplink isolated. The Crown Array can now receive the key.'},
  'crown-array': {title:'Crown Array', brief:'Reach the Crown transmitter and return the corridor to quiet.', encounters:[
    encounter('Secure the highland approach', 'clear', {bulwark:2, skirmisher:5}, 'ECHO: This is the last relay. Everything we restored leads here.'),
    encounter('Restore the crown feeder', 'restore', {sentinel:1, scrapper:3}, 'ECHO: Reconnect the feeder. A quiet pocket before the cradle; the guardian is listening.', 5),
    encounter('Hold the archive cradle', 'hold', {bulwark:2, mortar:2, skirmisher:4}, 'ECHO: Keep the archive inside the receiver circle while its checksum settles.', 15),
    encounter('Defeat the quarantine guardian', 'guardian', {warden:1, sentinel:1, scrapper:3}, 'ECHO: Dodge its marked slam, then strike while its core recovers. Break the shield escort first.'),
    encounter('Transmit the repair key', 'restore', {skirmisher:2}, 'ECHO: Only two runners remain. Start the final transmission. Let them hear us.', 5)], outro:'The repair key is received. Quarantine lifted. Along the corridor, machines lower their weapons. ECHO: Thank you. We can be quiet now.'},
});
export const MISSION_IDS = Object.freeze(Object.keys(MISSIONS));
export function missionForCampaign(id) {
  const mission = MISSIONS[id];
  if (!mission) throw new TypeError(`Unknown campaign map: ${id}`);
  return mission;
}

// Objective completion policy (F10 experiment).
// Audit finding F10: every authored objective label resolves through one shared
// rule -- `remaining()===0` -- so "restore the pump" and "clear the terrace" are
// mechanically the same task, and an authored transfer/hold can never complete
// on its own terms.
//
// The default is the CONTROL rule and must stay reachable unchanged: all
// deployed guards must die. `restore-and-withdraw` is the measured alternative
// and is opted into by exactly ONE encounter, so the experiment cannot leak
// into any other map, step or mechanic. It is a proposal, not a promotion.
export const OBJECTIVE_COMPLETION = Object.freeze({
  requireAllGuards: 'require-all-guards',
  restoreAndWithdraw: 'restore-and-withdraw',
});
export const DEFAULT_OBJECTIVE_COMPLETION = OBJECTIVE_COMPLETION.requireAllGuards;

// `siltwake-crossing` step 1, "Restart the west pump": a 5 s transfer beside a
// four-guard maintenance patrol whose own brief tells the player to use the
// pump platform to catch their breath. The encounter is already framed as a
// transfer rather than an extermination, which is what makes it the honest
// place to measure a completion rule that is not "kill everything".
const COMPLETION_EXPERIMENT = Object.freeze({
  'siltwake-crossing:1': OBJECTIVE_COMPLETION.restoreAndWithdraw,
});

// Resolve the effective policy for one encounter. An unknown request fails
// closed (TypeError, never silently downgraded); a request for the experiment
// against an encounter that did not opt in resolves to the control rule.
export function completionPolicyFor(mapId, stepIndex, requested = DEFAULT_OBJECTIVE_COMPLETION) {
  if (!Object.values(OBJECTIVE_COMPLETION).includes(requested)) throw new TypeError('Unsupported objective completion policy');
  return COMPLETION_EXPERIMENT[`${mapId}:${stepIndex}`] === requested ? requested : DEFAULT_OBJECTIVE_COMPLETION;
}
