const encounter = (title, mechanic, roster, text, seconds = 0) => ({title, mechanic, roster, text, seconds});
export const MISSIONS = Object.freeze({
  'rootfall-verge': {title:'Rootfall Verge', brief:'Follow the surviving archive signal through the fallen forest relay.', encounters:[
    encounter('Clear the fallen relay', 'clear', {scrapper:5}, 'ECHO: Maintenance signature accepted. Those cutters cannot distinguish you from the quarantine.'),
    encounter('Recover the archive fragment', 'interact', {scrapper:4, skirmisher:2}, 'ECHO: Keep moving around the runners. Clear the terminal, then press Interact to copy my archive.'),
    encounter('Restore the forest repeater', 'restore', {scrapper:5, skirmisher:3}, 'ECHO: Stay close and hold Interact to reconnect the repeater. You can break off safely.', 6),
    encounter('Break the shield formation', 'clear', {sentinel:1, skirmisher:4}, 'ECHO: That tripod broadcasts a shield pulse. Separate its escorts before the pulse lands.'),
    encounter('Secure the canyon access key', 'interact', {sentinel:2, scrapper:5}, 'ECHO: The archive is a rescue request. Take the access key to the riverworks.')], outro:'Archive recovered. The signal leads across the canyon.'},
  'siltwake-crossing': {title:'Siltwake Crossing', brief:'Restore the riverworks relays and open the canyon crossing.', encounters:[
    encounter('Take the river intake', 'clear', {skirmisher:5, sentinel:1}, 'ECHO: The bridge relays still have power. We need a clear approach.'),
    encounter('Restart the west pump', 'restore', {scrapper:5, sentinel:2}, 'ECHO: Hold Interact beside the pump after clearing the guards.', 7),
    encounter('Silence the mortar overlook', 'clear', {mortar:2, skirmisher:4}, 'ECHO: Artillery marks your last position before firing. Leave the marked circle; cover alone will not save you.'),
    encounter('Hold the bridge synchronizer', 'hold', {mortar:2, scrapper:6}, 'ECHO: Stay in the relay circle to synchronize. Step out to dodge shells; accumulated progress is retained.', 12),
    encounter('Authorize the crossing', 'interact', {mortar:2, sentinel:2, skirmisher:4}, 'ECHO: The bridge is stable. Clear its security lock and press Interact. I remember people waiting on the other side.')], outro:'Crossing restored. Climb toward the uplink works.'},
  'emberline-ascent': {title:'Emberline Ascent', brief:'Climb the basalt works and isolate the corrupted uplink.', encounters:[
    encounter('Clear the cooling terrace', 'clear', {mortar:2, skirmisher:5}, 'ECHO: The uplink repeats a quarantine order that should have expired years ago.'),
    encounter('Disable the armoured lock', 'interact', {bulwark:1, scrapper:5}, 'ECHO: The slab unit absorbs frontal fire. Use the side route and strike its back.'),
    encounter('Restore the maintenance bus', 'restore', {bulwark:2, skirmisher:4}, 'ECHO: The maintenance bus carries the repair key. Hold Interact at the console once the guards are down.', 8),
    encounter('Hold the uplink isolator', 'hold', {bulwark:2, mortar:2, scrapper:4}, 'ECHO: Hold the isolation circle. Keep circling the armour and move when artillery marks the ground.', 14),
    encounter('Release the Crown service lift', 'interact', {bulwark:2, sentinel:2, skirmisher:4}, 'ECHO: The command was never a weapon. It was a plea to stop the quarantine. Take the repair key to the Crown.')], outro:'Uplink isolated. The Crown Array can now receive the key.'},
  'crown-array': {title:'Crown Array', brief:'Reach the Crown transmitter and return the corridor to quiet.', encounters:[
    encounter('Secure the highland approach', 'clear', {bulwark:2, skirmisher:5}, 'ECHO: This is the last relay. Everything we restored leads here.'),
    encounter('Restore the crown feeder', 'restore', {mortar:2, sentinel:2, scrapper:4}, 'ECHO: Reconnect the feeder. The guardian is listening.', 8),
    encounter('Hold the archive cradle', 'hold', {bulwark:2, mortar:2, skirmisher:4}, 'ECHO: Keep the archive inside the receiver circle while its checksum settles.', 15),
    encounter('Defeat the quarantine guardian', 'guardian', {warden:1, sentinel:2, scrapper:5}, 'ECHO: Checkpoint secured. The guardian marks its ground slam before impact. Keep clear and break its escort formation.'),
    encounter('Transmit the repair key', 'restore', {bulwark:2, skirmisher:4}, 'ECHO: One final security lock. Clear it, then hold Interact to transmit. Let them hear us.', 8)], outro:'The repair key is received. Quarantine lifted. Along the corridor, machines lower their weapons. ECHO: Thank you. We can be quiet now.'},
});
export const MISSION_IDS = Object.freeze(Object.keys(MISSIONS));
export function missionForCampaign(id) {
  const mission = MISSIONS[id];
  if (!mission) throw new TypeError(`Unknown campaign map: ${id}`);
  return mission;
}
