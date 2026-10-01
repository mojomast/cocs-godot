import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync, existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const maps = ['rootfall-verge','siltwake-crossing','emberline-ascent','crown-array'];
test('campaign authority closure includes reviewed adapters and all four runtime maps', () => {
  const closure = JSON.parse(execFileSync(process.execPath, ['--no-warnings','--experimental-vm-modules','tools/godot-package/discover.mjs',root], {cwd:root,encoding:'utf8'}));
  const data = maps.map(id => `godot/campaign/generated/${id}.json`);
  assert.deepEqual(closure.campaignDataFiles, data);
  assert.deepEqual(closure.dataReads['port/native-campaign/maps.mjs'], data);
  for (const name of ['authority','maps','match','missions','enemies','story','core.generated']) {
    assert.ok(Object.hasOwn(closure.adapterModules, `port/native-campaign/${name}.mjs`), name);
    assert.ok(closure.routes.campaign.includes(`port/native-campaign/${name}.mjs`), name);
  }
  for (const path of data) assert.ok(existsSync(new URL('../../'+path,import.meta.url)), path);
});
test('both export entry points include campaign JSON data', () => {
  for (const path of ['build.py','../../godot/export_presets.cfg']) {
    const text = readFileSync(new URL(path,import.meta.url),'utf8');
    assert.match(text, /include_filter="[^"\n]*campaign\/generated\/\*\.json/);
    assert.match(text, /include_filter="[^"\n]*ui\/attract\/\*\.json/);
  }
});
