# Narrow Horde event-cursor / NPC-kill repair

**Both authorized defects are repaired and the bounded checks pass.
Integration remains HOLD until the lead reviews the diff and independently
replays it.** No source, public Room, shared native, launcher, aggregate or
package changes were made.

Baseline: independent HOLD
`3dbcceb91c2e1542c91e7e2e3fda55ff43a94cb2` in existing isolated worktree
`/tmp/opencode/horde-repair-independent`, branch
`review/horde-repair-independent`.

**Runtime + tests commit:** `c64762ad8104c1976ba7d08051a305009eb95782`.
The new report/evidence tree is committed separately. Runtime commit scope is
exactly `port/native-horde/{authority.mjs,validate.mjs,input-buffer.test.mjs,
event-cursor.test.mjs,npc-kills.test.mjs}`: two runtime/validator files and three
test files. Earlier external/integration commit identities remain those in the
unchanged independent report; this is a new repair on top of that audit.

## Repair and precise semantics

### Event append cursor

Removed the invalid assumption that `Match.serial - events.length` identifies
event positions. Source serial also allocates projectile/grenade/sentry IDs.
Each Match now owns an **append-object cursor** and independent monotonically
increasing **adapter event ordinal**. The last event object's position identifies
new appends, including after ring shifts. An evicted/missing marker throws and
the authority terminates the peer without sending a partial batch. Disconnect,
restart and new client state do not share the old cursor. Constructor events
are consumed before stepping and emitted after `start`.

Original payload ID and type remain untouched: wire `sourceId` preserves the
original ID; wire `id` is an adapter ordinal, **not a global source serial**.
Two distinct source objects with completely identical payloads are both emitted.
There is no payload-blind or source-ID deduplication. See [API.md](API.md).

### Genuine NPC kills versus net frags

The combat acceptance predicate derives three target NPC identities from
finished-round source snapshots, then requires three distinct local-actor NPC
death events. It rejects missing, duplicate, unknown, nonlocal and self victims
as NPC kills. It scopes snapshots/events to the actual result round, and does
not hard-code target IDs. Source net frags are checked against the result
actor's frags; lives and self-deaths are separate metadata. Source scoring and
all original exit/resource/input/geometry predicates remain unchanged.

The acceptance output adds
`combatKills:{npcKills,npcVictims,netFrags,lives,selfDeaths}`. This is a bounded
first-wave validator, not a full-run validator.

## Old-fail / new-pass evidence

### Ordinary normal-rate grenade, source object oracle

Both versions ran unchanged source Match at actual monotonic elapsed time,
fixed 1/60 steps and the existing five-step backlog cap. Both received the same
ordinary grenade-on seq 1 / grenade-off seq 2 pattern after startup. No injected
clock, seed selection or direct source-state assignment.

| Diagnostic UUID | Adapter | Result |
|---|---|---|
| `562ed4ea-ee2a-4047-aa2e-aac512b92766` | Actual committed `3dbcceb` adapter | **Expected FAIL**, exit 1; 2 source objects, 1 mismatching batch. Initial spawn sourceId 1 was replayed as wire ID 2 alongside grenade ID 3. |
| `8b638d7d-553f-44ff-9b52-5b27a515455d` | Repaired authority bytes | **PASS**, exit 0; 2 source objects, 0 mismatches. Spawn wire ID 1/sourceId 1; grenade wire ID 2/**sourceId 3**. |

Each UUID preserves its wire and source-object-oracle JSONL gzip plus summary.
Old authority SHA256:
`30a2dff03ba9a916cf7ff126b3de49f0cf5a11f0d50341eb49a578285b735f7a`.
New authority SHA256:
`0feff165159708c8d0a32b4092c7dfb34374fde4c16d2d414d09571dff4b442e`.

The oracle independently retains a WeakSet of observed **source event objects**
per Match and compares fresh objects to adapter batches. Its expected values do
not use adapter cursor fields, global serial arithmetic or payload equality to
identify a new event. The old committed adapter is loaded read-only through a
data URL with absolute import resolution and a read-only observation at its
event-batch call. The new adapter's exported cursor method is transparently
wrapped for observation. Neither wrapper edits Match, its state or returned
batches. Complete traces include the initial spawn, unchanged-ring reads and
the grenade allocation gap. The two listeners were closed and independently
reconnect-tested as closed.

### Preserved independent Meridian replay

The exact historical recording
`port/reports/horde-repair-independent/evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60`
was read without writing any file in that directory:

- Old committed validator: **REJECT**, `2 !== 3`; new output
  `meridian-old-reject.json` and `meridian-replay-old.log.gz` preserve that result.
- New validator: **PASS for the corrected predicate**, `npcKills:3`, victims
  `[1,2,3]`, `netFrags:2`, `lives:2`, `selfDeaths:1`; output is only
  `meridian-new-predicate.json` / `meridian-replay-new.log.gz` here.

The original HOLD, failed CLI log, screenshots and every original raw byte remain
unchanged. **This replay does not certify historical events as repaired**: that
old recording still contains the eight known event replays. Its launch commit
correctly remains `9c0f5a5...` in the replay metadata. Only the intended kill/net-
frag predicate changed acceptance; no raw state, source scoring, hygiene, input
correlation or geometry requirement was relaxed.

## Meaningful regression coverage

**50/50 adapter tests** = existing 29 (the internal event-helper test migrated
to the new cursor API) + **9 new event tests** + **12 new NPC predicate tests**.

Event tests use actual unchanged `Match` construction and methods as the ring
oracle: real projectile/fire, grenade and sentry allocations; repeated string
modifier IDs; two distinct objects with identical full payloads; payload type
overwrite; empty/unchanged reads; ring growth; shifts retaining the prior last
object even at index 0; missing marker with ordinal unchanged; authority
fail-closed/reconnect; restart and new-client isolation.

The overflow test explicitly injects 300 fixture events through source `emit`
at the adapter cursor boundary after real construction. The bounded restart
unit test invokes source `endMatch('time')` there. These are **synthetic fault/
lifecycle fixtures**, not source gameplay wins or normal-rate play evidence.
The source files, production Match implementation and shipped authority API are
not replaced. The genuine one-wave win/restart is separately recorded below.

NPC tests replay the real self-kill recording and mutate only in-memory copies
of acceptance evidence: missing victim, duplicate replacement/extra death,
nonlocal killer, NPC self-death, local actor as victim, unknown victim, absent
snapshot NPC identity, renamed valid target IDs, mismatched net-frag projection,
and dirty harness exit. Tests do not edit recorded files or source outcomes.

| Check | Result | Raw log |
|---|---:|---|
| Existing + new adapter/validator tests | **50/50** | `adapter.log.gz` |
| Source singleplayer/UI | **70/70** | `source-ui.log.gz` |
| Native Horde model | **15/15** | `horde-model.log.gz` |
| Native source input + look contracts | **31/31 + 3/3** | `native-input.log.gz` |
| Semantic regeneration / pinned import | **PASS**, nine maps | `semantic.log.gz`, `import.log.gz` |
| Immutable source verification | **PASS** | `source-lock.log.gz` |
| Normal-rate grenade differential | **Old FAIL / new PASS** | `grenade-{old,new}.log.gz` |
| Historical kill-predicate differential | **Old REJECT / new PASS** | `meridian-replay-{old,new}.log.gz` |
| Fresh real Meridian and source-object correlation | **PASS** | `live-audit.log`, fresh UUID below |

Existing normal-rate clock diagnostic in the 50-test run measured 4.45 source
seconds / 4.456514128 wall seconds = **0.998538×**. Scheduler code was unchanged;
this is a diagnostic, not a throughput/timing guarantee. Counts are not summed
across reruns. Prior Verdant, Ember, control-safety and Scoreboard results remain
their original records; those unchanged cases were not repeated in this lane.

## One fresh actual-product Meridian attempt

UUID **`d8cef3a2-e928-499b-8b41-41c6ba0a9b74`**, attempt **1**, **24.239233626s**
outer wall time. Maximum two attempts was declared before launch in `BUDGET.json`;
only one was used. Native deadline 170s, outer native deadline 180s.

- Actual `res://horde/demo.tscn` instantiated as a child by the unchanged separate
  observer. Existing engine input-event steering; no root script replacement.
- Source NPC victims **1,2,3**, local killer 0; genuine **wave 1/1 victory**,
  winner 0, score 94, lives 3, net frags 3, no self-deaths.
- Released restart: source time **0.05**, zero shots/kills/score, no auto-capture.
- Independent object oracle: **1,136 calls**, **467 empty reads**, **669 batches**,
  **810 distinct source event objects**, **810 matching wire events**,
  **zero mismatches**, across two Match instances. `swarm` string sourceId is
  preserved; wire ordinals reset to 1 on restart.
- **378 native-correlated snapshots**, **511 queued native samples** all matched
  to receipts, **513 wire receipts**, **510 distinct stepped samples**, applied
  ACK high-water **505**. These quantities are distinct; cancellation receipts
  need not be periodic queue traces, and an ACK is not a kill or a sample count.
- One successful observer completion, one complete native recording end,
  **harness exit 0**, clean resource/error logs, both owned native/Xvfb PIDs
  reaped and absent, private XDG removed, owned loopback listener closed.

`source-object-oracle.jsonl.gz` preserves expected objects and actual adapter
batches. `horde-live-audit.mjs` additionally matches every expected object to
actual emitted wire frames, so passing cursor comparison alone cannot hide a
dropped outgoing batch. Read-only instrumentation hashes are in `launch.json`.
The observer, source clock, native scripts and controls are unchanged.

### Direct pixel review

Opened all four fresh images below with the image reader:

- [960×640 product results](evidence/d8cef3a2-e928-499b-8b41-41c6ba0a9b74/gameplay-results.png)
- [1280×800 product results](evidence/d8cef3a2-e928-499b-8b41-41c6ba0a9b74/gameplay-results-alternate.png)
- [960×640 released restart](evidence/d8cef3a2-e928-499b-8b41-41c6ba0a9b74/gameplay-restart.png)
- [1280×800 released restart/help](evidence/d8cef3a2-e928-499b-8b41-41c6ba0a9b74/gameplay-alternate.png)

Horde victory/lives/score/restart stay above the complete product Scoreboard.
Restart shows zero frags/deaths, three lives, CLICK TO PLAY and readable two-line
controls at both sizes. The inherited board still calls the NPC-inclusive roster
“4 players”; no bespoke Horde result-design or human-input claim is added.

## Commands, provenance and cleanup

Principal commands, all in this isolated worktree:

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
python3 -B port/reports/horde-event-repair/horde-checks.py
python3 -B port/reports/horde-event-repair/horde-differentials.py
# Commit only the five runtime/test files, then run at c64762a:
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 TMPDIR=/tmp/opencode PORT=0 node port/reports/horde-event-repair/horde-run.mjs --map=meridian-exchange --scenario=combat --resolution=960x640
node port/reports/horde-event-repair/horde-live-audit.mjs
python3 -B port/reports/horde-event-repair/horde-provenance.py
git diff --check
```

Every check's exact argv, exit and temporary-XDG cleanup are in its JSON file;
full output is retained, including both expected old failures. Fresh launch
argv/endpoint/engine/runtime/helper hashes are in the UUID's manifest. Private
Xvfb uses `-nolisten tcp -nolisten unix`, isolated XDG and Dummy audio. Source
and observer steering use unselected `Math.random`, with no seed/RNG retries,
live source state writes, physics/timing or server-restriction changes.

These are the recorded commands. Check/replay helpers refuse to overwrite their
retained output; a lead replay needs its own fresh report root and declared
budget. The five Node test files can also be run directly with `node --test`
without writing any historical evidence.

Pinned Godot `4.5.2.stable.official.6ce3de25a`, SHA256
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`;
Node v22.23.1; locked/installed `ws 8.21.3`. Primary dependencies were used
read-only through the owned symlink, with no install.

`provenance.json` verifies **323 previous delivery/review/repair report files
byte-for-byte against the HOLD baseline**, including all prior rejects and
failed-run evidence. All five repaired files and every fresh launch hash match
runtime commit `c64762a...`. Protected source/public Room/shared native/tools/
contract/package paths have no baseline diff. Source Match SHA256 remains
`23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631` and source lock
`51289b79c627a26a381ba556b92bab71f93f3732` is unchanged.

All owned diagnostic/live ports were checked closed; native/Xvfb PIDs are absent.
Private XDG was removed by each owner. Ten generated resource hashes were
recorded before removing this worktree's semantic output/import cache and
generated untracked UIDs. The dependency symlink was removed; primary
`node_modules` remains present. No agents, merge, push, deployment, shared
restart or port-4332 interaction occurred.

## Remaining limits and lead decision

The narrow repairs and one fresh bounded product case pass. **Lead integration
remains HOLD** pending diff review and independent replay. Exact adapter and
acceptance contracts are in [API.md](API.md); common routing, closure manifests,
aggregate/package rebuild and extracted packaged-gameplay checks are lead-owned.

Full ten-wave completion, later waves/boss, natural defeat, upgrades, endless,
worst-wave/load performance, complete action gameplay effects, hardware/OS input
and audio remain **OPEN**. Campaign remains deferred. The historical ADS
differential and prior Verdant/Ember evidence retain their original scope; this
Meridian run adds no live ADS-aiming, full-game or package acceptance claim.
