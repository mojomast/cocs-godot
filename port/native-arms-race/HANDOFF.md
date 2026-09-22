# Native Arms Race — standalone handoff

Branch/worktree: `native-arms-race`, `/tmp/opencode/arms-race`, based on
`8a58c97e48493e41903c2c9a729e753cb3579500`. Implementation commit: `52de3b9`.
Only new files under the three assigned directories were changed. No merge,
push, deployment, shared runtime/client/session edits, campaign work or subagents.

## Delivered

- `godot/arms_race/demo.tscn`: standalone Node-authoritative Arms Race on
  Meridian Exchange, Verdant Reliquary and Ember Crucible. Default: **two Normal
  bots, 180 seconds, all ten source weapons**, ordinary source loadout/rules.
- Subclasses the existing native session, game HUD and scoreboard; reuses map
  rendering, actors, pickups, combat reticle/tracers/projectiles and event audio.
- Snapshot-owned ladder/current weapon/next weapon and promotion/demotion text;
  missing/invalid progress is unavailable, never reconstructed from frags.
  Scoreboard ranks ladder then frags. Explicit finisher wins; timed ties and
  scoreless draw match source outcome rules. Source result frame enables Enter
  restart; source start clears round state and recapture is required.
- Source-pinned loadout: native digit/wheel selection is consumed without sending
  weapon requests. Held-input latch requires release/fresh click across focus,
  death, respawn, missing/stale state and round boundaries.
- `DISCOVERY.md` records file/line findings written before coding, route decisions
  and retained failures. `shared-hooks.patch` is **unapplied**.

## Reproduction commands

From this worktree:

```sh
python3 port/native-arms-race/run.py
python3 port/native-arms-race/run.py --startup
python3 port/native-arms-race/audit.py
git apply --check port/native-arms-race/shared-hooks.patch
```

The two completed live combat attempts used exactly:

```sh
python3 port/native-arms-race/run.py --attempt=1
python3 port/native-arms-race/run.py --attempt=2
```

**Do not run another live combat attempt under this task's budget.** The second
command also has retained preflight failures with zero source starts/inputs;
`AUDIT.json` counts actual live combat runs and fails above two. Each successful
evidence directory's `summary.json` records every exact child command, ephemeral
port, temporary path, source config, elapsed result and cleanup. The observer
drives only Godot `InputEventKey`, `InputEventMouseMotion`, and mouse-button
events; it never sends gameplay packets itself. Its public-map navigation grid
is a test routing aid, not game collision/physics.

The runner makes a private `/tmp/opencode` copy, links primary `node_modules`
read-only in practice (no writes/install), exports/imports all nine maps, uses
isolated HOME/XDG directories, `PORT=0`, loopback server, Xvfb with
`-nolisten tcp -nolisten unix`, and reaps every owned child in `finally`.
The Node server keeps the source's default scheduler and RNG; no state/time/
physics injection or altered bot behavior. Histories/progression stores are null.

## Live combat evidence

### Startup / lifecycle / fixtures

Clean all-three run: `evidence/3c656705-8157-42f4-9083-54b35836ec26/`.

| Case | Resolution | Result |
|---|---|---|
| Meridian | 960x640 | Ordinary 60s timer result, two source starts / one result, held W blocked after restart, released/fresh capture moved >0.5m |
| Verdant | 1280x800 | Ordinary source startup, two Normal bots, source ACK through 215 |
| Ember | 960x640 | Ordinary source startup, two Normal bots, source ACK through 302 |
| Native fixtures | Headless | 0 failures; invalid/missing rung/weapon, bonus, demotion, final-rung non-win, explicit finisher, timed tie/draw, held input and locked selection, scoreboard ordering/reset |
| Source tests | Node | Existing Arms Race + outcome tests pass (fixtures, not live gameplay proof) |
| Content | Export/import | All nine maps exported/imported; native catalog asserts count=9 |

Native tests call `push_error` and `quit(1)` explicitly; Python checks raise
exceptions. Failures do not depend on release-disabled GDScript assertions.
Both clean runs report private temp removal, owned process reaping, server closed
and zero sockets. The 60-second lifecycle setting is a legal ordinary timer test,
separate from the 180-second combat route; no ladder shortening or fake victory.

Opened and reviewed actual clean-run screenshots:
[Meridian results](evidence/3c656705-8157-42f4-9083-54b35836ec26/meridian-exchange/results.png),
[Verdant startup](evidence/3c656705-8157-42f4-9083-54b35836ec26/verdant-reliquary/startup.png),
[Ember startup](evidence/3c656705-8157-42f4-9083-54b35836ec26/ember-crucible/startup.png).
960px results keep rung/frags/deaths and Enter restart legible; both resolutions
fit the ladder/current/next weapon HUD. Worlds retain distinct map palettes.

### Local kill -> promotion -> native display

Clean accepted route: `evidence/b84cae02-766d-41fc-b23a-ceb085b347e1/`.
1280x800, two Normal bots, normal-rate 180-second source round. Native observer
ended at **13.528445 seconds**, immediately after the first source promotion.

| Evidence layer | Observation |
|---|---|
| Native queued | 659 successful `input_queue` records; this alone is not delivery |
| Server received | 659 public input envelopes in passive wire archive |
| Source applied | Maximum ACK 659; promotion snapshot ACK 656 |
| Source kill | `death` event 382 at 13.133, victim actor 2, killer local actor 0, self=false |
| Source promotion | Event 381 at 13.133, local actor 0, weapon=1, bonus=false |
| Snapshot effect | Seq 393 -> 394: frags 0 -> 1, ladder 0 -> 1, weapon 0 -> 1, shots 36 -> 37 |
| Native display | Seq 394 / ACK 656: `RUNG 2 / 10 · Rocket Launcher`, `Next: Rail Lance`, `PROMOTED +1` |

`AUDIT.json` preserves the complete before/after actor records, event/death pair
and capture record. Do not treat source `death.weapon=1` as the gun that fired:
source advances the killer's ladder before building the death event. The preceding
snapshot and shot stream establish the original Pulse Rifle loadout.

Opened actual screenshot:
[`promotion.png`](evidence/b84cae02-766d-41fc-b23a-ceb085b347e1/meridian-exchange/promotion.png).
The ladder panel and weapon/ammo panel agree; health, controls and next weapon
are legible without clipping. This is snapshot-guided automated native input,
**not independent human usability acceptance**. Audio was routed through Dummy,
so event integration is reused but audible quality was not reviewed.

## Retained failures

- `22d20187-937d-405e-9543-da240344fbc5`: initial Meridian timer/restart ran to
  completion and fresh input moved, but clean-log check correctly failed on the
  hidden empty OptionButton. The nine selector entries are now populated.
- `6f67ab4b-c215-421d-9e50-43f27af7788f`: live combat attempt 1 promoted at 7.617
  and displayed Rocket Launcher, but retained **FAIL** for that same UI error.
- `24dc64cd-0ffd-45c4-b99c-f9067278ec50` and
  `7a26e248-84ab-4db6-9c5e-1e529b27ce33`: Xvfb display-fd short-read bug;
  Godot had no display. Zero starts/inputs. Read through newline before closing.
- `e57fff1f-508c-4dee-9907-f2fc3ee74797`: unavailable `xdpyinfo` preflight.
  No source server/client launched. Replaced with pinned Godot viewer `--quit`.

All original FAIL statuses, logs and any screenshots remain archived. Large
wire/native logs may be losslessly gzip-compressed; `audit.py` reads both formats.

## Provenance

Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`. Semantic exporter checks
the locked source ancestry and unchanged tracked source assets before export.
Node `v22.23.1`; Godot `4.5.2.stable.official.6ce3de25a` at the requested pinned
absolute path. Every run has `hashes.json` (all game/server modules, native scripts,
toolchain/dependency hashes) and `generated-hashes.json` (all nine map outputs).
`EVIDENCE-SHA256.json` hashes every retained evidence file after lossless log
compression. `FINAL-CHECKS.json` records all eight temporary directories removed,
zero source/contract changes and 610 game/server/native runtime files matching the
clean combat run's hashes at delivery.

| Runtime file | SHA-256 |
|---|---|
| Pinned Godot | `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae` |
| Node binary | `93956de2e59480474a7b46571da1651180b1a050cdf32641ebec4ce6e478e068` |
| Read-only ws tree | `c0dc2e2d4228652d0f4f653026eb2f85a0777177d34ec9a485260ebf82b9ef8d` |
| game/core.mjs | `23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631` |
| server/room.mjs | `5cd8777a8e14c9a5260283a8ff227f669e321f953d2f5a4c1539e506f654fbf2` |
| server/game-server.mjs | `06e79c72d0530abf5256b803a19fbfb00582892579f27f42eae871cc28fb98b0` |
| arms_race/demo.gd | `0cb94b4c21200af5eaeaee0fe4cf56c656582ade1205e3a52009eddb8b335969` |

## Integration proposal (unapplied)

`shared-hooks.patch` adds `--experience=arms-race` to the common development and
package experience tables, mapping all three supported maps to `armsrace` and
`res://arms_race/demo.tscn`. `git apply --check` passes against this baseline.
No indispensable shared network/session hook is needed: current wire fields
are sufficient. The standalone accepts `--endpoint`, `--map`, optional legal
`--round-seconds=60..900`; minimal route uses default 180 seconds.

After lead integration, proposed user commands are:

```sh
node tools/godot-dev/launch.mjs --experience=arms-race --map=meridian-exchange
node run.mjs --experience=arms-race --map=verdant-reliquary
```

These routes **are not installed by this branch**. The lead owns help/root docs,
table-driven launcher/package checks, aggregate verification, editor-free package
rebuild and fresh-extraction validation. Existing all-resources export includes
the new scene; test driver stays under excluded `tests/`. No package was rebuilt.

## Acceptance limits

Full ten-weapon ladder victory is **unaccepted**. Explicit winner/final-rung,
catch-up, demotion/respawn, timed tie and draw handling have fixture/source-test
coverage; a local human final kill/result is not claimed. Live focus/death/respawn
recapture permutations have not all been human-tested. The native UI retains
the shared diagnostic world/weapon presentation and source audio integration.
Campaign remains deferred. All nine map identities/assets remain preserved.
