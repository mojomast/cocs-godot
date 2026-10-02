// Validate accepted standalone canonical wrappers without feeding them through
// the legacy overhead baker (which would duplicate already-complete slabs).
import {readFileSync,existsSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {worldClosure,worldArt} from './world_closure.mjs';
import assert from 'node:assert/strict';
export async function worldResources(root) {
  const {WORLDS,readWorld}=await import(pathToFileURL(join(root,'port/multiplayer-worlds/catalog.mjs')));
  const data=worldClosure(WORLDS), paths=[];
  for (const path of data) {
    const id=path.split('/').at(-1).slice(0,-5);
    // readWorld checks identity, canonical arena hash and terrain/spawn support.
    const before=readFileSync(join(root,path));
    readWorld(id);
    assert.ok(before.equals(readFileSync(join(root,path))),`World validation changed ${id}`);
    const art='godot/'+worldArt(id).slice('res://'.length);
    assert.ok(existsSync(join(root,art)),`Accepted world art missing: ${art}`);
    paths.push(path,art);
  }
  return paths;
}
if (process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) console.log(JSON.stringify(await worldResources(resolve(process.argv[2]))));
