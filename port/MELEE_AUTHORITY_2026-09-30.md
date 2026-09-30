# Authoritative melee derivative — 2026-09-30

## Integration and provenance

- Immutable original source identity: `515daf07589150dd3241f4ae1425cc1b093912f5`.
- Previous reviewed source derivative: `61fca35c65488502b794900cde0a5247bfb123bf`.
- New scoped gameplay source commit: `0326b435a2fdd88e6e7a01b8a7325feccc4d15cb`.
- New `game/core.mjs` SHA-256:
  `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
- `port/contracts/lattice-catalog-derivative.json` explicitly selects the new
  derivative. Its other nine runtime hashes retain the previous derivative bytes.
- The campaign generator now pins this hash. Its generated core differs only in
  the existing 34 import rewrites and NPC `actorHit` specialization; inverse-byte
  comparison and exact regeneration remain enforced.

**Merge this branch preserving its source commit ancestry.** A cherry-pick creates
a different commit: if cherry-picking is necessary, update the derivative contract
to the resulting source commit and re-run source provenance checks. The source
verifier deliberately checks ancestry as well as bytes. Historical verification
and package reports describe their recorded older builds; a new package must be
built and verified against this derivative.

## Authority and input

Native multiplayer (`server/room.mjs`) and native Horde use `game/core.mjs`.
Campaign uses the generated copy of that same implementation. There is no client
damage or knockback authority.

Cooldown is 0.3 s; range, damage and arc stay 2.4 m / 45 / 0.2. External held input
is edge-consumed in Match, including refused cooldown presses. Dead-player input
is consumed so a held request does not become a fresh press on respawn. Direct
`Match.melee` calls are explicit attempts and remain cooldown gated. Native Horde
now emits F pulses, ignores key-repeat and duplicate keydowns, and preserves
physical down-state across focus/modal clears until release. Shared combat input
already implements this edge contract. Combined-arms infantry input gains F with
its existing focus/eligibility/physical-release gate.

Actual damage shoves a surviving enemy at most 0.85 m, scaled down by existing
knockback resistance. It uses <=0.08 m collision increments, body-radius bounds,
body/terrain sweeps and grounded support checks across the footprint. It stops at
walls, voids and >0.25 m support discontinuities, follows shallow floor changes,
and preserves vx/vy/vz. Mounted and active traversal targets keep their movement
owner's position. Dead targets and teammates are excluded; protection, immunity,
shields and mitigation are resolved by the existing damage authority. A zero
damage contact cannot shove. Killing hits still report damage/contact but do not
move a corpse.

## Public event contract

Every accepted attempt emits one `type: 'melee'` event (plus normal authority event
id/time). Refused cooldown/dead/mounted/ended/race attempts emit none.

| Field | Meaning |
|---|---|
| `actor` | Attacker id (zero is valid). |
| `hit` | Target id only when actual damage > 0, otherwise null. |
| `target` | Contacted actor id, including invulnerable contact; otherwise null. |
| `outcome` | `hit`, `blocked` (contact but zero damage), or `miss`. |
| `damage` | Actual returned health/shield/armor damage; zero on block/miss. |
| `pos` | Attacker eye at attempt time; legacy kick origin, use for the swing swoosh. |
| `impact` | Target hit-volume contact before knockback, including blocked contacts; null on miss. |
| `direction` | Unit attack/contact direction. |
| `normal` | Opposing contact-facing unit direction, null on miss (not a mesh triangle normal). |
| `knockback` | Applied authoritative displacement `{x,y,z}`, including collision truncation or zero. |

Animate/swoosh on each accepted attempt. Smack/shockwave should require
`outcome === 'hit'` / `damage > 0`, and use `impact` plus `direction`/`normal`.

## Verification status and pending slot

Lightweight checks completed: core JavaScript syntax, `git diff --check`, and
three text/Git-only campaign provenance tests (all passed). These prove the
selected runtime inventory and hashes, retained original identity, exact generated
bytes and inverse source-byte reconstruction.

Heavy imports/simulations and Godot runs are deferred to the parent's granted
slot (Astra capture owns it during implementation). Added/updated tests cover
actual contact, misses, immunity, teammates, thin walls, bounds, void/steep ledges,
shallow support changes, preserved movement, cooldown discard, held/no-repeat,
rapid fresh presses and focus/release. Pending runs:

```sh
node --test --test-concurrency=1 game/melee.test.mjs game/spec-passives.test.mjs port/native-horde/melee-hold.test.mjs server/room.test.mjs
node --test --test-concurrency=1 port/native-campaign/campaign.test.mjs port/native-campaign/hit-volume.test.mjs port/native-campaign/authority.test.mjs tools/godot-export/source-inventory.test.mjs
```

Also run Godot Horde controls, shared combat-actions controls and combined-arms
controls tests with their usual fixtures, followed by the integration's full
source/package verifier and requested native gameplay captures.
