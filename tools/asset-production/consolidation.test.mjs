import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {canonical,worldEntry} from '../../port/multiplayer-worlds/catalog.mjs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const plan=JSON.parse(read('port/finish/ASSET_PRODUCTION.json'));
const hashes=new Map([['vesper-viaduct','9b1d8b86'],['abyssal-pressureworks','67f79981'],['stormglass-causeway','e723b2fd']]);
test('candidate registration is fail closed and wrapper hashes match the CURRENT loader API',()=>{
  for(const [id,commit] of hashes){
    const data=JSON.parse(read(`godot/multiplayer_worlds/generated/${id}.json`));
    assert.deepEqual(data.arena.modeBindings,{});
    const unit=plan.units.find(u=>u.id===id);
    assert.deepEqual(data.arena.candidateModes,unit.candidateModes);
    for(const mode of unit.candidateModes)assert.throws(()=>worldEntry(id,mode));
    assert.equal(createHash('sha256').update(canonical(data.arena)).digest('hex'),data.geometryHash);
    const old=JSON.parse(execFileSync('git',['show',`${commit}:port/native-multiplayer-worlds/worlds/${id}.json`],{encoding:'utf8',maxBuffer:64*1024*1024}));
    const current=structuredClone(data.arena);
    for(const value of [old,current]){delete value.modeBindings;delete value.candidateModes;}
    assert.deepEqual(current,old,`${id}: only admission metadata may differ from source checkpoint`);
  }
});
test('frozen authority and accepted catalogs remain identical to canonical main',()=>{
  assert.equal(execFileSync('git',['diff','e38b3662','--','game/','port/contracts/source-lock.json','port/multiplayer-worlds/catalog.mjs','godot/source_operators/moth_finish/','godot/material_language/','godot/multiplayer_worlds/dressing/'],{encoding:'utf8'}),'');
});
test('complete bounded queue preserves every owner-requested asset unit and external Parallax ownership',()=>{
  assert.deepEqual(plan.units.map(u=>u.id),['parallax-interiors','robots','vehicles','scenery','vesper-viaduct','abyssal-pressureworks','stormglass-causeway']);
  assert.equal(plan.units[0].external,true);assert.deepEqual(plan.units[0].commands,[]);
  for(const unit of plan.units.filter(u=>!u.external)){
    assert.ok(unit.configuredTriangleCap>0);assert.equal(unit.measuredTriangles,null);
    assert.ok(unit.gates.length>=4);assert.ok(unit.nextAssets&&unit.nextCapture);
    for(const command of unit.commands){assert.ok(command.timeoutSeconds>0&&command.timeoutSeconds<=1800);for(const arg of command.argv){
      if(arg.endsWith('.py')||arg.endsWith('.mjs')||arg.endsWith('.gd'))assert.ok(existsSync(arg.startsWith('res://')?'godot/'+arg.slice(6):arg),arg);
    }}
  }
});
test('all queued builders call the bounded actual-Moth UV finish; no map shader on moving assets',()=>{
  const builders=plan.units.filter(u=>!u.external).flatMap(u=>u.recipePaths.filter(p=>p.endsWith('.py')&&!p.endsWith('recipe.py')));
  for(const path of builders)assert.match(read(path),/finish_scene\(/,path);
  const helper=read(plan.common.finishScript);
  assert.match(helper,/moth\/generated\/manifest\.json/);
  assert.match(helper,/attachment-local/);
  assert.match(helper,/uv_layers/);
  for(const path of ['godot/vehicle_assets/attachment.gd','godot/robot_assets/switchyard/skin_adapter.gd'])assert.doesNotMatch(read(path),/material_language\/family.gdshader|dressing\/surface.gd/);
  assert.match(read('tools/godot-multiplayer/new-maps/vesper-viaduct/author_blender.py'),/ART = ROOT \/ 'godot\/multiplayer_worlds\/art\/worlds'/);
});
