// Explicitly authorized diagnostic only: cold full-map navigation is heavy.
// Independent child processes prevent original/candidate floor-cache warming.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const map=process.argv[2];
assert.ok(map&&/^[a-z0-9-]+$/.test(map),'Usage: node compare_navigation.mjs <registered-map>');
if(process.argv[3]==='--worker'){
  const variant=process.argv[4];assert.ok(['original','candidate'].includes(variant));
  const {readWorld}=await import('../../port/multiplayer-worlds/catalog.mjs');
  const {navigation}=await import(variant==='original'?'../../game/core.mjs':'../../port/multiplayer-worlds/derived/core.mjs');
  const {arena,geometryHash}=readWorld(map),start=performance.now();
  const graph=navigation(arena),elapsedMs=performance.now()-start;
  console.log(JSON.stringify({map,variant,geometryHash,elapsedMs,nodes:graph.nodes.length,
    edges:graph.edges.reduce((n,e)=>n+e.length,0),orderedGraphSha256:createHash('sha256').update(JSON.stringify(graph)).digest('hex')}));
}else{
  assert.equal(process.argv.length,3,'Unexpected options');
  const reports=['original','candidate'].map(variant=>{
    const run=spawnSync(process.execPath,[fileURLToPath(import.meta.url),map,'--worker',variant],
      {encoding:'utf8',timeout:60000,maxBuffer:1024*1024});
    assert.equal(run.status,0,`${variant}: ${run.error??run.stderr}`);
    return JSON.parse(run.stdout);
  });
  console.log(JSON.stringify({scope:'cold source graph comparison; not native acceptance',reports},null,2));
  assert.equal(reports[0].geometryHash,reports[1].geometryHash);
  assert.equal(reports[0].orderedGraphSha256,reports[1].orderedGraphSha256,'Navigation contents/order changed');
}
