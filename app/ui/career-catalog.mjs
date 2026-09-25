// Pure presentation model for the career / arsenal surfaces (ProgressionScreen
// and the SettingsDialog Arsenal inspector).
//
// Everything here is derived from the same resolvers the match consumes
// (`gearPoints` / `gearBudget` for gear, `attachmentSpec` / `attachmentFits` for
// weapon mods) plus the generic catalogue and profile fields. A card therefore
// can never advertise an effect, a fit or a lock state the simulation would not
// apply — and the focused Node tests can read the same data without a DOM,
// React or a browser.
//
// No engine imports beyond the two pure catalogues, so the career source agent
// can keep reworking the progression internals as long as these resolvers keep
// their published shape.
import {gearBudget, gearPoints} from '../../game/progression.mjs';
import {attachmentFits, attachmentSpec} from '../../game/attachments.mjs';

// Fixed axis order keeps every stat/compare line deterministic for tests and
// stable across renders: offense, mobility, ehp, handling.
export const CAREER_AXES = Object.freeze(['offense', 'mobility', 'ehp', 'handling']);
export const AXIS_ABBR = Object.freeze({offense: 'DMG', mobility: 'SPD', ehp: 'EHP', handling: 'HND'});

const round3 = value => Math.round(value * 1000) / 1000;
const levelOf = item => Math.max(1, Math.round(Number(item?.level) || 1));
const signedPoint = value => `${value > 0 ? '+' : ''}${value}`;
const axisLabel = axis => AXIS_ABBR[axis] || String(axis || '—').toUpperCase();

// --- Gear -------------------------------------------------------------------
// The resolver's own point vector, so the loadout card never drifts from the
// capped modifiers `resolveGear` applies.
export function gearStatLine(item) {
  const points = gearPoints(item?.modifiers);
  return CAREER_AXES.map(axis => `${axisLabel(axis)} ${signedPoint(points[axis])}`).join(' · ');
}
export function gearNetLine(item) {
  const spend = gearBudget(item);
  return `${axisLabel(item?.powerAxis)}▲ ${axisLabel(item?.costAxis)}▼ · NET ${spend.net}/${spend.budget}`;
}
// Signed point difference of a candidate against the item already fitted in its
// slot. Positive is a benefit on every axis (handling already folded by
// `gearPoints`), so the compare line never inverts the sign.
export function gearDelta(candidate, equipped) {
  const candidatePoints = gearPoints(candidate?.modifiers);
  const equippedPoints = equipped ? gearPoints(equipped.modifiers) : null;
  const out = {};
  for (const axis of CAREER_AXES) out[axis] = round3(candidatePoints[axis] - (equippedPoints ? equippedPoints[axis] : 0));
  return out;
}
const COMPARE_WORD = Object.freeze({upgrade: 'UPGRADE', downgrade: 'DOWNGRADE', trade: 'TRADE', even: 'NO CHANGE'});
export function gearCompareState(candidate, equipped) {
  if (!equipped) return 'empty';
  if (candidate?.id && candidate.id === equipped.id) return 'equipped';
  const delta = gearDelta(candidate, equipped);
  const ups = CAREER_AXES.filter(axis => delta[axis] > 0).length;
  const downs = CAREER_AXES.filter(axis => delta[axis] < 0).length;
  if (!ups && !downs) return 'even';
  if (ups && !downs) return 'upgrade';
  if (downs && !ups) return 'downgrade';
  return 'trade';
}
export function gearCompareLine(candidate, equipped) {
  const state = gearCompareState(candidate, equipped);
  if (state === 'empty' || state === 'equipped') return '';
  const delta = gearDelta(candidate, equipped);
  const body = CAREER_AXES.map(axis => `${axisLabel(axis)} ${signedPoint(delta[axis])}`).join(' · ');
  return `${COMPARE_WORD[state]} VS EQUIPPED · ${body}`;
}

// --- Lock state -------------------------------------------------------------
// Level is the only gate the catalogue declares, so the reason is exact and
// machine-readable instead of a bare "LV n".
export function lockState(item, level) {
  const required = levelOf(item);
  const current = Math.max(1, Math.round(Number(level) || 1));
  const locked = current < required;
  return Object.freeze({locked, required, current, levelsAway: Math.max(0, required - current)});
}
export function lockLabel(item, level) {
  const state = lockState(item, level);
  if (!state.locked) return 'UNLOCKED';
  return `LOCKED · LV ${state.required} · ${state.levelsAway} ${state.levelsAway === 1 ? 'LEVEL' : 'LEVELS'} TO GO`;
}
export function nextLevelLine(item, level) {
  const state = lockState(item, level);
  return state.locked ? `${state.levelsAway} ${state.levelsAway === 1 ? 'LEVEL' : 'LEVELS'} TO LV ${state.required}` : '';
}

// --- Equipped state ---------------------------------------------------------
// `unlocked` and `equipped` are different facts: an item the career has granted
// is not necessarily the one fitted into the slot.
export function isEquipped(profile, kind, id) {
  const p = profile && typeof profile === 'object' ? profile : {};
  if (!id) return false;
  if (kind === 'gear') return Object.values(p.gear || {}).includes(id);
  if (kind === 'attachment') return Object.values(p.attachments || {}).includes(id);
  if (kind === 'finish') return p.finish === id;
  if (kind === 'crosshair') return p.crosshair === id;
  return false;
}
export function unlockState(profile, item) {
  if (lockState(item, profile?.level).locked) return 'locked';
  return isEquipped(profile, item?.kind, item?.ref ?? item?.id) ? 'equipped' : 'unlocked';
}
export function unlockStateLabel(profile, item) {
  const state = unlockState(profile, item);
  if (state === 'locked') return lockLabel(item, profile?.level);
  return state === 'equipped' ? 'EQUIPPED' : 'UNLOCKED';
}

// --- Weapon mods ------------------------------------------------------------
// Weapon indices resolve through the same catalogue the match uses, and an
// empty `weapons` list means universal, exactly like `attachmentFits`.
export function attachmentFitNames(item, weapons = []) {
  const list = Array.isArray(weapons) ? weapons : [];
  const indexes = Array.isArray(item?.weapons) ? item.weapons : [];
  if (!indexes.length) return ['ALL WEAPONS'];
  return indexes.map(index => list[Number(index)]?.name || `WEAPON ${Number(index) + 1}`);
}
export function attachmentFitLine(item, weapons = []) {
  const names = attachmentFitNames(item, weapons);
  return names.length === 1 && names[0] === 'ALL WEAPONS' ? 'UNIVERSAL · ALL WEAPONS' : `FITS ${names.join(', ')}`;
}
export function attachmentSpecLine(item) {
  return attachmentSpec(item).join(' · ');
}
export function attachmentWorksOn(item, weaponIndex) {
  return attachmentFits(item, weaponIndex);
}
// What the equipped mod set actually does to one weapon: fittings that apply
// are separated from fittings the match will ignore because the weapon is not
// on their list. This is the "applied vs merely unlocked" distinction.
export function weaponModStatus(profile, weaponIndex, attachments = []) {
  const equipped = (profile && profile.attachments) || {};
  const byId = new Map((Array.isArray(attachments) ? attachments : []).map(item => [item.id, item]));
  const applied = [];
  const blocked = [];
  for (const id of Object.values(equipped)) {
    const item = byId.get(id);
    if (!item) continue;
    (attachmentFits(item, weaponIndex) ? applied : blocked).push(item);
  }
  return Object.freeze({applied, blocked, total: applied.length + blocked.length, fitted: applied.length > 0});
}

// --- Durable profile loadout ------------------------------------------------
// Flattens the saved selection into label/value rows so the surfaces can show
// what is actually persisted, and which slots are still empty, without each one
// re-deriving the slot maps.
export function equippedGearForSlot(profile, slot, gearList = []) {
  const id = (profile && profile.gear && profile.gear[slot]) || null;
  return id ? (Array.isArray(gearList) ? gearList : []).find(item => item.id === id) || null : null;
}
export function equippedAttachmentForSlot(profile, slot, attachments = []) {
  const id = (profile && profile.attachments && profile.attachments[slot]) || null;
  return id ? (Array.isArray(attachments) ? attachments : []).find(item => item.id === id) || null : null;
}
export function equippedLoadout(profile, catalogs = {}) {
  const p = profile && typeof profile === 'object' ? profile : {};
  const nameOf = (list, id) => (Array.isArray(list) ? list : []).find(item => item.id === id)?.name || null;
  const rows = [];
  for (const slot of Array.isArray(catalogs.GEAR_SLOTS) ? catalogs.GEAR_SLOTS : []) {
    rows.push({group: 'GEAR', kind: 'gear', slot: slot.id, label: slot.name, name: nameOf(catalogs.GEAR, p.gear?.[slot.id])});
  }
  for (const slot of Array.isArray(catalogs.ATTACHMENT_SLOTS) ? catalogs.ATTACHMENT_SLOTS : []) {
    rows.push({group: 'MOD', kind: 'attachment', slot: slot.id, label: slot.name, name: nameOf(catalogs.ATTACHMENTS, p.attachments?.[slot.id])});
  }
  rows.push({group: 'FINISH', kind: 'finish', slot: 'finish', label: 'Weapon finish', name: nameOf(catalogs.WEAPON_FINISHES, p.finish)});
  rows.push({group: 'RETICLE', kind: 'crosshair', slot: 'crosshair', label: 'Reticle', name: nameOf(catalogs.CROSSHAIR_STYLES, p.crosshair)});
  return rows;
}
export function equippedCount(profile) {
  const p = profile && typeof profile === 'object' ? profile : {};
  return Object.values(p.gear || {}).filter(Boolean).length + Object.values(p.attachments || {}).filter(Boolean).length + (p.finish ? 1 : 0) + (p.crosshair ? 1 : 0);
}
