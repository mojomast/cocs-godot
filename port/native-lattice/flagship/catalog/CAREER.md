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
`/tmp/opencode/lattice-catalog-{stock,max}-fullsmoke.json` in this session.
These numbers do not justify a balanced-capstone claim or replace the broader
two-policy gate. The 32-match comparison also failed the tier invariant; small
samples were not treated as acceptance evidence.
