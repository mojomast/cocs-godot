// Executes actual source functions and the actual page's desktop keydown body.
// Generated fixtures are consumed by native contracts, never production code.
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {DEFAULT_BINDINGS, KEYBIND_ACTIONS, KEYBIND_OPTIONS, RESERVED_CODES,
  normalizeBindings, rebindAction, actionForCode, bindingConflicts} from '../../../game/keybinds.mjs';
import {controlsFromState, blocksGameplay} from '../../../game/input.mjs';
import {cursorOpen, initialCursorMode, cursorCombatKeysBlocked} from '../../../game/cursor-mode.mjs';
import {onboardingStepView, ONBOARDING_STEPS} from '../../../game/onboarding.mjs';

const root = new URL('../../../', import.meta.url);
const source = path => readFileSync(new URL(path, root), 'utf8');
const page = source('app/page.tsx');
const start = page.indexOf('const boundAction=actionForCode(r.bindings||bindings,e.code);');
const end = page.indexOf("if(!e.repeat&&!cursorRef.current.surfaces.includes(CURSOR_SURFACE.SPEND)", start);
assert(start > 0 && end > start, 'actual keydown source boundaries');
const body = page.slice(start, end);
const press = new Function('r', 'bindings', 'e', 'keys', 'actionForCode', body);
const consumed = page.match(/r\.net\.input\(input\);r\.net\.predict\(input\);(r\.fireTap=false;[^\n]+?r\.grenade=false;)/)?.[1];
assert(consumed, 'actual queued-action consumption boundary');
const consume = new Function('r', consumed);
const model = source('godot/input_bindings/model.gd');
const nativeDefaults = JSON.parse(model.match(/const DEFAULTS := (\{[\s\S]*?\})\n/)[1]);
assert.deepEqual(Object.fromEntries(KEYBIND_ACTIONS.map(k => [k, nativeDefaults[k]])), DEFAULT_BINDINGS);
const editable = JSON.parse(model.match(/const LABELS := (\{[^\n]+\})/)[1]);
const cases = [null, [], 42, {}, {forward:'ArrowUp', power:'KeyY'},
  {forward:'KeyS', back:'KeyS', left:'KeyS', power:'Escape', mobility:['KeyI'], reload:4},
  Object.fromEntries(KEYBIND_ACTIONS.map(k => [k, 'KeyQ'])),
  {crouch:'ControlRight', sprint:'ShiftRight', power:'Backslash', future:{keep:true}},
  Object.fromEntries(KEYBIND_ACTIONS.map((k,i) => [k, KEYBIND_OPTIONS[(i+7)%KEYBIND_OPTIONS.length]]))];
const normalization = cases.map(raw => ({raw, expected:normalizeBindings(raw)}));
for (const row of normalization) assert.equal(bindingConflicts(row.expected).length, 0);
const swaps = KEYBIND_ACTIONS.flatMap(action => KEYBIND_OPTIONS.map(code => ({action, code,
  expected:rebindAction(DEFAULT_BINDINGS, action, code)})));
for (const row of swaps) assert.equal(bindingConflicts(row.expected).length, 0);
const samples = [];
const fields = ['x','z','yaw','pitch','fire','ads','jump','sprint','crouch','reload','melee','grenade','power','mobility','interact','altFire'];
// JSON wire encoding canonicalizes signed zero; compare at that boundary.
const complete = p => JSON.parse(JSON.stringify(Object.fromEntries(fields.map(k => [k, p[k] ?? (['x','z','yaw','pitch'].includes(k) ? 0 : false)]))));
for (const action of Object.keys(editable).filter(k => k in DEFAULT_BINDINGS)) {
  const bindings = rebindAction(DEFAULT_BINDINGS, action, 'KeyI');
  const keys = new Set();
  const r = {bindings};
  const timeline = [];
  function key(code, pressed, repeat=false) {
    if (pressed) press(r, bindings, {code, repeat, preventDefault() {}}, keys, actionForCode);
    else keys.delete(code); // Actual source keyup: page.tsx keys.delete(e.code).
    timeline.push({event:{code, pressed, repeat}});
  }
  function sample(label) {
    const controls = complete(controlsFromState({...r, keys}));
    timeline.push({sample:label, expected:controls});
    consume(r);
    return controls;
  }
  key(DEFAULT_BINDINGS[action], true);
  assert.deepEqual(sample('old binding inert'), complete({fire:false}));
  key(DEFAULT_BINDINGS[action], false);
  key('KeyI', true);
  sample('new press');
  sample('held second sample');
  key('KeyI', true, true);
  sample('repeat');
  key('KeyI', false);
  assert.deepEqual(sample('released'), complete({fire:false}));
  key('KeyI', true);
  sample('fresh second press');
  key('KeyI', false);
  sample('final release');
  samples.push({action, bindings, timeline});
}
for (const surface of ['settings','chat','pause','respawn']) {
  const transition = cursorOpen(initialCursorMode(), surface);
  assert(transition.effects.clearInput && cursorCombatKeysBlocked(transition.state));
}
assert(blocksGameplay(false, true, null, null));
assert(blocksGameplay(true, false, null, null));
assert(blocksGameplay(false, false, {tagName:'SELECT'}, null));
const onboarding = ONBOARDING_STEPS.map(step => onboardingStepView(step, rebindAction(DEFAULT_BINDINGS, 'forward', 'ArrowUp')));
const fixture = {schema:1, provenance:'Actual game/keybinds.mjs + game/input.mjs + extracted app/page.tsx keydown and queued consumption',
  hashes:Object.fromEntries(['game/keybinds.mjs','game/input.mjs','app/page.tsx'].map(path => [path, createHash('sha256').update(source(path)).digest('hex')])),
  defaults:DEFAULT_BINDINGS, reserved:RESERVED_CODES, normalization, swaps, samples, onboarding};
const path = new URL('godot/tests/input_bindings/source-fixtures.json', root);
// One generated case per line keeps exhaustive cross-product fixtures reviewable.
const text = '{\n' + Object.entries(fixture).map(([key, value]) =>
  `  ${JSON.stringify(key)}: ` + (Array.isArray(value)
    ? '[\n' + value.map(row => '    ' + JSON.stringify(row)).join(',\n') + '\n  ]'
    : JSON.stringify(value))).join(',\n') + '\n}\n';
if (process.argv.includes('--write')) writeFileSync(path, text);
else assert.equal(readFileSync(path, 'utf8'), text, 'committed source fixtures are current');
console.log(JSON.stringify({result:'PASS', defaults:KEYBIND_ACTIONS.length, normalization:normalization.length,
  sourceSwaps:swaps.length, inputTimelines:samples.length, sourceSamples:samples.reduce((n,s) => n+s.timeline.filter(r => r.sample).length,0),
  sourceModalBoundaries:4, fixture:fileURLToPath(path)}));
