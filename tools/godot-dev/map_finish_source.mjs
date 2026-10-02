// Source-only adapter: reuse catalog identity and the shared material validator.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {worldEntry, readWorld} from '../../port/multiplayer-worlds/catalog.mjs';
import {validate, glbMaterialNames} from '../../port/map-finish/shared/validate.mjs';

const [id, art] = process.argv.slice(2);
assert.ok(id && art, 'map_finish_source.mjs MAP ART.glb');
const registration = worldEntry(id); // A profile alone never grants a route.
const world = readWorld(id);
const profile = JSON.parse(readFileSync(`godot/multiplayer_worlds/dressing/profiles/${id}.json`, 'utf8'));
assert.equal(profile.geometry_hash, world.geometryHash, 'bound production identity');
const result = validate(profile, {materialNames: glbMaterialNames(art)});
assert.deepEqual(result.errors, [], 'real resource/material coverage');
const output = {status: 'passed', evidence_kind: 'source-only', map: id,
  geometry_hash: world.geometryHash, registered_modes: registration.modes, ...result};
if (process.env.EVIDENCE_DIR) writeFileSync(join(process.env.EVIDENCE_DIR, 'map-source.json'), JSON.stringify(output, null, 2));
console.log(JSON.stringify(output));
