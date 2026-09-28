import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {GEAR, UNLOCKS} from '../../game/progression.mjs';
import {ATTACHMENTS} from '../../game/attachments.mjs';
import {WEAPONS} from '../../game/data.mjs';

const catalog = JSON.parse(await readFile(new URL('../../godot/career/catalog.json', import.meta.url)));
test('every exported item is still a source unlock with exact description, slot and level', () => {
 const items = [...GEAR.map(i=>[i,'gear']), ...ATTACHMENTS.map(i=>[i,'attachment'])];
 assert.equal(catalog.items.filter(i=>i.kind==='gear').length, GEAR.length);
 assert.equal(catalog.items.filter(i=>i.kind==='attachment').length, ATTACHMENTS.length);
 for(const [source,kind] of items){
  const item=catalog.items.find(i=>i.kind===kind&&i.id===source.id);
  assert.ok(item, source.id);
  assert.equal(item.description,source.description);
  assert.equal(item.slot,source.slot);
  assert.equal(item.level,source.level);
  assert.deepEqual(item.modifiers,source.modifiers);
  if(kind==='attachment')assert.deepEqual(item.weaponNames,source.weapons.map(index=>WEAPONS[index].name));
  assert.ok(UNLOCKS.some(unlock=>unlock.id===item.unlockId));
 }
});
test('catalog is data only and never contains ownership or synthetic purchases',()=>{
 assert.equal(catalog.schema,1);
 assert.ok(catalog.items.every(item=>!('owned' in item)&&!('price' in item)&&!('ownerToken' in item)));
});
