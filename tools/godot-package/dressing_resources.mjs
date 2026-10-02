// Optional authored finish JSON is a dynamic FileAccess read, not an imported
// resource. Only registered worlds grant export eligibility; profiles add no route.
import {readFileSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import assert from 'node:assert/strict';
export const DRESSING_IDS = Object.freeze(['helix-conservatory','gravemill-foundry','parallax-observatory']);
export function dressingResources(root, worlds) {
  const files=[];
  for (const id of DRESSING_IDS) {
    if (!Object.hasOwn(worlds,id)) continue;
    const path=`godot/multiplayer_worlds/dressing/profiles/${id}.json`;
    if (!existsSync(join(root,path))) continue;
    const p=JSON.parse(readFileSync(join(root,path),'utf8'));
    const data=JSON.parse(readFileSync(join(root,`godot/multiplayer_worlds/generated/${id}.json`),'utf8'));
    assert.ok(p.version===1 && p.map_id===id && p.geometry_hash===data.geometryHash,`Dressing identity mismatch: ${id}`);
    files.push(path);
  }
  return files;
}
