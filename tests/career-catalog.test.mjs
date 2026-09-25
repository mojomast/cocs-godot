// Career / Arsenal catalogue presentation: focused, dependency-free tests for
// the pure model in app/ui/career-catalog.mjs plus source wiring guards for the
// two surfaces that render it (ProgressionScreen and the SettingsDialog Arsenal
// inspector).
//
// The model is a pure read of the shipped resolvers (`gearPoints`,
// `gearBudget`, `attachmentSpec`, `attachmentFits`) over the generic catalogue
// and profile fields, so it runs under plain Node with no DOM, React or
// installed dependencies. The render-level behaviour is still covered by the
// existing SSR suites; this file pins the derivations they depend on and the
// honesty rules (applied vs merely unlocked, exact lock reasons, no invented
// purchase affordance).
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
  CAREER_AXES, AXIS_ABBR,
  gearStatLine, gearNetLine, gearDelta, gearCompareState, gearCompareLine,
  lockState, lockLabel, nextLevelLine,
  isEquipped, unlockState, unlockStateLabel,
  attachmentFitNames, attachmentFitLine, attachmentSpecLine, attachmentWorksOn, weaponModStatus,
  equippedGearForSlot, equippedAttachmentForSlot, equippedLoadout, equippedCount,
} from '../app/ui/career-catalog.mjs';
import {gearBudget, gearPoints, GEAR, GEAR_SLOTS, UNLOCKS} from '../game/progression.mjs';
import {attachmentById, attachmentFits, ATTACHMENTS, ATTACHMENT_SLOTS} from '../game/attachments.mjs';
import {WEAPONS} from '../game/data.mjs';

const root = new URL('../', import.meta.url);
const read = path => readFile(new URL(path, root), 'utf8');
const FIXTURE_WEAPONS = [{name: 'Pulse Rifle'}, {name: 'Rocket Launcher'}, {name: 'Rail Lance'}, {name: 'Scattergun'}];

test('the gear stat line is the resolver point vector in a fixed axis order', () => {
  const item = {modifiers: {damage: 1.1, speed: .9, spread: .85, armor: 25, health: 10}};
  const points = gearPoints(item.modifiers);
  assert.deepEqual({...points}, {offense: 10, mobility: -10, handling: 15, ehp: 35});
  assert.equal(gearStatLine(item), 'DMG +10 · SPD -10 · EHP +35 · HND +15', 'axes are offense, mobility, ehp, handling');
  assert.deepEqual(CAREER_AXES, ['offense', 'mobility', 'ehp', 'handling'], 'the axis order is pinned');
  assert.deepEqual({...AXIS_ABBR}, {offense: 'DMG', mobility: 'SPD', ehp: 'EHP', handling: 'HND'});
  assert.equal(gearStatLine({}), 'DMG 0 · SPD 0 · EHP 0 · HND 0', 'an item with no modifiers reads as a clean zero vector');
  assert.equal(gearStatLine(undefined), 'DMG 0 · SPD 0 · EHP 0 · HND 0', 'a missing item never throws');
});

test('the gear net line is the budget resolver, including axis arrows and the cap', () => {
  const item = {powerAxis: 'offense', costAxis: 'mobility', budget: 15, modifiers: {damage: 1.1, speed: .9}};
  const spend = gearBudget(item);
  assert.equal(spend.net, 0);
  assert.equal(gearNetLine(item), 'DMG▲ SPD▼ · NET 0/15', 'power/cost arrows and the slot budget come from gearBudget');
  assert.equal(gearNetLine({powerAxis: 'ehp', costAxis: 'mobility', budget: 25, modifiers: {armor: 25, speed: .98}}), 'EHP▲ SPD▼ · NET 23/25');
  assert.deepEqual(gearDelta(item, null), {offense: 10, mobility: -10, ehp: 0, handling: 0}, 'an empty slot diffs against zero');
});

test('the per-slot compare classifies upgrades, trades, downgrades and even swaps', () => {
  const equipped = {id: 'equipped', modifiers: {damage: 1.1, spread: .9}};
  const upgrade = {id: 'upgrade', modifiers: {damage: 1.15, spread: .9}};
  const trade = {id: 'trade', modifiers: {damage: 1.15, spread: 1.05}};
  const downgrade = {id: 'downgrade', modifiers: {damage: .95, spread: 1.05}};
  const even = {id: 'even', modifiers: {damage: 1.1, spread: .9}};
  assert.equal(gearCompareState(equipped, equipped), 'equipped', 'the fitted item is not compared to itself');
  assert.equal(gearCompareLine(equipped, equipped), '', 'the fitted item shows no delta');
  assert.equal(gearCompareState(upgrade, null), 'empty', 'an empty slot has no baseline');
  assert.equal(gearCompareLine(upgrade, null), '');
  assert.equal(gearCompareState(upgrade, equipped), 'upgrade');
  assert.equal(gearCompareLine(upgrade, equipped), 'UPGRADE VS EQUIPPED · DMG +5 · SPD 0 · EHP 0 · HND 0');
  assert.equal(gearCompareState(trade, equipped), 'trade');
  assert.match(gearCompareLine(trade, equipped), /^TRADE VS EQUIPPED · DMG \+5 · .* HND -15$/, 'a handling loss is signed by the resolver');
  assert.equal(gearCompareState(downgrade, equipped), 'downgrade');
  assert.equal(gearCompareState(even, equipped), 'even');
  assert.equal(gearCompareLine(even, equipped), 'NO CHANGE VS EQUIPPED · DMG 0 · SPD 0 · EHP 0 · HND 0');
});

test('lock state names the exact level and the exact number of levels still owed', () => {
  assert.deepEqual({...lockState({level: 12}, 7)}, {locked: true, required: 12, current: 7, levelsAway: 5});
  assert.equal(lockLabel({level: 12}, 7), 'LOCKED · LV 12 · 5 LEVELS TO GO');
  assert.equal(lockLabel({level: 12}, 11), 'LOCKED · LV 12 · 1 LEVEL TO GO', 'a single level reads singular');
  assert.equal(lockLabel({level: 12}, 12), 'UNLOCKED', 'reaching the gate is never still locked');
  assert.equal(lockLabel({}, 1), 'UNLOCKED', 'a missing item level defaults to level 1');
  assert.equal(nextLevelLine({level: 30}, 21), '9 LEVELS TO LV 30');
  assert.equal(nextLevelLine({level: 30}, 30), '');
  assert.equal(lockState({level: 5}, 0).current, 1, 'the profile level floor is 1');
});

test('unlock state separates equipped from merely unlocked and locked', () => {
  const profile = {level: 30, gear: {primary: 'heavy-barrel'}, attachments: {optic: 'holo-sight'}, finish: 'finish-a', crosshair: 'cross-a'};
  assert.equal(isEquipped(profile, 'gear', 'heavy-barrel'), true);
  assert.equal(isEquipped(profile, 'gear', 'scope'), false);
  assert.equal(isEquipped(profile, 'attachment', 'holo-sight'), true);
  assert.equal(isEquipped(profile, 'finish', 'finish-a'), true);
  assert.equal(isEquipped(profile, 'crosshair', 'cross-a'), true);
  assert.equal(isEquipped(profile, 'finish', null), false);
  assert.equal(unlockState(profile, {kind: 'gear', ref: 'heavy-barrel', level: 5}), 'equipped');
  assert.equal(unlockState(profile, {kind: 'gear', ref: 'scope', level: 2}), 'unlocked');
  assert.equal(unlockState(profile, {kind: 'attachment', ref: 'holo-sight', level: 2}), 'equipped');
  assert.equal(unlockState(profile, {kind: 'finish', id: 'finish-a', level: 1}), 'equipped', 'cosmetic unlocks carry their id, not a ref');
  assert.equal(unlockStateLabel(profile, {kind: 'gear', ref: 'heavy-barrel', level: 5}), 'EQUIPPED');
  assert.equal(unlockStateLabel(profile, {kind: 'gear', ref: 'scope', level: 2}), 'UNLOCKED');
  assert.equal(unlockStateLabel(profile, {kind: 'gear', ref: 'command-kit', level: 50}), 'LOCKED · LV 50 · 20 LEVELS TO GO', 'a locked unlock names the exact shortfall');
});

test('attachment fit lines resolve weapon indices through the shared catalogue', () => {
  assert.deepEqual(attachmentFitNames({weapons: []}, FIXTURE_WEAPONS), ['ALL WEAPONS'], 'an empty list is universal');
  assert.equal(attachmentFitLine({weapons: []}, FIXTURE_WEAPONS), 'UNIVERSAL · ALL WEAPONS');
  assert.deepEqual(attachmentFitNames({weapons: [0, 3]}, FIXTURE_WEAPONS), ['Pulse Rifle', 'Scattergun']);
  assert.equal(attachmentFitLine({weapons: [0, 3]}, FIXTURE_WEAPONS), 'FITS Pulse Rifle, Scattergun');
  assert.deepEqual(attachmentFitNames({weapons: [9]}, FIXTURE_WEAPONS), ['WEAPON 10'], 'an unknown index still names a slot instead of dropping it');
  assert.equal(attachmentSpecLine({modifiers: {spread: .9}}), '-10% SPREAD', 'the spec line is the shared attachment resolver');
  assert.equal(attachmentWorksOn({weapons: []}, 7), true, 'a universal mod fits any index');
  assert.equal(attachmentWorksOn({weapons: [0, 3]}, 3), true);
  assert.equal(attachmentWorksOn({weapons: [0, 3]}, 2), false);
});

test('a weapon only applies the equipped mods that actually fit it', () => {
  const profile = {attachments: {optic: 'holo-sight', barrel: 'long-barrel'}};
  const chosen = Object.values(profile.attachments).map(attachmentById);
  for (let index = 0; index < WEAPONS.length; index += 1) {
    const status = weaponModStatus(profile, index, ATTACHMENTS);
    const expectedApplied = chosen.filter(item => attachmentFits(item, index)).map(item => item.id);
    const expectedBlocked = chosen.filter(item => !attachmentFits(item, index)).map(item => item.id);
    assert.deepEqual(status.applied.map(item => item.id), expectedApplied, `weapon ${index} applies the fitting mods only`);
    assert.deepEqual(status.blocked.map(item => item.id), expectedBlocked, `weapon ${index} blocks the non-fitting mods`);
    assert.equal(status.total, chosen.length);
    assert.equal(status.fitted, expectedApplied.length > 0);
  }
  const universal = weaponModStatus({attachments: {optic: 'red-dot'}}, 99, ATTACHMENTS);
  assert.deepEqual(universal.applied.map(item => item.id), ['red-dot'], 'a universal mod applies to every index');
  assert.deepEqual(weaponModStatus({}, 0, ATTACHMENTS).applied, [], 'no equipped mods apply nothing without inventing a row');
});

test('the durable loadout flattens profile slots into labelled rows with real names', () => {
  const catalogs = {
    GEAR_SLOTS: [{id: 'primary', name: 'Weapon Kit'}, {id: 'armor', name: 'Armour'}],
    GEAR: [{id: 'g1', name: 'Heavy Barrel'}],
    ATTACHMENT_SLOTS: [{id: 'optic', name: 'Optic'}],
    ATTACHMENTS: [{id: 'a1', name: 'Holo Sight'}],
    WEAPON_FINISHES: [{id: 'f1', name: 'Carbon'}],
    CROSSHAIR_STYLES: [{id: 'c1', name: 'Dot'}],
  };
  const profile = {gear: {primary: 'g1'}, attachments: {optic: 'a1'}, finish: 'f1', crosshair: null};
  const rows = equippedLoadout(profile, catalogs);
  assert.deepEqual(rows.map(row => [row.label, row.name]), [
    ['Weapon Kit', 'Heavy Barrel'],
    ['Armour', null],
    ['Optic', 'Holo Sight'],
    ['Weapon finish', 'Carbon'],
    ['Reticle', null],
  ]);
  assert.deepEqual(equippedLoadout(null, catalogs).map(row => row.name), [null, null, null, null, null], 'a missing profile reads as empty slots');
  assert.equal(equippedGearForSlot(profile, 'primary', catalogs.GEAR).name, 'Heavy Barrel');
  assert.equal(equippedGearForSlot(profile, 'armor', catalogs.GEAR), null);
  assert.equal(equippedAttachmentForSlot(profile, 'optic', catalogs.ATTACHMENTS).name, 'Holo Sight');
  assert.equal(equippedCount(profile), 3, 'only filled slots are counted');
  assert.equal(equippedCount(null), 0);
});

test('every shipped catalogue entry produces an honest line with no unknown axis', () => {
  for (const item of GEAR) {
    assert.ok(gearStatLine(item).length > 0, `${item.id} has a stat line`);
    assert.match(gearNetLine(item), / · NET -?\d+(\.\d+)?\/\d+$/, `${item.id} has a net/budget line`);
    assert.ok(gearCompareLine(item, null) === '' || gearCompareLine(item, null).includes('VS EMPTY'), 'an empty baseline never produces a delta');
  }
  for (const item of ATTACHMENTS) {
    assert.ok(attachmentSpecLine(item).length > 0 || Object.keys(item.modifiers || {}).length === 0, `${item.id} has resolver chips when it declares modifiers`);
    assert.ok(/^(UNIVERSAL · ALL WEAPONS|FITS )/.test(attachmentFitLine(item, WEAPONS)), `${item.id} has a fit line`);
  }
  const profile = {level: 1};
  for (const item of UNLOCKS) {
    const label = unlockStateLabel(profile, item);
    assert.ok(label === 'EQUIPPED' || label === 'UNLOCKED' || label.startsWith('LOCKED · LV '), `${item.id} has a truthful state label (${label})`);
  }
  assert.ok(GEAR_SLOTS.length > 0 && ATTACHMENT_SLOTS.length > 0, 'the real slot catalogues are present');
});

test('the progression screen renders the compare, fit, lock and equipped facts', async () => {
  const source = await read('app/ui/screens/ProgressionScreen.tsx');
  assert.match(source, /from '\.\.\/career-catalog\.mjs'/, 'the screen reads the shared pure model');
  assert.match(source, /gearCompareLine/, 'the gear slot compare renders on each option');
  assert.match(source, /attachmentFitLine/, 'the mod compatibility line renders');
  assert.match(source, /unlockStateLabel/, 'equipped vs merely unlocked is labelled');
  assert.match(source, /equippedLoadout/, 'the durable profile loadout is shown');
  assert.match(source, /EQUIPPED · /, 'the equipped slot owner is named');
  assert.match(source, /lockLabel/, 'locked entries name the exact shortfall through the shared label');
  assert.doesNotMatch(source, /\bBUY\b|\bPURCHASE\b/, 'no purchase affordance is invented on the career surface');
  assert.doesNotMatch(source, /aria-live/, 'the progression screen adds no live region');
});

test('the arsenal inspector shows equipped state, mod fit and exact lock reasons without a live region', async () => {
  const source = await read('app/ui/screens/SettingsDialog.tsx');
  assert.match(source, /from '\.\.\/career-catalog\.mjs'/, 'the inspector reads the shared pure model');
  assert.match(source, /weaponModStatus/, 'each weapon reports the equipped mods that actually fit it');
  assert.match(source, /attachmentFitLine/, 'mod compatibility is shown');
  assert.match(source, /gearCompareLine/, 'gear options compare against the fitted item');
  assert.match(source, /unlockStateLabel|lockLabel/, 'locked entries name the exact shortfall');
  assert.match(source, /equippedLoadout/, 'the saved loadout is surfaced');
  assert.match(source, /EQUIPPED/, 'equipped is distinct from unlocked');
  assert.doesNotMatch(source, /aria-live/, 'the inspector still adds no live region');
  assert.doesNotMatch(source, /\bBUY\b|\bPURCHASE\b/, 'the read-only inspector never invents a purchase button');
  // The exported surfaces the existing SSR suite imports must survive.
  assert.match(source, /export function SettingsDialog/, 'SettingsDialog stays exported');
  assert.match(source, /export function ArsenalInspector/, 'ArsenalInspector stays exported');
  assert.match(source, /export function WeaponCompare/, 'WeaponCompare stays exported');
  assert.match(source, /export function HelpSections/, 'HelpSections stays exported');
});
