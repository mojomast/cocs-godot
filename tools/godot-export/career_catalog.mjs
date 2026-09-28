// Source-derived presentation only. Run from any directory: node tools/godot-export/career_catalog.mjs [--check]
import {GEAR, GEAR_SLOTS, UNLOCKS} from '../../game/progression.mjs';
import {ATTACHMENTS, ATTACHMENT_SLOTS, attachmentSpec} from '../../game/attachments.mjs';
import {WEAPON_FINISHES, CROSSHAIR_STYLES} from '../../game/cosmetics.mjs';
import {createHash} from 'node:crypto';
import {readFile, writeFile} from 'node:fs/promises';

const target = new URL('../../godot/career/catalog.json', import.meta.url);
const sourceFiles = ['game/progression.mjs', 'game/attachments.mjs', 'game/cosmetics.mjs'];
const hashes = Object.fromEntries(await Promise.all(sourceFiles.map(async path => [path, createHash('sha256').update(await readFile(new URL('../../' + path, import.meta.url))).digest('hex')])));
const allowed = new Set(UNLOCKS.map(item => item.id));
const project = (items, kind) => items.map(item => {
  const unlockId = kind === 'gear' ? `gear-${item.id}` : kind === 'attachment' ? `attachment-${item.id}` : item.id;
  if (!allowed.has(unlockId)) throw Error(`No source unlock: ${unlockId}`);
  if (!item.id || !item.name || !item.description || !Number.isInteger(item.level)) throw Error(`Incomplete source item: ${unlockId}`);
  return {id:item.id, unlockId, kind, slot:item.slot ?? '', name:item.name, description:item.description, level:item.level,
    modifiers:item.modifiers ?? {}, spec:kind === 'attachment' ? attachmentSpec(item) : [], weapons:item.weapons ?? []};
});
const payload = {schema:1, sources:hashes, slots:{gear:GEAR_SLOTS, attachment:ATTACHMENT_SLOTS}, items:[...project(GEAR,'gear'), ...project(ATTACHMENTS,'attachment'), ...project(WEAPON_FINISHES,'finish'), ...project(CROSSHAIR_STYLES,'crosshair')]};
const text = JSON.stringify(payload, null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (await readFile(target, 'utf8').catch(() => '') !== text) throw Error('Career catalog stale; regenerate from source');
} else await writeFile(target, text);
