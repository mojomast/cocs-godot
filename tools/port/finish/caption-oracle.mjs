// Frozen-source eligibility vectors for the combined caption boundary.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {cocsEventVisible, COCS_PUBLIC_EVENTS} from '../../../game/cocs-intel.mjs';
import {latticeSoundCue} from '../../../game/lattice-feedback.mjs';
const original = JSON.parse(fs.readFileSync('godot/tests/lattice/fixtures/expansion_feedback.json'));
const events = [...original.captions.map(row => row.event),
  {type:'cocs-command', action:'unknown', team:0},
  {type:'cocs-role-repair', repaired:[], actor:0},
  {type:'cocs-role-spot', targets:[], actor:0},
  {type:'cocs-buy', actor:0, team:0},
  {type:'cocs-device-use', actor:1, team:1, kind:'teleporter'}];
const vectors = events.flatMap(event => [
  {actor:0, team:0}, {actor:1, team:1}, {actor:2, team:0}, {actor:-1, team:null}
].map(({actor, team}) => {
  // The source wire admits untagged events; native spectators deliberately
  // retain the reviewed stricter public allowlist. No private context invented.
  const publicSpectator = actor >= 0 || !event.type.startsWith('cocs-') || COCS_PUBLIC_EVENTS.includes(event.type);
  const eligible = !!latticeSoundCue(event, {id:actor, team});
  return {event, actor, team, expected: publicSpectator && cocsEventVisible(event, team) && eligible};
}));
const path = 'godot/tests/finish/caption-eligibility.json';
const bytes = JSON.stringify(vectors, null, 2) + '\n';
if (process.argv.includes('--write')) { fs.mkdirSync('godot/tests/finish', {recursive:true}); fs.writeFileSync(path, bytes); }
else assert.equal(fs.readFileSync(path, 'utf8'), bytes);
console.log(`CAPTION_ELIGIBILITY_SOURCE_OK ${vectors.length} current-recipient/source-cue vectors`);
