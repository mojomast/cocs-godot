# Persistent career gear and weapon-mod expansion

This development branch extends the web/source career catalogue after the
source commit named in `port/contracts/source-lock.json`. It is a new derivative,
not a byte-for-byte reproduction of the published LATTICE preview. The original
gear and attachment IDs, unlock levels and modifiers retain their earlier
values; existing profiles and equipped presets remain valid.

`game/progression.mjs` now offers 23 gear choices across primary, armour and
utility slots (previously 8). Each additional choice changes the spawn health,
armour, damage, movement speed or spread that `resolveGear` applies. Distinct
power/cost axes, one-per-slot selection, the existing slot budgets and final
combined caps remain enforced. New choices unlock from levels 5 to 50; existing
level-2-through-9 unlocks still occupy their original positions.

`game/attachments.mjs` now offers 22 weapon mods (previously 14), including
early per-slot starter choices and later weapon-specific options. The two-round
Salvo Module uses the existing firing loop's burst behavior; the other additions
use existing weapon-stat modifiers. Weapon compatibility and level gating are
resolved through the same attachment normalization/fit rules as before.

The Career loadout and unlock track and the Arsenal inspector show stat-derived
descriptions, levels and tradeoffs. Career gear persists between matches; personal
REQ purchases in LATTICE remain round-scoped and are described in `REQ.md`.
These are source/web screens. A native Godot career gear selector or personal
REQ shop has not been implemented by this catalog lane.

Verification: focused progression, gear dominance, attachment behavior,
bot-loadout, server persistence and balance-manifest contracts; TypeScript
typecheck, targeted UI/view tests and bounded web production build. The full
smoke **neutral-policy** stock and max-gear sweeps each completed 144/144 matches
with zero mode alarms. The separate stock-vs-max tier invariant **failed**:
operator rank correlation 0.3833 (max shift 6), spec correlation 0.5357 (shift 3)
and wing correlation -0.5 (shift 2), against the required correlation ≥0.85
and max shift ≤2. The complete reports are kept at
`/home/mojo/.tmp-on-disk/lattice-catalog-evidence-20260925/` outside this
repository (`lattice-catalog-stock-fullsmoke.json` SHA-256
`6903ad0b13bb98ed7c92fc4441b8eca4a41ee333c9bde8c06fb3a586ea1846b3`,
`lattice-catalog-max-fullsmoke.json` SHA-256
`d1d7dd216fa84c15ce48b8ee53ab92635368f1b9d13c33b87d0641685a2db302`).
These numbers do not justify a balanced-capstone claim or replace the broader
two-policy gate. The 32-match comparison also failed the tier invariant; small
samples were not treated as acceptance evidence.

For context, an otherwise identical 144-match max-gear sweep against the **old**
eight-item source catalog also failed the same stock reference (operator/spec/
wing correlations 0.2333/0.8571/0.5, and max gain above the permitted 4 points).
Its separate report is `lattice-catalog-old-max-fullsmoke.json` in the same
directory (SHA-256 `cc35dd3090a619d1037fe93e0eae1a4eddd868c9d63a59159c62e47f8b538221`).
Therefore the invariant was already unearned on this sample; the expanded
capstones do not establish it either. This comparison is diagnostic, not a
substitute for a tuned two-policy acceptance sweep.
