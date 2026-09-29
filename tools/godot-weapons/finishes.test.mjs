import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {WEAPON_FINISHES} from '../../game/cosmetics.mjs';
import {Color} from 'three';

test('generated native palette is source-derived and maps the Three.js material roles', async () => {
  const source = await readFile(new URL('../../game/cosmetics.mjs', import.meta.url));
  const renderer = await readFile(new URL('../../game/view.mjs', import.meta.url));
  const native = await readFile(new URL('../../godot/first_person/generated/finishes.gd', import.meta.url), 'utf8');
  assert.match(native, new RegExp(createHash('sha256').update(source).digest('hex')));
  assert.match(native, new RegExp(createHash('sha256').update(renderer).digest('hex')));
  const palette = JSON.parse(native.slice(native.indexOf('const PALETTES = ') + 17));
  assert.equal(Object.keys(palette).length, 6);
  for (const item of WEAPON_FINISHES) {
    const roles = {dark: item.colors.secondary, light: item.colors.accent, glow: item.colors.primary};
    assert.equal(palette[item.id].name, item.name);
    assert.equal(palette[item.id].description, item.description);
    assert.equal(palette[item.id].level, item.level);
    for (const [role, hex] of Object.entries(roles)) {
      assert.equal(palette[item.id][role], hex);
      const oracle = new Color(hex);
      for (const [channel, expected] of palette[item.id].linear[role].entries())
        assert.ok(Math.abs(expected - oracle.toArray()[channel]) < 1e-9, `${item.id} ${role} ${channel}`);
    }
  }
});
