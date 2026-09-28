import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {DEFAULT_ITINERARY, journeyOptions} from './journey_options.mjs';
const registry=JSON.parse(readFileSync(new URL('../../godot/ui/routes.json',import.meta.url)));

test('default journey is unchanged and independent entries can select the same route twice',()=>{
  assert.deepEqual(journeyOptions(DEFAULT_ITINERARY,registry),DEFAULT_ITINERARY);
  const entries=journeyOptions([{route:'combat',options:{map:'meridian-exchange'}},
    {route:'combat',options:{map:'verdant-reliquary'}},{route:'horde'}],registry);
  assert.equal(entries.length,3);
  assert.equal(entries[1].options.map,'verdant-reliquary');
  assert.deepEqual(entries[2].options,{});
});

test('itinerary rejects unbounded, debug, offline and private transport controls',()=>{
  for(const raw of [[],Array(7).fill({route:'combat'}),null,[{route:'missing'}],[{route:'viewer'}],
    [{route:'cheats-combat'}],[{route:'combat',options:{endpoint:'ws://other-host'}}],
    [{route:'combat',options:{'debug-panel':true}}],[{route:'combat',options:{map:2}}],
    [{route:'combat',options:[]}],[{route:'combat',credentials:'never-accepted'}]]){
    assert.throws(()=>journeyOptions(raw,registry));
  }
});
