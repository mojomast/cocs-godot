# Independent native zone-mode verification

**PASS for the bounded Meridian/Domination and Verdant/KOTH capture → held score
→ natural timed results → authoritative restart scenarios.** One live attempt
per scenario; both passed. No second attempts were needed. This review found no
blocking runtime defect for those scenarios. Two helper/integration caveats and
one inherited visual issue are recorded below.

## Exact baseline and provenance

- Integration base: `8a58c97e48493e41903c2c9a729e753cb3579500`.
- Delivery commits, applied in order: `2b3d75829372894b7dcb5add7809bc9fe04d011e`,
  `7238c9dc7c706b47dd6a0f36ae1e6454ee81325e`.
- Local cherry-picks: `9c824d1`, then tested HEAD
  `70f4b8f726cf202776b1e7a2fc49e66e5da184ed`.
- Isolated worktree: `/tmp/opencode/zone-modes-independent`.
- Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`.
- Godot: `4.5.2.stable.official.6ce3de25a`.
- Independent session: `ses_f38bfad3dffeCtFsekw8G6EuRS`.

`provenance.json` records SHA-256 for 638 tracked runtime/contract/helper files,
the pinned binary, and all ten generated semantic files. Each original run
summary also retains the helper's runtime hash subset. The independent audit
verified those hashes against this checkout and all gzip uncompressed hashes
and byte counts. Source-lock verification ran before each live attempt.
Runtime, source, shared launchers, gates, package files and delivery evidence
were unchanged. `integration.UNAPPLIED.patch` was not applied.

Read ownership from the primary checkout's `port/handoffs/ACTIVE_LANES.md`
(path/hash recorded), since this integration baseline does not contain that
coordination file. Reviewed both delivery documents, all new runtime scripts,
unit/live tests and helpers, shared session/HUD lifecycle, and authoritative
zone rules. Primary checkout and other lane reservations were untouched.

Ignored semantic assets and an import-cache copy came from the delivery
worktree. The generated manifest is `semantic-diagnostic`, with nine maps and
null `world_glb`; these runs use the ordinary native procedural world, not the
optional GLB visual probe. `node_modules` is an existing-primary-dependencies
symlink; no install occurred.

## Genuine live receipts

| Observation | Meridian / Domination | Verdant / KOTH |
|---|---|---|
| Independent evidence suffix | `455f5397-f4ee-4985-afce-a6a33b0e0118` | `1de6fe4a-f185-4959-a56a-43fc6df84067` |
| Actual image resolution | 960×640 | 1280×800 |
| Initial source actor x/y/z | `(-36,0,-6)` | `(-28,0,30)` |
| Captured zone | Bravo `(-14,0,-19)`, radius 3.5 | Alpha `(8,0,-4)`, radius 4 |
| Source capture event time | 9.417s | 12.750s |
| First observed capture transition | 9.433s | 12.767s |
| Source capture stat | 0 → 1 | 0 → 1 |
| Living in-zone score-growth samples | 1,518 | 518 |
| Final authoritative score | 50.59999999999841 : 0 | 17.250000000000302 : 0 |
| Results source time | 60.01666666666454s | 60.01666666666454s |
| Source-round observed wall duration | 59.212s | 59.453s |
| Whole helper wall duration, including routing | 68.669s | 73.004s |
| Correlated native/source snapshots | 1,801 | 1,802 |
| Queued / source-received inputs | 1,468 / 1,467 | 1,868 / 1,867 |
| ACK high-water (receipt only) | 1,465 | 1,865 |
| Results / authoritative starts | 1 / 2 | 1 / 2 |
| Native driver checks | 5,414 | 1,813 |

Both used ordinary host `botCount:0,timeLimit:60`, default target 100 and source
speed/gravity/damage 1, without mutators, preferred seeds, tick overrides or
state writes. Input was ordinary Godot key/mouse events via
`Input.parse_input_event`, routed through the shipped scene and session.
The wire contains only create/host/start/input requests. Source receipt and ACK
counts are not objective application evidence: the separate audit requires an
ownership transition, an increased local actor capture statistic, actual living
occupancy, score growth and a source `zone-capture` event.

Verdant rotated to Bravo `(-28,0,10)` at source time 30.017s. Native projection
and marker identity followed the recipient snapshot; source score stopped at
17.25 once the old hill was inactive. No rotated-hill capture is claimed.
This run's initial spawn and route match the delivery's earlier failed spawn
case; the delivered exact-geometry/received-ID binding succeeded unchanged.

Both drivers verified held-W capture refusal, fresh-click capture, Escape
release, results pointer release/control ineligibility, Enter restart, no
inherited capture, held-W restart refusal and fresh-click recapture. The audit
also independently requires restarted source time below one second, zero team
scores and zero local capture stat. The post-restart observation is brief; this
does not claim completion of a second round.

## Screenshots directly opened

- [Meridian gameplay, 960×640](../../native-zone-modes/evidence/meridian-exchange-455f5397-f4ee-4985-afce-a6a33b0e0118/gameplay.png)
- [Meridian results, 960×640](../../native-zone-modes/evidence/meridian-exchange-455f5397-f4ee-4985-afce-a6a33b0e0118/results.png)
- [Verdant gameplay, 1280×800](../../native-zone-modes/evidence/verdant-reliquary-1de6fe4a-f185-4959-a56a-43fc6df84067/gameplay.png)
- [Verdant results, 1280×800](../../native-zone-modes/evidence/verdant-reliquary-1de6fe4a-f185-4959-a56a-43fc6df84067/results.png)

Opened all four original PNG files with the image-reading tool. Gameplay shows
the friendly ring, ownership/progress, inside/radius hint, score/clock, vitals,
weapon/ammo and controls fitting the target resolution. Results show a compact
victory/score header and a readable, non-overlapping inherited scoreboard.
Close-range inherited pickup captions become enormous behind results (especially
Verdant's ROCKET caption); the results remain readable. This existing visual
limitation is preserved in the evidence. Each scenario was reviewed at its
listed size; this is not a full cross-product of both maps at both sizes.

## Focused checks

All exit 0, with no Godot errors or leak warnings in retained output:

| Suite | Checks/tests |
|---|---:|
| `godot/tests/zone_modes/unit.gd` | 42 |
| `port/native-zone-modes/route.test.mjs` | 3 tests, both maps' authored spawns plus exact geometry binding |
| `godot/tests/protocol/control_safety.gd` | 2,497 |
| `godot/tests/protocol/stall_controls.gd` | 12 |
| `godot/tests/protocol/round_boundaries.gd` | 34 |
| `godot/tests/protocol/local_lifecycle.gd` | 15 |

Exact commands/statuses are in `checks.json`; logs are adjacent. `audit.py` is a
separate read-only receipt/hash audit and produced `audit.json` with empty
`audit.stderr.log`. To reproduce the archive audit from this repository root:

```sh
python3 port/reports/zone-modes-independent/audit.py \
  port/native-zone-modes/evidence/meridian-exchange-455f5397-f4ee-4985-afce-a6a33b0e0118 \
  port/native-zone-modes/evidence/verdant-reliquary-1de6fe4a-f185-4959-a56a-43fc6df84067
```

## Issues and precise unapplied fixes

1. **Acceptance-helper caveat (medium):** `port/native-zone-modes/run.mjs:57`
   assigns exit 0 even for `bounded partial`, and `validate.mjs:26` conditionally
   checks capture/scoring transitions only when the stats claim them. A moving
   but unsuccessful approach can therefore be a successful process exit.
   The existing partial label is honest; it must not be treated as an acceptance
   pass by a common gate. Minimal integration fix: immediately after writing
   `validation.json`, add
   `assert.ok(validation.nativeCapture && validation.nativeHeldScore && validation.captureTransition && validation.scoredInside, 'capture and held-score acceptance');`
   before setting `exit=0`. This preserves the JSON and raw archives on failure.
   Alternatively the lead's gate must require those four true fields explicitly.
   This independent audit requires all four effects and actual source events.

2. **Provenance-helper caveat (low):** `run.mjs:66` hardcodes `base:'013ad65'`.
   Both untouched run summaries therefore retain that stale field. Use this
   report's exact tested HEAD and `provenance.json` for the independent baseline.
   Minimal fix: replace that literal field with
   `testedHead:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim()`;
   retain runtime hashes for dirty-tree detection. Original summaries were not
   rewritten to hide this mismatch.

3. **Inherited visual limitation (low):** oversized nearby pickup captions behind
   results, visible above. No zone-runtime correction is required for acceptance
   of these captures. Any shared pickup presentation change belongs to the lead.

All fixes above are recommendations only. No runtime/helper edit was applied.

## Scope, retained history and owned cleanup

The helper has no output-directory option, so only its two newly generated
evidence directories were added under `port/native-zone-modes/evidence/`, each
with explicit independent provenance. The independent report/checks/audit live
under this new report directory. All delivery attempt archives, including its
failed Verdant attempt, remain byte-for-byte preserved. There were no independent
live failures to omit.

Each attempt owned `server.listen(0,'127.0.0.1')`, a private Xvfb launched with
`-nolisten tcp -nolisten unix`, isolated HOME/data/config/cache directories and
an additional private `XDG_RUNTIME_DIR`. Four owned child PIDs were reaped and
absent: Meridian `3186590`, `3186599`; Verdant `3193498`, `3193501`. Both authorities
closed with zero sockets; both helper runtime trees and both outer XDG runtime
directories were removed. Focused tests' isolated XDG tree was also removed.
The private worktree and its ignored local asset/cache/dependency setup remain
for inspection. No shared service was stopped, no merge/push/deploy occurred,
and no further agents were started.

Acceptance remains bounded to these two ordinary zero-bot native scenarios and
synthetic edge-state checks. Live contest/neutralization/recapture, opponent
combat, all-three Domination zones, other supported map/mode pairs, multi-human
play, common-launcher hooks and packaged launch were not exercised here.
Campaign remains deferred. Delivery commits are dependencies; the independent
evidence/report commit should be cherry-picked separately by the lead.
