// Pure Node fixture exporter: evaluate the weather declarations verbatim from the
// browser source, without loading Three.js, opening a scene, or running a server.
import {readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {runInNewContext} from 'node:vm';

const directory=resolve(fileURLToPath(new URL('.',import.meta.url)));
const source=readFileSync(resolve(directory,'../../game/environment.mjs'),'utf8');
const section=(start,end)=>{
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 if(a<0||b<0||b<=a)throw new Error(`Weather source boundary changed: ${start}`);
 return source.slice(a,b).replaceAll('export const ','const ').replaceAll('export function ','function ');
};
// The sky tests use explicit sky or NIGHT_MAPS ids, so no Three.js Color is
// needed. Everything below is evaluated from the actual source, not a port.
const declarations=section('export const SKY_PHASES=', '// Three.js Color')+
 section('export function skyPhase(', '// Pure, deterministic palette')+
 section('// Deterministic weather layer.', '// Wet-surface look');
const api=runInNewContext(`${declarations}\n({arenaSeedNumber,hashUnit2,biomeAmbience,selectWeather,timeOfDayAt,windGustAt,weatherPreset,lightningSchedule,precipParticleAdds})`,{}, {filename:'game/environment.mjs'});
const plain=value=>JSON.parse(JSON.stringify(value));
const seeds=[0,1,7,0x7fffffff,0x80000000,0xffffffff];
const hashes=seeds.flatMap(seed=>[-17,0,1,2147483647].map(salt=>({seed,salt,unit:api.hashUnit2(seed,salt)})));
const maps=['','arena','frost-gate','sunscar-dune','neon-vertical','☃-arena','skybreak'];
const mapSeeds=maps.map(id=>({id,seed:api.arenaSeedNumber({id})}));
const arenas=[
 {id:'frost-ember',biome:'forest'}, {id:'sunscar-dune'}, {id:'ashen-frost'},
 {id:'neon-storm'}, {id:'snowfield',biome:'urban'}, {id:'titan-ruins',biome:'ruins'},
 {id:'deep-cave',biome:'cavern'}, {id:'open-land',biome:'unknown'},
 {id:'skybreak',biome:'snow'}, {id:'dune-ravine',biome:'canyon'},
 {id:'ember-caldera',biome:'volcanic'}, {id:'storm-station'},
 {id:'exchange'}, {id:'glacier',reducedMotion:true},
 ];
const selection=arenas.flatMap(arena=>[1,7,0xffffffff].map(seed=>({arena,seed,time:{t:seed===7?2.5:0},biome:plain(api.biomeAmbience(arena)),kind:api.selectWeather(arena,{t:seed===7?2.5:0},seed).kind})));
for(const kind of ['storm','rain','overcast','clear']){
 const arena={id:'neon-storm'},time={t:0};
 const seed=Array.from({length:4096},(_,i)=>i).find(candidate=>api.selectWeather(arena,time,candidate).kind===kind);
 if(seed===undefined)throw new Error(`No source seed produces ${kind}`);
 selection.push({arena,seed,time,biome:plain(api.biomeAmbience(arena)),kind});
}
selection.push({arena:{id:'neon-storm'},seed:1,time:{t:0},reduced:true,biome:plain(api.biomeAmbience({id:'neon-storm'})),kind:api.selectWeather({id:'neon-storm'},{t:0},1,{reduced:true}).kind});
const times=[
 {arena:{id:'arena',sky:'day'},elapsed:0,mode:'playing'},
 {arena:{id:'arena',sky:'day'},elapsed:85,mode:'selection'},
 {arena:{id:'skybreak'},elapsed:360,mode:'theater'},
 {arena:{id:'☃-arena',sky:'dusk'},elapsed:1190,mode:'playing'},
 {arena:{id:'arena',sky:'night',reducedMotion:true},elapsed:42,mode:'playing'},
 {arena:{id:'arena',sky:'dusk',timeOfDay:false},elapsed:13,mode:'progression'},
 {arena:{id:'arena',sky:'day',timeOfDayOverride:false},elapsed:80,mode:'playing'},
 {arena:{id:'arena',sky:'day'},elapsed:-12,mode:'selection'},
].map(({arena,elapsed,mode})=>({arena,elapsed,mode,expected:plain(api.timeOfDayAt(arena,elapsed,mode))}));
const winds=[
 {time:0,seed:0,strength:1},{time:10.25,seed:1,strength:2},
 {time:120,seed:0xffffffff,strength:0},{time:-3.5,seed:0x80000000,strength:0.5},
 {time:999,seed:7,strength:4},
].map(v=>({...v,expected:api.windGustAt(v.time,{seed:v.seed,strength:v.strength})}));
const lightning=[
 {kind:'clear',seed:1,window:60,count:4},
 {kind:'storm',seed:0,window:60,count:4},
 {kind:'storm',seed:0xffffffff,window:6,count:24},
 {kind:'rain',seed:1,window:60,count:4},
 {kind:'rain',seed:42,window:60,count:4},
 {kind:'rain',seed:4782,window:60,count:4},
 {kind:'overcast',seed:1,window:60,count:4},
 {kind:'overcast',seed:7173,window:60,count:4},
 {kind:'storm',seed:7,window:0,count:0},
].map(v=>({...v,expected:plain(api.lightningSchedule(api.weatherPreset(v.kind),v))}));
const precipitation=[
 {serial:0,kind:'clear',origin:{x:0,y:0,z:0},radius:9},
 {serial:0,kind:'rain',origin:{x:0,y:0,z:0},radius:9},
 {serial:17,kind:'snow',origin:{x:12,y:3,z:-8},radius:3},
 {serial:-3,kind:'ash',origin:{x:-4,y:0,z:2},radius:1},
 {serial:2147483647,kind:'storm',origin:{x:1,y:-2,z:9},radius:12},
].map(v=>({...v,expected:plain(api.precipParticleAdds(v.serial,v.kind,v.origin,v.radius))}));
const fixtures={source:'game/environment.mjs',mapSeeds,hashes,selection,times,winds,lightning,precipitation};
const output=JSON.stringify(fixtures,null,2)+'\n';
const path=resolve(directory,'weather-vectors.json');
if(process.argv.includes('--check')){
 if(readFileSync(path,'utf8')!==output)throw new Error('Weather vectors stale; regenerate with node port/native-audiovisual/weather-oracle.mjs');
 console.log('WEATHER_VECTORS_OK');
}else{
 writeFileSync(path,output);
 console.log(`Wrote ${path}`);
}
