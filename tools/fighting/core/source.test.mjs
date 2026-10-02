import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {expandTrace} from './traces.mjs';
const root = fileURLToPath(new URL('../../../', import.meta.url));
const read = p => readFileSync(resolve(root, p), 'utf8');
const roster = JSON.parse(read('godot/fighting/data/roster.json'));
const schema = read('godot/fighting/core/schema.gd');
const optional = Object.fromEntries([...schema.matchAll(/^\s*"(\w+)": \[([^\n]+)\],?$/gm)]
  .map(([, key, values]) => [key, JSON.parse(`[${values}]`)]));
const aliases = {projectile: {vx: 'speed', x: 'spawn_x', y: 'spawn_y', w: 'width', h: 'height', clash_strength: 'clash'},
  armor: {to: 'until'}, throw: {release_frame: 'duration', knockdown_frames: 'knockdown'}};

test('all authored optional mechanic subfields enter the strict core schema', () => {
  let moves = 0;
  for (const op of roster.operators) for (const [id, move] of Object.entries(op.moves)) {
    moves++;
    for (const section of ['movement', 'projectile', 'throw', 'resource_effect', 'stance', 'armor', 'counter']) {
      for (const key of Object.keys(move[section] ?? {})) {
        assert.ok(optional[section].includes(aliases[section]?.[key] ?? key), `${op.id}/${id}: ${section}.${key}`);
      }
    }
  }
  assert.equal(moves, 138);
});

test('all 27 authored traces expand with finite commands and mirror exactly', () => {
  let count = 0;
  for (const op of roster.operators) for (const combo of op.combos) {
    count++;
    const a = expandTrace(combo), b = expandTrace(combo, -1);
    assert.equal(a.length, b.length);
    assert.ok(a.length < 1000);
    for (let i = 0; i < a.length; i++) {
      assert.equal(a[i].axis_x + b[i].axis_x, 0);
      assert.equal(a[i].axis_y, b[i].axis_y);
      assert.equal(a[i].held, b[i].held);
    }
    assert.equal(combo.status, 'proposed', 'source tests must not promote unexecuted combos');
  }
  assert.equal(count, 27);
});

test('DeepSeek setup is a real sustained back input and release is represented', () => {
  const combo = roster.operators.find(o => o.id === 'deepseek').combos[1];
  const trace = expandTrace(combo);
  assert.ok(trace.slice(0, 36).every(c => c.axis_x === -1 && c.held === 0));
  assert.equal(trace[69].axis_x, 1);
  assert.equal(trace[69].held, 8);
  assert.equal(trace[70].held, 0);
  const defender = expandTrace({inputs: combo.defender_setup_inputs});
  assert.ok(defender.slice(0, 36).every(c => c.axis_x === -1 && c.held === 0));
  assert.equal(defender[36].axis_x, 0);
});

test('trace tool rejects nonintegral, unknown-mask and ambiguous inputs', () => {
  const input = {tick: 0, axis_x: 0, axis_y: 0, held: 1, pressed: 0};
  assert.throws(() => expandTrace({inputs: [{...input, held: 512}]}));
  assert.throws(() => expandTrace({inputs: [{...input, axis_y: 0.5}]}));
  assert.throws(() => expandTrace({inputs: [input, input]}));
  assert.equal(expandTrace({inputs: [input]})[0].pressed, 0, 'stale hint is preserved for authority to ignore');
});

test('core stays RefCounted and contains no engine physics, clocks, signals or random globals', () => {
  for (const name of readdirSync(resolve(root, 'godot/fighting/core')).filter(n => n.endsWith('.gd'))) {
    const source = read(`godot/fighting/core/${name}`);
    assert.match(source, /^extends RefCounted/m);
    assert.doesNotMatch(source, /\b(class_name|signal|CharacterBody\w*|PhysicsServer\w*|AnimationPlayer|randf|randi)\b/);
    assert.doesNotMatch(source, /\b(Time|Input|Engine)\.(get_ticks|is_action|get_physics|time_scale)/);
    if (name !== 'integer_math.gd') {
      const statements = source.split('\n').filter(line => !line.trim().startsWith('#')).join('\n');
      assert.doesNotMatch(statements, /\s\/\s/, `${name}: integer division must use mul_div`);
    }
  }
});
