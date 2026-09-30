# The Quiet Relay — authority and gameplay

The maintenance operator follows ECHO through Rootfall Verge, Siltwake Crossing,
Emberline Ascent and the Crown Array. Recover an archive rescue request, restore
the riverworks, isolate a corrupted quarantine uplink, then transmit its repair
key. The final Continue changes the phase to `campaign-complete`; it never loops.

## Play and pacing

Each chapter has five finite encounters and an exit. Future encounter anchors and
the exit cannot bypass the active objective. Deployment begins within 36 metres
of the current encounter (or marker radius + 20, whichever is larger). Only the
current encounter is live, leaving traversal legs quiet. Source pickups on the
worlds lane's optional supply/flank loops remain usable. Checkpoints recover
health, armour and already-owned ammunition after clears; source health regen
also provides recovery between fights.

The four chapters target **300–600 seconds each**, via 900–1,500 m authored routes,
five fights, exploration and short active interactions. This is a design target,
not measured human timing. There is no campaign clock failure. Human timing and
navigation playtests remain required; deterministic tests prove sequencing.

| Chapter | Five encounters in order |
| --- | --- |
| Rootfall | Relay clear; archive interaction; repeater restoration; shield formation; access-key interaction |
| Siltwake | Intake clear; pump restoration; mortar overlook; bridge hold; crossing authorization |
| Emberline | Cooling terrace; armoured lock; maintenance bus; uplink hold; service-lift release |
| Crown | Highland approach; feeder restoration; archive hold; guardian; repair-key transmission |

**Clear / guardian:** kill every deployed guard and reach the relay marker at its
supported height. Clearing from a doorway leaves “Area clear—reach the relay
marker” active until arrival; no timer is imposed. **Interact:** clear guards and
press Interact inside the marker. **Restore:** clear guards, press Interact once
to begin, then remain inside the marker for 6–8 seconds. **Hold:** accumulate
12–15 seconds inside the marker while fighting and eliminate all guards. Hold
and restore progress pauses outside the marker, so dodging is never punished by
a reset. NativeClient treats Interact as a pulse; restoration deliberately does
not require a held input. These are active objective beats, not long forced waits.

Every cleared encounter advances exactly once and establishes a new checkpoint.
An approach checkpoint is also captured before deploying the next fight,
including the Crown guardian. Death freezes the source match. Retry creates a
fresh match from the saved step and position, repopulates only the unfinished
fight and drops all old projectiles, timers and inputs. Restart returns to the
chapter start. Checkpoints are session-local; no filesystem save option is added.

## Robots and source mechanics

| Public `npcModel` | Source `npcType` | Actual source behaviour / tells |
| --- | --- | --- |
| `scrapper` | `husk` | Low-health melee swarm |
| `skirmisher` | `lancer` | Cover-seeking melee flanker; `flankWindup`, `flankerBurstUntil`, `enemy-telegraph` / `enemy-flank` |
| `sentinel` | `sentinel` | Formation shield pulse; `phalanxWindup`, `phalanx-shield` |
| `mortar` | `mortar` | Fixed ground mark then real AoE; `artilleryWindup`, `artilleryMark`, `enemy-artillery` |
| `bulwark` | `bulwark` | Directional armour: frontal reduction, rear vulnerability via `npcShield` |
| `warden` | `warden` | Three health-driven source phase profiles, `bossStompWindup`, `bossStompMark`, `boss-slam` |

`spawnGroup`, `placeGroup`, `updateEnemyRoles` and `updateHealthRegen` are imported
from locked singleplayer code. The subclass retains source movement, collision,
weapons, bots and damage. The mission loop does not call source mission lookup.
There are no frontend-authored damage events or custom `campaignTell` fields.
NPC roles retain source stats and difficulty behaviour. Groups are spread across
distinct local nav nodes. Every palette has at most three models and every fight
at most eight enemies (hard cap ten); no reinforcements or infinite spawners.

Dead actors remain inert indexed slots until the chapter/retry boundary. This
preserves source `actors[id]` bot-target/projectile-owner semantics. They cannot
respawn: the step wrapper pins dead timers and the spawn override refuses any
previously dead actor. A fresh match is the only retry path. Source roles tick
exactly once per active frame. The owned loop has no clock failure, and the base
`endMatch('time')` seam also refuses a clock ending.

`ROBOTS` declares separately the scaled main-chassis dimensions `[width,height,
depth]`, chassis centre above feet (`chassisY`) and authoritative `hitScale`.
Hit scales are `.72, .86, 1.28, 1.15, 1.5, 2` in table order, assigned **after**
source spawn. Explicit `npcHitVolume` now overrides the scalar NPC hitbox:
`robotHitVolume(model)` uses chassis width/depth and the feet-relative chassis
bottom through central sensor top. Upper heights are `.63, 1.372, 1.12, 1.28225,
2.3925, 1.784` metres in table order. Low scrappers no longer inherit tall humanoid
damage boxes, nor does Warden inherit a 3.6 m-high box. Thin animated limbs,
barrels and antennae remain decorative. These are bounded axis-aligned body
volumes, not exact animated mesh collision. Warden
deployment additionally requires 1.65 m clear radius and 2 m from other bodies;
source movement radius stays unchanged. Art/hitbox gallery review remains an
integration requirement; tests check visible-body hits and overhead misses
through source hitscan slabs and source projectile stepping.

The private source `actorHit` function has no subclass seam. Runtime imports the
committed static `core.generated.mjs`, generated from exactly `game/core.mjs`
SHA256 `2905696af09ccace8c2dbb384139748ef80146be25bbbe75bf8111d28dc146e8`.
Only 34 relative imports and `actorHit` differ. The NPC-only explicit volume is
finite/bounded (width/depth .1–4 m, bottom >=0, top <=4 m). Human and absent/invalid
volume behaviour retain the original scalar path. Every other source byte is
verified by an independent inverse comparison. There is no runtime generation,
dynamic import or evaluation, and no locked source file is edited.

Regenerate with `node port/native-campaign/generate-core.mjs`; unknown source
hashes fail closed and require review. Text-only `core-provenance.test.mjs` pins
source drift and committed-byte reproducibility. Runtime packaging must include
`port/native-campaign/core.generated.mjs`; the generator/provenance test are
build/review tools, not runtime dependencies.

## Authority API and protocol

`createAuthority(options={})` and alias `createCampaignAuthority` return unbound
`{server,wss,close}`. Bind the server to `127.0.0.1` or `::1`. GET `/` exposes
readiness service `cocs-native-campaign`; WebSocket `/native-campaign` is the
campaign route (`/` is accepted for standard local-client compatibility).

Options: `mapId`, `difficulty` (`easy|normal|hard`), `random`, `observe`; trusted
in-process `mapLoader` and `matchFactory` are deterministic test seams, never wire options.
`observe` receives copied input/output frames and applied control samples.
`close()` is idempotent and owns its timer, HTTP and WebSocket resources.

Use NativeClient v3 `create` (with `nativeArenaInput:1`), optional standard `host`
for the launch-selected map/mode, then `start`. Geometry and difficulty remain
launch-owned. All snapshots are full frames. Start carries map ID, geometry hash,
round revision and input epoch. Snapshot/results carry input epoch and the exact
additive `state.campaign` contract. `holdProgress` is normalized **0–1**;
`checkpoint` is the numeric step **0–5**; `stepCount` is **6**, including the exit.
`elapsed` is chapter active time including retries; `totalElapsed` is cumulative
active time across completed chapters plus the current level; restart resets
current-level time and removes that contribution from totalElapsed. `kills` counts completed encounter
kills plus this attempt's current kills; retry discards failed-attempt kills.

`{type:'campaign-action', action:'retry'|'restart'|'continue', inputEpoch}`:
retry is accepted only when dead, continue only at level completion, restart at
any chapter phase. Non-final Continue constructs the next chapter and emits a
fresh start. Final Continue emits a fresh same-map/hash start with advanced epoch
and round revision, resets sequence, then emits campaign-complete results with
sequence 1. The completed match is preserved without reconstruction. Each boundary
resets controls and advances the epoch. Old-epoch frames are ignored. Held input
expires after 250 ms; pulse controls use the existing bounded input FIFO.

Remote connections, Origin-bearing upgrades, binary frames, oversized or
rate-excessive messages and unknown fields are refused. Numeric controls must be
finite and buttons boolean before source normalization. One human socket only.

## Verification (run serially in the integration slot)

```sh
node --test --test-concurrency=1 port/native-campaign/core-provenance.test.mjs port/native-campaign/campaign.test.mjs port/native-campaign/hit-volume.test.mjs port/native-campaign/authority.test.mjs
```

Tests use seeded source matches and real source damage, ordinary ticks for
progression, restoration/hold gating, all-four ending, checkpoint reconstruction,
source artillery telegraph/damage and real WebSocket input cancellation, expiry,
restart epochs and finite-frame rejection. The test completion driver moves the
human to authored anchors; it does not claim human navigation or timing evidence.
