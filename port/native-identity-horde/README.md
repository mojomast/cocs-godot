# Identity Horde — Nacre Engine lane

Scope: make **Nacre Engine** played as **Horde** on the identity map family —
source-authoritative waves, a reviewed static map hook in the existing
loopback-only Horde adapter, and a real acceptance lane with its own logs,
screenshots and corridor measurements.

The survival-layout revision, its researched reference patterns, map diagram,
weapon locations, and wave-based cache timetable are in [SURVIVAL_MAP.md](SURVIVAL_MAP.md).

This lane owns:

| Path | What it is |
| --- | --- |
| `port/native-horde/authority.mjs` | the reviewed identity-family map/factory hook (inline, see below) |
| `port/native-identity-horde/` | acceptance runner, validator, corridor measurement, evidence |
| `godot/native_arenas/identity_horde_demo.gd/.tscn` | the identity Horde composition (new scene, separate from `native_arenas/demo.*`) |
| `godot/horde/{demo,controls}.gd` | map-family seams and the shared combat-focus contract |
| `godot/tests/horde/identity_*` | test-only observer and offline composition gate |

It does **not** own launcher/package routing (the lead wires that), the Horde
scoreboard layout (`godot/horde/scoreboard.gd`, UI lane) or
`godot/identity_maps/**` (art lane).

## Route

```sh
GODOT_BIN=<pinned 4.5.2> node port/native-identity-horde/run.mjs --scenario=startup
GODOT_BIN=<pinned 4.5.2> node port/native-identity-horde/run.mjs --scenario=waves --waves=4 --resolution=1280x800
GODOT_BIN=<pinned 4.5.2> node port/native-identity-horde/run.mjs --scenario=defeat --waves=1
GODOT_BIN=<pinned 4.5.2> node port/native-identity-horde/run.mjs --scenario=peak --waves=10
node port/native-identity-horde/validate.mjs port/native-identity-horde/evidence/<run>
node port/native-identity-horde/measure.mjs port/native-identity-horde/evidence/nacre-corridors.json
```

Every run is local-only: a private `Xvfb` display (`-nolisten tcp -nolisten
unix`), a private `HOME`/XDG tree, an ephemeral loopback port, `--audio-driver
Dummy`, and bounded wall time. No package build, no shared service.

## The reviewed static hook

`port/native-horde/authority.mjs` keeps its historical three-map Horde allowlist
and gains one frozen identity entry:

```js
import {IDENTITY_MAPS, HORDE_MAPS, readIdentityMap, createHordeMatch} from './port/native-horde/authority.mjs';
IDENTITY_MAPS // Object.freeze(['nacre-engine'])
createHordeMatch({mapId:'nacre-engine', config, random}) // source Match + local wave-gated cache adapter
```

Review properties, all asserted by `port/native-identity-horde/identity-horde.test.mjs`:

- **No client input can select a map, path or document.** The allowlist is a
  frozen literal; the path is a literal entry in a frozen lookup table. There is
  no URL, no CLI flag, no environment variable, no glob, no directory scan and
  no wire field that reaches it.
- **One recipe, validated before construction.** Envelope schema/id/name, the
  recipe's own `mode: 'horde'`, bounded size, arena identity/bounds/spawns/
  navNodes/blocks/pickups/terrain meshes and the SHA-256 of the canonical
  `arena` object are all re-checked. A regenerated or edited recipe fails closed.
- **The arena is installed the reviewed way.** A local subclass accessor
  intercepts the source constructor's own `this.arena = getMap(mapId)`
  assignment before floor bake, navigation, spawns and actor initialization. No
  source `MAPS` registry write and no post-construction transplant.
- **Progression uses native source behavior.** Source team spawn pools place
  survivor/enemies, source steps and proximity checks keep pickup respawns
  authoritative, and the local subclass unlocks only five recipe-listed weapon
  entries when their source wave begins. [Layout and timetable](SURVIVAL_MAP.md).
- **Post-conditions are re-checked**: arena identity, `mode === 'horde'`,
  exactly one human, the selected source operator/harness, `botCount === 0`,
  and a supported, unblocked spawn. The solo authority echoes the reviewed
  loadout on the lobby wire and retains it across round restarts.
- **Transport contract unchanged**: loopback-only upgrade, one client, browser
  `Origin` rejected, message rate/burst limits, per-round input epochs,
  retained-object event cursor, bounded outbound frames, fixed 1/60 steps with
  the source's five-step backlog cap.

The hook is deliberately inline in `authority.mjs` rather than a new imported
module: `tools/godot-package/discover.mjs` derives the shipped adapter inventory
from the static import graph and rejects unreviewed runtime inputs, so a new
imported helper would change the package closure without a package-lane review.

## Godot composition

`res://native_arenas/identity_horde_demo.tscn` extends `res://horde/demo.gd`
and overrides the catalog, allowlist, default map, world loader and view-layer
seams, plus passive cache signs driven by the source pickup snapshot:

- the arena is built by `res://identity_maps/map.gd` (the same builder the
  identity Deathmatch route ships), including its detail trims and signature FX;
- exactly **one sun and one `WorldEnvironment`** come from
  `res://native_arenas/identity_environment.gd`; the base scene's viewer
  environment is freed before `_ready`;
- shared session presentation, first person/ADS, pickups, combat feedback, the
  Horde strip, GameHUD and scoreboard remain the inherited code.

`HordeControls` (owned here) exposes the `focused` flag that the shared combat
composition gates its effect stack on (`godot/world/combat_feedback.gd`
`_allowed`), so blood/impacts/weapon effects stay live while the window is
focused and never replay held input after a focus loss.

## Corridor measurement

`measure.mjs` measures clearance with the capsule the source actually moves —
`game/data.mjs RULES = {radius .42, height 1.8}` through
`game/core.mjs obstructed()`. Enemy `npcProfile.scale` (0.72 husk … 1.32 brute)
is presentation-only: no movement, spawn, nav, ray or damage path reads it.

Two metrics are reported and they are not interchangeable:

- **clearance** = 2 × nearest-obstacle distance at a sampled point. This is a
  conservative lower bound on corridor width (an off-centre point under-reads).
- **channel width** = the smallest sum of two opposite 0.02 m capsule probe rays
  through the point over four direction pairs. This is the local corridor width,
  and it is what the traversed minimum below uses.

## Verification

```sh
node --test port/native-identity-horde/identity-horde.test.mjs
node --test port/native-horde/test.mjs port/native-horde/input-buffer.test.mjs \
  port/native-horde/repair-regression.test.mjs port/native-horde/event-cursor.test.mjs port/native-horde/npc-kills.test.mjs
GODOT_BIN=<pinned> godot --headless --path godot --script res://tests/horde/identity_composition_test.gd
GODOT_BIN=<pinned> node port/native-identity-horde/validate.mjs <evidence dir>
```

## Open items (not claimed)

- **Boss**: the champion wave (wave 9 in a bounded run) was not reached inside
  the bounded attempts.
- **Endless**: the adapter has no endless contract; `validateConfig` rejects
  anything but a bounded 1–30 wave target, matching the existing Horde lane.
- **Ten-wave completion**: the default ten-wave target was exercised at startup,
  but no bounded attempt cleared all ten waves.
- **Upgrade selection**: the local-only Horde upgrade intent applies source-
  offered choices and reports authoritative acceptance or refusal; the public
  multiplayer protocol still has no Horde upgrade command.
- **Human feel/audio/focus**: automated runs use Dummy audio and Xvfb; no human
  playthrough is claimed.
- **Frame cadence** is measured on software rendering (llvmpipe under Xvfb); the
  numbers in `HANDOFF.md` are honest for that environment, not a GPU claim.
