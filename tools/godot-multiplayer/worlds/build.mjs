// Cheap deterministic recipe export. Blender is a separate, explicitly invoked step.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {WORLD_RECIPES} from './recipes.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const dest=path.join(root,'godot/multiplayer_worlds/generated/worlds');
const authored=path.join(root,'port/native-multiplayer-worlds/worlds');
const stable=value=>JSON.stringify(value);
for(const dir of [dest,authored])fs.mkdirSync(dir,{recursive:true});
const manifest={schemaVersion:1,format:'source-compatible map recipe + deterministic Blender art',maps:[]};
for(const map of WORLD_RECIPES){
  const body=stable(map)+'\n';
  const sha256=crypto.createHash('sha256').update(body).digest('hex');
  fs.writeFileSync(path.join(authored,`${map.id}.json`),body);
  fs.writeFileSync(path.join(dest,`${map.id}.json`),body);
  manifest.maps.push({id:map.id,sha256,modes:map.modeBindings,visual:`res://multiplayer_worlds/art/worlds/${map.id}.glb`,
    authority:`port/native-multiplayer-worlds/worlds/${map.id}.json`});
  console.log(`${map.id} ${sha256.slice(0,12)} blocks=${map.blocks.length} nav=${map.navNodes.length} pieces=${map.art.pieces.length}`);
}
fs.writeFileSync(path.join(authored,'manifest.json'),stable(manifest)+'\n');
fs.writeFileSync(path.join(dest,'manifest.json'),stable(manifest)+'\n');
