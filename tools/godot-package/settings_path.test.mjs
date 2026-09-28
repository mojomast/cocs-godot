import test from 'node:test';
import assert from 'node:assert/strict';
import {settingsPath} from './settings_path.mjs';

test('explicit isolated preference path wins over development and platform defaults', () => {
  assert.equal(settingsPath({COCS_SETTINGS_PATH:'/test/preferences.json'},
    {platform:'linux', home:'/home/fixture', developmentRoot:'/checkout'}), '/test/preferences.json');
  assert.throws(() => settingsPath({COCS_SETTINGS_PATH:'relative.json'},
    {platform:'linux', home:'/home/fixture'}), /must be absolute/);
  assert.equal(settingsPath({COCS_SETTINGS_PATH:'D:\\Profile\\settings.json'},
    {platform:'win32', home:'C:\\Users\\fixture'}), 'D:\\Profile\\settings.json');
});

test('development preferences live outside disposable route runtime directories', () => {
  const options = {platform:'linux', home:'/home/fixture', developmentRoot:'/checkout'};
  for (const runtime of ['/tmp/route-one','/tmp/route-two','/tmp/route-three']) {
    assert.equal(settingsPath({XDG_DATA_HOME:runtime, XDG_CONFIG_HOME:runtime}, options),
      '/checkout/.port-runtime/local_settings.json');
  }
});

test('installed preferences use native per-user config roots without depending on cwd', () => {
  assert.equal(settingsPath({XDG_CONFIG_HOME:'/profile/config'}, {platform:'linux',home:'/home/fixture'}),
    '/profile/config/cocs-native/local_settings.json');
  assert.equal(settingsPath({XDG_CONFIG_HOME:'relative'}, {platform:'linux',home:'/home/fixture'}),
    '/home/fixture/.config/cocs-native/local_settings.json');
  assert.equal(settingsPath({}, {platform:'darwin',home:'/Users/fixture'}),
    '/Users/fixture/Library/Application Support/cocs-native/local_settings.json');
  assert.equal(settingsPath({APPDATA:'D:\\Roaming'}, {platform:'win32',home:'C:\\Users\\fixture'}),
    'D:\\Roaming\\cocs-native\\local_settings.json');
  assert.equal(settingsPath({}, {platform:'win32',home:'C:\\Users\\fixture'}),
    'C:\\Users\\fixture\\AppData\\Roaming\\cocs-native\\local_settings.json');
});
