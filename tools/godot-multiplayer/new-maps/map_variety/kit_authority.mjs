import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export function composeKitAuthority(arena) {
  // stampTerrainFloor installs a runtime callback. Candidate authority is data
  // only: do not hash an unserializable function that disappears from JSON.
  delete arena.terrain.height;
  const result=spawnSync('python3',['-B',fileURLToPath(new URL('./source_geometry.py',import.meta.url))],{
    input:JSON.stringify(arena),encoding:'utf8',maxBuffer:32*1024*1024,timeout:30000,
  });
  if(result.status!==0)throw new Error(`Pure Kit geometry capture failed: ${result.stderr||result.error}`);
  const {surfaces,walls}=JSON.parse(result.stdout);
  // New identity also invalidates terrain helpers' WeakMap caches if a recipe
  // queried support while assembling its foundation heights.
  arena.terrain={...arena.terrain,surfaces:[...arena.terrain.surfaces,...surfaces],walls:[...arena.terrain.walls,...walls]};
  arena.art.kitCollisionLineage={surfaces:surfaces.length,walls:walls.length,source:'source_geometry.py / committed Kit methods / pre-bevel conservative boundary'};
  return arena;
}
