// Execute the actual Three.js presentation methods; do not restate their math.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import * as T from 'three';
import {ArenaView} from '../game/view.mjs';
import {WEATHER_KINDS, weatherPreset, wetSheen, timeOfDayAt} from '../game/environment.mjs';

const base = {fog: '#607f8f', density: .003, exposure: 1.1, fill: .8, key: .9, fillColor: '#cce4e9', keyColor: '#e1efff', roughness: .84, metallic: .1};
const scene = new T.Scene();
scene.fog = new T.FogExp2(base.fog, base.density);
const hemi = new T.HemisphereLight(base.fillColor, '#20364f', base.fill);
const sun = new T.DirectionalLight(base.keyColor, base.key);
scene.add(hemi, sun);
const material = new T.MeshStandardMaterial({roughness: base.roughness, metalness: base.metallic});
const world = new T.Group();
world.add(new T.Mesh(new T.BoxGeometry(1, 1, 1), material));
const view = Object.assign(Object.create(ArenaView.prototype), {
  scene, worldGroup: world, renderer: {isSoftware: false, toneMappingExposure: base.exposure}, sky: null,
  _arenaLook: {background: base.fog, fog: base.fog, fogDensity: base.density, exposure: base.exposure},
  _arenaLight: {hemi: base.fill, sun: base.key, hemiColor: new T.Color(base.fillColor), sunColor: new T.Color(base.keyColor), groundColor: new T.Color('#20364f')},
});
const srgb = color => color.clone().convertLinearToSRGB().toArray();
const looks = WEATHER_KINDS.map(kind => {
  const preset = weatherPreset(kind), state = {kind, preset, phase: 'day', wetness: preset.material.wet};
  view._applyArenaLook(state);
  view._wetSheenApplied = -1;
  view._applyWetSheen(state);
  return {kind, wetness: state.wetness, density: scene.fog.density, fog: srgb(scene.fog.color), exposure: view.renderer.toneMappingExposure,
    fill: hemi.intensity, fillColor: srgb(hemi.color), key: sun.intensity, keyColor: srgb(sun.color), roughness: material.roughness, metallic: material.metalness};
});
// _updateWeather is the source transition integrator. Stub unrelated display hooks.
view.reduced = () => false;
view._weatherSeed = 7;
view.weatherState = {clock: 0, kind: 'clear', preset: weatherPreset('clear'), wetness: 0};
const replay = [];
for (const kind of ['storm', 'rain', 'clear', 'snow', 'ash']) {
  view._weatherOverride = kind;
  for (let step = 0; step < 12; step++) {
    const state = view._updateWeather({id: 'world-weather-oracle'}, .25, 'playing');
    replay.push({kind, delta: .25, wetness: state.wetness});
  }
}
const phases = ['#303030', '#606060', '#909090', '#cccccc'].map(background => ({background, expected: timeOfDayAt({id: 'linear-oracle', background, timeOfDay: false}, 0)}));
const result = {source: 'game/environment.mjs + ArenaView._applyArenaLook/_applyWetSheen/_updateWeather', base, looks, replay, phases,
  sourceHashes: Object.fromEntries(['environment.mjs', 'view.mjs'].map(name => [name, createHash('sha256').update(fs.readFileSync(new URL('../game/' + name, import.meta.url))).digest('hex')])),
  sheen: [-1, 0, .04, .16, .22, .5, 1, 2].map(value => ({value, expected: wetSheen(value)}))};
const path = new URL('../godot/tests/world_weather/source.json', import.meta.url);
if (process.argv.includes('--check')) assert.deepEqual(JSON.parse(fs.readFileSync(path, 'utf8')), result);
else fs.writeFileSync(path, JSON.stringify(result, null, 2) + '\n');
console.log(`WORLD_WEATHER_SOURCE_OK looks=${looks.length} replay=${replay.length} luminance=${phases.length}`);
