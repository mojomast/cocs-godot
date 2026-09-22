# Native projectile combat

Base: `5ce0ae0` (compact HUD, weapon controls, TDM, native worlds/entities/audio,
standalone Puma). Source gameplay remains locked at
`51289b79c627a26a381ba556b92bab71f93f3732`; `git diff --quiet` against that revision
for `game server` passes.

Rocket Arena is enabled in native setup and `--mode=rockets` **only on Meridian
Exchange, Verdant Reliquary, and Ember Crucible**, after graphical verification
on all three through the real guest session. This closes the presentation gap
recorded in `port/native-mode-expansion/README.md`.

## Authority and presentation

- `game/core.mjs:1058`: primary fire adds `{id,owner,weapon,pos,dir,...}` to
  `rockets`, then emits `launch {actor,weapon,pos}`. **The launch event has no
  projectile identity.** Its event ID is not a projectile ID.
- `game/core.mjs:1314`: the snapshot serializes the rocket objects, including
  `dir` and `pos`. Native meshes use these exact positions/directions and stable
  IDs, independent of array ordering or local/remote ownership. No camera-relative
  path, extrapolated simulation, collision, hit, or damage is invented.
- `game/core.mjs:1155`: primary `explosion {pos,weapon}` has no actor, owner, or
  projectile identity. Only this event creates the short expanding/fading blast
  cue. Disappearance simply removes the flight mesh. Generic source detonations
  can also emit `explosion {pos,...}` without weapon; these remain valid cues.
- A blocked muzzle can emit ordinary `shot` even in Rockets (`core.mjs:1056`).
  `shots`, `launches`, and `local_launches` are distinct. Launch does not draw a
  hitscan tracer or play a second shot sound. Damage events alone confirm hits.
- Rocket mode pins weapon 1 and infinite ammo and retains health/armor pickups.
  Their existing authoritative presentation stays active.

`godot/world/projectiles.gd` has at most 128 live mesh instances, scans at most
512 rows, shares the low-poly mesh resources, validates finite bounded vectors
and integer identities, and removes absent/malformed entries. Rocket geometry
points along local -Z with a short orange exhaust; other source projectiles use
a small cyan orb. Vertical directions get a non-collinear up vector. This is
snapshot-rate presentation, not a client physics implementation.

`combat_feedback.gd` owns the lazily created projectile renderer plus at most
32 blast cues (0.32 seconds, visual radius capped below one world unit). A blast
is a restrained visual cue, **not a damage-radius indicator**. Projectiles and
blasts clear on round start, results, errors, and parent destruction. The
session has one new snapshot hook, `combat.apply_state(frame.state)`, and its
Rockets smoke requires real local launches instead of ordinary shots. Existing
weapon input code is preserved.

Audio keeps its existing eight-player pool, mute, and monotonic cue cooldowns.
Local `launch` gets a short procedural whoosh; actorless source `explosion` gets
a quiet procedural rumble, with a 180 ms rate limit. Both are non-positional,
as are the existing local combat cues; neither implies hit confirmation. The
two extra original waveforms are cached on first use.

## Verification and reproduction

Use the pinned preinstalled engine, the existing primary `node_modules` through
a read-only symlink, and a local copy of the locked generated semantic content.
No packages or toolchains are installed. From this worktree:

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/projectiles.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/combat_feedback.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/audio_feedback.gd
"$GODOT_BIN" --headless --audio-driver Dummy --path godot --script res://tests/protocol/match_selection.gd
GODOT_BIN="$GODOT_BIN" node port/native-projectile-combat/run.mjs
GODOT_BIN="$GODOT_BIN" node port/native-projectile-combat/smoke.mjs
```

The focused projectile fixture covers independent trajectories, same-ID turns,
vertical direction, removal without fake explosion, duplicate/malformed IDs and
vectors, capacity, authoritative event deduplication and audio, no self-tracer,
blast expiry, results/reset/error/free ownership. Its explicit synthetic states
are separate from live verification.

`run.mjs` owns its private Xvfb, a `127.0.0.1:0` authority with default normal
timers and disabled persistence, a passive WebSocket host, and graphical Godot
children. `live.gd` instantiates **the shipped `session.tscn`**, drives ordinary
native physical-key/mouse-button/relative-look input events, and observes actual
received snapshots and actual mesh transforms. It does not set the camera,
game/session controls, state, clock, health, projectiles, or simulation rate.

The external host allows graphical Rocket play to be verified through the
shipped guest session before enabling the host setup capability. Each arena
uses normal Rocket rules and two source bots. Deathmatch uses the existing
read-only pickup route planner to walk to a real rocket pickup before firing.
Captured images are real live viewports from this scene, never diagnostic
standalone world substitutes or injected snapshots.

Logs omit room IDs, endpoints, credentials, and raw network dumps. Output and
child lifetime are bounded; summary records child/socket/server cleanup. The
14-second gameplay samples are not full-round or complete-trace claims.
`trace_complete` is explicitly false.

Focused checks passed: **27** projectile assertions, **95** capability/selection
assertions, **13** existing combat assertions (plus 610 recorded shots and 32
recorded hits), **37** existing audio assertions, and **64** existing graphical
weapon-selection assertions. The Godot import also passed. No existing combat,
audio, or weapon test was edited. One attempted headless weapon-selection run
could not capture the pointer; rerunning its intended graphical path passed.

The actual host session smoke passes on each arena with **zero ordinary shots,
one launch, one local launch, six health/armor markers**, movement, and source
ACK 16 / 16 / 17. These short smoke checks supplement the graphical evidence;
they do not replace it.

### Final graphical evidence

All four final runs passed with the current source hashes recorded in
[`evidence/summary.json`](evidence/summary.json). The source-side observer's
local launch totals exactly match native counters. Each run includes 14 seconds
of fire/movement after connection or the Deathmatch pickup approach.

| Actual shipped session | Local launches | Ordinary shots | Explosion events | Snapshot-to-mesh samples | Max live projectiles | ACK |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Meridian / Rockets | 15 | 0 | 19 | 1330 | 5 | 678 |
| Verdant / Rockets | 15 | 0 | 22 | 1429 | 9 | 717 |
| Ember / Rockets | 14 | 0 | 25 | 1267 | 8 | 432 |
| Meridian / Deathmatch, real rocket pickup | 12 | 0 | 9 | 1360 | 5 | 888 |

Inspected native captures (1280×800):

- [Meridian Rocket Arena](evidence/meridian-exchange-rockets.png): in-flight
  rocket exhaust/body at approximately pixel **663,407**, 4.47 units ahead.
- [Verdant Rocket Arena](evidence/verdant-reliquary-rockets.png): rocket at
  **653,391**, 2.55 units ahead, before the source resolves its wall impact.
- [Ember Rocket Arena](evidence/ember-crucible-rockets.png): rocket at
  **644,385**, 2.54 units ahead; real remote actor also visible at left.
- [Meridian Deathmatch](evidence/meridian-exchange-deathmatch.png): rocket at
  **683,431**, after one authoritative `pickup.kind == "rocket"`. The HUD shows
  ordinary finite rocket ammo (5 in this frame), rather than Rocket Arena ∞.

The bright orange exhaust and gray body rim are seen end-on from the firing
player's actual camera. These are 3D flight meshes at source positions, not HUD
marks. Direction/position agreement is checked for every observed projectile.
All final logs are free of script errors, engine errors, and leaked-object
warnings. The software GL driver reports its usual unsupported V-Sync warning.
The observer drains the bounded audio tail for 0.4 seconds during shutdown;
earlier immediate-exit attempts exposed an AudioServer playback-tail warning.
An initial Deathmatch route attempt missed pointer capture; explicit native
recapture before route input resolved it. No source gameplay was modified.

Final cleanup: **all owned children reaped, authority closed, zero sockets**.

## Lead integration

- Add `res://tests/protocol/projectiles.gd` to the shared verifier in the lead
  lane. No shared verifier or root docs are changed here.
- Existing combat/audio tests are kept and run unchanged. The weapon-selection
  test needs graphical Xvfb; headless cannot capture its physical pointer.
- Rerun the graphical runner independently and inspect the PNGs with their
  `summary.json` capture metadata. `smoke.mjs` reruns the normal host scene on
  all three enabled Rocket map selections.
- Generic projectile orbs are intentionally minimal; this does not establish
  complete native acceptance of every other source projectile weapon/mode.
