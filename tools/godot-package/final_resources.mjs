// Final content inventory is data-driven within reviewed families, never a glob
// granting every candidate asset. Also usable against recorded Git object bytes.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {fileURLToPath} from 'node:url';
export const OPERATORS=Object.freeze(['chatgpt','claude','grok','meta','gemini','deepseek','mistral','kimi','qwen']);
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const sorted=value=>Object.fromEntries(Object.entries(value).sort());
export function finalResources({read,has,requireFighters=true}) {
  const resources={},provenance={},raw={},pending=[];
  const add=(path,expected=null,buildOnly=false)=>{
    assert.ok(/^(godot|game|tools)\/[a-zA-Z0-9_./-]+$/.test(path)&&!path.split('/').includes('..'),`Invalid content path: ${path}`);
    const bytes=read(path),hash=sha(bytes);
    if(expected!==null)assert.equal(hash,expected,`Content hash mismatch: ${path}`);
    (buildOnly?provenance:resources)[path]=hash;return bytes;
  };
  const json=path=>JSON.parse(add(path));
  if(has('godot/moth/derived/manifest.json')) {
    const original=json('godot/moth/generated/manifest.json');
    const derived=json('godot/moth/derived/manifest.json');
    add(original.provenance.source,original.provenance.source_sha256,true);
    add(derived.provenance.tool,derived.provenance.tool_sha256,true);
    assert.equal(derived.provenance.source_manifest,'godot/moth/generated/manifest.json');
    assert.equal(derived.provenance.source_manifest_sha256,resources['godot/moth/generated/manifest.json']);
    const textures=value=>{
      if(!value||typeof value!=='object')return;
      if(value.path&&value.png_sha256) {
        assert.match(value.path,/^res:\/\/moth\/(generated|derived)\/[a-zA-Z0-9_/-]+\.png$/);
        add('godot/'+value.path.slice(6),value.png_sha256);
      }
      for(const child of Object.values(value))if(child&&typeof child==='object')textures(child);
    };
    for(const family of ['textures','normals','sky','materials','effects'])textures(original[family]);
    textures(derived.derived);
  }
  if(has('godot/source_operators/moth_finish/binder.gd')) {
    const base='godot/source_operators/moth_finish/';
    const m=json(base+'manifest.json');assert.equal(m.version,1);
    assert.equal(Object.keys(m.finishes).length,63,'Reviewed operator finish identity count');
    assert.equal(Object.keys(m.textures).length,116,'Reviewed operator finish texture count');
    for(const [uri,entry] of Object.entries(m.textures)) {
      assert.match(uri,/^res:\/\/source_operators\/moth_finish\/assets\/[a-z0-9-]+\.png$/);
      add('godot/'+uri.slice(6),entry.png_sha256);
    }
    for(const id of OPERATORS) {
      const profile=json(base+`profiles/${id}.json`);
      assert.equal(profile.operator_id,id);assert.equal(profile.version,1);
      for(const finish of [...profile.bindings.map(b=>b.finish),...Object.values(profile.overlay_finishes)]) {
        assert.ok(Object.hasOwn(m.finishes,finish),`Missing finish: ${finish}`);
        for(const channel of ['albedo','normal','roughness'])if(m.finishes[finish][channel])
          assert.ok(Object.hasOwn(m.textures,m.finishes[finish][channel]),`Uninventoried finish texture: ${finish}/${channel}`);
      }
    }
    const p=m.provenance;
    add(p.generator,p.generator_sha256,true);
    add(p.moth_baked_source.path,p.moth_baked_source.sha256,true);
    for(const [path,hash]of Object.entries(p.art_reference_sources))add(path,hash,true);
    add('godot/moth/generated/manifest.json',p.moth_manifest_sha256);
    add('godot/source_operators/generated/manifest.json',p.operator_catalog_manifest_sha256);
    for(const entry of Object.values(p.moth_sources)) {
      assert.match(entry.path,/^res:\/\/moth\/generated\/textures\/[a-z0-9_-]+\.png$/);
      add('godot/'+entry.path.slice(6),entry.png_sha256);
    }
    assert.deepEqual(Object.keys(p.source_glbs).sort(),[...OPERATORS].sort());
    for(const id of OPERATORS)add(`godot/source_operators/generated/${id}.glb`,p.source_glbs[id]);
  }
  if(has('godot/fighting/main.gd')) {
    for(const path of ['tools/fighting/effects/build.mjs','tools/fighting/effects/sync_content.mjs','tools/fighting/effects/content_contract.json'])add(path,null,true);
    const pipeline=createHash('sha256');
    for(const name of ['recipes.py','glb.py','kinematics.py','pairing.py','content.py','blender_pipeline.py']) {
      pipeline.update(name);pipeline.update(add('tools/fighting/animation/'+name,null,true));
    }
    const pipelineHash=pipeline.digest('hex');
    for(const name of ['roster','rules','schema'])json(`godot/fighting/data/${name}.json`);
    const roster=JSON.parse(read('godot/fighting/data/roster.json'));
    assert.deepEqual(roster.operators.map(o=>o.id).sort(),[...OPERATORS].sort());
    const base='godot/fighting/assets/effects/';
    const manifest=json(base+'manifest.json'),catalog=json(base+'catalog.json');
    assert.equal(catalog.content_roster_sha256,resources['godot/fighting/data/roster.json'],'Fighting FX roster drift');
    const expected=OPERATORS.flatMap(id=>['attack','guard','impact','throw','super','tech'].map(role=>`audio/${id}_${role}.wav`)).sort();
    assert.deepEqual(manifest.files.map(e=>e.file).sort(),expected,'All 54 fighting sounds must be present exactly once');
    for(const entry of manifest.files) {
      const bytes=add(base+entry.file,entry.sha256);
      assert.equal(bytes.length,entry.bytes);assert.equal(bytes.toString('ascii',0,4),'RIFF');
      raw[base+entry.file]=resources[base+entry.file];
    }
    for(const id of OPERATORS) {
      const base=`godot/fighting/assets/operators/${id}`;
      if(!has(base+'.json')||!has(base+'.glb')) {pending.push(id);continue;}
      const m=json(base+'.json');assert.equal(m.version,1);assert.equal(m.operator_id,id);
      assert.equal(m.pipeline_sha256,pipelineHash,`Fighter authoring pipeline drift: ${id}`);
      assert.match(m.master_sha256??'',/^[a-f0-9]{64}$/);
      add(`tools/fighting/animation/masters/${id}.blend`,m.master_sha256,true);
      assert.match(m.source_sha256??'',/^[a-f0-9]{64}$/);
      add(`godot/source_operators/generated/${id}.glb`,m.source_sha256);
      for(const name of ['roster','rules'])assert.equal(m.content_hashes[name],resources[`godot/fighting/data/${name}.json`],`Fighter timing drift: ${id}/${name}`);
      assert.ok(m.clips&&Object.keys(m.clips).length>0,`Missing fighter clips: ${id}`);
      assert.match(m.sha256??'',/^[a-f0-9]{64}$/);assert.equal(m.timing_status,'content_bound',`Draft fighter timing: ${id}`);
      const glb=add(base+'.glb',m.sha256);
      assert.ok(glb.length>=20&&glb.toString('ascii',0,4)==='glTF'&&glb.readUInt32LE(4)===2&&glb.readUInt32LE(8)===glb.length,`Invalid fighting GLB: ${id}`);
      // Current exports are self-contained. A future shared library must be
      // explicitly named here by its committed manifest, never directory-scanned.
      for(const [path,hash]of Object.entries(m.shared_resources??{})) {
        assert.match(path,/^res:\/\/fighting\/assets\/shared\/[a-zA-Z0-9_-]+\.(glb|tres|res|json)$/);
        add('godot/'+path.slice(6),hash);
      }
    }
    if(requireFighters)assert.deepEqual(pending,[],'Final fighting release requires all nine exported operators');
    // Stage catalog hashes this original GLB as well as loading its imported scene.
    const helix='godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb';
    if(has(helix)){add(helix);raw[helix]=resources[helix];}
  }
  return {resources:sorted(resources),provenance:sorted(provenance),raw:sorted(raw),pending};
}
export function readFinalResources(root,options={}) {
  return finalResources({read:path=>readFileSync(join(root,path)),has:path=>existsSync(join(root,path)),...options});
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))
  console.log(JSON.stringify(readFinalResources(resolve(process.argv[2]),{requireFighters:!process.argv.includes('--audit')}),null,2));
