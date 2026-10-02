import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {terrainSupportAt, terrainTriangles, terrainWallTriangles} from '../../game/terrain.mjs';

// World lane adds entries here after its per-mode authority/geometry audit.
export const WORLDS = Object.freeze({
  'parallax-observatory':Object.freeze({name:'Parallax Observatory',modes:Object.freeze(['deathmatch','teamdeathmatch','ctf','koth','uplink','holdout'])}),
  'switchyard-ward':Object.freeze({name:'Switchyard Ward',modes:Object.freeze(['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'])}),
  'rainmarket-exchange':Object.freeze({name:'Rainmarket Exchange',modes:Object.freeze(['deathmatch','teamdeathmatch','instagib','rockets','armsrace','domination','koth','uplink','holdout','assault','payload'])}),
  'breakwater-exchange':Object.freeze({name:'Breakwater Exchange',modes:Object.freeze(['deathmatch','teamdeathmatch','domination','assault','payload','combined-arms'])}),
  'thermal-divide':Object.freeze({name:'Thermal Divide',modes:Object.freeze(['deathmatch','teamdeathmatch','instagib','rockets','armsrace','ctf','domination','koth','uplink','holdout','assault'])}),
  'sirocco-circuit':Object.freeze({name:'Sirocco Circuit',modes:Object.freeze(['puma-race'])}),
  'copper-bowl':Object.freeze({name:'Copper Bowl',modes:Object.freeze(['puma-soccer'])}),
  'tern-archipelago':Object.freeze({name:'Tern Archipelago',modes:Object.freeze(['cocs','cocs-coop'])}),
});
export const worldEntry = (id,mode) => {
  const entry=Object.hasOwn(WORLDS,id)?WORLDS[id]:null;
  if(!entry || mode!==undefined && !entry.modes.includes(mode)) throw new TypeError(`Unsupported multiplayer world/mode: ${id}/${mode}`);
  return entry;
};
export function canonical(value){
  if(Array.isArray(value))return `[${value.map(canonical).join(',')}]`;
  if(value&&typeof value==='object')return `{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
export function readWorld(id){
  worldEntry(id);
  const data=JSON.parse(readFileSync(new URL(`../../godot/multiplayer_worlds/generated/${id}.json`,import.meta.url),'utf8'));
  if(data.schemaVersion!==1||data.id!==id||data.name!==WORLDS[id].name||data.arena?.id!==id||data.arena?.name!==data.name)throw Error('Multiplayer world identity mismatch');
  const a=data.arena,hash=createHash('sha256').update(canonical(a)).digest('hex');
  if(data.geometryHash!==hash)throw Error('Multiplayer geometry hash mismatch');
  if(!Array.isArray(a.terrain?.surfaces)||!Array.isArray(a.terrain?.walls)||!Array.isArray(a.blocks)||!Array.isArray(a.navNodes)||!Array.isArray(a.spawns)||!Array.isArray(data.spawnPoints))throw Error('World geometry incomplete');
  terrainTriangles(a.terrain);terrainWallTriangles(a.terrain);
  const support=(x,z)=>terrainSupportAt(x,z,a.terrain,a.terrain.maxSlope)?.y;
  for(const [i,[x,z]] of a.spawns.entries()) {
    const y=support(x,z),p=data.spawnPoints[i];
    if(!Number.isFinite(y)||y<=a.voidY||p?.x!==x||p?.z!==z||Math.abs(p.y-y)>.15)throw Error(`Unsupported spawn ${i}`);
  }
  for(const zone of a.objectiveZones??[])if(!Number.isFinite(support(zone.x,zone.z))||Math.abs(zone.y-support(zone.x,zone.z))>.15)throw Error(`Unsupported objective ${zone.id}`);
  for(const [team,pool] of Object.entries(a.teamSpawns??{}))for(const [x,z] of pool)if(!Number.isFinite(support(x,z)))throw Error(`Unsupported team spawn ${team}`);
  for(const p of Object.values(a.flagSpawns??{}))if(!Number.isFinite(support(p.x,p.z)))throw Error('Unsupported flag');
  return data;
}
export function worldRace(id){return readWorld(id).arena.race;}
