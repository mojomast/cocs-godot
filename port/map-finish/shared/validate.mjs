// Source-only authoring check. Explicit profile inputs; never scans worker files.
import {readFileSync, existsSync} from 'node:fs';
import {resolve, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const read = p => readFileSync(resolve(ROOT, p), 'utf8');
const profileSource = read('godot/multiplayer_worlds/dressing/profile.gd');
const identities = Object.fromEntries([...profileSource.matchAll(/"([a-z-]+)": "([a-f0-9]{64})"/g)].map(m => [m[1], m[2]]));
const bounds = Object.fromEntries([...read('godot/material_language/library.gd').matchAll(/"([a-z_]+)": \[(-?[\d.]+), (-?[\d.]+),/g), ...profileSource.matchAll(/"([a-z_]+)": \[(-?[\d.]+), (-?[\d.]+)\]/g)].map(m => [m[1], [+m[2], +m[3]]]));
const families = {};
const source = read('godot/material_language/families.gd');
for (const block of source.split(/(?=^\t"[a-z-]+": \{)/m).slice(1)) {
  const id = block.match(/^\t"([a-z-]+)"/)[1];
  const parse = text => Object.fromEntries([...text.matchAll(/"(base|normal|normal_source|mask)": "([^"]+)"/g)].map(m => [m[1], m[2]]));
  const defaults = parse(block.match(/"default": \{([^\n]+)/)[1]);
  const variants = Object.fromEntries([...block.matchAll(/^\t\t\t"([a-z-]+)": \{([^\n]+)/gm)].map(m => [m[1], {...defaults, ...parse(m[2])}]));
  const lut = block.match(/"accent": \{"lut": "([^"]+)"/)?.[1];
  families[id] = {default: {...defaults, lut}, ...Object.fromEntries(Object.entries(variants).map(([key,v])=>[key,{...v,lut}]))};
}
const moth = JSON.parse(read('godot/moth/generated/manifest.json'));
const derived = JSON.parse(read('godot/moth/derived/manifest.json')).derived;
const caps = {material_variants: 32, panels: 96, signs: 24, motes: 96};
const color = v => typeof v === 'string' && /^[\da-f]{6}$/i.test(v);
const number = (v, a, b) => typeof v === 'number' && Number.isFinite(v) && v >= a && v <= b;
const vector = (v, n, a, b) => Array.isArray(v) && v.length === n && v.every(c => number(c, a, b));
const text = (v, n) => typeof v === 'string' && v.trim().length > 0 && v.length <= n;
function luminance(hex) {
  return [0,2,4].map(i => parseInt(hex.slice(i,i+2),16)/255).map(v => v <= .04045 ? v/12.92 : ((v+.055)/1.055)**2.4).reduce((a,v,i) => a+v*[.2126,.7152,.0722][i],0);
}
export function validate(p, {materialNames = null} = {}) {
  const errors = [], resources = new Set();
  const fail = s => errors.push(s);
  const closed = (o, keys, context) => {
    if (!o || typeof o !== 'object' || Array.isArray(o)) {fail(`${context}: object required`); return false;}
    for (const k of Object.keys(o)) if (!keys.includes(k)) fail(`${context}: unknown key ${k}`);
    return true;
  };
  const resource = record => {
    if (!record?.path || !existsSync(resolve(ROOT, 'godot', record.path.replace('res://','')))) fail('unresolved resource');
    else {
      const bytes = readFileSync(resolve(ROOT,'godot',record.path.replace('res://','')));
      if (bytes.length < 24 || bytes.subarray(0,8).toString('hex') !== '89504e470d0a1a0a' || bytes.readUInt32BE(16) !== record.width || bytes.readUInt32BE(20) !== record.height) fail(`invalid PNG ${record.path}`);
      else if (record.png_sha256 && createHash('sha256').update(bytes).digest('hex') !== record.png_sha256) fail(`PNG identity mismatch ${record.path}`);
      else resources.add(record.path);
    }
  };
  if (!closed(p, ['version','map_id','geometry_hash','materials','panels','signs','pockets','preserve_materials','budgets'], 'profile')) return {errors, resources: []};
  if (p.version !== 1 || !identities[p.map_id] || identities[p.map_id] !== p.geometry_hash) fail('invalid profile identity');
  const budgets = closed(p.budgets, Object.keys(caps), 'budgets') ? p.budgets : {};
  for (const [k, cap] of Object.entries(caps)) if (!Number.isInteger(budgets[k]) || !number(budgets[k],0,cap)) fail(`invalid budget ${k}`);
  const selectors = new Set(), ids = new Set();
  let motes = 0;
  for (const group of ['materials','panels','signs','pockets','preserve_materials']) {
    if (!Array.isArray(p[group])) {fail(`${group}: array required`); continue;}
    const limit = {materials:32, panels:96, signs:24, pockets:12, preserve_materials:32}[group];
    if (p[group].length > limit) fail(`${group}: hard cap`);
    const budgetKey = group === 'materials' ? 'material_variants' : group;
    if (budgetKey in caps && p[group].length > budgets[budgetKey]) fail(`${group}: budget`);
    for (const e of p[group]) {
      if (group === 'preserve_materials') {
        if (!text(e,128) || selectors.has(e)) fail('invalid preserved selector');
        selectors.add(e); continue;
      }
      if (group === 'materials') {
        if (!closed(e,['source','family','options'],group)) continue;
        if (!text(e.source,128) || selectors.has(e.source)) fail('invalid/duplicate selector');
        selectors.add(e.source);
        const options = e.options ?? {};
        if (!closed(options,[...Object.keys(bounds),'tint','variant','glow','wear_tint'],'options')) continue;
        for (const [k,v] of Object.entries(options)) {
          if (bounds[k] && !number(v,...bounds[k])) fail(`invalid option ${k}`);
          if (['tint','wear_tint'].includes(k) && !color(v)) fail(`invalid color ${k}`);
          if (k === 'glow' && typeof v !== 'boolean') fail('invalid glow');
        }
        if (options.wear_strength > 0 && (!color(options.wear_tint) || !number(options.wear_height_min,-100,100) || !number(options.wear_height_max,-100,100) || options.wear_height_max <= options.wear_height_min)) fail('invalid wear interval');
        const recipe = families[e.family]?.[options.variant ?? 'default'];
        if (!recipe) {fail('unknown family/variant'); continue;}
        resource(moth.textures[recipe.base]);
        resource(derived['data--'+recipe.base]);
        resource(recipe.normal_source === 'derived' ? derived['normal--'+recipe.normal] : moth.normals[recipe.normal]);
        if (recipe.mask) resource(derived[recipe.mask]);
        if (recipe.lut) {resource(moth.materials[recipe.lut]?.r); resource(moth.materials[recipe.lut]?.t);}
        continue;
      }
      const keys = ['id','position','size', ...(group === 'pockets' ? ['kind','color','count'] : ['rotation_degrees','essential', ...(group === 'panels' ? ['texture','tint','normal','wear_mask','opacity','feather','seed'] : ['text','foreground','background'])])];
      if (!closed(e,keys,group)) continue;
      if (!text(e.id,80) || ids.has(e.id)) fail('invalid/duplicate id');
      ids.add(e.id);
      if (!vector(e.position,3,-512,512)) fail('invalid position');
      if (!vector(e.size,group === 'pockets' ? 3 : 2,.05,group === 'pockets' ? 8 : 16)) fail('invalid size');
      if (group !== 'pockets' && (!vector(e.rotation_degrees,3,-360,360) || typeof (e.essential ?? false) !== 'boolean')) fail('invalid rotation/essential');
      if (group === 'panels') {
        resource(moth.textures[e.texture]);
        const normal = e.normal ?? e.texture;
        resource(typeof normal !== 'string' ? null : normal.startsWith('baked:') ? moth.normals[normal.slice(6)] : normal.startsWith('derived:normal--') ? derived[normal.slice(8)] : moth.normals[normal] ?? derived['normal--'+normal]);
        if (!color(e.tint)) fail('invalid tint');
        if ('wear_mask' in e) {
          resource(moth.textures[e.wear_mask]);
          if (!number(e.opacity ?? 1,0,1) || !number(e.feather ?? .15,0,.5) || !Number.isInteger(e.seed ?? 0) || !number(e.seed ?? 0,0,2147483647)) fail('invalid wear controls');
        } else if (['opacity','feather','seed'].some(k=>k in e)) fail('wear controls require wear_mask');
      } else if (group === 'signs') {
        if (!text(e.text,96) || !color(e.foreground) || !color(e.background)) fail('invalid sign');
        else {
          const a = luminance(e.foreground), b = luminance(e.background);
          if ((Math.max(a,b)+.05)/(Math.min(a,b)+.05) < 4.5) fail('sign contrast below 4.5:1');
        }
      } else {
        if (!['dust','pollen','ash','mist','vent'].includes(e.kind) || !color(e.color) || !Number.isInteger(e.count) || !number(e.count,1,32)) fail('invalid pocket');
        else motes += e.count;
        resource(moth.textures['dust-field']); resource(moth.textures['flow-field']);
      }
    }
  }
  if (motes > budgets.motes) fail('mote budget');
  if (materialNames) {
    for (const name of materialNames) if (!selectors.has(name)) fail(`unmatched surface ${name}`);
    for (const selector of selectors) if (!materialNames.includes(selector)) fail(`unused selector ${selector}`);
  }
  return {errors, resources: [...resources]};
}
export function glbMaterialNames(path) {
  const b = readFileSync(path);
  if (b.toString('ascii',0,4) !== 'glTF' || b.readUInt32LE(4) !== 2 || b.readUInt32LE(16) !== 0x4e4f534a) throw Error('invalid GLB');
  const gltf = JSON.parse(b.toString('utf8',20,20+b.readUInt32LE(12)));
  return [...new Set(gltf.meshes.flatMap(m => m.primitives.map(p => gltf.materials?.[p.material]?.name ?? '<null>')))];
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (!process.argv[2]) throw Error('usage: node validate.mjs PROFILE.json [ART.glb]');
  const result = validate(JSON.parse(readFileSync(process.argv[2],'utf8')), {materialNames: process.argv[3] ? glbMaterialNames(process.argv[3]) : null});
  console.log(JSON.stringify(result,null,2)); process.exitCode = result.errors.length ? 1 : 0;
}
