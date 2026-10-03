// Actual Three.js production methods, with only the DOM canvas transport stubbed.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import * as T from 'three';
import {wetSheenTexture, clearWetSheenTextures} from '../game/textures.mjs';
import {ArenaView} from '../game/view.mjs';
import {RipplePool} from '../game/effects-fx.mjs';

globalThis.document = {createElement() {
  const canvas = {width: 0, height: 0};
  canvas.getContext = () => ({createImageData: (w,h) => ({data:new Uint8ClampedArray(w*h*4)}), putImageData: image => {canvas.pixels=image.data;}});
  return canvas;
}};
const textures = [14, 20, 2147483660].map(seed => {
  const texture = wetSheenTexture({seed});
  const pixels = texture.image.pixels;
  assert.equal(wetSheenTexture({seed}), texture);
  return {seed, size:128, sha256:createHash('sha256').update(pixels).digest('hex'),
    pixels:[0,1,63,127,128,1024,8191,10000,16383].map(i=>({index:i, rgba:Array.from(pixels.slice(i*4,i*4+4))}))};
});
clearWetSheenTextures();
// Ring mask canvas needs a richer DOM; headless source explicitly permits null.
delete globalThis.document;
const scene = new T.Scene();
const view = Object.assign(Object.create(ArenaView.prototype), {scene, _weatherSplashSerial:0, _weatherSplashUsed:0,
  characterGroundAt:(x,z)=>x>5?2:0});
const desc = {pos:{x:1,y:5,z:3},velocity:{x:2,y:-10,z:1},color:'#cfe0ef',life:1};
const schedules = Array.from({length:20},()=>Boolean(view._scheduleWeatherSplash(desc)));
assert.equal(schedules.filter(Boolean).length,3);
const slot = view.ripplePool.slots[0];
const contact = {position:slot.obj.position.toArray(),delay:slot.delay,base:slot.base,grow:slot.grow,
  color:slot.material.color.toArray(),total:slot.total};
const pool = new RipplePool(new T.Scene(),18);
pool.spawn({x:1,y:.02,z:3},{delay:.2,size:.3,life:.5});
const replay = Array.from({length:8},()=>{pool.update(.1);const s=pool.slots[0];return {active:s.active,visible:s.obj.visible,scale:s.obj.scale.x,opacity:s.material.opacity};});
const result = {sourceHashes:Object.fromEntries(['textures.mjs','view.mjs','effects-fx.mjs'].map(name=>[name,createHash('sha256').update(fs.readFileSync(new URL('../game/'+name,import.meta.url))).digest('hex')])),textures,schedules,contact,replay};
// Check the explicit adapter contract without launching the native engine.
const adapter = fs.readFileSync(new URL('../godot/ambience/wet_surface.gd',import.meta.url),'utf8');
const anchors = [...adapter.matchAll(/^\s*"(res:\/\/[^"\n]+)": ("(?:[^"\\]|\\.)*"),$/gm)];
assert.deepEqual(anchors.map(([,path])=>path).sort(),[
  'res://campaign/materials/ground.gdshader',
  'res://material_language/family.gdshader',
  'res://moth/surface.gdshader',
  'res://moth/surface_opaque.gdshader',
].sort());
for(const [,path,quoted] of anchors){
  const code=fs.readFileSync(new URL('../godot/'+path.slice(6),import.meta.url),'utf8');
  assert.equal(code.split(JSON.parse(quoted)).length,2,`unique reviewed roughness anchor: ${path}`);
}
const path = new URL('../godot/tests/world_weather/spatial_source.json',import.meta.url);
if(process.argv.includes('--check')) assert.deepEqual(JSON.parse(fs.readFileSync(path,'utf8')),result);
else fs.writeFileSync(path,JSON.stringify(result,null,2)+'\n');
pool.dispose();view.ripplePool.dispose();
console.log('WORLD_WEATHER_SPATIAL_SOURCE_OK textures=3 schedules=20 ripple_steps=8');
