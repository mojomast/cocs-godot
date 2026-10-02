// Explicit revision-three promotion, after archiving the functional checkpoint.
import fs from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('../../../../../',import.meta.url),candidate=JSON.parse(fs.readFileSync(new URL('candidate.json',import.meta.url)));
const archive='/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/revision3-production/checkpoint-afbe57dc';
for(const asset of JSON.parse(fs.readFileSync(`${archive}/manifest.json`))){const digest=createHash('sha256').update(fs.readFileSync(`${archive}/${asset.path}`)).digest('hex');if(digest!==asset.sha256)throw Error('Checkpoint archive damaged');}
for(const [from,to] of [
 ['arena.json','port/native-multiplayer-worlds/worlds/gravemill-foundry.json'],
 ['arena.json','godot/multiplayer_worlds/generated/worlds/gravemill-foundry.json'],
 ['candidate.json','godot/multiplayer_worlds/generated/gravemill-foundry.json'],
 ['probes.json','godot/tests/new_maps/gravemill_foundry/probes.json'],
 ['art/gravemill-foundry.glb','godot/multiplayer_worlds/art/worlds/gravemill-foundry.glb'],
 ['gravemill-foundry.blend','tools/godot-multiplayer/new-maps/gravemill-foundry/gravemill-foundry.blend']
])fs.copyFileSync(new URL(from,import.meta.url),new URL(to,root));
console.log('PROMOTED',candidate.geometryHash,'; original runtime assets retained in read-only checkpoint archive and afbe57dc');
