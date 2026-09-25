// GDScript rendering for the native REQ catalogue mirror.
//
// The mirror is the generated region between `BEGIN` and `END` inside
// `godot/lattice/req_catalog.gd`. The surrounding hand-written gate logic is
// never rewritten, so regeneration can never silently drop a hand edit outside
// the region.
import {CATALOG_FIELDS, catalogRows, digestRows, assertSourceViewMatches} from './source.mjs';

export const BEGIN = '## >>> GENERATED REQ ITEMS — do not edit by hand';
export const END = '## <<< END GENERATED REQ ITEMS';

function gdString(value) {
  return '"' + String(value)
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', '\\n')
    .replaceAll('\t', '\\t') + '"';
}

function gdValue(value) {
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return Number.isInteger(value) ? String(value) : String(value);
  if (Array.isArray(value)) return '[' + value.map(gdValue).join(',') + ']';
  return gdString(value);
}

/** Render the generated region for the canonical launched rows. */
export function renderBlock(rows, digest = digestRows(rows)) {
  const lines = [];
  lines.push(BEGIN);
  lines.push('## Regenerate with: node port/tools/native_lattice_req_catalog/export.mjs');
  lines.push(`## Source: game/cocs-economy.mjs REQ_ITEMS (canonical sha256 ${digest}).`);
  lines.push(`const SOURCE_SHA256 := "${digest}"`);
  lines.push('const ITEMS: Array = [');
  const head = ['id', 'name', 'category', 'cost', 'personalBuff', 'commanderOnly',
    'requiresRelay', 'teamWide', 'target', 'modes', 'effectKind', 'launch', 'coopLaunch'];
  for (const row of rows) {
    lines.push('\t{' + head.map(field => gdString(field) + ':' + gdValue(row[field])).join(',') + ',');
    lines.push('\t\t"effectCopy":' + gdValue(row.effectCopy) + '},');
  }
  lines.push(']');
  lines.push(END);
  return lines.join('\n');
}

/** Replace the marked region in `text` with `block`. Throws if unmarked. */
export function replaceBlock(text, block) {
  const begin = text.indexOf(BEGIN);
  if (begin < 0) throw new Error(`missing generated-region marker: ${BEGIN}`);
  const end = text.indexOf(END, begin);
  if (end < 0) throw new Error(`missing generated-region terminator: ${END}`);
  const newline = text.indexOf('\n', end);
  const stop = newline < 0 ? text.length : newline + 1;
  return text.slice(0, begin) + block + '\n' + text.slice(stop);
}

/** The full, regenerated target text. Deterministic. */
export function generateCatalogText(text) {
  const rows = assertSourceViewMatches();
  const digest = digestRows(rows);
  return {rows, digest, text: replaceBlock(text, renderBlock(rows, digest))};
}

export {catalogRows, digestRows, CATALOG_FIELDS};
