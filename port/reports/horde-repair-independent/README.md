# Independent repaired-Horde review — HOLD

**Do not integrate this tip into the local adapter/package yet.** Five old
finding areas are closed within their documented scope. The event cursor repair
still replays source events under new wire IDs when the unchanged source
allocates a projectile/grenade ID. This is independently reproduced with an
ordinary normal-rate input and in the fresh actual-product combat recording.
The prescribed 29 tests all pass despite that defect.

The three requested bounded gameplay effects were independently observed with
the final runtime bytes, clean observer and harness exits, and fresh PNGs. The
Meridian repaired-validator rejection is retained: three distinct NPC kills
occurred, but a source self-kill made net frags/kills 2. No seed retry was made.
This is a **HOLD**, not packaged acceptance or a full Horde feature pass.

## Exact isolation and commits

Worktree `/tmp/opencode/horde-repair-independent`, branch
`review/horde-repair-independent`, created from latest committed primary HEAD
`1a00d90227c9cf7d24a1e132b34f53e8aafcb838`. Primary uncommitted package/log work
was left with its owner. Applied commits in the requested order:

| External commit | Independent-worktree cherry-pick |
|---|---|
| `94690b6674e20f550990df68213376c554ec898c` delivery | `bdffe52d5fa87e49f61c3f30be06515becebe811` |
| `59c2b33c3080845eb73f8490b3dc9e355117c000` original HOLD | `6fae625ccb3273fe9d69e32daab76aa9307c9766` |
| `74d0e277e193e90b860b46143857d9bda4ce060a` repair | `1e75e9434d67498e95b71709d553f092b6086e16` |
| `25eae77fb593ddb0a4211850d5d1a7e0ea6b87aa` help | `c5f1cb2a3b74aa863bc87a26469b8341339c6cd8` |
| `48d1029d7b29d730a85dfd47cd0af14f10dcc221` validator JSON | `31e6af257153a33c5e0ebfd47445b865b45fb790` |
| `50521191ee6922295a50448301e929d945926ef9` final ADS runtime | `fbc2fa3c617fc38686eb9ae12f4d266da9cbb9ef` |
| `272558ec165f31499e47dac9b4d508559de7c4ac` repair report | `9c0f5a50c8935eecbf21cf6f0ff0e1ded57f7345` |

These integration hashes are distinct from the external delivery/repair
hashes. Every fresh launch records `9c0f5a5...` plus exact runtime/observer/wrapper
SHA256s. All **25 changed runtime/helper files match external `5052119` bytes**.
Only this new report tree and the new Horde-prefixed look helper are audit work.
No agents, merge, push, shared restart or port-4332 interaction was used.

Read original HOLD/repair/API/handoff, every changed runtime/helper, inherited
client/session boundaries, source input/keybinding/reset/look/scheduler code,
source event allocation and source net-kill projection. Runtime and source
remained read-only throughout.

## Six-finding disposition

| Area | Independent disposition |
|---|---|
| Input edges/holds/taps and applied ACK | **Closed for the documented default desktop contract.** Old fire-on/off gives ACK 2/shots 0; repaired gives ACK 2/shots 1 and explicit step seqs 1,2. FIFO/cancel/expiry/epoch checks pass. Source-generated 31 input samples and 3 look vectors pass. Queue, receipt, successful source-step records, native ACK and gameplay outcomes are audited separately. |
| Serial event cursor / string source IDs | **OPEN, blocking.** `swarm` now survives, but `Match.serial` is shared by event and entity allocations. `serial - events.length` reindexes old entries after a grenade/projectile. The independent probe replays spawn sourceId 1 as wire IDs 1 and 2. Fresh Meridian contains eight repeated payloads, including explosion. |
| Payload/rate/outbound bounds and WS errors | **Closed for reviewed bounds.** Oversize closes only the peer and reconnect works; message flood and synthetic backlog close the peer; FIFO/frame/total-buffer edge tests pass. Read pre-upgrade checks, error handlers, HTTP bounds, expiry and owned close. No worst-wave/load-performance claim. |
| Elapsed source clock | **Closed.** Actual monotonic accumulator, unmodified 1/60 steps and source five-step cap, construction/round reset excluded. Old normal-rate diagnostic 4.65 source / 4.498521058 wall = **1.033673×**; repaired 4.45 / 4.448470401 = **1.000344×**. Observation/callback jitter makes this diagnostic, not a timing guarantee. |
| Product HUD/Scoreboard layout | **Closed at 960×640 and 1280×800 for the checked composition.** Actual product child, visible result Scoreboard, readable Horde strip/restart and compact help. Synthetic legacy layout fails 2/2; repaired layout passes 2/2, paging 4/10 rows. Fresh PNGs directly opened. |
| Fail-closed exits/resources | **Closed for the old exit/leak defect.** Old validator accepts retained failed run; repaired rejects both exit 1 and nominal exit 0 with resource errors. Five additional negative hygiene mutations reject. Old script replacement leaks 20 orphan Nodes; direct product has zero. Fresh runs have distinct completion, trace-end, harness-exit and cleanup proof. Meridian exposes a separate over-restrictive gameplay predicate, retained below. |

### Test quality and ADS-specific differential

Reproduced **all nine old-fail/new-pass differentials** exactly as documented.
Old TAP is 0 pass/9 expected failures, final aggregate adapter TAP 29 pass/0
fail. Tests use real unchanged Match for taps, source wave event, ordinary clock,
and boundary probes. Rate uses valid lifecycle messages; outgoing-backlog is
explicitly a synthetic socket getter, not a load test. Cancellation/epoch tests
exercise the new adapter contract. The failed historical product resource log
is real retained evidence. Layout is an explicit synthetic fixture.

The event tests are **incomplete**: their synthetic ring assumes a contiguous
event-only serial, and the real-wave test checks only presence/uniqueness of the
modifier. Neither mixes entity allocation with appends or checks event payload
replay. The independent grenade probe adds that missing case and fails final tip.

The native oracle calls source `controlsFromState`, parser and weapon cycling;
desktop press/reset preparation was cross-checked against `app/page.tsx`.
Movement normalization is intentional before wire axis clamps. Expected ADS
gain is derived from source display defaults, not native constants. The new
`godot/tests/horde-repair-independent-look.gd` extracts the **exact product
`update_look` body** from pre-ADS `48d1029` and final source, with only a synthetic
capture predicate. Hip/ADS/release vectors produce old **2/3** (ADS wrong
`[0.5,0]` instead of `[0.53,0.03]`) and final **3/3**. This checks product dispatch
as well as the control model. It is focused differential evidence, not physical
mouse feel or live ADS aiming. Earlier repair live runs preceded ADS correction;
our fresh runs use final bytes but the unchanged observer also does not aim ADS.

## Required verification results

Raw complete outputs are gzip logs; corresponding JSON records exact argv,
exit/expected exit and private-XDG cleanup. Counts from reruns are not added.

| Gate | Result | Evidence |
|---|---:|---|
| Adapter/validator/differential/bounds | **29/29** | `adapter-final.log.gz` |
| Nine original differentials on old committed adapter | **0/9; 9 expected failures** | `regression-old.log.gz` |
| Source singleplayer/UI | **70/70** | `source-ui.log.gz` |
| Native Horde | **15/15** | `horde-model.log.gz` |
| Native source input/look | **31/31 + 3/3** | `source-input-final.log.gz` |
| Exact product ADS method differential | **old 2/3, final 3/3** | `product-look-{old,final}.log.gz` |
| Inherited control safety | **2,497/2,497** | `control-safety.log.gz` |
| GameHUD session | **PASS** | `hud-session.log.gz` |
| Scoreboard | **25/25** | `scoreboard.log.gz` |
| Scoreboard session | **PASS** | `scoreboard-session.log.gz` |
| Horde layout | **old 0/2, final 2/2** | `layout-{old,final}.log.gz` |
| Orphan/resource attribution | **old +20/exit 1; final 0/exit 0** | `leak-{old,final}.log.gz` |
| Semantic/pinned import/source lock | **PASS**, nine maps | `semantic`, `import`, `source-lock` logs |
| Normal default Room rejects Horde | **PASS**, real private WS/default `local` room | `default-room.json` |
| Additional normal-rate grenade event probe | **FAIL, blocking** | `event-gap.json`, raw wire and console |

Normal default Room returns `single-player modes are local only`, retains
deathmatch config, and constructs no Horde Match. This used its own loopback
PORT 0 with default factory options, not the shared service.

## Fresh normal-rate product attempts

Budget declared before runs in `BUDGET.json`: at most two per case, native 170s,
outer native deadline 180s. Exactly **one attempt per case** was used. Every run
uses actual `res://horde/demo.tscn` instanced as a child of a separate observer;
no root script replacement. Steering is existing engine input events. No RNG
selection/retry, source state writes, clock injection, physics or restriction
edits. Private Xvfb is `-nolisten tcp -nolisten unix`; private XDG; Dummy audio.

| Case / UUID | Wall time | Actual outcome / acceptance status |
|---|---:|---|
| Meridian `b3e2a06b-5e89-46ab-a078-24cc57c91b60` | 32.183s | Enemy victims **1,2,3**, all killer 0; legal 1-wave winner-0 victory, score 94; released restart at source time .05 with zero shots/kills. Source self-kill at 22.35s caused net frags/kills **2**, lives **2**. Observer/harness exit 0. **Repaired CLI FAIL** `2 !== 3`, preserved. Independent bounded effects pass; integration HOLD and eight event replays. |
| Verdant `fe8751ed-4200-4eec-8e91-5252bf598f4b` | 32.328s | Natural enemy-attributed death, lives **3→2**, actual dead snapshot 511, living respawn 551. E press plus physically held E/crouch before death; **129 neutral native samples** through release/respawn; blocked capture until release, fresh capture after. **Repaired CLI PASS**, bounded effects pass. |
| Ember `f1346289-0f65-4210-bad5-1df72d0dc179` | 11.502s | Real default **wave 1/10**, three enemies, no result; both viewport/help sizes. **Repaired CLI PASS**, startup only. |

| Case | Native correlated snapshots | Native queued / receipt-matched | Wire input receipts | Distinct stepped samples | Native applied ACK high-water |
|---|---:|---:|---:|---:|---:|
| Meridian | 564 | 1,411 / 1,411 | 1,455 | 1,295 across two rounds | 1,446 |
| Verdant | 588 | 1,106 / 1,106 | 1,149 | 1,024 | 1,148 |
| Ember | 150 | 296 / 296 | 297 | 295 | 296 |

Immediate cancellation receipts need not have a periodic queue trace row;
cancelled samples need not be stepped. An ACK high-water is not an applied count
or a contiguous-prefix guarantee. The independent auditor checks **stream order**
of receipt→successful-step record→snapshot ACK, parsed controls, epochs, native
ACK equality, every projected Horde model field, rendered identity/positions,
and separate source effects. Floating-point model timers use <1e-9 tolerance
for Godot JSON decimal precision. Initial strict deep-equality audit failure
(`1.98333333333333` vs `1.9833333333333334`) is retained in
`live-audit-console.log`; corrected auditor passed the same raw runs without
another gameplay attempt (`live-audit-final.log`, `live-audits.json`).

All three have one `HORDE_DONE ok=true`, one complete native `recording_end`,
clean **harness exit 0**, no resource/script errors, reaped/absent native and
Xvfb PIDs, removed private XDG and closed owned listeners. These are separate
facts. A recording end is not ten-wave completion. Meridian's validator failure
is separate from its successful observer/harness exit and is never overwritten.

### Directly opened PNGs

Eight fresh images were opened with the image reader, not just hashed:

- Meridian [960×640 results](evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60/gameplay-results.png),
  [1280×800 results](evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60/gameplay-results-alternate.png),
  [960×640 restart](evidence/b3e2a06b-5e89-46ab-a078-24cc57c91b60/gameplay-restart.png).
  Horde lives/score/restart remain above the full Scoreboard at y=280; the board
  ends at y=581. Results correctly show 2 frags/1 death and 2 lives, not 3 frags.
- Verdant [1280×800 respawn](evidence/fe8751ed-4200-4eec-8e91-5252bf598f4b/gameplay-final.png),
  [960×640 respawn](evidence/fe8751ed-4200-4eec-8e91-5252bf598f4b/gameplay-alternate.png),
  [1280×800 death](evidence/fe8751ed-4200-4eec-8e91-5252bf598f4b/gameplay-death.png).
  Lives, health, ammo and both help lines are legible. The known close-range
  world badge becomes oversized behind the death/status panel; cosmetic limit
  retained. A still image does not prove held-action suppression.
- Ember [960×640 startup](evidence/f1346289-0f65-4210-bad5-1df72d0dc179/gameplay-final.png),
  [1280×800 startup](evidence/f1346289-0f65-4210-bad5-1df72d0dc179/gameplay-alternate.png).
  Default ten-wave target and two-line source controls are readable/unclipped;
  help ends at y=632/792. Startup only.

The inherited Scoreboard still calls NPC-inclusive rows “4 players.” No claim
of a bespoke solo-Horde results design, live human Tab use or enemy-art parity.

## Provenance, commands and cleanup

Pinned engine `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`,
`4.5.2.stable.official.6ce3de25a`, SHA256
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
Node v22.23.1; existing primary `node_modules` linked for read-only module
resolution (no install). `ws` remains locked at 8.21.3.

`provenance.json` independently compares **119 historical delivery/review files**
to baseline git blobs, plus **94 prior repair report files**, all byte-identical.
Source Match SHA256 remains
`23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631`.
Source lock `51289b79c627a26a381ba556b92bab71f93f3732` remains valid. Protected
source/shared/launcher/package paths have no diff from integration baseline.
All 25 final repair files and each fresh launch hash match. PNG sizes/hashes,
all six absent/reaped live PIDs, closed owned ports and ten generated-resource
hashes are recorded. `cleanup.json` records subsequent owned cache/symlink/
generated-output removal; `final-scope.json` records final scope/whitespace checks.

Exact principal commands (full per-check argv also recorded in JSON):

```sh
git worktree add -b review/horde-repair-independent /tmp/opencode/horde-repair-independent 1a00d90227c9cf7d24a1e132b34f53e8aafcb838
git cherry-pick 94690b6674e20f550990df68213376c554ec898c 59c2b33c3080845eb73f8490b3dc9e355117c000 74d0e27 25eae77 48d1029 50521191ee6922295a50448301e929d945926ef9 272558ec165f31499e47dac9b4d508559de7c4ac
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
python3 -B port/reports/horde-repair-independent/horde-checks.py
node port/reports/horde-repair-independent/horde-event-gap.mjs # expected FAIL
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
node port/reports/horde-repair-independent/horde-run.mjs --map=meridian-exchange --scenario=combat --resolution=960x640
node port/reports/horde-repair-independent/horde-run.mjs --map=verdant-reliquary --scenario=death --resolution=1280x800
node port/reports/horde-repair-independent/horde-run.mjs --map=ember-crucible --scenario=startup --resolution=960x640
node port/reports/horde-repair-independent/horde-default-room.mjs
python3 -B port/reports/horde-repair-independent/horde-final-checks.py # stops at retained Meridian validation FAIL
python3 -B port/reports/horde-repair-independent/horde-complete-checks.py
node port/reports/horde-repair-independent/horde-audit.mjs
python3 -B port/reports/horde-repair-independent/horde-provenance.py
python3 -B port/reports/horde-repair-independent/horde-cleanup.py
git diff --check
```

The owned live wrapper changes only output root, absolute authority import,
budget label and its own hash inventory in the committed launcher's source;
it does not change source, scheduler, product or steering. Raw logs for every
failure and all three UUIDs remain. No second attempt is needed to establish
the event defect or to discard an unfavorable source outcome.

## Lead action and remaining limits

See [PROPOSED-FIXES.md](PROPOSED-FIXES.md) for the minimal **unapplied** event
cursor replacement, event API wording correction, net-frag acceptance predicate
correction, and exact local factory/readiness/closure requirements.

Full ten-wave completion, boss combat, natural defeat, upgrades, endless,
worst-wave resource/load behavior, complete action gameplay effects,
human/OS/hardware input and audio remain **OPEN**. Campaign stays deferred.
Common/aggregate, package build and packaged Horde gameplay were not run in this
lane. The lead retains ownership of those gates. **Independent HOLD before
local-adapter integration.**
