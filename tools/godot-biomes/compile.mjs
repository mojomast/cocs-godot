import {mkdirSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {nativeArenaGeometryHash, parseIdentityArena} from '../../port/native-arenas/schema.mjs';
import {terrainSupportAt} from '../../game/terrain.mjs';

export const BIOMES = ['canopy-divide', 'basalt-reach'];
const smooth = (a, b, v) => { const t = Math.max(0, Math.min(1, (v - a) / (b - a))); return t*t*(3-2*t); };
const round = n => +n.toFixed(5);

// A single continuous support sheet: ramps never hide a second floor beneath
// them. This respects the source simulation's highest-XZ support model.
export function height(id, x, z) {
  const forest = id === 'canopy-divide';
  const channel = (forest ? 3.2 : 4.2)*Math.sin(x*.075);
  const shelf = Math.abs(z-channel);
  const ridge = forest ? 8*smooth(5, 26, shelf) : 12*smooth(6, 24, shelf);
  const noise = forest ? .65*Math.cos(x*.14)*Math.sin(z*.16)**2 : .42*Math.cos(x*.18)*Math.sin(z*.15)**2;
  const rampWeight = Math.max(1-smooth(3, 12, Math.abs(Math.abs(x)-26)), 1-smooth(3, 7, Math.abs(Math.abs(x)-40)));
  const ramp = (forest ? 8 : 12)*smooth(0, 34, shelf);
  const outcrops = (forest?4.5:5.5) * (Math.exp(-((x-12)**2+(z-21)**2)/95)+Math.exp(-((x+12)**2+(z+21)**2)/95));
  return round(1 + ridge*(1-rampWeight) + ramp*rampWeight + noise + outcrops*(1-rampWeight));
}

export function compileBiome(id) {
  if (!BIOMES.includes(id)) throw Error('Unknown biome');
  const forest = id === 'canopy-divide';
  const name = forest ? 'Canopy Divide' : 'Basalt Reach';
  const arena = {id, name, description:forest ? 'Forest ravine, mossy ruins and two elevated ridge circuits.' : 'Sandstone canyon, basalt shelves and weathered relay crossings.',
    bounds:{minX:-48,maxX:48,minZ:-40,maxZ:40}, spawns:[],pickups:[],navNodes:[],blocks:[],
    terrain:{maxSlope:.65,surfaces:[],walls:[]},voidY:-12,ceilingY:60,raised:false,nextGen:true};
  // Two-metre cells retain small gullies and organic grade changes. Render and
  // collision consume these same triangles. Group by surface material for batching.
  const surfaces = {};
  for (let x=-48;x<48;x+=2) for(let z=-40;z<40;z+=2) {
    const vertices=[[x,height(id,x,z),z],[x,height(id,x,z+2),z+2],[x+2,height(id,x+2,z+2),z+2],[x+2,height(id,x+2,z),z]];
    const gradient = Math.max(...vertices.map(v=>v[1]))-Math.min(...vertices.map(v=>v[1]));
    const material = gradient>1 ? 'rock' : Math.abs(z)<5 ? 'gravel' : Math.abs(z)>29 ? (forest?'moss':'sand') : (forest?'soil':'rock');
    const s=surfaces[material]??={id:`terrain-${material}`,material,walkable:true,vertices:[],triangles:[]};
    const i=s.vertices.length;s.vertices.push(...vertices);s.triangles.push([i,i+1,i+2],[i,i+2,i+3]);
  }
  arena.terrain.surfaces=Object.values(surfaces);
  const support=(x,z)=>terrainSupportAt(x,z,arena.terrain,arena.terrain.maxSlope)?.y;
  const box=(bid,x,z,w,d,h,material='stone')=>{
    // Bury the lower face into the terrain; support never comes from cover.
    const baseY=Math.min(height(id,x-w/2,z-d/2),height(id,x+w/2,z+d/2))-.35;
    arena.blocks.push({id:bid,x,z,w,d,h:round(height(id,x,z)+h),baseY:round(baseY),material});
  };
  // Opposing spawn pools and cover are rotationally symmetric. Both pools get
  // an outer ridge route and an inward ramp without crossing a firing lane.
  for(const side of [-1,1]) {
    for(const z of [-30,0,30]) arena.spawns.push([side*42,z]);
    for(const z of [-30,0,30]) box(`spawn-screen-${side}-${z}`,side*36,z,2.2,5,3.1,'stone');
    for(const z of [-25,25]) {
      box(`ridge-wall-${side}-${z}`,side*14,z,3.5,4,2.6,'stone');
      box(`ridge-relay-${side}-${z}`,side*7,z+side*10,2.4,3,4.6,forest?'stone':'metal');
    }
    box(`valley-cover-${side}`,side*12,side*5,4.5,2.5,2.2,forest?'stone':'metal');
    box(`crossing-pier-${side}`,side*5,side*15,3,3,3.5,'stone');
  }
  if(forest) for(const x of [-18,-8,8,18]) for(const z of [-36,-19,19,36])
    box(`tree-${x}-${z}`,x,z,.85,.85,5.2,'bark');
  // Open lintels create readable ruins / relay gantries. Their underside and
  // ray collision share the exact block; no hidden second support layer.
  for(const z of [-15,15]) {
    for(const x of [-5,5]) if(!arena.blocks.some(b=>b.x===x&&b.z===z))box(`gateway-post-${x}-${z}`,x,z,2.2,2.2,4.8,forest?'stone':'metal');
    const baseY=Math.max(height(id,-5,z),height(id,5,z))+4.8;
    arena.blocks.push({id:`gateway-lintel-${z}`,x:0,z,w:12,d:1.8,h:round(baseY+.65),baseY:round(baseY),material:forest?'stone':'metal'});
  }
  const routes=[];
  const route=(rid,corners)=>{
    const points=[];
    for(let i=1;i<corners.length;i++) {
      const [ax,az]=corners[i-1], [bx,bz]=corners[i], steps=Math.ceil(Math.hypot(bx-ax,bz-az)/2);
      for(let j=0;j<steps;j++) {const x=round(ax+(bx-ax)*j/steps),z=round(az+(bz-az)*j/steps);points.push({x,y:round(support(x,z)),z});}
    }
    const [x,z]=corners.at(-1);points.push({x,y:round(support(x,z)),z});
    routes.push({id:rid,points});
  };
  for(const z of [-30,0,30]) {
    const detour=z+(z<0?-6:6);
    route(z===0?'low-channel':`ridge-${z<0?'north':'south'}`,[[-42,z],[-40,z],[-40,detour],[-32,detour],[-30,z],[30,z],[32,detour],[40,detour],[40,z],[42,z]]);
  }
  for(const x of [-40,-26,26,40]) route(`ascent-${x}`,Array.from({length:16},(_,i)=>[x,-30+i*4]));
  for(const r of routes) for(const {x,z} of r.points) arena.navNodes.push([x,z]);
  for(const side of [-1,1]) arena.pickups.push(['health',side*40,side*15],['armor',side*26,-side*30],['ammo',side*24,0]);
  // Power weapons require exposed centre crossings; both teams travel equal distances.
  arena.pickups.push(['rocket',0,0],['rail',0,-30],['health',0,30]);
  const art = [{id:'vista-bedrock',material:'rock',walkable:false,
    vertices:[[-70,-3,-56],[-70,-3,56],[70,-3,56],[70,-3,-56]],triangles:[[0,1,2],[0,2,3]]}];
  const data={schemaVersion:1,id,name,mode:'deathmatch',palette:forest?['526b43','b3ad8c','315858','debb78']:['c49765','b58158','303c4d','6bd3ce'],
    arena,geometryHash:nativeArenaGeometryHash(arena),art,routes,
    spawnPoints:arena.spawns.map(([x,z])=>({x,y:round(support(x,z)),z})),
    cameras:[{id:'vista',at:[-43,24,38],target:[0,4,0]},{id:'valley',at:[-28,4,2],target:[8,10,-24]}],
    provenance:{godot:'4.5.2.stable.official.6ce3de25a',compiler:'tools/godot-biomes/compile.mjs',input:'authored continuous biome terrain and symmetric route network',supportModel:'single walkable heightfield; exact shared render/collision triangles'},
    artNotes:[{id:'vegetation',collision:'presentation-only',reason:'Small foliage stays outside routes and spawn clearance; solid trunks use arena blocks.'}]};
  return data;
}

if(process.argv[1]===fileURLToPath(import.meta.url)) {
  const out=new URL('../../godot/identity_maps/generated/',import.meta.url);mkdirSync(out,{recursive:true});
  for(const id of BIOMES) {
    const data=compileBiome(id);parseIdentityArena(data,id);
    writeFileSync(new URL(`${id}.json`,out),JSON.stringify(data)+'\n');
    console.log(`${id}: ${data.arena.terrain.surfaces.reduce((n,s)=>n+s.triangles.length,0)} terrain triangles; ${data.routes.length} traversable routes`);
  }
}
