import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validate,glbMaterialNames} from './validate.mjs';
import {readFileSync} from 'node:fs';
const base = () => ({version:1,map_id:'helix-conservatory',geometry_hash:'f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2',materials:[{source:'Panel',family:'pearl-ceramic',options:{variant:'worn',tint:'abcdef',roughness_variation:.3}}],panels:[],signs:[],pockets:[],preserve_materials:['Glass'],budgets:{material_variants:16,panels:96,signs:24,motes:96}});
test('real baked/derived family resources and exact surface exclusions resolve', () => {
  const result = validate(base(),{materialNames:['Panel','Glass']});
  assert.deepEqual(result.errors,[]); assert.ok(result.resources.length >= 3);
});
test('closed schema rejects misspellings, fabricated assets, bad identities and unsafe numeric inputs', () => {
  for (const mutation of [p=>p.version=2,p=>p.geometry_hash='0'.repeat(64),p=>p.extraneous=true,p=>p.materials[0].options.typo=1,p=>p.materials[0].options.variant='invented',p=>p.materials[0].options.tiles_per_metre=0,p=>p.materials[0].options.normal_strength=Infinity,p=>p.materials[0].options.tint='#abcdef',p=>p.materials.push(p.materials[0]),p=>p.budgets.motes=1000,p=>p.budgets=[],p=>p.pockets=[{id:'a',position:[0,0,0],size:[2,2,2],kind:'smoke',color:'ffffff',count:3}],p=>p.panels=[{id:'a',position:[0,0,0],rotation_degrees:[0,0,0],size:[1,1],texture:'invented',tint:'ffffff'}],p=>p.materials[0].options.wear_strength=.4,p=>p.materials[0].options.wear_height_min={}]) {
    const p=base(); mutation(p); assert.ok(validate(p).errors.length,JSON.stringify(p));
  }
});
test('selector coverage is exact and missing selectors never count as success', () => {
  assert.match(validate(base(),{materialNames:['panel','Glass']}).errors.join('\n'),/unmatched surface panel/);
  assert.match(validate(base(),{materialNames:['Panel']}).errors.join('\n'),/unused selector Glass/);
});
test('readable signs and local pocket budgets have meaningful negative cases', () => {
  const p=base(); p.signs=[{id:'sign',text:'COOLING / C2',position:[0,2,0],rotation_degrees:[0,0,0],size:[2,.6],foreground:'ffffff',background:'101010',essential:true}];
  assert.deepEqual(validate(p).errors,[]);
  p.signs[0].foreground='202020'; assert.match(validate(p).errors.join('\n'),/contrast/);
  p.signs=[];p.budgets.motes=1;p.pockets=[{id:'dust',position:[0,2,0],size:[2,2,2],kind:'dust',color:'ffffff',count:2}];
  assert.match(validate(p).errors.join('\n'),/mote budget/);
});
test('handed-off real profiles cover all 17 Helix/Foundry opaque selectors and preserve Helix glass', () => {
  let opaque=0;
  for (const [id,art] of [['helix-conservatory','helix-conservatory/helix-conservatory.glb'],['gravemill-foundry','worlds/gravemill-foundry.glb']]) {
    const p=JSON.parse(readFileSync(`godot/multiplayer_worlds/dressing/profiles/${id}.json`));
    const names=glbMaterialNames(`godot/multiplayer_worlds/art/${art}`);
    const result=validate(p,{materialNames:names});
    assert.deepEqual(result.errors,[],id);opaque+=p.materials.length;
    assert.ok(result.resources.length >= 3); // Family reuse is valid; counts are not visual quality.
  }
  assert.equal(opaque,17);
  const p=JSON.parse(readFileSync('godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json'));
  assert.deepEqual(p.preserve_materials,['glass']);
});
test('four optional variation controls accept boundaries and reject invalid values independently', () => {
  for (const mode of ['none','organic','manufactured']) {
    for (const [strength,scale,seed] of [[0,.01,0],[1,1,2147483647],[.6,.08,61002]]) {
      const p=base(); Object.assign(p.materials[0].options,{variation_mode:mode,variation_strength:strength,variation_scale:scale,variation_seed:seed});
      assert.deepEqual(validate(p).errors,[]);
    }
  }
  for (const [key,values] of Object.entries({variation_mode:['Organic','noise',1,null,{}],variation_strength:[-.01,1.01,NaN,Infinity,'0.5',true],variation_scale:[0,.009,1.01,NaN,null],variation_seed:[-1,2147483648,1.5,NaN,Infinity,'1',true]})) {
    for (const value of values) {
      const p=base(); p.materials[0].options[key]=value;
      assert.ok(validate(p).errors.some(e=>e.includes(key)),`${key}=${value}`);
    }
  }
});
test('private shader retains every shared uniform type/default and only exposes implemented options', () => {
  const read=p=>readFileSync(p,'utf8');
  const shared=read('godot/material_language/family.gdshader');
  const shader=read('godot/multiplayer_worlds/dressing/surface.gdshader');
  const uniforms=s=>new Map([...s.matchAll(/^uniform\s+(\w+)\s+(\w+)([^;]*);/gm)].map(m=>[m[2],`${m[1]}${m[3]}`]));
  const actual=uniforms(shader);
  for(const [name,signature] of uniforms(shared)) assert.equal(actual.get(name),signature,name);
  for(const path of ['godot/material_language/library.gd','godot/multiplayer_worlds/dressing/profile.gd']) {
    for(const m of read(path).matchAll(/"([a-z_]+)": \[-?[\d.]+, -?[\d.]+(?:, -?[\d.]+)?\]/g)) assert.ok(actual.has(m[1]),m[1]);
  }
  const runtime=read('godot/multiplayer_worlds/dressing/surface.gd');
  assert.ok(runtime.includes('shared.duplicate()'));
  assert.ok(runtime.includes('shared.shader.get_shader_uniform_list()'));
  assert.ok(runtime.includes('Profile.VARIATION_BOUNDS'));
  assert.ok(runtime.includes('Profile.VARIATION_MODES.find'));
  assert.ok(runtime.includes('int(options.get("variation_seed", 0))'));
  assert.ok(!runtime.includes('.code.replace('));
});
test('organic sampler mapping is identical across color/data/normal/mask and bounded; manufactured skips it', () => {
  const shader=readFileSync('godot/multiplayer_worlds/dressing/surface.gdshader','utf8');
  for(const map of ['albedo_map','linear_map','data_map','normal_map','mask_map']) {
    for(const axis of ['ux','uy','uz']) assert.ok(shader.includes(`surface_sample(${map}, ${axis}, blend, offset)`),`${map}/${axis}`);
  }
  const helper=shader.slice(shader.indexOf('vec3 surface_sample('),shader.indexOf('void vertex()'));
  assert.equal((helper.match(/\btexture(?:Grad)?\(/g)||[]).length,2);
  assert.match(helper,/variation_mode == 1 && variation_strength > 0.0/);
  assert.match(helper,/dFdx\(uv\) \* 0.731, dFdy\(uv\) \* 0.731/);
  assert.ok(!helper.includes('TIME'));
  assert.ok(!helper.includes('floor('));
  // Static structural check, explicitly not a Godot compiler substitute.
  const code=shader.replace(/\/\/[^\n]*/g,''); const stack=[];
  for(const c of code) {if('({['.includes(c)) stack.push(c); else if(')}]'.includes(c)) assert.equal(stack.pop(),'({['[')}]'.indexOf(c)]);}
  assert.equal(stack.length,0);
});
test('Parallax profile schema and actual PNG resources resolve without claiming isolated geometry', () => {
  const p=JSON.parse(readFileSync('godot/multiplayer_worlds/dressing/profiles/parallax-observatory.json'));
  assert.equal(p.materials.length,6);assert.deepEqual(p.preserve_materials,['sea']);
  assert.ok(p.materials.some(e=>e.source==='mirror' && e.family==='brushed-alloy'));
  assert.deepEqual(validate(p).errors,[]);
});
test('feathered wear fields reject opacity/seed/mask mistakes and keep opaque panels backward compatible', () => {
  const p=base();p.panels=[{id:'wear',texture:'metal-oxide',position:[0,2,0],rotation_degrees:[0,0,0],size:[1,1],tint:'ffffff',wear_mask:'dust-field',opacity:.22,feather:.15,seed:610022}];
  assert.deepEqual(validate(p).errors,[]);
  for (const patch of [{wear_mask:'fake'},{opacity:1.01},{feather:.6},{seed:-1},{seed:1.5},{normal:'derived:data--metal-oxide'}]) {
    const bad=structuredClone(p);Object.assign(bad.panels[0],patch);assert.ok(validate(bad).errors.length);
  }
  delete p.panels[0].wear_mask;assert.ok(validate(p).errors.length);
  for (const key of ['opacity','feather','seed']) delete p.panels[0][key];
  assert.deepEqual(validate(p).errors,[]);
});
