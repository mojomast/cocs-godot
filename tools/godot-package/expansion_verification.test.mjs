import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {coverage} from './verify_expansion.mjs';
import {WORLDS} from '../../port/multiplayer-worlds/catalog.mjs';

const files=Object.keys(WORLDS).map(id=>`godot/multiplayer_worlds/generated/${id}.json`);
const manifest={server_closure:{worldDataFiles:files,hordeDataFiles:['godot/horde_maps/generated/blackwater-reclamation.json']}};
test('the extracted manifest and packaged options require seven worlds and all 43 pairs',()=>{
  const pairs=coverage(manifest,WORLDS);
  assert.equal(pairs.length,43);
  for(const mode of ['puma-race','puma-soccer','cocs','cocs-coop','combined-arms','payload'])assert.ok(pairs.some(row=>row.mode===mode));
});
test('missing manifest family or packaged catalog option fails instead of silently skipping expansion',()=>{
  assert.throws(()=>coverage({server_closure:{hordeDataFiles:manifest.server_closure.hordeDataFiles}},WORLDS),/worldDataFiles/);
  assert.throws(()=>coverage({server_closure:{...manifest.server_closure,worldDataFiles:files.slice(1)}},WORLDS));
  assert.throws(()=>coverage({server_closure:{...manifest.server_closure,hordeDataFiles:[]}},WORLDS),/Blackwater/);
  assert.throws(()=>coverage(manifest,Object.fromEntries(Object.entries(WORLDS).slice(1))));
});
test('external probe loads production scenes/PCK resources and never substitutes product authority',()=>{
  const probe=readFileSync(new URL('../../godot/tests/package_expansion.gd',import.meta.url),'utf8');
  for(const scene of ['multiplayer_worlds/demo.tscn','multiplayer_worlds/sports_demo.tscn','multiplayer_worlds/lattice_demo.tscn','horde_maps/blackwater_demo.tscn'])assert.ok(probe.includes(scene));
  assert.match(probe,/client\.snapshot\.connect/);
  assert.match(probe,/start_hash != expected_hash/);
  assert.match(probe,/ResourceLoader\.exists\(art\)/);
  const verifier=readFileSync(new URL('./verify_expansion.mjs',import.meta.url),'utf8');
  assert.match(verifier,/runtime\/port\/multiplayer-worlds\/catalog\.mjs/);
  assert.match(verifier,/--main-pack/);
  assert.match(verifier,/join\(root,'cocs\.pck'\)/);
  assert.doesNotMatch(verifier,/\b--smoke\b|\b--path\b/);
});
