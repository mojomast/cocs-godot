# Native DAMAGE and PICKUP-HEALTH — executed live acceptance

**PASS on the first live attempt:** intentional nonlethal damage, native hurt
feedback/HUD, physical W/mouse movement to Meridian health `(-6,22)`, same-ID
collection/marker hiding, leaving the radius, and authoritative 12-second return.

Base: `aee6f797cdd5daecd16efde8482aaeadd5298cae`.
Branch: `subagent/native-health-damage`.
Worktree: `/tmp/opencode/cocs-native-health-damage`.
The original death worktree/branch at `1d5a3dd` is preserved. This lane owns only
`port/native-health-damage/` and `port/tools/native_health_damage/`.

## Exact commands executed / reproduction

From the checkout being evaluated:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node port/tools/native_health_damage/run.mjs

node port/tools/native_health_damage/analyze.mjs port/native-health-damage/evidence/d06d6f7a-cacd-43a4-8910-97007273dc21

node --test port/tools/native_health_damage/test.mjs > port/native-health-damage/offline-tests.tap
```

All three commands exited **0**. There was one live invocation, with **no failed
live attempts**. Each future invocation creates a new UUID evidence directory;
inconclusive/failure evidence is retained rather than overwritten. The runner
copies and evaluates the invoking checkout's runtime, so the lead can rerun
against its integrated checkout. Existing Godot, Node, `ws`, Xvfb and software
Mesa are used without installation.

## Actual recording

`evidence/d06d6f7a-cacd-43a4-8910-97007273dc21/`

- **22.717849 seconds** observed gameplay wall time.
- Native guest actor **1**, supported-protocol attacker actor **0**, roundRevision **1**.
- **2,028** native trace records; **693** snapshots correlated to owned authority.
- **1,334** native queued inputs exactly matched to server receipt seq 1..1334.
- **284** nonzero native movement inputs before health collection.
- **360** hidden-pickup snapshots; **335** snapshots outside collection radius
  after the leave boundary through authority return.
- ACK high-water **1333**: input 1334 is receipt-only, not acknowledged/application
  evidence.

### DAMAGE

The native remained stationary while the attacker navigated and fired weapon 0
through supported INPUT. The victim's default initial state was **100 HP / 5 armor**.
Five positive damage events, IDs **4, 13, 22, 31, 40**, occurred from simulation
time **3.900** through **4.367**. Their amounts sum to **54.447**.

Authority accounting is **49.447 HP lost + 5 armor lost = 54.447**. Temporary
shield, Juggernaut shield and Alignment Review pool losses were zero. This is
explicitly not an assumption that `damage.amount` equals HP loss. Event amounts
are already downstream of source weapon handling/falloff and damage modifiers.
The analyzer verifies the actual damage=1/no-mutator deathmatch configuration,
chatgpt/adaptive + openclaw profile, no active ability/brace/arrival/NPC shield,
and damage/gear multipliers of 1 over the observed combat window. Adaptive's
signature is enabled; `actor.active=0` refers to the active ability timer, not to
disabling the signature. The narrow accounting model refuses unsupported
profiles/configurations rather than silently applying the default assumptions.

The first damage event amount was **10.730**, including consumption of the
remaining 5 armor; the later events were 10.812, 10.918, 10.987 and 11.000.
Quantized sum comparison permits `.002 * (eventCount + 1)` = **.012** here for
three-decimal wire rounding. Actual aggregate equality was exact at retained
precision. No HP/armor regeneration or further incoming damage occurred during
the route/collection window.

At snapshot **132**, time **4.400**, the attacker latched stop at **50.553 HP**,
with neutral-fire input beginning at attacker seq **85**. Every subsequent
retained attacker input has `fire=false`; the final authoritative attacker shot
was at 4.367. The native stayed alive throughout the capture. Movement began
only after a one-simulation-second stabilization window, at time **5.433**.
Attacker input records are sends, not a claim that each was individually applied;
the absence of later authoritative damage/shot events and stable native HP
corroborate the observed stop.

All five positive damage events were independently observed by the real native
event handler. `combat.hurts`, `hurt_remaining`, and `combat.text()` established
hurt feedback. A subsequent real process-frame sample at accepted snapshot
**124**, next native trace sequence **349**, had both `combat.text()` and the
actual `combat_label.text` equal to **`TAKING DAMAGE`**. Native HUD and its actual
display Label also matched snapshot HP/armor throughout the recording, including
the injured **HP 50.553 / Armor 0** state.

### PICKUP-HEALTH

The authored target is **health pickup ID 6**, `x=-6, y=0, z=22`. Source behavior
in `game/core.mjs` uses useful proximity collection, adds **35 capped at
maxHealth**, and sets health-pickup wait to **12 simulation seconds**. The actual
normalized configuration was deathmatch, zero bots, timeLimit 180, fragLimit
**50** (the requested 100 was normally clamped), damage/speed/gravity 1 and no
mutators. The observed native maxHealth was **100**.

The geometry route from the real spawn `[-36,0,-6]` was `[-6,19] -> [-6,22]`,
avoiding the other health supplies. It was traversed by real physical W events
and mouse-motion events. No position/control method was overridden.

| Boundary | Snapshot / time | HP | Pickup wait | Native marker |
|---|---|---:|---:|---|
| Before collection | **309 / 10.300** | 50.553 | 0 | visible |
| Collected | **310 / 10.333** | **85.553** | **11.983** | hidden |
| Returned | **670 / 22.333** | 85.553 | **0** | visible |

Native health pickup event **45** occurred at time **10.317**. The observed gain
was exactly **35**, satisfying `min(maxHealth, priorHP + 35)`. This run exercises
the below-cap branch; it does not separately exercise healing into the 100-HP cap.
The before/after HUD and display Label changed with authority. Other health
pickup IDs did not transition in the collection bracket, there was exactly one
local health pickup event, and native proximity plus the same target ID/wait
transition identify the authored target despite events lacking a pickup ID.

The marker's instance ID stayed **39963330253** throughout; its position stayed
`[-6,1,22]`. It was hidden on every positive-wait snapshot. After collection the
native followed a leave route toward `[-2,22]`, stopped outside radius 1.05, and
stayed outside through return. At return its authority position was
`[-3.423,0,22.712]`, safely outside. The first observed return was **12.016
simulation seconds after the pickup event**, consistent with the actual 12-second
timer sampled at 30Hz. Every retained positive wait also matched authority time
advancement. The native remained outside for the final post-return observation;
no immediate recollection was used to manufacture the transition.

## Harness, privacy and provenance

- The server is an owned loopback `createGameServer({historyPath:null,
  progressionPath:null})` with default tick/snapshot timing and RNG. Native joins
  before host START. No actor/HP/position/spawn/timer mutation, fake snapshot or
  direct damage/fire API is used.
- The shipped `res://world/session.tscn` is instantiated unchanged in a private
  Godot project copy. This is real native Godot 4.5.2, not an exported release.
  W and mouse stimulus use `Input.parse_input_event` and flush its buffer. The
  native victim's emitted fire field is false for the entire capture.
- Private Xvfb uses dynamically allocated abstract-local transport with TCP and
  filesystem UNIX listeners disabled; shared desktop state is not touched.
  Temporary project/HOME/XDG/generated/import data live under `/tmp/opencode`.
- The recorder uses explicit projection lists for actors, pickups and events.
  Welcome frames are never retained; only their nonsensitive peer/room identity
  is used transiently for association. **Neither `welcome.token` nor
  `progressToken` is written to any evidence artifact.** Tests scan retained JSON
  and native records for credential field names and welcome bodies. No other
  lane's raw archives were used.
- Setup, cleanup and correlation patterns are attributed to
  `native_death_respawn` at `1d5a3dd` and its prior guest/correlation lineage.
  Native route input patterns and the geometry planner were inspected read-only
  from `native_pickup_acceptance` at
  `5e8e02e0f66be5f571649e06deb16a7f149ac71c`. The original planner SHA256 is
  `20b1298ee82556a1152e74a9cce63c7e14ff456e551c928c2ca96d7feb1723c5`;
  this lane adds explicit goals, other-health avoidance and a neutral error label.
  Execution has no dependency on that other mutable worktree.
- `summary.json` retains exact commands, base/source/runtime hashes, actual
  durations, process IDs and artifact SHA256/lengths. Native streams and projected
  wire data are retained once as gzip files: **100,185 bytes** of artifact payload
  in total. Summaries contain only compact witnesses, not copies of full logs.

## Correlation and limits

Native trace still omits protocol snapshot/input IDs. The passive observer runs
synchronously after shipped handlers and must print directly after the matching
native trace; its accepted snapshot seq provides the key to owned-server output.
Actor, health/dead, ACK, pickup identity/wait and projected native actor values
are compared. Successful input ordinal is inferred only from the observed fresh
START prefix and compared to contiguous actual server receipt and every emitted
control field. Trace sequence is never treated as protocol sequence. ACK is a
high-water mark, not proof of independent application of every command.

**`completionProven=false` remains explicit.** The `harness_end` record marks the
bounded observation window. Neither it, native child exit, nor cleanup proves
native trace recording completion. Unknown/error/limit records, sequence gaps,
lost observer association, input receipt tails, death, missing targets, route
failure or a missed return prevent PASS and retain inconclusive evidence.

Bounds: version 10s; exporter/importer 60s each; private display/listen/host waits
5s; native pre-start join 12s; driver gameplay 105s; supervisor gameplay 118s
(successful capture asserted <=120s); native child watchdog 125s. Each output
stream and projected wire retention is capped at 8MB; the native 10,000-record
trace limit is rejected. Cleanup uses only owned handles, escalates TERM to KILL
after 2s, reaps processes and verifies ESRCH; owned server close has a 5s bound.

This is program-state acceptance of diagnostic native HUD/marker behavior on a
real private graphical display. Human visual fidelity, physical hardware input,
general OS focus acceptance, alternate damage modifiers/profiles, other maps,
cap-branch healing and adverse networking remain outside this recording.

## Checks actually completed

- Live runner and offline replay: **PASS**, exit 0.
- **9** focused tests passed: genuine scenario, artifact/executed-source hashes,
  credential exclusion, and explicitly synthetic corruptions for UI-only proof,
  HP-only damage accounting, missing receipt, broken association, replacement
  marker and continued fire. Synthetic cases are analyzer checks, not gameplay.
- Independent `os.kill(pid, 0)` verification: native **2048759**, Xvfb **2048753**,
  importer **2048506** all returned ESRCH. Server closed, zero clients, private
  temporary tree removed. Native stderr contains only the retained VSync warning.
- `git diff --check` and scoped staged-path review completed before commit.
