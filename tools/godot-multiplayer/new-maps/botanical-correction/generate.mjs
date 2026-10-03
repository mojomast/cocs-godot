// Pure successor source generation. U source/artifacts are read-only inputs.
import {mkdirSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {makeRecipe as parallax} from '../parallax-observatory/revisions/districts-v4/recipe-v4.mjs';
import {makeRecipe as vesper} from '../vesper-viaduct/revisions/urban-v3/recipe-v3.mjs';
import {makeRecipe as helix} from '../helix-conservatory/recipe-v4.mjs';
import {loadPack,validateBindings,auditArena,writeCandidate,readJson,REPO_ROOT} from '../map_variety/variety_lib.mjs';
import {auditPhysicalRoutes} from '../map_variety/navigation_audit.mjs';
export const candidates=[
  {id:'helix-conservatory',prior:'revision-3',revision:'revision-4',make:helix},
  {id:'parallax-observatory',prior:'districts-v3',revision:'districts-v4',make:parallax},
  {id:'vesper-viaduct',prior:'urban-v2',revision:'urban-v3',make:vesper},
];
export function generate(c) {
  const bindingPath=c.id==='helix-conservatory'?'tools/godot-multiplayer/new-maps/helix-conservatory/variety_bindings.json':
    `tools/godot-multiplayer/new-maps/${c.id}/revisions/${c.prior}/variety_bindings.json`;
  const bindings=readJson(bindingPath);
  bindings.revision=c.revision;
  const pack=loadPack(bindings.pack);validateBindings(c.id,bindings,pack);
  const arena=c.make();
  const routes=arena.routes.filter(r=>arena.verification.varietyRouteIds.includes(r.id));
  const audit=auditArena(arena,{bindings,pack,clearance:.5,label:c.id,routes,visualCongruence:false});
  const prior=readJson(`port/new-maps/${c.id}/variety/${c.prior}/authority.json`);
  const physical=auditPhysicalRoutes(arena,prior.arena);
  audit.failures.push(...physical.failures.map(f=>JSON.stringify(f)));
  if(audit.failures.length)throw new Error(c.id+' '+audit.failures.join('\n'));
  const out=resolve(REPO_ROOT,`port/new-maps/${c.id}/variety/${c.revision}`);
  mkdirSync(out,{recursive:true});
  const write=(path,value)=>writeFileSync(path,JSON.stringify(value,null,2)+'\n');
  write(resolve(out,'authority.json'),audit.authority);
  write(resolve(out,'recipe.json'),arena);
  write(resolve(out,'bindings.json'),bindings);
  write(resolve(out,'candidate.json'),writeCandidate({mapId:c.id,revision:c.revision,authority:audit.authority,bindings,pack,
    report:{status:'source-only; actual successor build/native pending'}}));
  write(resolve(out,'source-report.json'),{map:c.id,revision:c.revision,predecessor:prior.geometryHash,
    geometryHash:audit.geometryHash,recipeHash:audit.authority.recipeHash,physical,
    status:'source-only; U native acceptance does not apply',glbSha256:null,masterSha256:null});
  console.log(c.id,c.revision,audit.geometryHash,'source routes pass');
  return {arena,audit};
}
if(import.meta.url===`file://${process.argv[1]}`)for(const c of candidates)generate(c);
