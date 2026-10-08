import test from 'node:test';
import assert from 'node:assert/strict';
import {weatherSpawnPlan, hordeWindowArgs} from './gpu-process.mjs';

test('weather uses the native binary only on win32', () => {
  const binary = 'C:\\Program Files\\Godot\\godot.exe';
  const args = ['--path', 'godot', '--', '--map=siltwake-crossing'];
  assert.deepEqual(weatherSpawnPlan('win32', binary, args), {command: binary, args});
  for (const platform of ['linux', 'darwin']) {
    assert.deepEqual(weatherSpawnPlan(platform, binary, args),
      {command: 'xvfb-run', args: ['-a', binary, ...args]});
  }
});

test('Horde uses a native rendered window on win32 and preserves Linux display paths', () => {
  const rendered = ['--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--windowed', '--resolution', '640x480'];
  assert.deepEqual(hordeWindowArgs('win32', null), rendered);
  assert.deepEqual(hordeWindowArgs('win32', 'native'), rendered);
  assert.deepEqual(hordeWindowArgs('linux', ':99'), rendered);
  assert.ok(rendered.includes('--windowed'));
  assert.deepEqual(hordeWindowArgs('linux', null), ['--headless']);
});
