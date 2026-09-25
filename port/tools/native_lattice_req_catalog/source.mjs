// Deterministic source reader for the native REQ catalogue mirror.
//
// The native Godot client never owns REQ gameplay rules: it mirrors the rows
// the source already launches so it can decide what it is allowed to *ask* for.
// This module is the one place that turns `game/cocs-economy.mjs` into the
// canonical row list the mirror is generated from. It is pure (no clock, no
// RNG, no network) and fails closed on anything it cannot classify.
//
// Two independent views of the same source are produced:
//   * `catalogRows()`  imports the frozen module and resolves every effect
//     object, so generation is exact.
//   * `parseItemsBlock()` reads the tracked text block the way GDScript can,
//     so the native parity contract and the generator are proven to agree.
// `assertSourceViewMatches()` cross-checks them.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname, join} from 'node:path';
import {REQ_ITEMS, reqItemModes} from '../../../game/cocs-economy.mjs';

export const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '../../..');
export const ECONOMY_PATH = join(REPO_ROOT, 'game/cocs-economy.mjs');

// The effect kinds the native client knows how to gate today. A launched row
// with any other kind is refused by the generator instead of being offered as a
// pay-for-no-op: extend this list (and `req_catalog.gd`'s gate) deliberately.
export const KNOWN_EFFECT_KINDS = Object.freeze([
  'heal', 'resupply', 'haste', 'shield', 'spot', 'repair-link', 'vehicle',
  'sentry', 'recon-pulse',
]);

export const CATALOG_FIELDS = Object.freeze([
  'id', 'name', 'category', 'cost', 'personalBuff', 'commanderOnly',
  'requiresRelay', 'teamWide', 'target', 'modes', 'effectKind', 'effectCopy',
  'launch', 'coopLaunch',
]);

export class ReqCatalogSourceError extends Error {}

function fail(message) {
  throw new ReqCatalogSourceError(message);
}

function launched(item) {
  return item.launch === true || item.coopLaunch === true;
}

function nonEmptyString(value, label, id) {
  if (typeof value !== 'string' || value.trim() === '') {
    fail(`REQ row '${id}' has no ${label}; the native mirror refuses to offer it (fail-closed).`);
  }
  return value;
}

/** Canonical mirror row for one launched source item. Throws if unclassifiable. */
export function canonicalRow(item) {
  const id = String(item?.id ?? '');
  if (!id) fail('REQ_ITEMS contains a row without an id');
  if (!launched(item)) fail(`canonicalRow called for unlaunched row '${id}'`);
  const name = nonEmptyString(item.name, 'name', id);
  const category = nonEmptyString(item.category, 'category', id);
  const effectCopy = nonEmptyString(item.effectCopy, 'effectCopy', id);
  const cost = item.cost;
  if (!Number.isInteger(cost) || cost < 0) fail(`REQ row '${id}' has a non-integer cost ${String(cost)}`);
  const modes = [...reqItemModes(item)];
  if (modes.length === 0) fail(`REQ row '${id}' is launched but has no canonical mode (fail-closed)`);
  const effect = item.effect;
  if (!effect || typeof effect !== 'object' || typeof effect.kind !== 'string') {
    fail(`REQ row '${id}' is launched with no machine effect descriptor; the native mirror refuses to offer it (fail-closed).`);
  }
  if (!KNOWN_EFFECT_KINDS.includes(effect.kind)) {
    fail(`REQ row '${id}' has unknown effect kind '${effect.kind}'. The native client cannot gate it. ` +
      `Add it to KNOWN_EFFECT_KINDS in port/tools/native_lattice_req_catalog/source.mjs and to ` +
      `godot/lattice/req_catalog.gd, then re-run the exporter (fail-closed).`);
  }
  return {
    id,
    name,
    category,
    cost,
    personalBuff: item.personalBuff === true,
    commanderOnly: item.commanderOnly === true,
    requiresRelay: item.requiresRelay === true,
    teamWide: item.teamWide === true,
    target: typeof item.target === 'string' && item.target !== '' ? item.target : 'self',
    modes,
    effectKind: effect.kind,
    effectCopy,
    launch: item.launch === true,
    coopLaunch: item.coopLaunch === true,
  };
}

/**
 * The canonical launched catalogue. Every row the source *offers* (non-empty
 * modes, the `reqPurchaseOptions` filter) must also be launchable
 * (`launch`/`coopLaunch`), and vice versa. A row with modes but no launch flag
 * would be advertised and then refused `not-launched`; that is a source
 * inconsistency the native mirror must not paper over, so generation fails.
 */
export function catalogRows(items = REQ_ITEMS) {
  const launchedIds = [];
  const offeredIds = [];
  for (const item of items) {
    const id = String(item?.id ?? '');
    if (launched(item)) launchedIds.push(id);
    if (reqItemModes(item).length > 0) offeredIds.push(id);
  }
  const launchedSet = new Set(launchedIds);
  const offeredSet = new Set(offeredIds);
  for (const id of offeredIds) {
    if (!launchedSet.has(id)) {
      fail(`REQ row '${id}' has modes but is not launchable; the source picker would offer it while ` +
        `the buy path refuses 'not-launched'. Mark it launchable or clear its modes (fail-closed).`);
    }
  }
  for (const id of launchedIds) {
    if (!offeredSet.has(id)) {
      fail(`REQ row '${id}' is launchable but has empty modes, so it can never be offered (fail-closed).`);
    }
  }
  return items.filter(launched).map(canonicalRow);
}

/** Stable digest of the canonical rows. Order is part of the mirror. */
export function digestRows(rows) {
  return createHash('sha256').update(JSON.stringify(rows)).digest('hex');
}

// ---------------------------------------------------------------------------
// Text view — the same block the GDScript parity contract reads.
// ---------------------------------------------------------------------------

const BLOCK_BEGIN = 'export const REQ_ITEMS=deepFreeze([';
const BLOCK_END = ']);';

export function locateItemsBlock(text) {
  const begin = text.indexOf(BLOCK_BEGIN);
  if (begin < 0) fail(`could not find '${BLOCK_BEGIN}' in game/cocs-economy.mjs`);
  const end = text.indexOf(BLOCK_END, begin);
  if (end < 0) fail(`could not find the closing '${BLOCK_END}' after REQ_ITEMS`);
  return {begin, end, block: text.slice(begin, end)};
}

function effectKindsByIdent(text) {
  const found = {};
  const declaration = /export const (\w+)\s*=\s*deepFreeze\(\{[^}]*?kind\s*:\s*'([^']*)'/g;
  let match;
  while ((match = declaration.exec(text)) !== null) found[match[1]] = match[2];
  return found;
}

function capture(chunk, pattern, fallback = '') {
  const match = new RegExp(pattern).exec(chunk);
  return match ? match[1] : fallback;
}

function parseRow(chunk, effectKinds) {
  const id = capture(chunk, String.raw`id:'([^']*)'`);
  if (!id) fail('source text parser found a row without an id');
  const modesRaw = capture(chunk, String.raw`modes:\[([^\]]*)\]`);
  const modes = modesRaw.split(',').map(token => token.trim().replace(/^'|'$/g, '')).filter(Boolean);
  const effectMatch = /effect:\s*(\{[^}]*kind\s*:\s*'([^']*)'|(\w+))/.exec(chunk);
  let effectKind = '';
  if (effectMatch) effectKind = effectMatch[2] || effectKinds[effectMatch[3]] || '';
  return {
    id,
    name: capture(chunk, String.raw`name:'([^']*)'`),
    category: capture(chunk, String.raw`category:'([^']*)'`),
    cost: Number(capture(chunk, String.raw`cost:(\d+)`, 'NaN')),
    personalBuff: chunk.includes('personalBuff:true'),
    commanderOnly: chunk.includes('commanderOnly:true'),
    requiresRelay: chunk.includes('requiresRelay:true'),
    teamWide: chunk.includes('teamWide:true'),
    target: capture(chunk, String.raw`(?:^|[{,])target:'([^']*)'`, 'self'),
    modes,
    effectKind,
    effectCopy: capture(chunk, String.raw`effectCopy:'((?:[^'\\]|\\.)*)'`),
    launch: chunk.includes('launch:true'),
    coopLaunch: chunk.includes('coopLaunch:true'),
  };
}

/** Text-parsed rows for every REQ_ITEMS row (launched and unlaunched). */
export function parseItemsBlock(text) {
  const {block} = locateItemsBlock(text);
  const effectKinds = effectKindsByIdent(text);
  const rows = [];
  let position = block.indexOf("{id:'");
  while (position >= 0) {
    let next = block.indexOf('\n {', position + 1);
    if (next < 0) next = block.length;
    rows.push(parseRow(block.slice(position, next), effectKinds));
    position = block.indexOf("{id:'", next);
  }
  if (rows.length === 0) fail('source text parser found no REQ_ITEMS rows');
  return rows;
}

export function readEconomyText(path = ECONOMY_PATH) {
  return readFileSync(path, 'utf8');
}

/**
 * Prove the import view and the text view agree. The GDScript parity contract
 * uses the same text shape, so a disagreement here means the native contract
 * cannot be trusted even if generation "succeeds".
 */
export function assertSourceViewMatches(text = readEconomyText()) {
  const imported = catalogRows();
  const textRows = parseItemsBlock(text).filter(row => row.launch || row.coopLaunch);
  if (textRows.length !== imported.length) {
    fail(`imported ${imported.length} launched rows but the text block shows ${textRows.length}`);
  }
  for (let index = 0; index < imported.length; index += 1) {
    const left = imported[index];
    const right = textRows[index];
    for (const field of CATALOG_FIELDS) {
      if (JSON.stringify(left[field]) !== JSON.stringify(right[field])) {
        fail(`source views disagree on row '${left.id}' field '${field}': ` +
          `import=${JSON.stringify(left[field])} text=${JSON.stringify(right[field])}`);
      }
    }
  }
  return imported;
}
