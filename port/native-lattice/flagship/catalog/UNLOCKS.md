# Career unlock and upgrade authority

This development branch hardens the career unlock/upgrade layer on top of the
gear and attachment catalogue recorded in `catalog/CAREER.md`. It is a new
derivative, not a byte-for-byte reproduction of the published LATTICE preview:
the source commit named in `port/contracts/source-lock.json` is unchanged, and
no stat vector, slot budget or envelope cap was moved. Every existing profile
field, unlock id, signature and call shape still works.

The problem this lane fixes is that **unlock ownership and equip validation
disagreed with each other**. Four surfaces each decided whether an item was
allowed, using three different rules:

| Surface | Old rule |
| --- | --- |
| `unlockedItems` / `nextUnlockFor` (unlock track) | `UNLOCKS[].level <= level`, plus stored `unlocks` |
| `normalizeGear` / `normalizeAttachments` (loadout) | item `level <= level` only |
| `normalizeProgression` cosmetics | valid **id** only, level ignored |
| `ProgressionStore.setGear` (server write) | item `level <= level`; finish valid id only |

That let a level-1 profile equip a level-22 finish or a level-16 crosshair, and
silently dropped an item the profile had *explicitly* been granted (a reward, a
season drop, or a legacy profile whose xp curve moved under it). The unlock
track and the loadout could therefore disagree about the same profile.

## The authority

`game/progression.mjs` now exposes one gate and routes every normaliser through
it:

```js
isUnlocked(entryId, level = 1, owned = null) -> boolean
```

`UNLOCKS` (gear, attachments, weapon finishes, crosshairs) is the single source
of truth. An entry is available when `UNLOCKS[entryId].level <= level` **or**
`owned[entryId] === true`. Unknown ids are always false. `owned` is the
profile's stored `unlocks` map, so a grant survives regardless of the level
recomputed from xp.

All additions are pure and backwards compatible:

| Export | Change | Notes |
| --- | --- | --- |
| `isUnlocked(entryId, level, owned?)` | **new** | the authority above |
| `normalizeGear(value, level?, owned?)` | optional 3rd arg | honours explicit grants |
| `normalizeAttachments(value, level?, owned?)` | optional 3rd arg | `owned` keyed `attachment-<id>` |
| `resolveGearItem(item)` | **new** | one definition through the §4.8 envelope |
| `resolveAttachmentItem(item)` | **new** (`game/attachments.mjs`) | one mod through the range clamps |
| `unlockPlan(profile, {limit?})` | **new** | loadout-aware upgrade roadmap |
| `catalogAudit({gear?, attachments?})` | **new** | duplicate / dead-upgrade detector |
| `ProgressionStore.setGear(id, gear, attachments, finish, crosshair?)` | optional 5th arg | gated write; existing 4-arg callers unchanged |

`normalizeGear`/`normalizeAttachments` with the argument omitted behave exactly
as before, so web callers and presets need no change.

## Upgrade roadmap and audit

`unlockPlan(profile)` turns the flat level order into per-slot, applied-effect
advice. For each gear and attachment slot it returns the equipped item, the next
locked items, and for every candidate:

- `verdict` — `new` | `upgrade` | `sidegrade` | `downgrade` | `duplicate`,
  computed by resolving the candidate and the equipped item through the same
  `resolveGear` / `resolveAttachments` the live match uses;
- `changes` — the applied axis deltas; `before` / `after` snapshots;
- `replaces`, `gap`, `actionable`, and (attachments) `universal`,
  `compatibleWeapons`, `behaviorChanged`.

`nextUpgrade` and `nextActionable` scan the whole remaining catalogue and skip
`downgrade`/`duplicate` candidates, so a later real upgrade is not hidden behind
a nearer dead one. `nextUnlock`/`nextUnlocks` are unchanged and still expose the
flat level order the results/selection surfaces render today.

`catalogAudit()` is the authoring gate: it reports same-slot entries with an
identical applied effect (`duplicate`) and higher-level entries that are
strictly worse on every axis than a same-slot entry that unlocks no later
(`dead-upgrade`). Attachment dominance also requires the earlier entry's weapon
list to be a superset, so a universal mod is never called dominated by a
weapon-locked one; a behaviour-parameter change (burst 3 vs burst 2) is a real
change, not a duplicate.

### Known finding (not fixed: no stat, cap or base-vector changes)

The resolved audit reports exactly one dead upgrade in the shipped catalogue:

```
dead-upgrade gear primary: light-frame (level 8) strictly dominates command-kit (level 50)
```

`light-frame` declares `armor:-5`, which `resolveGear` clamps to `0`. Once that
clamp is applied, `light-frame` matches the `command-kit` damage (`1.08`) and is
better on both mobility (`1` vs `0.95`) and spread (`0.9` vs `0.95`). The level-50
capstone is therefore mechanically worse than a level-8 item, even though the
declared-vector `no item dominates any other` gate in `gear-dominance.test.mjs`
passes (it compares the raw `-5` armour before the clamp).

Per this lane's scope this is **reported, not re-tuned**: correcting it needs a
stat or level change that would move the §4.8 envelope and the stock-vs-max
balance comparison, and the existing full-smoke tier invariant is already
failing on this sample. The behavioral mitigation is that `unlockPlan` labels
`command-kit` a `downgrade` and never offers it as an upgrade, while the unlock
track still announces it. `catalogAudit().ok` is `false` with this single pinned
issue; the focused test pins the exact issue set so a future catalogue edit must
be deliberate.

## Integration contract (career-UI lane)

The separate Flash career-UI branch cannot rely on the new exports until this
work is merged; nothing here removes or renames an existing export.

- **No change required:** `nextUnlockFor`, `nextUnlocksFor`, `unlockedItems`,
  `matchRewardSummary`, `matchSummaryCard`, `normalizeGear(value, level)`,
  `normalizeAttachments(value, level)` keep their shapes.
- **Adopt after merge:** `unlockPlan(profile)` for an actionable per-slot chip;
  `isUnlocked(slot, level, owned)` if the screen wants the same gate locally.
- **Server:** `setGear` now rejects a locked finish/crosshair and honours stored
  grants. An optional 5th `crosshair` argument is accepted but the `GEAR`
  packet does not carry it yet, so crosshair still persists only through the
  profile load path until a later wire change.
- A preset saved with a locked cosmetic id will now be normalised to `null` on
  load instead of being applied; this is the intended integrity fix.

## Verification

Focused Node tests (no broad suites, no Godot/import/render/build/sweep):

```
node --test game/unlock-upgrade.test.mjs game/progression.test.mjs \
  game/attachments.test.mjs game/gear-dominance.test.mjs server/progression.test.mjs
```

`game/unlock-upgrade.test.mjs` pins `isUnlocked`, ownership-aware gear and
attachment normalisation, cosmetic level gating, single-item resolver agreement
for every shipped item, the roadmap's dead-capstone skip, and the synthetic
duplicate/dead-upgrade detector. `game/result-learning.test.mjs` is not in this
set: it cannot load because the `three` package is not installed in this
worktree, a pre-existing environmental failure unrelated to these edits.
