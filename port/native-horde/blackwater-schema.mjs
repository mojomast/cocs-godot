import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';

const FILE=new URL('../../godot/horde_maps/generated/blackwater-reclamation.json',import.meta.url);
export const BLACKWATER_ID='blackwater-reclamation';
const canonical=v=>Array.isArray(v)?`[${v.map(canonical).join(',')}]`:v!==null&&typeof v==='object'?`{${Object.keys(v).sort().map(k=>`${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`:JSON.stringify(v);
const hash=v=>createHash('sha256').update(canonical(v)).digest('hex');
export function readBlackwater(){
 const bytes=readFileSync(FILE);
 if(!bytes.length||bytes.length>3*1024*1024)throw Error('Blackwater recipe size');
 const data=JSON.parse(bytes.toString('utf8'));
 if(data.schemaVersion!==1||data.mode!=='horde'||data.id!==BLACKWATER_ID||data.name!=='Blackwater Reclamation'||data.arena?.id!==data.id||data.arena?.name!==data.name)throw Error('Blackwater identity');
 const arena=data.arena;
 if(arena.bounds?.minX!==-220||arena.bounds?.maxX!==220||arena.bounds?.minZ!==-190||arena.bounds?.maxZ!==190||arena.hordeStagePlan?.version!==1||arena.hordeStagePlan.stages?.length!==3||arena.hordeStagePlan.transitions?.length!==2)throw Error('Blackwater geometry contract');
 if(hash(arena)!==data.geometryHash||hash(arena.hordeStagePlan)!==data.planHash)throw Error('Blackwater hash');
 if(canonical(arena).length>3*1024*1024)throw Error('Blackwater complexity');
 return data;
}
