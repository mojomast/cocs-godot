import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {floorAt,obstructed} from '../../game/core.mjs';

export const CINDERWAKE_PATH='godot/horde_maps/generated/cinderwake-drydock.json';
export const CINDERWAKE_MAX_BYTES=2*1024*1024;
const fail=label=>{throw Error(`Invalid Cinderwake recipe: ${label}`);};
const canonical=v=>Array.isArray(v)?`[${v.map(canonical).join(',')}]`:v!==null&&typeof v==='object'?`{${Object.keys(v).sort().map(k=>`${JSON.stringify(k)}:${canonical(v[k])}`).join(',')}}`:JSON.stringify(v);
const hash=v=>createHash('sha256').update(canonical(v)).digest('hex');
const keys=(v,allowed)=>{if(!v||typeof v!=='object'||Array.isArray(v)||Object.keys(v).some(k=>!allowed.includes(k)))fail('keys');};
const list=(v,min,max)=>{if(!Array.isArray(v)||v.length<min||v.length>max)fail('list');};
const number=n=>{if(!Number.isFinite(n)||Math.abs(n)>10000)fail('finite coordinate');};
function tree(v,depth=0,budget={left:100000}){
 if(depth>16||--budget.left<0)fail('JSON complexity');
 if(v===null||typeof v==='boolean')return;
 if(typeof v==='number')return number(v);
 if(typeof v==='string'){if(v.length>4096)fail('text');return;}
 if(Array.isArray(v)){for(const x of v)tree(x,depth+1,budget);return;}
 if(!v||typeof v!=='object'||![null,Object.prototype].includes(Object.getPrototypeOf(v)))fail('JSON object');
 for(const [k,x] of Object.entries(v)){if(['__proto__','constructor','prototype'].includes(k))fail('JSON key');tree(x,depth+1,budget);}
}
export function validateCinderwake(data){
 tree(data);
 keys(data,['schemaVersion','id','name','mode','arena','palette','art','routes','cameras','landmarks','presentation','provenance','planHash','geometryHash']);
 if(data.schemaVersion!==1||data.id!=='cinderwake-drydock'||data.name!=='Cinderwake Drydock'||data.mode!=='horde')fail('identity/mode');
 const a=data.arena;keys(a,['id','name','bounds','voidY','ceilingY','raised','nextGen','spawns','teamSpawns','navNodes','pickups','blocks','terrain','hordeStagePlan']);
 if(a.id!==data.id||a.name!==data.name||a.nextGen!==true||a.raised!==false||a.voidY!==-10||a.ceilingY!==40)fail('arena contract');
 keys(a.bounds,['minX','maxX','minZ','maxZ']);if(!(a.bounds.minX<a.bounds.maxX&&a.bounds.minZ<a.bounds.maxZ))fail('bounds');
 const ids=new Set();const unique=id=>{if(typeof id!=='string'||!/^[A-Za-z][A-Za-z0-9_-]{0,63}$/.test(id)||ids.has(id))fail('unique id');ids.add(id);};
 list(a.blocks,1,512);
 for(const b of a.blocks){keys(b,['id','x','z','w','d','h','baseY','material']);unique(b.id);for(const key of ['x','z','w','d','h','baseY'])number(b[key]);if(!(b.w>0&&b.d>0&&b.h>b.baseY)||!['floor','shell','cut','enamel','accent','trim'].includes(b.material))fail('block extent/material');}
 keys(a.terrain,['maxSlope','surfaces','walls']);list(a.terrain.surfaces,1,512);list(a.terrain.walls,0,0);
 for(const s of a.terrain.surfaces){
  keys(s,['id','material','walkable','vertices','triangles']);unique(s.id);if(s.walkable!==true)fail('walkable floor');list(s.vertices,3,1024);list(s.triangles,1,2048);
  for(const p of s.vertices){list(p,3,3);p.forEach(number);}
  for(const t of s.triangles){list(t,3,3);if(t.some(i=>!Number.isInteger(i)||i<0||i>=s.vertices.length)||new Set(t).size!==3)fail('triangle index');const [p,q,r]=t.map(i=>s.vertices[i]);if(Math.abs((q[0]-p[0])*(r[2]-p[2])-(q[2]-p[2])*(r[0]-p[0]))<1e-6)fail('degenerate floor');}
 }
 const pool=(ps,min=2,max=32)=>{list(ps,min,max);for(const p of ps){list(p,2,2);p.forEach(number);const [x,z]=p,y=floorAt(x,z,a);if(x<a.bounds.minX||x>a.bounds.maxX||z<a.bounds.minZ||z>a.bounds.maxZ||y===null||obstructed(x,y,z,1.2,a))fail('unsupported/blocked anchor');}};
 pool(a.spawns);keys(a.teamSpawns,['0','1']);pool(a.teamSpawns[0],2,4);pool(a.teamSpawns[1],4,32);
 list(a.navNodes,1,10000);for(const p of a.navNodes){list(p,2,2);p.forEach(number);}
 list(a.pickups,1,64);for(const p of a.pickups){list(p,3,3);if(!['health','armor','ammo','megahealth','scatter','plasma','shock','rocket','flak'].includes(p[0]))fail('pickup kind');pool([[p[1],p[2]]],1,1);}
 const plan=a.hordeStagePlan;keys(plan,['version','initialStage','stages','gates','transitions']);
 if(plan.version!==1||plan.initialStage!=='B')fail('plan version/start');list(plan.stages,3,3);list(plan.gates,2,2);list(plan.transitions,8,8);
 const stages=new Set(),gates=new Set();
 for(const s of plan.stages){keys(s,['id','arrival','humanSpawns','enemySpawns']);if(!['B','C','D'].includes(s.id)||stages.has(s.id))fail('stage id');stages.add(s.id);keys(s.arrival,['minX','maxX','minZ','maxZ']);const r=s.arrival;if(!(r.minX<r.maxX&&r.minZ<r.maxZ))fail('arrival');pool(s.humanSpawns,2,4);pool(s.enemySpawns,4,32);pool([[(r.minX+r.maxX)/2,(r.minZ+r.maxZ)/2]],1,1);}
 for(const g of plan.gates){keys(g,['id','x','z','w','d','h','baseY','material']);unique(g.id);gates.add(g.id);for(const key of ['x','z','w','d','h','baseY'])number(g[key]);if(!(g.w>0&&g.d>0&&g.h>g.baseY)||g.material!=='accent')fail('gate extent');}
 let wave=0,from='B';for(const t of plan.transitions){keys(t,['afterWave','from','to','open','close']);if(!Number.isInteger(t.afterWave)||t.afterWave<=wave||t.afterWave>29||t.from!==from||!stages.has(t.to)||t.to===from)fail('transition');for(const xs of [t.open,t.close]){list(xs,0,2);if(new Set(xs).size!==xs.length||xs.some(id=>!gates.has(id)))fail('gate refs');}if(!t.open.length||t.close.some(id=>t.open.includes(id)))fail('gate targets');wave=t.afterWave;from=t.to;}
 if(hash(plan)!==data.planHash||hash(a)!==data.geometryHash)fail('canonical checksum');
 return data;
}
export function readCinderwake(){
 const bytes=readFileSync(new URL('../../'+CINDERWAKE_PATH,import.meta.url));
 if(!bytes.length||bytes.length>CINDERWAKE_MAX_BYTES)fail('byte limit');
 return validateCinderwake(JSON.parse(bytes.toString('utf8')));
}
