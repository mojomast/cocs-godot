import {Match, floorAt, obstructed} from '../../game/core.mjs';
import {readFileSync} from 'node:fs';
import {nativeArenaGeometryHash} from '../native-arenas/schema.mjs';
export const CATALOG=Object.freeze({'lacuna-court':'deathmatch','vermilion-fold':'domination','nacre-engine':'horde'});
export function loadRecipe(id){
 if(!Object.hasOwn(CATALOG,id))throw Error('Unknown identity map');
 const r=JSON.parse(readFileSync(new URL(`../../godot/identity_maps/generated/${id}.json`,import.meta.url)));
 if(r.schemaVersion!==1||r.id!==id||r.arena.id!==id||r.mode!==CATALOG[id]||nativeArenaGeometryHash(r.arena)!==r.geometryHash)throw Error('Recipe integrity mismatch');
 return r;
}
// Trusted in-process map seam, NOT a network adapter. Never accepts client geometry.
export function createIdentityMatch(id,options={}){
 const recipe=loadRecipe(id),arena=recipe.arena;
 const allowed=['botCount','difficulty','timeLimit','fragLimit','random'];
 if(Object.keys(options).some(k=>!allowed.includes(k)))throw Error('Unsupported identity option');
 if(options.botCount!==undefined&&(!Number.isInteger(options.botCount)||options.botCount<0||options.botCount>7))throw Error('botCount must be 0..7');
 if(options.timeLimit!==undefined&&(!Number.isInteger(options.timeLimit)||options.timeLimit<60||options.timeLimit>900))throw Error('timeLimit must be 60..900');
 if(options.fragLimit!==undefined&&(!Number.isInteger(options.fragLimit)||options.fragLimit<1||options.fragLimit>50))throw Error('Invalid target');
 if(options.difficulty!==undefined&&!['easy','normal','hard','nightmare'].includes(options.difficulty))throw Error('Invalid difficulty');
 const config={mode:recipe.mode,botCount:recipe.mode==='horde'?0:recipe.mode==='domination'?5:3,difficulty:'normal',timeLimit:180,fragLimit:recipe.mode==='horde'?10:15,...options};
 delete config.random;
 if(recipe.mode==='horde'&&config.botCount!==0)throw Error('Horde supports one human only');
 let assigned=false;
 class IdentityMatch extends Match {get arena(){return arena;}set arena(_fallback){if(assigned)throw Error('Arena reassignment');assigned=true;}}
 const match=new IdentityMatch('chatgpt','openclaw',options.random??Math.random,id,config);
 if(!assigned||match.arena!==arena||match.snapshot().mapId!==id||match.config.mode!==recipe.mode)throw Error('Source factory drift');
 for(const a of match.actors)if(!Number.isFinite(a.y)||floorAt(a.x,a.z,arena)===null||obstructed(a.x,a.y,a.z,undefined,arena))throw Error('Invalid initial source spawn');
 return match;
}
