# Combined non-art feature candidate

**Historical source checkpoint. Native follow-up and remaining blockers: [NATIVE_CLOSEOUT.md](NATIVE_CLOSEOUT.md).**

Branch: `finish/integration-20261002`; base: `6cefd9eb`.
Runtime/source candidate: `76c6a9ec` (the following documentation commit does not
change runtime files). The final handoff supplies the exact full branch HEAD.
Parent can fast-forward this branch or cherry-pick `6cefd9eb..HEAD` in order.

All **24 prepared feature commits**, covering **nine feature lanes**, plus both
requested packaging commits are integrated. Published runtime remains `e731fd53`. Frozen source `515daf07589150dd3241f4ae1425cc1b093912f5`,
core SHA-256 `58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`,
and reviewed derivative `0326b435a2fdd88e6e7a01b8a7325feccc4d15cb` are preserved.
There are no `game/` or `server/` edits. No new map recipes/art, empty robot/fleet/
scenery preloads, old-art regeneration, or all-map regeneration was performed.
No Godot, import, renderer, Blender, audio playback/capture or ffmpeg was run.
Helix revision 2 is the sole heavy-slot owner following Parallax's release;
parent retains native scheduling ownership. This is not a finished release.

## Original commit mapping

Every prepared commit was cherry-picked with `-x`; full original identities are
retained in its commit body. Abbreviated mapping below is unambiguous in this repo.

| Lane | Original | Integrated |
|---|---|---|
| Gameplay | `77e7684f` | `40c36946` |
| Gameplay | `f747c3ef` | `93a7df5b` |
| World | `f93f71b2` | `464223e2` |
| World AV hook | `12f0aa1b` | `d167545a` |
| Modes | `9e5d0dd4` | `a6b7f780` |
| Modes baseline package hooks | `8d7bf0c3` | `da5f5295` |
| Modes fixtures | `e94b3da0` | `c433c97e` |
| Experience | `ab437a38` | `de31460d` |
| Experience session hooks | `6ca4959a` | `78e99016` |
| Experience runner | `84b91928` | `40ef4af7` |
| Experience camera ownership | `8d1efc60` | `7eab4e55` |
| Horde | `b56cfbd1` | `422d868b` |
| Horde journeys | `f4437002` | `41bf04d1` |
| Horde targeting fixture | `05986449` | `91527a85` |
| Audio | `22b95dba` | `99a89082` |
| Audio AV hook | `0b5823a3` | `58b81fba` |
| Audio source checks | `bf4d8865` | `aff76249` |
| LATTICE | `dabf5b9c` | `818a7d42` |
| LATTICE handoff | `9f944afb` | `db1cc6f4` |
| Controls | `def1e974` | `a91e48e6` |
| Controls shared hooks | `a1b1c090` | `357740dd` |
| Controls handoff | `9aa752a8` | `46685921` |
| Replay | `9120d991` | `9c36ac70` |
| Replay capture hook | `9794575a` | `e6a5c48b` |
| Packaging closure | `8522dcde` | `bd672ba5` |
| Packaging evidence | `1466c861` | `92a29142` |

Integrator commits:

- `3a04121e`: confirmed-recipient caption eligibility, before formatter wiring.
- `593a5339`: isolated reviewed `caption-integration.patch` hunk, applied with
  the patch tool after the eligibility gate.
- `54503e41`: merged lifecycle/hints, wet shader parameter-shadow repair,
  source eligibility oracle/native contract, stale Horde assertion repair.
- `ff8a30fb`: direct Home Replay entry, packaging hook report and pending native
  Home/attract/helper teardown contract.
- `76c6a9ec`: fail-closed exported Replay startup, prepared native negative
  journey, cross-language manifest contract and reconciled factory/closure tests.

## Conflict and semantic decisions

1. **Gameplay / Controls textual conflict:** `player_gameplay/session_binding.gd`
   keeps Gameplay's rope hint, change-only `status_changed`, nonempty-model cue
   guard and fallback visibility. Controls' `Hints.resolve(Status.text(model))`
   wraps that result. The actual Experience ability label also resolves bindings,
   and subscribes to binding changes even if the projected gameplay model has
   not changed. Grok hold/release and held-X/shared-rope instructions survive.
2. **Caption privacy:** the prepared formatter was not safe to wire by itself.
   `caption_model.event_allowed` now checks the existing spectator allowlist,
   foreign team intent, source local-actor buy/device eligibility, source team
   sound eligibility, supported command actions and nonempty repair/spot payloads.
   It runs before formatting/dedupe. Team comes only from the current confirmed
   own-actor snapshot; team changes, missing actor, seat changes, backwards clock,
   stale state and existing lifecycle clearing cannot retain old private captions.
   Existing TTL/priority/settings and single caption queue remain authoritative.
   The native spectator allowlist intentionally stays stricter than the source
   wire's untagged-event rule. New source vectors explicitly account for this.
3. **Spectator camera / remapping:** public camera guards and zero actor packets
   (including neutral packets) survive. Inactive sampler observation now sees
   physical key releases while spectating, preventing a key held during a seat
   change from remaining stuck in the old binding ledger. It neither consumes
   spectator camera input nor captures the pointer. Horde's per-frame camera
   rotation is also guarded. Existing source-derived sports generator inputs
   contain the fix; its generated derivative passes exact `--check`.
4. **Horde guidance / labels:** repair priority/prerequisites, station receipts,
   upgrade scrolling/details and Warden fixture correction survive. Blackwater's
   new dynamic E-use guidance resolves the configured binding at the HUD boundary.
   LATTICE's latest-command receipt/recovery/progress text and fixed deck keys
   remain intact; Controls does not overwrite that feedback.
5. **World / Audio AV hooks:** Git merged both changes cleanly. Round and seek
   reset rain contacts and threat voices; weather ticks only with confirmed
   context and remains independent of audio mute. Threat routing retains
   event-before-snapshot consumption and focus/stale/results/round cleanup.
   Static review found `_bind_material(..., surface: int, ...)` shadowing the
   new `surface` helper, making `surface.lease_shader` invalid. The parameter is
   now `surface_index`; shader/texture ownership restoration is preserved.
6. **Replay Home:** `Replays` opens `res://replay/library.tscn` in-process,
   without `MENU_ROUTE` or authority startup. Home stops attract, saves menu
   preferences, suspends AV and is freed by scene replacement. Replay Home
   returns to the existing main menu and releases its local helper. No live
   client/net/Career award path is added to playback. See the exact production
   paths and packaging coordination in [HOME_REPLAY_HOOK.md](HOME_REPLAY_HOOK.md).
7. **Persistence:** bindings retain their separate atomic device-local store,
   unknown binding/envelope fields and reset semantics. Shared settings schema
   is unchanged. Package-worker closure commits were cherry-picked after the
   features, retaining Modes' challenge authority/discovery hooks. Acceptance
   registration remains separately owned by the canonical acceptance worker.
8. **Retained regression failure:** the existing identity-Horde test expected an
   allowlist lacking already-shipped `blackwater-reclamation`. The production
   allowlist was not changed. The assertion now includes that existing map.

## Source/static evidence actually executed

Unique evidence root:
`/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002/`.

| Check | Actual result / evidence |
|---|---|
| Combined Node suite, 41 files across all lanes | **610 passed / 1 failed / 611 total** in `combined-node-tests-01.tap`; failure retained as described above |
| Repaired identity-Horde suite | **15/15 passed**, `identity-horde-rerun-final.log` |
| Remaining store/input/options coverage, 6 files | **29/29 passed**, `stores-input-options-tests.tap` |
| Distinct accepted Node tests | **640 distinct tests** have passing evidence; 655 total executions including the 15-test rerun, one retained initial failure. Not a claim of one clean 640-test invocation |
| GDScript grammar | **93 files passed**, `static-final.log`; grammar only, not Godot typing/import/runtime |
| Changed/new Node syntax | **42 modules passed**, `static-final.log` |
| Static context audit | No member/parameter shadows or instance counter writes inside static functions in changed scripts; manual recipient/camera/AV/replay composition review. `static-final.log`, `counter-input-audit.txt` |
| Gameplay second pass | Seven movement journeys + seven negative controls; shared-rope/no-X/expiration source oracle, `gameplay-second-final.log` |
| Gameplay existing catalog/fixtures | `gameplay-catalog-final.log`, `gameplay-fixtures-final.log`, exact `--check` passed |
| World spatial oracle | Three texture hashes, 20 schedules, eight ripple steps passed; `weather-spatial-final.log` |
| World existing oracle | Six looks, 60 replay samples, four luminance cases passed; `weather-final.log` |
| Spectator oracle | 48 target, 30 assist, 63 visibility, 40 motion vectors passed; `spectator-final.log` |
| Experience existing oracle | 115 captions, 432 replacements, ten ranges passed; `experience-final.log` |
| LATTICE oracle | 47 captions, four progress, thirteen recovery vectors; ten derivative runtime hashes passed; `lattice-final.log` |
| Controls oracle | 25 defaults, nine normalization cases, 1,075 swaps, fourteen timelines / 98 samples, four modal boundaries passed; `bindings-final.log` |
| New combined caption oracle | **208** direct-source recipient/cue vectors generated and rechecked; `caption-eligibility-final.log`. Native comparison is prepared, unexecuted |
| Generated scenes/options/flow | Exact generator `--check` passed after final resolutions; `generated-scenes-post-resolution.log`. No map/art regeneration |
| Gameplay Node real-wire journey | Guest ride, owner resume, ordinary-fire death/anchor cleanup passed; `gameplay-wire-01/{report.json,trace.json}`, plus `gameplay-wire-01.log` |
| LATTICE Node real-wire journey | **22/22** checks passed; `wire-6VNp7F/result.json`, trace and `lattice-wire-01.log`; controlled wallet/phase setup explicitly labelled |
| Frozen source/export exclusions | Empty game/server diff, core hash and `tests/*` export exclusion passed; `static-final.log` |
| Whitespace | Passed in `whitespace-final.log`; supplied unified-diff data artifact excluded from whitespace lint |

`source-checks.json` records exact oracle commands/exits. All runs used Node or
Python static tooling; no native process ran. Existing external `node_modules`
is linked for source checks only and is untracked/ignored. Source tests use
actual source rules; controlled setup and accelerated source clocks are not
native, human, real-time performance or rendered acceptance.

## Combined engine acceptance remaining

**Native jobs executed here: 0. Native acceptance deferred: true.** All nine
lanes retain their native obligations. The packaging worker must finish runtime
closure/canonical registration before extracted-package acceptance. Parent grants
one combined serialized acceptance slot after current map finalization.

Start with import/type/resource checks of the combined candidate, then existing
canonical regressions and these prepared lane gates, serially under that grant:

| Surface | Prepared executable gate(s) / required follow-up |
|---|---|
| New integration boundary | `res://tests/finish/caption_integration.gd` (208 source comparisons + four consume checks); `res://tests/finish/home_replays.gd` (six production entry/cleanup checks) |
| Gameplay | `tests/player_gameplay/second_pass_test.gd`; `tools/port/pass-two-gameplay/native.mjs`; `native-shared.mjs` death/expiration/reconnect variants |
| World / Audio composition | `tests/world_weather/spatial.gd`, existing weather/AV lifecycle gates, `tests/audio_expansion/threat_gate.gd`; granted `tools/godot-audiovisual/expansion/native_journey.mjs`; real-driver recording/listening still required |
| Modes / Career | `tests/mode_expansion/challenges_contracts.gd`; granted `port/pass-two/modes/native-proof.mjs`; fresh-process persistence/reconnect/settlement and wide/compact Career |
| Experience | `tests/experience/spectator_contract.gd`, `competitive_camera.gd`; `tools/experience/connected-native.mjs` world/mode/sports/combined_arms families; actual seat/modal/focus/reconnect and zero wire input |
| Horde | `tests/horde_expansion/guidance_test.gd`; `port/expansion-three/horde/native-journey.mjs` chain/boss and wide/compact rendered variants; full native mission victory remains required |
| LATTICE | `tests/lattice/expansion_feedback_contract.gd`, tactical/commands regressions; granted `tools/port/lattice/native-clients.mjs`; own/enemy/spectator dynamic caption privacy and command lifecycle |
| Controls | `tests/input_bindings/contracts.gd`; granted `tools/port/input-bindings/native-journey.mjs` wide/compact; actual remapped cross-route lifecycle and OS side/modifier events |
| Replay | `godot/tests/replay/run.mjs`; Home entry/attract teardown above; saved/reopened recording, seek poses, no authority packets/award path, listening and both extracted-platform runtime closures |
| Exported Replay startup | `tests/finish/replay_bridge_negative.gd`: 48 prepared native checks, missing/corrupt runtime and Windows executable refusals before helper startup; unexecuted |

Exact environment flags/limits, source provenance and unsatisfied graphical
criteria remain in each original lane's `PARITY.md` / `ACCEPTANCE.md` under
`port/pass-two/`, `port/expansion-three/` and `port/expansion-four/`.
All new native tests are under the existing excluded `godot/tests/` tree.
Wide/compact layouts, real native typing, shader pixels, live UI/audio/resource
lifecycle and extracted Linux/Windows packages are deliberately unclaimed.
The known Sunscar VIP ordinary-input extraction obstruction remains documented
in Modes; this integration does not change its frozen authority/geometry.

## Packaging follow-up verification

Steering added packaging `8522dcde` + `1466c861` after the feature integration.
Production fixes and prepared tests are committed at
`76c6a9ec4c7fffaaa086fac23498d2e52604480f`.

- Exported Replay startup now anchors exclusively to the executable directory,
  verifies manifest version/kind, exact four paths and every SHA-256, then checks
  platform Node discovery before helper startup. Editor checkout discovery is
  behind `OS.has_feature("editor")`. Windows requires the package's `node.exe`;
  Linux uses its own bundled node or PATH node. Failures emit readable errors
  without checkout/authority retry. The 48-check native rejection journey is
  prepared, not executed; its instrumented spawn seam must remain untouched on
  every negative case. Cross-language manifest vocabulary is source-tested.
- Both native-arena launcher factory fixtures now retain valid 1/7/8 coverage,
  add **24 bots / 25 actual source actors**, and preserve lower/upper refusals at
  **0 and 25**. Both launcher option modules explicitly permit 1..24, matching
  the reviewed port-owned authority/local-roster configuration. All **13** dev/
  package factory tests passed, including direct authority bounds. These use a
  synthetic geometry and Node protocol executable, not Godot.
- `package-combined-tests-01.tap`: **249/250 passed**, one retained failure from
  the existing Horde closure assertion expecting 85 source modules. Keeping the
  challenge-authority hook adds the unchanged `game/challenges.mjs`, yielding 86.
  The assertion now checks 86 plus named challenge adapter/module inclusion and
  exclusion from the Horde route; no range or provenance checks were weakened.
- `package-resolution-tests.tap`: **4/4 passed** (three closure tests plus the new
  cross-language Replay manifest contract). Thus all 250 package/Replay/factory
  tests have passing evidence, plus the new contract; the initial failure remains
  on disk. The actual Replay adapter subset passed **15/15** in the combined run.
- `package-static-final.log`: four additional/changed GDScript files passed
  grammar parsing; sixteen Node modules passed syntax; `build.py` passed Python
  AST parsing. Native type/resource/runtime acceptance is still unexecuted.
- **Post-commit actual combined closure:** `combined-committed-closure.log` and
  `combined-committed-discovery.json` are bound to `76c6a9ec…`. Discovery was
  re-derived from committed Git objects and compared exactly to the checkout:
  **86 source modules, 39 port adapters, seven original world data files**.
  Challenge adapter and source challenge module are explicitly present.
- `combined-feature-resources.json`: **166** feature resources checked against
  committed provenance, including all **160** deterministic telegraph WAV hashes;
  **14** original-world geometry/art resources validated read-only. No new public
  map assets/catalog grants were merged.
- `combined-replay-package-01/replay-runtime`: four files copied from the recorded
  commit, then independently provenance-verified. `combined-replay-check-01/`
  contains a passing actual extracted **Node-only** helper authentication/library/
  unsupported-admission check, launched from a fresh working directory. It starts
  no engine or authority and is not native bridge startup proof.

Exact package-suite command is retained in `package-combined-command.txt`.
The canonical acceptance worker still owns verify registration. Helix revision 2
owns the heavy slot. **Native grant deferred; no native processes executed.**
