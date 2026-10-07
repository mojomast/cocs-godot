// Source-only closure. Promotion receipts must be committed by the parent after
// production/acceptance; the queue's presence or a fallback never grants assets.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {existsSync,readFileSync} from 'node:fs';
import {join,resolve,posix} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {robotImportPaths,verifyRobotImports} from './robot_imports.mjs';
import {vehicleImportPaths,verifyVehicleImports,VEHICLE_EVIDENCE} from './vehicle_imports.mjs';
import {sceneryImportPaths,verifySceneryImports,SCENERY_EVIDENCE} from './scenery_imports.mjs';
import {vesperImportPaths,verifyVesperImports,VESPER_EVIDENCE,VESPER_SUPPORTING_RUNTIME} from './vesper_imports.mjs';
import {abyssalImportPaths,verifyAbyssalImports,ABYSSAL_EVIDENCE,ABYSSAL_SUPPORTING_RUNTIME} from './abyssal_imports.mjs';
import {FEATURE_ROOTS,verifyFeatureAdvance,robotSupportingHash} from './feature_dependencies.mjs';
import {stormglassImportPaths,verifyStormglassImports,verifyStormglassAdvance,STORMGLASS_EVIDENCE,STORMGLASS_SUPPORTING_RUNTIME} from './stormglass_imports.mjs';
import {polishPaths,verifyPolishAdvance,verifyOperatorFinishImports} from './polish_dependencies.mjs';
import {movementSupportingHash,verifyMovementPredecessor} from './movement_dependencies.mjs';
import {verifyVesperApronAdvance} from './vesper_apron_dependencies.mjs';
import {verifyConsolidationAdvance, consolidationSupportingHash} from './consolidation_dependencies.mjs';
export const REQUIREMENTS='tools/godot-package/production_requirements.json';
export const REQUIRED_UNITS=Object.freeze(['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
const skins=['needle_surveyor','caisson_guard','kiln_tender'];
const props=['relay_console','repair_dock','battery_rack','blast_shutter_frame','cargo_stack','cable_junction'];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const sorted=value=>Object.fromEntries(Object.entries(value).sort(([a],[b])=>a.localeCompare(b,'en')));
const equal=(a,b,label)=>assert.deepEqual([...a].sort(),[...b].sort(),label);
const safe=path=>assert.ok(typeof path==='string'&&/^(godot|tools|port|game)\/[a-zA-Z0-9_./-]+$/.test(path)&&!path.split('/').some(p=>p==='..'||p==='.'||p===''),`Invalid production path: ${path}`);
const digest=value=>assert.match(value??'',/^[a-f0-9]{64}$/);
const BUILD_INPUTS={
  robots:['tools/godot-robots/recipe.py','tools/godot-robots/build.py','godot/robot_assets/switchyard/contract.json'],
  vehicles:['tools/godot-vehicle-assets/recipe.mjs','tools/godot-vehicle-assets/build.py'],
  scenery:['tools/godot-biomes/expansion/recipe.mjs','tools/godot-biomes/expansion/meshes.json','tools/godot-biomes/expansion/build.py','godot/biomes/expansion/catalog.json'],
  'parallax-interiors':['build_recipe.py','author_candidate.py','candidate-meshes.json'].map(p=>'tools/godot-multiplayer/new-maps/parallax-observatory/revisions/interiors-v2/'+p),
  'vesper-viaduct':['recipe.mjs','author_blender.py'].map(p=>'tools/godot-multiplayer/new-maps/vesper-viaduct/'+p),
  'abyssal-pressureworks':['recipe.mjs','blender_author.py'].map(p=>'tools/godot-multiplayer/new-maps/abyssal-pressureworks/'+p),
  'stormglass-causeway':['recipe.mjs','blender_export.py'].map(p=>'tools/godot-multiplayer/new-maps/stormglass-causeway/'+p),
};

// Inspect real embedded bytes; a receipt alone cannot assert texture/fingerprint
// identity. Material quality/animation/collision acceptance remains native work.
export function inspectProductionGlb(bytes,fingerprint,{requireFingerprint=true,requireTextures=true}={}) {
  assert.ok(bytes.length>=28&&bytes.toString('ascii',0,4)==='glTF'&&bytes.readUInt32LE(4)===2&&bytes.readUInt32LE(8)===bytes.length,'Invalid production GLB');
  assert.equal(bytes.readUInt32LE(16),0x4e4f534a,'GLB JSON chunk required');
  const length=bytes.readUInt32LE(12),end=20+length;
  assert.ok(end+8<=bytes.length);const doc=JSON.parse(bytes.subarray(20,end));
  assert.equal(bytes.readUInt32LE(end+4),0x004e4942,'Embedded GLB BIN required');
  const bin=bytes.subarray(end+8);assert.equal(bin.length,bytes.readUInt32LE(end));
  for(const buffer of doc.buffers??[])assert.ok(!buffer.uri,'External GLB buffer rejected');
  const textures=(doc.images??[]).map(image=>{
    assert.ok(image.bufferView!==undefined&&!image.uri,'Embedded texture required');
    const view=doc.bufferViews?.[image.bufferView];assert.ok(view&&Number.isInteger(view.byteLength)&&view.byteLength>0);
    const start=view.byteOffset??0;assert.ok(Number.isInteger(start)&&start>=0&&start+view.byteLength<=bin.length,'Invalid embedded texture range');
    return {name:image.name??'',bytes:view.byteLength,sha256:hash(bin.subarray(start,start+view.byteLength))};
  });
  if(requireTextures)assert.ok(textures.length,'Production GLB has no embedded textures');
  let meshes=0;
  for(const node of doc.nodes??[])if(node.mesh!==undefined) {
    meshes++;
    if(requireFingerprint)assert.equal(node.extras?.asset_source_fingerprint,fingerprint,'Stale production helper/recipe fingerprint');
  }
  assert.ok(meshes,'Production GLB has no mesh nodes');
  return textures;
}

function specification(unit,read) {
  const id=unit.id,inputs=[...unit.recipePaths],masters=[],exports=[],extra=[];
  if(id==='robots') {
    for(const name of [...skins,...props]){masters.push(`tools/godot-robots/masters/${name}.blend`);exports.push(`godot/robot_assets/switchyard/generated/${name}.glb`);}
    extra.push(...skins.map(name=>`tools/godot-robots/masters/${name}_skeletal.glb`),'godot/robot_assets/switchyard/generated/build-receipt.json','tools/godot-robots/generated/recipe.json');
    extra.push(...robotImportPaths(exports),'tools/godot-robots/production-d.json','godot/biomes/expansion/scenery_pack.gd');
    inputs.push('tools/godot-robots/verify_blender.py','godot/robot_assets/switchyard/skin_adapter.gd');
    const contract=JSON.parse(read('godot/robot_assets/switchyard/contract.json'));
    inputs.push(...Object.keys(contract.source));
  } else if(id==='vehicles') {
    for(const kind of ['puma','titan','scout'])for(let lod=0;lod<3;lod++) {
      const stem=`${kind}-lod${lod}`;masters.push(`tools/godot-vehicle-assets/masters/${stem}.blend`);
      exports.push(`godot/vehicle_assets/generated/${stem}.glb`);
      extra.push(`tools/godot-vehicle-assets/generated/${stem}.json`,`tools/godot-vehicle-assets/masters/${stem}-report.json`);
    }
    inputs.push('tools/godot-vehicle-assets/write-recipes.mjs','godot/vehicle_assets/attachment.gd','godot/vehicles/puma.gd','godot/vehicles/renderer.gd','godot/combined_arms/chassis.gd','godot/combined_arms/fleet.gd','game/vehicles.mjs');
    extra.push(...vehicleImportPaths(exports),...VEHICLE_EVIDENCE);
  } else if(id==='scenery') {
    const catalog=JSON.parse(read('godot/biomes/expansion/catalog.json'));
    const ids=Object.values(catalog.chapters).flatMap(c=>c.placements.map(p=>p.asset));
    assert.equal(ids.length,12);assert.equal(new Set(ids).size,12);
    for(const name of ids){assert.match(name,/^[a-z0-9-]+$/);masters.push(`tools/godot-biomes/expansion/masters/${name}.blend`);for(let lod=0;lod<2;lod++)exports.push(`godot/biomes/expansion/art/${name}-${lod}.glb`);}
    inputs.push('tools/godot-biomes/expansion/compile.mjs','tools/godot-biomes/expansion/reopen.py','port/edge-effects/structure-faces.json','godot/biomes/expansion/scenery_pack.gd','godot/campaign/terrain.gd',...Object.keys(catalog.chapters).map(ch=>`godot/campaign/generated/${ch}.json`));
    extra.push(...sceneryImportPaths(exports,read),...SCENERY_EVIDENCE);
  } else if(id==='parallax-interiors') {
    const base='tools/godot-multiplayer/new-maps/parallax-observatory/';
    masters.push(base+'revisions/interiors-v2/output/parallax-observatory.blend');
    exports.push('godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb');
    inputs.push(base+'blender_author.py',base+'parallax-observatory.blend',base+'revisions/interiors-v2/reopen_candidate.py',base+'revisions/interiors-v2/source-check.json','godot/multiplayer_worlds/generated/parallax-observatory.json',...['binder.gd','profile.gd','surface.gd','surface.gdshader','profiles/parallax-observatory.json'].map(p=>'godot/multiplayer_worlds/dressing/'+p));
    const evidencePath='port/new-maps/parallax-observatory/production-c.json';
    const evidence=JSON.parse(read(evidencePath));
    inputs.push(evidencePath,...Object.keys(evidence.inputHashes),...Object.keys(evidence.runtimeHooks).filter(p=>!p.startsWith('godot/tests/')),
      'godot/multiplayer_worlds/catalog.gd','port/multiplayer-worlds/catalog.mjs',
      'godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb.import');
  } else {
    const base=`tools/godot-multiplayer/new-maps/${id}/`;
    masters.push(base+(id==='stormglass-causeway'?'':'masters/')+id+'.blend');
    exports.push(`godot/multiplayer_worlds/art/worlds/${id}.glb`);
    inputs.push(base+'build.mjs',`port/native-multiplayer-worlds/worlds/${id}.json`,`godot/multiplayer_worlds/generated/${id}.json`);
    if(id==='vesper-viaduct')extra.push(...vesperImportPaths(),...VESPER_EVIDENCE,'godot/multiplayer_worlds/catalog.gd','port/multiplayer-worlds/catalog.mjs');
    if(id==='abyssal-pressureworks')extra.push(...abyssalImportPaths(),...ABYSSAL_EVIDENCE,'godot/multiplayer_worlds/catalog.gd','port/multiplayer-worlds/catalog.mjs','godot/multiplayer_worlds/abyssal_presentation.gd');
    if(id==='stormglass-causeway')extra.push(...stormglassImportPaths(),...STORMGLASS_EVIDENCE,base+'architecture.py','godot/multiplayer_worlds/catalog.gd','port/multiplayer-worlds/catalog.mjs');
  }
  return {inputs:[...new Set(inputs)].sort(),masters:masters.sort(),exports:exports.sort(),extra:extra.sort()};
}

function helperClosure(paths,read,has) {
  const seen=new Set(),todo=[...paths];
  while(todo.length) {
    const path=todo.pop();safe(path);if(seen.has(path))continue;seen.add(path);
    if(!has(path))continue;
    const source=/\.(mjs|gd|tscn|tres|gdshader|gdshaderinc)$/.test(path)?read(path).toString():'';
    if(path.endsWith('.mjs'))for(const m of source.matchAll(/\b(?:from\s*|import\s*)['"](\.[^'"]+)['"]/g)){
      // This exact generator output template is covered by core.generated.mjs,
      // an explicit root. All actual literal imports keep strict path checks.
      if(path==='port/native-campaign/generate-core.mjs'&&m[1]==='../../game/${file}')continue;
      todo.push(posix.normalize(posix.join(posix.dirname(path),m[1])));
    }
    if(path.endsWith('.gd')) {
      for(const m of source.matchAll(/(?:preload|load)\("res:\/\/([^"%{}]+)"\)/g))todo.push('godot/'+m[1]);
      for(const m of source.matchAll(/^extends\s+"res:\/\/([^"%{}]+)"/gm))todo.push('godot/'+m[1]);
    }
    if(/\.(tscn|tres)$/.test(path))for(const m of source.matchAll(/\[ext_resource\b[^\]\n]*\bpath="res:\/\/([^"%{}]+)"/g))todo.push('godot/'+m[1]);
    if(/\.(gdshader|gdshaderinc)$/.test(path))for(const m of source.matchAll(/^\s*#include\s+"res:\/\/([^"%{}]+)"/gm))todo.push('godot/'+m[1]);
  }
  return [...seen].sort();
}

export function productionResources({read,has,worldIds=[],strict=true}) {
  const resources={},provenance={},raw={},pending=[],units={};
  const add=(path,expected=null)=>{
    safe(path);const bytes=read(path),sha=hash(bytes);
    if(expected!==null){digest(expected);assert.equal(sha,expected,`Production content hash mismatch: ${path}`);}
    (path.startsWith('godot/')&&!path.endsWith('.import')?resources:provenance)[path]=sha;return bytes;
  };
  const requirements=JSON.parse(add(REQUIREMENTS));assert.equal(requirements.version,1);
  assert.equal(requirements.plan,'port/finish/ASSET_PRODUCTION.json');
  equal(Object.keys(requirements.units),REQUIRED_UNITS,'Dropped or unknown required production unit');
  const plan=JSON.parse(add(requirements.plan));assert.equal(plan.version,1);
  assert.equal(plan.common.finishScript,'tools/asset-production/moth_finish.py','Reviewed common finish helper required');
  equal(plan.units.map(u=>u.id),REQUIRED_UNITS,'Production plan lost a required unit');
  for(const unit of plan.units) {
    assert.equal(Boolean(unit.external),unit.id==='parallax-interiors','Only isolated Parallax uses external authoring');
    for(const path of BUILD_INPUTS[unit.id])assert.ok(unit.recipePaths.includes(path),`Required builder/recipe dropped: ${path}`);
    const requirement=requirements.units[unit.id];assert.equal(requirement.required,true,'Required production unit cannot be disabled');
    assert.ok(requirement.promotion===null||(requirement.promotion&&typeof requirement.promotion==='object'&&!Array.isArray(requirement.promotion)),'Explicit promotion identity or null required');
    const expectedMap=unit.id==='parallax-interiors'?'parallax-observatory':['robots','vehicles','scenery'].includes(unit.id)?undefined:unit.id;
    assert.equal(requirement.map,expectedMap,'Production map identity changed');
    const missing=[];let spec;
    // External Parallax recipes are not read from its active worktree. Pending
    // absence is reported until parent imports reviewed committed revision bytes.
    try {spec=specification(unit,read);}catch(error){if(requirement.promotion)throw error;missing.push('specification: '+error.message);spec={inputs:unit.recipePaths,masters:[],exports:[],extra:[]};}
    // The first-person weapon export manifest joins the moth generated/derived
    // manifests as an explicit root. It is a shipped generated export, so the
    // receipts must own the exported byte itself: it declares 21 source shas, but
    // only 4 of them are declared package inputs -- game/data.mjs,
    // game/sights.mjs, game/reticle.mjs and the game/weapon-ads.mjs byte whose
    // drift forced the re-export -- and the remaining 17 (the weapon-model modules
    // plus the detail/handling exporters) are pinned only by the manifest's own
    // table. The export was unowned because the manifest was not a closure root, not
    // because its sources were: godot/first_person/generated/catalog.gd and
    // finishes.gd reach the closure transitively through rig.gd's preloads, while
    // the manifest is never preloaded, so it has to be named here.
    const inputs=helperClosure([...spec.inputs,...spec.extra,...FEATURE_ROOTS,...polishPaths(read),'godot/replay/stage.gd',plan.common.finishScript,'tools/asset-production/receipt.mjs','tools/asset-production/reopen.py','godot/moth/generated/manifest.json','godot/moth/derived/manifest.json','godot/first_person/generated/manifest.json','game/moth-baked.mjs'],read,has);
    spec.packageInputs=inputs;
    for(const path of [...inputs,...spec.masters,...spec.exports]){safe(path);if(!has(path))missing.push(path);}
    const registered=!expectedMap||worldIds.includes(expectedMap);
    const promotion=requirement.promotion;
    units[unit.id]={registered,promoted:promotion!==null,missing,expected:spec};
    if(!promotion||!registered||missing.length){pending.push(unit.id);continue;}
    assert.equal(promotion.receipt,`tools/godot-package/production_receipts/${unit.id}.json`,'Promotion receipt must have its fixed committed path');
    const receipt=JSON.parse(add(promotion.receipt,promotion.sha256));assert.equal(receipt.unit,unit.id);
    verifyPolishAdvance(receipt,read);
    verifyStormglassAdvance(receipt);
    if(['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks'].includes(unit.id))verifyFeatureAdvance(receipt);
    if(unit.id==='parallax-interiors') {
      const evidence=JSON.parse(read('port/new-maps/parallax-observatory/production-c.json'));
      for(const [path,sha]of Object.entries(evidence.inputHashes))add(path,sha);
      for(const [path,sha]of Object.entries(evidence.runtimeHooks))if(!path.startsWith('godot/tests/')) {
        let expected=sha;
        for(const [record,policy]of [[receipt.vesperPackageVerifierAdvance,VESPER_SUPPORTING_RUNTIME],[receipt.abyssalPackageVerifierAdvance,ABYSSAL_SUPPORTING_RUNTIME],[receipt.stormglassPackageVerifierAdvance,STORMGLASS_SUPPORTING_RUNTIME]]) {
          const advance=record?.runtimeChanged?.[path];
          if(!advance)continue;
          assert.deepEqual(advance,policy[path],'Unreviewed supporting runtime advance');
          assert.equal(advance.before,expected,'Broken Parallax native-to-supporting history');
          expected=advance.after;
        }
        const dressing=receipt.dressingAdvance?.runtimeChanged?.[path];
        if(dressing){
          assert.equal(dressing.before,expected,'Broken Parallax dressing history');
          expected=dressing.after;
        }
        // The apron lane is newer than dressing, and it moved profile.gd too.
        const apron=receipt.vesperApronAdvance?.runtimeChanged?.[path];
        if(apron){
          assert.equal(apron.before,expected,'Broken Parallax apron history');
          expected=apron.after;
        }
        assert.equal(receipt.runtimeHooks[path],expected,'Production content hash mismatch: '+path);add(path,expected);
      }
      assert.deepEqual(receipt.masters,evidence.masters,'Parallax production master identity');
      assert.deepEqual(receipt.exports,evidence.exports,'Parallax production export identity');
      assert.ok(receipt.rawFiles?.includes(spec.exports[0]),'Parallax native audit requires raw GLB bytes');
    }
    equal(Object.keys(receipt.packageInputs??{}),inputs,'Incomplete production packageInputs');
    for(const path of inputs)add(path,receipt.packageInputs[path]);
    const fingerprintInputs=Object.fromEntries([...unit.recipePaths,plan.common.finishScript].sort().map(p=>[p,hash(read(p))]));
    assert.deepEqual(receipt.sourceHashes,fingerprintInputs,'Stale declared production source hashes');
    const fingerprint=hash(JSON.stringify(fingerprintInputs));assert.equal(receipt.sourceFingerprint,fingerprint,'Stale declared source fingerprint');
    for(const [field,paths]of [['masters',spec.masters],['exports',spec.exports]]) {
      assert.ok(Array.isArray(receipt[field]));equal(receipt[field].map(r=>r.path),paths,`Missing required ${unit.id} ${field}`);
      for(const row of receipt[field]) {
        const bytes=add(row.path,row.sha256);
        if(field==='exports') {
          // Committed Parallax authoring uses material batches plus native Moth
          // dressing, not the local finish_scene/embedded-image pipeline.
          const textures=inspectProductionGlb(bytes,fingerprint,{requireFingerprint:!unit.external,requireTextures:!unit.external});
          assert.deepEqual(row.textures,textures,'Stale declared embedded texture identities');
        }
      }
    }
    assert.ok(receipt.runtimeHooks&&Object.keys(receipt.runtimeHooks).length,'Promoted unit requires committed activation/placement hooks');
    for(const [path,sha]of Object.entries(receipt.runtimeHooks)) {
      assert.match(path,/^godot\/(?!tests\/).+\.(gd|gdshader|json)$/);
      add(path,receipt.movementAdvance.runtimeChanged[path]?movementSupportingHash(path,sha,read):sha);
    }
    // No builder currently performs raw reads of these GLBs. Future raw reads
    // must name an already-declared resource, never an arbitrary extra file.
    assert.ok(Array.isArray(receipt.rawFiles),'Explicit rawFiles inventory required');
    assert.equal(new Set(receipt.rawFiles).size,receipt.rawFiles.length,'Duplicate production raw path');
    for(const path of receipt.rawFiles){assert.ok(Object.hasOwn(resources,path),'Undeclared production raw path');raw[path]=resources[path];}
    if(unit.id==='scenery') {
      verifySceneryImports(spec.exports,read);
      const catalog=JSON.parse(read('godot/biomes/expansion/catalog.json'));
      assert.equal(catalog.recipeSha256,hash(read('tools/godot-biomes/expansion/meshes.json')),'Stale scenery mesh recipe');
      for(const [id,c]of Object.entries(catalog.chapters))assert.equal(c.recipeSha256,hash(read(`godot/campaign/generated/${id}.json`)),'Stale scenery chapter binding');
    }
    if(unit.id==='robots') {
      verifyRobotImports(spec.exports,read);
      const contract=JSON.parse(read('godot/robot_assets/switchyard/contract.json'));
      for(const [path,sha]of Object.entries(contract.source))add(path,consolidationSupportingHash(path,movementSupportingHash(path,robotSupportingHash(path,sha,receipt,read),read),receipt));
      const built=JSON.parse(read('godot/robot_assets/switchyard/generated/build-receipt.json'));
      // Archive the exact Python json.dumps(manifest(), sort_keys=True) bytes
      // used by the builder, so verification needs no Python/Blender on Windows.
      assert.equal(built.recipeSHA256,hash(read('tools/godot-robots/generated/recipe.json')),'Stale declared robot recipe hash');
      assert.equal(built.generatorSHA256,hash(read('tools/godot-robots/build.py')),'Stale robot builder');
      equal(Object.keys(built.assets),[...skins,...props],'Incomplete robot builder receipt');
      for(const [name,row]of Object.entries(built.assets))assert.equal(row.sha256,resources[`godot/robot_assets/switchyard/generated/${name}.glb`],'Stale robot export receipt');
    }
    if(unit.id==='vehicles')verifyVehicleImports(spec.exports,read);
    if(unit.id==='vesper-viaduct')verifyVesperImports(read);
    if(unit.id==='abyssal-pressureworks')verifyAbyssalImports(read);
    if(unit.id==='stormglass-causeway')verifyStormglassImports(read,receipt);
    verifyConsolidationAdvance(receipt,read);
    verifyVesperApronAdvance(receipt,read);
    verifyMovementPredecessor(receipt,read);
    if(unit.id==='vehicles')for(const kind of ['puma','titan','scout'])for(let lod=0;lod<3;lod++) {
      const stem=`${kind}-lod${lod}`,report=JSON.parse(read(`tools/godot-vehicle-assets/masters/${stem}-report.json`));
      assert.equal(report.kind,kind);assert.equal(report.lod,lod);
      assert.equal(report.recipe_sha256,hash(read(`tools/godot-vehicle-assets/generated/${stem}.json`)),'Stale vehicle recipe');
    }
  }
  // Private shader is an actual preload dependency, not a new route/acceptance.
  if(!pending.length)verifyOperatorFinishImports(read);
  if(has('godot/multiplayer_worlds/dressing/surface.gd')) {
    add('godot/multiplayer_worlds/dressing/surface.gd');
    add('godot/multiplayer_worlds/dressing/surface.gdshader');
  }
  if(strict)assert.deepEqual(pending,[],'Required final production units remain pending');
  return {resources:sorted(resources),provenance:sorted(provenance),raw:sorted(raw),pending,units};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const root=resolve(process.argv[2]);const {WORLDS}=await import(pathToFileURL(join(root,'port/multiplayer-worlds/catalog.mjs')));
  console.log(JSON.stringify(productionResources({read:p=>readFileSync(join(root,p)),has:p=>existsSync(join(root,p)),worldIds:Object.keys(WORLDS),strict:!process.argv.includes('--audit')}),null,2));
}
