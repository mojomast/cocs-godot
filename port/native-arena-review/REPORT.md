# Independent review of the native Deathmatch delivery (review lane)

Reviewer lane: `port/native-arena-review/**` + `godot/tests/native_arena_review/**`.
Read-only with respect to every other path. All numbers below come from my own
harnesses and logs in this directory, not from the delivered gate logs.

Reviewed revision: `454debba` (working tree also carried concurrent,
uncommitted work from the `source_operators` lane; see §6).

| Map | geometryHash (recomputed by me) | nav nodes | sp/routes |
| --- | --- | ---: | --- |
| prism-foundry | `9ba6d451e7acb61847d1b5726ec52385c019e32bbc0805731f14396aca336572` | 378 (mine: 378) | 6 / 7 |
| aurora-basin | `2a8c06ba5b3a893135a3a6aef906a36f016107b5153fe5ec3b8a9efbfee66c86` | 303 (mine: 303) | 6 / 4 |
| cinder-array | `e4b7763a5dae391cfcc0e9a13b5202a054cdfd9761c449cf6a4bf2fd4765ab8c` | 369 (mine: 369) | 6 / 9 |

## 1. Verdict summary

Passing (independently re-derived):

- Envelope `geometryHash` for all three assets recomputed with my own
  canonicalizer (`logs/geometry-analysis-*.json`).
- Walkable support: no grounded-without-support ticks and no sunk actors in
  3 × 180 s live rounds; enclosed support pinholes are ≤ 0.75 m² (max 3 cells
  of 0.5 m) and do not block movement (`logs/probe-followup-*.json`).
- Spawns: all 6 authored feet per map supported, un-obstructed at the source
  0.42 m radius, height agreement ≤ 0.15 m; 31/93/144 live respawns all legal
  (no illegal spawn in any round).
- Pickups: all 16 per map supported, un-obstructed, and in the single connected
  nav component (reachable from spawn 0).
- Authored DM routes: every sampled point supported, `walkEdge`-continuous, no
  blocked points (worst height delta ≤ 0.3 m).
- Nav graph: one component, every node bot-usable
  (378/378, 303/303, 369/369 unobstructed at the bots' 0.378 m filter).
- Wall bands vs collider geometry: 0 samples (prism, cinder) and 3 samples
  (aurora, at the `x=42.5` bound, outside play) further than 0.9 m from any
  collider triangle; `walkEdge`-passable spans never have a blocking ray
  (`passableRayBlocked = 0` for all three maps) → no walk-through cover.
- Real source acceptance: full 180 s rounds with 1 human seat + 7 bots on all
  three maps, 10 800 ticks each, 0 non-finite/out-of-bounds/void positions;
  kills, deaths, respawns, pickups, powers, grenades, results and a clean
  restart all observed (`logs/sim-*.json`). Rounds:
  prism 180 s/time — 21 kills, 23 deaths, 23 respawns; aurora 155 s/frag
  limit — 83 kills, 86 deaths, 85 respawns; cinder 180 s/time — 64 kills,
  138 deaths, 136 respawns. Human seat: 2/51/30 kills and 2/1/15 deaths.
- Launcher path: `node tools/godot-dev/launch.mjs --experience=native-dm
  --map=<id> --smoke` exits 0 with `NATIVE_DM_SMOKE_OK` for all three maps and
  at both bot/round-seconds extremes (`bots=1/7`, `round-seconds=60/300`)
  (`logs/launcher-*.log`).
- Graphical session on a private Xvfb (`:97`), real Node authority, real
  injected input: 960x640 and 1280x800 frames for all three maps
  (`captures/<map>-*/`). Godot physics raycast straight down from the local
  eye hits the collider floor exactly at the authoritative feet Y
  (`downDistance == eye height`, `downY == actor.y`) in every frame, including
  while airborne.
- Source/game lock: `git status` clean for `game/`, `tools/` (except the
  concurrent operators lane file), `server/` and `port/contracts/`; the
  nine-map catalog list in `port/contracts/source-lock.json` is unchanged; the
  launcher's `verifySource` passed on every run; `game/*` untouched.

Defects found (details in §2):

1. **Live actor can become permanently immobile (ramp side band contact).**
   Reproduced in a real round on prism-foundry: a bot froze for 71 s. High
   gameplay severity, precise repro below.
2. **Current working tree: every native DM run spams failed remote-operator
   weapon imports** (`world_weapons/weapon-*.glb`); the assets are untracked
   concurrent work, not part of `454debba`, but they currently break remote
   weapon visuals. Low severity, attribution note in §6.
3. **Delivered Aurora graphical evidence is stale**: the retained
   `evidence/final/aurora-basin-*.png` + logs carry geometry hash
   `909daa29…` (the pre-navigation asset, 948 nav nodes), not the delivered
   `2a8c06ba…` (303 nodes). The delivered `verification.json`/`live-smoke.json`
   are current, so the *claims* hold but the *image evidence* does not match
   the shipped asset.
4. **Minor documentation inaccuracies** in `port/native-arena-geometry/README.md`
   (§4).
5. `createNativeArenaAuthority` silently ignores unknown top-level options
   (e.g. `url`) instead of rejecting them. Not exploitable (no option is
   honoured), recorded for hardening.

## 2. Defect 1 — permanent immobilisation inside the source wall-contact band

### Observation (real round, delivered asset)

`node port/native-arena-review/trap-repro.mjs --map=prism-foundry --seconds=180`
(seed 20260922, 1 human + 7 bots, `prism-foundry` hash `9ba6d451…`):

- Bot actor 6 was frozen at `(-8.96, 3.42, -8.40)` from **t = 62 s to
  t = 133 s (71 s of a 180 s round)** with `maxRadius = 0.00 m` — it never moved
  horizontally, only hopped in place (`y` oscillating 3.42 → 4.76).
  `bot.state = engage`, `bot.stuck` cycling 0 → 1.3.
- Trajectory into the trap (0.25 s sampling): the bot jumps along the west
  ramp, is airborne at `(-9.37, 4.45, -9.17)` at t = 61.0, and lands at
  `(-8.96, 3.42, -8.40)` at t = 62.0 — 0.06 m inside the ramp's side edge.
- The same detector found **no** > 2 s window on aurora-basin in 180 s (nor at
  seed 777), short windows on cinder-array (5.0 s and 2.5 s at seed 20260922,
  2.0/1.5/1.5 s at seed 777, all with `maxRadius 0`), and **none** on the
  locked source arena `meridian-exchange` (120 s, 8 actors).
- Mirrored second instance, different seed
  (`trap-repro --map=prism-foundry --seed=777`): actor 4 is immobile at exactly
  `(9.0, 3.6, …)` — the east ramp side, mirror of the west trap — for four
  consecutive windows (3.0 s, 2.5 s, 2.0 s, 1.5 s) across states
  `engage/roam/pursue`. Seed 424242 only produced a 0.5 s window, so the
  *long* (71 s) freeze is seed-dependent while the hazard is not.

### Mechanism (source-locked code, delivered bands)

`game/core.mjs moveActor` applies each axis only when the destination is *not*
`obstructed(..., RULES.radius=0.42)`. Movement is velocity/acceleration based
(sub-centimetre first steps), so an actor whose centre is already inside the
0.42 m contact band can never produce a destination outside it: every axis move
is refused and velocity is zeroed. Jumping does not help because the band's
height range still intersects the capsule.

The prism ramp's side face produces wall bands whose height range includes the
ramp surface, so the contact strip is 0.42 m wide **on the walkable ramp top
itself** and on the floor strip beside it.

### Minimal reproduction

```sh
node port/native-arena-review/trap-min.mjs          # prism-foundry
```

Result (`maxHorizontalDisplacement` after 2 s of ordinal movement input):
`0.000 m` in all four cardinal directions, and `0.000 m` with jump held, from
`(-8.96, 3.42, -8.4)`; `0.000 m` also from `(-8.6, 0, -8.4)` (0.34 m outside the
ramp face, on the atrium floor). Control positions 0.7 m further out run away
16.6 m normally.

### Why the delivered gates missed it

The delivered live gates assert kills, damage, results, restart and floor/ray
parity; none asserts that a live actor remains mobile, and the source `Match`
has no "stuck for N seconds" health check. The delivered `README.md` provenance
lists "internal ramp skirt walls" as a fixed class of failure, but the ramp's
own side bands still create reachable freeze strips.

### Suggested smallest fix (owner's call, not applied by me)

Either (a) drop wall bands that lie at/below the adjacent walkable support
within a small epsilon (the "buried seam" rule already exists, it just does not
cover walkable-adjacent faces), or (b) allow a depenetrating move in the source
movement when the current position is already obstructed (source-locked code,
so needs the source owner). A per-actor "immobile > N s while alive" assertion
in the native live gate would catch this class cheaply.

Precise evidence: `logs/trap-prism.out`, `logs/trap-*.jsonl`,
`logs/probe-move-*.json`, `logs/trap-*-*.outs`.

## 3. Requirement matrix

| Check | Result | Evidence |
| --- | --- | --- |
| Evidence images inspected (delivered) | Aurora/Cinder current-image issues: none found at 1280x720 (HUD, weapon, geometry all consistent); Aurora/Cinder 1280x720 images predate the Aurora navigation switch for Aurora; Prism has only `pre-visual-fix/` images in the delivered tree | §4, own captures |
| Rendered vs collision structure | no walk-through cover (0 samples), no invisible bands > 0.9 m from colliders (3/20931 aurora samples at the bounds edge) | `logs/geometry-analysis-*.json` |
| Real source round per map (multi-minute, bots) | 180 s / 180 s / 180 s, 1 human + 7 bots, kills 21 / 83 / 64, deaths 23 / 86 / 138, respawns 23 / 85 / 136, results + restart clean | `logs/sim-*.json`, `logs/sim-*.jsonl` |
| Launcher per map (`--smoke`) | exit 0, `NATIVE_DM_SMOKE_OK`, geometry hashes match the assets | `logs/launcher-*-smoke.log` |
| Launcher extremes | `--bots=1`, `--bots=7`, `--round-seconds=60`, `--round-seconds=300` all exit 0 | `logs/launcher-*-bots*.log` |
| Graphical native session 960x640 + 1280x800 | all three maps, real authority, real injected input, Xvfb `:97`; FP rig, HUD, scores, weapon, pickups, effects | `captures/*/`, `captures/*/godot-filtered.log` |
| Boundary cases | see §5 | `logs/boundary-*.json` |
| Source/catalog lock | `game/` clean, nine map ids unchanged, `verifySource` passes | §5, `git status` |

## 4. Delivered-claim audit

Claims I could confirm:

- "Aurora now uses source nextGen navigation (hash 2a8c06ba…), 303 nodes" —
  confirmed: hash recomputed, `navigation()` returns 303 nodes, one component.
- "cold construct 2.28 s" — consistent: my cold `createNativeMatch` (which also
  re-reads/parses the 5.6 MB JSON) took 2.48 s; the live smoke round finished
  inside the launcher's 20 s smoke budget on every map.
- "real AI/combat, round results and restart checks" — confirmed for all three
  maps with my own rounds (kills/deaths/respawns/results/restart).
- "one local human + 1–7 source bots" — confirmed; 8-actor rounds drive 8
  distinct source actors, second WS seats are rejected.
- Bounds `bots 1–7`, `timeLimit 60–900` (authority) / `60–300` (launcher),
  `fragLimit 5–50` — confirmed by rejection tests (§5).

- Delivered capture eyes are legal: `(16, 10.45, -34)` aurora, `(-29, 17.45,
  -26)` cinder and `(26, 5.45, 0)` prism are each exactly 1.45 m above the
  supported floor and un-obstructed at 0.06/0.42/1.2 m, so those images are
  genuine first-person positions, not a detached camera. The large dark masses
  in the delivered Aurora frame sit where the sealed buttress/opaque panel
  geometry is; my band/ray probes found no invisible collision there.

Claims that are inaccurate or unsupported:

- `README.md`: "Prism's final images show the weapon but also the stale-input
  click-to-play banner". There are **no Prism images under `evidence/final/`**;
  the only Prism first-person images are `evidence/pre-visual-fix/`
  (`prism-foundry.log` hash `9ba6d451…`, same geometry, pre-fix lighting) plus
  two `prism-resize-*.log` files whose 1280×720 capture succeeded but whose
  1920×1080 pass aborted (`Capture requires a visible live first-person rig`,
  pointer not captured). My own captures supply post-fix Prism at 960x640 and
  1280x800.
- `evidence/final/aurora-basin-{1280x720,1920x1080}.png` + `aurora-basin.log`
  and the Aurora rows of `final/actual-source-maps.log` /
  `final/deterministic-rebuild.log` were produced against hash `909daa29…`
  (948 nav nodes), i.e. **before** the navigation switch that the same directory
  advertises. The delivered live-smoke JSON (`2a8c06ba…`) is current, so no
  gameplay claim is falsified, but the graphical evidence does not show the
  shipped Aurora.
- The README's "five real bots" for the graphical fixture: the delivered
  capture runner uses `botCount: 5`, which is consistent; but the scripted
  capture also *pins* MSAA off and retries pointer capture, so those images
  establish rendering, not normal interactive capture — this nuance is already
  documented by the author.

## 5. Boundary cases (all observed, no timeouts)

From `logs/boundary-*.json` (authority API, HTTP/WS surface, protocol lifecycle,
missing asset, launcher CLI). Every case below produced a real response or a
real rejection; none is a timeout-driven pass:

| Case | Observed behaviour |
| --- | --- |
| invalid map id | `TypeError: Unsupported native arena ID`, no port bound (launcher rejects `--map=tidal-citadel`) |
| `bots=0` / `bots=8` | `botCount must be 1..7`; launcher rejects the same values; `--bots=1` and `--bots=7` smoke OK |
| `round-seconds=30` / `901` | `timeLimit must be 60..900`; launcher range 60–300 (`--round-seconds=30/901` reject, `60/300` smoke OK) |
| `fragLimit=1` | `fragLimit must be 5..50` |
| conflicting aliases | `bots`+`botCount` → `Conflicting bot counts`; `roundSeconds`+`timeLimit` likewise |
| `mode=koth` | `Native arenas support deathmatch only` |
| unknown top-level option | silently ignored (authority binds) — hardening note only |
| `GET /` | 200 readiness `{service, v:3, localOnly:true, humanCount:1, mapId, geometryHash, port}` |
| any other HTTP path / `POST /` | also served 200 readiness (handler ignores URL/method); recorded as-is |
| WS `/`, `/native-arenas` | accepted |
| WS `/other` | socket destroyed (`socket hang up`) |
| WS with `Origin` header | socket destroyed |
| second concurrent WS seat | socket destroyed while the first seat is open |
| `create` | `welcome` (v3, nativeArenaInput 1, geometryHash) + `lobby` |
| `host` wrong `mapId` | `{"type":"error","message":"Unsupported launch map/mode"}` then terminate |
| `host` valid | configured lobby (`mode deathmatch, botCount 7, timeLimit 60, fragLimit 5`) |
| `start` | `start` with `roundRevision 1`, `inputEpoch 1`, hash match; first snapshot `time 0`, 8 actors |
| round to completion | `results` at `time 60.02`, `over:true`, `overReason:"time"`, 19 death events, leaders present, `inputEpoch 3` |
| restart during results | second `start` → `roundRevision 2`, `inputEpoch 4`, snapshot `time 0`, all frags/deaths 0, event ids restart at 1 |
| invalid input (`missing seq`) | `{"type":"error","message":"Invalid input sequence/payload"}` (connection terminated) |
| disconnect mid-round | authority stays up (`GET /` 200, `server.listening`), seat released |
| reconnect after disconnect | accepted; a new `create` handshake completes |
| missing geometry file | with the documented package closure copied to a private temp tree and `cinder-array.json` removed, `createNativeArenaAuthority` throws before binding: `ENOENT` on the generated asset path |
| launcher CLI rejects | `--map=tidal-citadel`, `--bots=0/8`, `--round-seconds=30/901`, `--mode=koth`, `--endpoint=…`, `--play` all exit non-zero with a specific message |

## 6. Working-tree contamination note (not the arena lane)

During this review another lane had uncommitted changes
(`git status`: `M godot/source_operators/operator_visual.gd`,
`M godot/world/presentation.gd`, `?? godot/source_operators/generated/world_weapons/`,
`?? tools/godot-operators/*`). Consequence for my graphical runs: every frame
with a remote actor emitted hundreds of
`Failed loading resource: …/world_weapons/weapon-N.glb` errors because the
`.glb` files exist but their `.godot/imported/*.scn` imports do not. The
delivered `port/combat-expansion/evidence/native-dm-live-02/*.log` contain zero
such errors, so this is *not* part of `454debba`; I recorded it because it
affects remote-operator weapon visuals in the current tree. `presentation.gd`
being modified concurrently means my images reflect that working tree, not only
`454debba`.

## 7. Not verified / residual risk

- Arbitrary off-route collision is not exhaustively verified (as the author
  also states); my probes cover bands, routes, spawns, pickups and the player's
  own position only.
- Human-seat policy in my rounds is a review-owned deterministic policy, not a
  human play study; the human seat in my sims used world-axis movement inputs
  rather than view-relative ones.
- Only one seed was used per map for the long rounds (20260922) plus one
  60 s seed-11 spot check; trap frequency across seeds is therefore a lower
  bound, not a rate.
- Windows/GPU performance claims were not tested (llvmpipe/GL Compatibility on
  Linux only, matching the author's stated scope).
