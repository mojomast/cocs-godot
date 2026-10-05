// Deterministic source-only check for the runtime Moth dressing profiles.
// Re-implements godot/multiplayer_worlds/dressing/profile.gd's closed schema in
// Node so the three newly authored maps can be verified without an import pass,
// then cross-checks every selector against the map's own art GLB.
//
//   node check.mjs                       # the three new maps
//   node check.mjs gravemill-foundry     # any accepted map, as a control
//
// godot/material_language/** is not always materialised in a sparse worktree, so
// families.gd / library.gd are read from the checkout when present and otherwise
// from `git show HEAD:<path>`. Nothing is copied into the repository.
import {readFileSync, existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {serialise} from './author.mjs';

const color = v => typeof v === 'string' && /^[\da-f]{6}$/i.test(v);
const number = (v, a, b) => typeof v === 'number' && Number.isFinite(v) && v >= a && v <= b;
const integer = (v, a, b) => number(v, a, b) && v === Math.floor(v);
const vector = (v, n, a, b) => Array.isArray(v) && v.length === n && v.every(c => number(c, a, b));
const text_ = (v, n) => typeof v === 'string' && v.trim().length > 0 && v.length <= n;
const contrast = (a, b) => {
  const x = luminance(a), y = luminance(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
};

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../../..');
const PROFILE_DIR = resolve(ROOT, 'godot/multiplayer_worlds/dressing/profiles');
const ART_DIR = resolve(ROOT, 'godot/multiplayer_worlds/art');
const NEW_MAPS = ['vesper-viaduct', 'abyssal-pressureworks', 'stormglass-causeway'];

// profile.gd is the authority: identities, wear/variation bounds, modes and caps.
const profileSource = read('godot/multiplayer_worlds/dressing/profile.gd');
const identities = Object.fromEntries(
  [...profileSource.matchAll(/"([a-z-]+)": "([a-f0-9]{64})"/g)].map(m => [m[1], m[2]]));
const caps = Object.fromEntries(
  [...profileSource.matchAll(/"(material_variants|panels|signs|motes)": (\d+)/g)].map(m => [m[1], +m[2]]));
const variationModes = [...profileSource.match(/const VARIATION_MODES := \[([^\]]+)\]/)[1]
  .matchAll(/"([a-z_]+)"/g)].map(m => m[1]);
const pairBounds = Object.fromEntries([...profileSource
  .matchAll(/"([a-z_]+)": \[(-?[\d.]+), (-?[\d.]+)\]/g)].map(m => [m[1], [+m[2], +m[3]]]));
if (Object.keys(caps).length !== 4 || variationModes.length !== 3) {
  throw Error('profile.gd constants did not parse; the schema authority moved');
}

// families.gd / library.gd: families, variants and the bounded option table.
const bounds = {...pairBounds, ...numberBounds(readMaybe('godot/material_language/library.gd'))};
const families = parseFamilies(readMaybe('godot/material_language/families.gd'));

const moth = JSON.parse(read('godot/moth/generated/manifest.json'));
const derived = JSON.parse(read('godot/moth/derived/manifest.json')).derived ?? {};
if (moth.version !== 1) throw Error('unexpected Moth manifest version');

const unresolved = [];
const resources = new Set();
let failures = 0;
for (const mapId of (process.argv.slice(2).length ? process.argv.slice(2) : NEW_MAPS)) {
  const errors = check(mapId);
  const p = JSON.parse(readFileSync(resolve(PROFILE_DIR, `${mapId}.json`), 'utf8'));
  const motes = p.pockets.reduce((sum, e) => sum + e.count, 0);
  const summary = `${mapId}: materials=${p.materials.length}/${p.budgets.material_variants} ` +
    `panels=${p.panels.length}/${p.budgets.panels} signs=${p.signs.length}/${p.budgets.signs} ` +
    `motes=${motes}/${p.budgets.motes} preserve=${p.preserve_materials.length} ` +
    `placements=${p.panels.length + p.signs.length + p.pockets.length}`;
  if (errors.length) {
    failures++;
    console.error(`FAIL ${summary}`);
    for (const e of errors) console.error(`  - ${e}`);
  } else {
    console.log(`PASS ${summary}`);
  }
}
console.log(`resources resolved: ${resources.size}`);
process.exitCode = failures ? 1 : 0;

function check(mapId) {
  const errors = [];
  const fail = s => errors.push(s);
  const path = resolve(PROFILE_DIR, `${mapId}.json`);
  if (!existsSync(path)) return [`missing ${path}`];
  const text = readFileSync(path, 'utf8');
  let p;
  try { p = JSON.parse(text); } catch (e) { return [`unparseable JSON: ${e.message}`]; }
  // The three new profiles are emitted by author.mjs, so they must match their
  // authoring source byte for byte: a hand edit to the JSON cannot silently
  // diverge from the place the placements are actually documented.
  // The already-accepted maps were emitted by Python, whose float formatting
  // differs, so the byte check is scoped to the new files only.
  if (NEW_MAPS.includes(mapId)) {
    let authored = null;
    try { authored = serialise(mapId); } catch { /* not an authored map */ }
    if (authored !== null && authored !== text) fail('committed JSON has drifted from author.mjs');
  }

  // ---- identity: profile.gd accepts exactly these geometry hashes ----------
  if (!identities[mapId]) fail(`${mapId} has no Profile.IDENTITIES entry`);
  if (p.map_id !== mapId) fail(`map_id ${p.map_id} !== ${mapId}`);
  if (p.geometry_hash !== identities[mapId]) fail('geometry_hash does not match Profile.IDENTITIES');
  if (p.version !== 1) fail('version must be 1');
  const geometry = glbMaterialNames(artPath(mapId));
  if (p.geometry_hash !== generatedHash(mapId)) fail('geometry_hash differs from generated/<map>.json');

  // ---- budgets -------------------------------------------------------------
  const closed = (o, keys, context) => {
    if (!o || typeof o !== 'object' || Array.isArray(o)) { fail(`${context}: object required`); return false; }
    for (const k of Object.keys(o)) if (!keys.includes(k)) fail(`${context}: unknown key ${k}`);
    return true;
  };
  closed(p, ['version', 'map_id', 'geometry_hash', 'materials', 'panels', 'signs', 'pockets',
    'preserve_materials', 'budgets'], 'profile');
  if (!closed(p.budgets, Object.keys(caps), 'budgets')) return errors;
  for (const [k, cap] of Object.entries(caps)) {
    if (!Number.isInteger(p.budgets[k]) || p.budgets[k] < 0 || p.budgets[k] > cap) fail(`invalid budget ${k}`);
  }

  // ---- selectors and placements -------------------------------------------
  const selectors = new Set();
  const ids = new Set();
  const limits = {materials: 32, panels: 96, signs: 24, pockets: 12, preserve_materials: 32};
  let motes = 0;
  for (const group of ['materials', 'panels', 'signs', 'pockets', 'preserve_materials']) {
    if (!Array.isArray(p[group])) { fail(`${group}: array required`); continue; }
    if (p[group].length > limits[group]) fail(`${group} exceeds hard cap ${limits[group]}`);
    const budgetKey = group === 'materials' ? 'material_variants' : group;
    if (budgetKey in caps && p[group].length > p.budgets[budgetKey]) fail(`${group} exceeds profile budget`);
    for (const e of p[group]) {
      if (group === 'preserve_materials') {
        if (!text_(e, 128) || selectors.has(e)) fail('invalid/duplicate preserved selector');
        selectors.add(e);
        continue;
      }
      if (!e || typeof e !== 'object' || Array.isArray(e)) { fail(`${group} entry must be object`); continue; }
      if (group === 'materials') {
        if (!closed(e, ['source', 'family', 'options'], 'materials')) continue;
        if (!text_(e.source, 128) || selectors.has(e.source)) fail('invalid/duplicate material selector');
        selectors.add(e.source);
        const recipe = families[e.family]?.[e.options?.variant ?? 'default'];
        if (!recipe) { fail(`unknown family/variant ${e.family}/${e.options?.variant}`); continue; }
        const options = e.options ?? {};
        if (!closed(options, [...Object.keys(bounds), 'tint', 'variant', 'glow', 'wear_tint',
          'variation_mode', 'variation_seed'], 'options')) continue;
        for (const [k, v] of Object.entries(options)) {
          if (bounds[k] && !number(v, ...bounds[k])) fail(`invalid option ${k} on ${e.source}`);
          if (['tint', 'wear_tint'].includes(k) && !color(v)) fail(`invalid ${k} on ${e.source}`);
          if (k === 'glow' && typeof v !== 'boolean') fail(`invalid glow on ${e.source}`);
          if (k === 'variation_mode' && !variationModes.includes(v)) fail(`invalid variation_mode on ${e.source}`);
          if (k === 'variation_seed' && !integer(v, 0, 2147483647)) fail(`invalid variation_seed on ${e.source}`);
        }
        if (number(options.wear_strength, 0.001, 0.65)) {
          if (!color(options.wear_tint) || !number(options.wear_height_min, -100, 100)
            || !number(options.wear_height_max, -100, 100)) fail(`wear needs tint + height interval on ${e.source}`);
          else if (options.wear_height_max <= options.wear_height_min) fail(`empty wear interval on ${e.source}`);
        }
        resource(moth.textures[recipe.base]);
        resource(derived[`data--${recipe.base}`]);
        resource(recipe.normal_source === 'derived' ? derived[`normal--${recipe.normal}`] : moth.normals[recipe.normal]);
        if (recipe.mask) resource(derived[recipe.mask]);
        if (recipe.lut) { resource(moth.materials[recipe.lut]?.r); resource(moth.materials[recipe.lut]?.t); }
        continue;
      }
      const keys = ['id', 'position', 'size', ...(group === 'pockets'
        ? ['kind', 'color', 'count']
        : ['rotation_degrees', 'essential', ...(group === 'panels'
          ? ['texture', 'tint', 'normal', 'wear_mask', 'opacity', 'feather', 'seed']
          : ['text', 'foreground', 'background'])])];
      if (!closed(e, keys, group)) continue;
      if (!text_(e.id, 80) || ids.has(e.id)) fail('invalid/duplicate placement id');
      ids.add(e.id);
      if (!vector(e.position, 3, -512, 512)) fail(`invalid position on ${e.id}`);
      if (group !== 'pockets' && !vector(e.rotation_degrees, 3, -360, 360)) fail(`invalid rotation on ${e.id}`);
      if (!vector(e.size, group === 'pockets' ? 3 : 2, 0.05, group === 'pockets' ? 8 : 16)) fail(`invalid size on ${e.id}`);
      if (group !== 'pockets' && typeof (e.essential ?? false) !== 'boolean') fail(`essential must be boolean on ${e.id}`);
      if (group === 'panels') {
        resource(moth.textures[e.texture]);
        const normal = e.normal ?? e.texture;
        resource(typeof normal !== 'string' ? null
          : normal.startsWith('baked:') ? moth.normals[normal.slice(6)]
          : normal.startsWith('derived:normal--') ? derived[normal.slice(8)]
          : moth.normals[normal] ?? derived[`normal--${normal}`]);
        if (!color(e.tint)) fail(`invalid tint on ${e.id}`);
        if ('wear_mask' in e) {
          resource(moth.textures[e.wear_mask]);
          if (!number(e.opacity ?? 1, 0, 1) || !number(e.feather ?? 0.15, 0, 0.5)
            || !integer(e.seed ?? 0, 0, 2147483647)) fail(`invalid wear controls on ${e.id}`);
        } else if (['opacity', 'feather', 'seed'].some(k => k in e)) fail(`wear controls require wear_mask on ${e.id}`);
      } else if (group === 'signs') {
        if (!text_(e.text, 96) || !color(e.foreground) || !color(e.background)) fail(`invalid sign ${e.id}`);
        else if (contrast(e.foreground, e.background) < 4.5) fail(`sign contrast below 4.5:1 on ${e.id}`);
        if (/[^\x20-\x7e\n]/.test(e.text ?? '')) fail(`non-ASCII sign text on ${e.id}`);
      } else {
        if (!['dust', 'pollen', 'ash', 'mist', 'vent'].includes(e.kind) || !color(e.color)
          || !integer(e.count, 1, 32)) fail(`invalid pocket ${e.id}`);
        else motes += e.count;
        resource(moth.textures['dust-field']);
        resource(moth.textures['flow-field']);
      }
    }
  }
  if (motes > p.budgets.motes) fail(`motes ${motes} exceed budget ${p.budgets.motes}`);
  for (const missing of unresolved.splice(0)) fail(`unresolved Moth resource ${missing}`);

  // ---- selector coverage against the map's own art -------------------------
  for (const name of geometry) if (!selectors.has(name)) fail(`unmatched art material ${name}`);
  for (const selector of selectors) if (!geometry.includes(selector)) fail(`unused selector ${selector}`);
  return errors;
}

// The binder keys on the imported glTF material resource_name, so the GLB is the
// only honest source of selectors.
function glbMaterialNames(path) {
  const b = readFileSync(path);
  if (b.toString('ascii', 0, 4) !== 'glTF' || b.readUInt32LE(4) !== 2 || b.readUInt32LE(16) !== 0x4e4f534a) {
    throw Error(`invalid GLB ${path}`);
  }
  const gltf = JSON.parse(b.toString('utf8', 20, 20 + b.readUInt32LE(12)));
  return [...new Set(gltf.meshes.flatMap(m => m.primitives.map(p => gltf.materials?.[p.material]?.name ?? '<null>')))].sort();
}

function artPath(mapId) {
  for (const candidate of [`worlds/${mapId}.glb`, `${mapId}/${mapId}.glb`]) {
    if (existsSync(resolve(ART_DIR, candidate))) return resolve(ART_DIR, candidate);
  }
  throw Error(`no art GLB for ${mapId}`);
}

function generatedHash(mapId) {
  const p = resolve(ROOT, `godot/multiplayer_worlds/generated/${mapId}.json`);
  if (!existsSync(p)) return null;
  return JSON.parse(readFileSync(p, 'utf8')).geometryHash;
}

// profile.gd refuses a family whose base/normal/data/mask/LUT is missing, so an
// unresolved Moth record is a failure, not a warning. Records are collected and
// drained per map.
function resource(record) {
  const path = record?.path;
  if (!path || !existsSync(resolve(ROOT, 'godot', path.replace('res://', '')))) {
    unresolved.push(record ? `${path} (missing)` : 'unknown Moth key');
    return;
  }
  const bytes = readFileSync(resolve(ROOT, 'godot', path.replace('res://', '')));
  if (bytes.length < 24 || bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a'
    || bytes.readUInt32BE(16) !== record.width || bytes.readUInt32BE(20) !== record.height) {
    throw Error(`invalid PNG ${path}`);
  }
  resources.add(path);
}

function read(p) {
  return readFileSync(resolve(ROOT, p), 'utf8');
}
// Sparse worktrees skip godot/material_language/**; fall back to the committed blob.
function readMaybe(p) {
  const local = resolve(ROOT, p);
  if (existsSync(local)) return readFileSync(local, 'utf8');
  try {
    return execFileSync('git', ['-C', ROOT, 'show', `HEAD:${p}`], {encoding: 'utf8', maxBuffer: 1 << 24});
  } catch {
    throw Error(`cannot read ${p} from the worktree or from HEAD`);
  }
}
function numberBounds(source) {
  const out = {};
  const table = source.match(/const BOUNDS := \{([\s\S]*?)\n\}/);
  if (!table) throw Error('material_language/library.gd BOUNDS did not parse');
  for (const m of table[1].matchAll(/"([a-z_]+)": \[(-?[\d.]+), (-?[\d.]+),/g)) out[m[1]] = [+m[2], +m[3]];
  return out;
}

function parseFamilies(source) {
  const table = source.match(/const TABLE := \{([\s\S]*)\n\}\s*$/);
  if (!table) throw Error('material_language/families.gd TABLE did not parse');
  const out = {};
  const shape = text => Object.fromEntries(
    [...text.matchAll(/"(base|normal|normal_source|mask)": "([^"]+)"/g)].map(m => [m[1], m[2]]));
  for (const block of table[1].split(/(?=^\t"[a-z-]+": \{)/m).slice(1)) {
    const id = block.match(/^\t"([a-z-]+)"/)[1];
    const defaults = shape(block.match(/"default": \{([^\n]+)/)[1]);
    const lut = block.match(/"accent": \{"lut": "([^"]+)"/)?.[1];
    const variants = Object.fromEntries([...block.matchAll(/^\t\t\t"([a-z-]+)": \{([^\n]+)/gm)]
      .map(m => [m[1], {...defaults, ...shape(m[2]), lut}]));
    out[id] = {default: {...defaults, lut}, ...variants};
  }
  return out;
}

function luminance(hex) {
  return [0, 2, 4].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(v => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
    .reduce((a, v, i) => a + v * [0.2126, 0.7152, 0.0722][i], 0);
}