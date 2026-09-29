# Three-stream expansion and consolidated build

## Final candidate: 156cd370

Both platform packages are built from **`156cd37060b3935aa5a93459ce4de6b2710424ab`**.
Its clean local run passed **273/273 native gates**, **228/228 server tests**, and
lint with **zero errors / 916 warnings**. Exact reports and artifact manifests are
under `native-consolidated/evidence/verified-156cd370/` and `packages-156cd370/`.

This revision includes responsive Assault/Uplink HUD composition proven live at
760×520/UI150 and 1280×800/UI100 in development. It also repairs the crew fixture's
intermediate-waypoint orbit by waiting for neutral source ACK/velocity before
turning, and entering the Puma whenever the actual source position is in range.
Three-client gates passed at normal rendering, 10 FPS and 8 FPS. The 5 FPS camera
correlation stress failure remains recorded under `native-vehicle-expansion/evidence/ci-repair/`.

| Final candidate artifact | SHA-256 |
| --- | --- |
| `cocs-native-linux.tar.gz` | `3935146e7c90ed33424dea8daf11628acca2dca894d048f7c77f5da4ab51ef27` |
| `cocs-native-windows.zip` | `ae69daa594a30b26324ed826145da1a067ceb2b7bfb52fefceb5019fc8b82f2f` |

Fresh extracted acceptance passed **31 Linux launcher/runtime cases**, **six
Horde product checks**, both manifest validations and **17 actual Windows
headless cases** with all 148 packaged files verified. Actual release-PCK live
Assault/Uplink captures passed strict bounds/non-overlap and direct visual review
at **760×520/UI150** and **1280×800/UI100**. Package binary/PCK/manifest bytes
remained unchanged. Final evidence is retained under `native-consolidated/evidence/`
in `linux-package-156cd370/`, `windows-ci-156cd370/`, `compact-release-156cd370/`,
`desktop-release-156cd370/`, and `release-layout-review-156cd370.json`.

Hosted native: <https://github.com/mojomast/cocs-godot/actions/runs/36565120535>.
This hosted run stopped in the three-renderer crew fixture during the driver's
approach; local normal/10FPS/8FPS runs passed. The hosted log shows a large
source-snapshot/input-processing gap and is retained under `ci-156cd370/`.
A constrained-CPU fixture diagnosis is in progress; hosted green is not claimed.
General: <https://github.com/mojomast/cocs-godot/actions/runs/36565120586>.
Windows: <https://github.com/mojomast/cocs-godot/actions/runs/36567727776>.

## Previous candidate: 8ba6371b

`8ba6371b92658b44ccb6b28fd51f06309b037c78` adds the final Nacre DM adapter
repair and source-legal player-flow outcome check. Its full rerun passed **273/273
native gates**, **228/228 server tests**, and lint with **zero errors / 916 warnings**.
Both fresh exports completed from clean checkouts at that exact revision.
Evidence is in `native-consolidated/evidence/verified-8ba6371b/` and
`native-consolidated/evidence/packages-8ba6371b/`. Hosted native and general
runs are <https://github.com/mojomast/cocs-godot/actions/runs/36558651282> and
<https://github.com/mojomast/cocs-godot/actions/runs/36558651274>.

| Final artifact | SHA-256 |
| --- | --- |
| `cocs-native-linux.tar.gz` | `425f76d483d89db3b73ac2cbba77b6ac004117581b7a896830ec1bae5a36786a` |
| `cocs-native-windows.zip` | `18ce3faba3b21afcba4f21b71141448df7a9adb44c9fbb19479442941e0d67e3` |

Extracted Linux acceptance passed **31 launcher/runtime cases** and **six Horde
product captures**, using an unrelated working directory and a Node-only PATH,
without an editor, Git or npm. Both final manifest validations passed and package
bytes stayed unchanged. Original compact screenshots showed joining rather than
the live HUD, so a focused source-observed recapture is pending before those
images can support live compact-HUD acceptance.

The final Windows runner passed **17
headless smoke/resource cases**, verified **148 files** against the manifest,
and confirmed owned listener/process cleanup. Actual Nacre DM passed. Evidence:
`native-consolidated/evidence/windows-ci-final/`. Windows:
<https://github.com/mojomast/cocs-godot/actions/runs/36561065502>.

- The first Windows candidate exposed strict DM schema rejection of the shipped
  Nacre recipe's `hordeCaches` and source-supported `megahealth`. The bounded
  adapter repair preserves the canonical recipe/hash and rejects unknown fields.
  Actual native-arena tests passed 37/37; targeted Nacre DM/Horde checks passed
  17/17, with actual DM combat/results/restart and separately scripted Horde
  wave coverage. No authoritative source or generated recipe bytes changed.
- The first hosted player-flow run ended legally in sudden death at 48.07 source
  seconds. The fixture's unconditional 60-second assertion was wrong. The new
  check correlates the accepted Career result with the exact terminal frame and
  validates time, frag-limit or sudden-death conditions. The two-bot product
  preset is unchanged. The focused corrected journey passed.
- Exported acceptance now clicks LATTICE's real Connect/Start controls; these
  routes intentionally wait for the host. Release Home/trace records can be
  stdout-buffered until normal close, so the verifier observes windows and source
  health live and checks the full required trace/readiness content after close.

## Previous candidate verification (superseded artifacts)

At **`79c7b8c74468d840277e44d5ec5f4024880e7a70`**, the full native aggregate
passed **273/273 gates, zero unrun**. Server tests passed **228/228**; lint passed
with **zero errors and 916 warnings**. Canonical logs are in `port/reports/`, with
the exact final report, server/lint logs and SHA-256 manifest retained in
`native-consolidated/evidence/verified-79c7b8c7/`. Earlier failures remain under
`native-consolidated/evidence/attempt-*/` and `diagnostic-1/`.

The passing full run includes the normal-rate objective and controlled-placement
completion gates, three-native crew journey, source weather vectors, all audio
lifecycle fixtures, older-mode regressions and complete player flows. Human
acceptance and physical Windows/audio/control testing remain distinct.

Both platform exports were produced from that exact verified revision, with
clean build checkouts and identical generated-resource inventory hashes.

| Artifact | SHA-256 |
| --- | --- |
| `cocs-native-linux.tar.gz` | `1e8eeac90c89a03e85bf038967fe9e27f3f68e86f3ed20a162100d7bfba7b941` |
| `cocs-native-windows.zip` | `aa7b4e7266731acdde4f04fb10d9bfb62e316ab5dc3bda14d3cfb7f4890ce456` |

Windows static commit-bound artifact validation passed. Extracted Linux startup
acceptance is being completed with actual clicks for the intentionally manual
LATTICE setup. Release resource probes passed: 13 scenes, 38 derived Moth
textures, 101 source Moth planes, ten first-person weapons, 37 score samples,
36 announcer takes/12 phrases and the delivered Moth bed.

Hosted native CI: <https://github.com/mojomast/cocs-godot/actions/runs/36554919515>.
Hosted general CI: <https://github.com/mojomast/cocs-godot/actions/runs/36554919531>.
General CI passed; the first native CI run stopped on the player-flow ending
assertion and its original log is retained in `native-consolidated/evidence/ci-79c7b8c7/`.
The fixture correction and hosted rerun are pending. The actual Windows package
is also exercising the existing Windows runner workflow:
<https://github.com/mojomast/cocs-godot/actions/runs/36557214690>.

The user authorized all three recommended additions and a final consolidated
build on 2026-09-29. This supersedes the earlier **build hold**. Windows and Linux
packages will be generated serially from one reviewed integration revision after
the ongoing player-flow polish and these feature streams are integrated.

## Workstreams

1. **Objective modes:** complete source-backed Uplink, Assault and Holdout loops,
   including setup, supported maps, objective presentation, results and rematch.
2. **Vehicles/combined arms:** inventory every source-supported vehicle and close
   actual native gaps in interactions, cameras, HUDs, damage/weapon feedback and
   multiplayer presentation. Existing coverage is retained rather than duplicated.
3. **Audiovisual presentation:** source-derived music, announcer cues, weather and
   map ambience, including source-event correlation, volume/mute controls and
   bounded presentation resource use.

Read-only discovery runs in parallel, followed by bounded implementation lanes.
Every engine import, rendered test, benchmark, full suite and build uses the
single local heavy-work slot. The active player-flow clarity lane holds that
slot until its focused verification completes.

## Integration contracts

- Gameplay, vehicles, mode scoring, progression and admission remain owned by the
  recorded source authority. Existing purchases/recon privacy and unknown-state
  rules remain intact. New native presentation does not invent source features.
- Shared launch/route/catalog registration and package resource inventories are
  integrated centrally. The original source lock remains strict, with the
  reviewed combined derivative explicitly selected where required.
- Device settings, endpoint-scoped credentials and owned progression/history
  remain separate. Fixture state is isolated and secrets stay out of evidence.
- Failed verification attempts are retained with their exact tested composition.
  New screenshots shared with the user use stable public GitHub release hosting.
- Builds record the reviewed commit, source identity, input/resource hashes and
  archive hashes. Artifact validation resolves recorded Git objects rather than
  ambient checkout files or environment-selected authority.

## Build and acceptance

The existing pinned Godot 4.5.2 editor/export templates and bundled Windows Node
archive are available from the reviewed local toolchain cache. Build state will
use the disk-backed owned package root, avoiding tmpfs capacity pressure.

Acceptance includes extracted Linux startup/resource/ownership checks and static
Windows package validation. Native Windows execution, physical hardware feel,
eight-human play and natural full-wave campaigns remain owner-run evidence;
scripted fixtures will not be labelled as those outcomes.

The package verifier's old default-combat assumption has been updated for the
current Home supervisor: default boot must display the exported Home without
creating an authority, while explicit combat setup retains its independent
readiness/cleanup case. This change will be exercised against the final package.

Discovery findings, implementation commits, serial verification results and final
package paths/hashes will be appended as work completes.

## Objective discovery and implementation assignment

All three IDs are implemented in the source. No map-catalog expansion or source
authority edit is required:

| Mode | Existing supported maps | Source semantics that native presentation must preserve |
| --- | --- | --- |
| `uplink` | Meridian Exchange, Verdant Reliquary, Ember Crucible | Three shared sequential stage captures; most banked captures wins. Objective kind is `koth`, not the mode ID. |
| `holdout` | Meridian Exchange, Verdant Reliquary, Ember Crucible | Own a quorum of two zones continuously for 30 seconds; losing ownership quorum resets progress. Objective kind is `domination`. |
| `assault` | Tidal Citadel, Sunscar Convoy | Attackers breach ordered sectors; defenders win an unbreached timeout. Sector count uses source `fragLimit` (1–9). Source vehicles stay enabled. |

The objective-mode orchestrator owns one zone-family worker (Uplink/Holdout), one
Assault worker, and shared mode launch/route/scoreboard integration. Assault must
consume its source sectors from the snapshot's `zones` field and must not require
a `contested` flag that the source does not publish. Source `over`, `overReason`
and `winner` determine all endings, including timeout and tiebreak cases.

The independent vehicle stream supplies reusable vehicle coverage for Assault;
an infantry-only composition is not complete Assault parity. Shared package and
aggregate registration remain with the parent integration owner.

## Integrated implementation checkpoints

- Player-flow polish: source-driven integrated flow passed 24 checks at
  `2d45b0b4`; compact pending/unknown/confirmed/results flow passed 34 checks at
  `436903a8`. Both successes and the preceding fixture failures are retained in
  `native-player-flow/evidence/`.
- Objective implementation: six reviewed lane commits integrated through
  `27d5ffa7`, including Uplink/Holdout projections, Assault and the 23-route
  generated registry. Follow-up `66559cba` (integrated as `96273b9a`) replaces
  Assault's temporary vehicle composition with the shared bridge and verifies
  normal-rate Room timeout/results/rematch across all eight eligible pairs.
  Controlled-placement completion/results/rematch passed for all three modes,
  with both Assault maps covered. These are not natural-input completion claims.
  Node checks passed 53/53, four Godot fixtures passed, and existing KOTH and
  Domination real-input capture/scoring/rematch regressions passed. Sixteen
  original success/failure reports are retained with hashes beneath
  `native-objective-expansion/evidence/objective-lane/`. Post-audio-merge
  verification remains part of the final aggregate.
- Vehicle implementation: ten lane commits integrated through `bfa71652`.
  The exact source roster is Puma, Hornet, Titan, Scout and Transport; no sixth
  chassis is implied by source aliases. The shared seat bridge covers source
  actor/vehicle occupancy, mounted input, cameras and visible crew. Genuine
  three-native-client crew evidence passed twice after fixes through `a0c1c958`
  (integrated through `4abcae6e`). Both normal-input journeys naturally boarded
  one Puma, drove 27.842 m, fired 84 source gunner volleys and passenger personal
  shots, and witnessed exactly one accepted brake edge. Each run took about
  79 seconds. Five-kind/all-seat and Hornet jump behavior remain separately
  labelled arranged source fixtures. All 18 attempt summaries, including 16
  failures, are indexed in `native-vehicle-expansion/evidence/lane/`; raw logs
  and compressed wire also have a disk-backed mirror recorded there. Source
  bytes, process cleanup and private-state cleanup were verified in both passes.
- Audiovisual lane: initial commit `7da98bad` packages 37 original orchestral Ogg
  samples, all 36 existing announcer takes (12 phrases) and the delivered Moth
  ritual bed. Final fix `87c13766` (integrated as `b8127f4a`, identical native
  bytes) passed the pinned import and all ten audiovisual/weather fixtures plus
  selective legacy settings, combat-audio, Horde and LATTICE regressions. Source
  weather vectors and original asset hashes passed. A private ALSA null sink
  captured 44,100 nonzero native DSP frames (peak 0.2551); two seeded captures had
  distinct pitch plans and PCM zero-crossing rates. Dummy failed the negative
  control. The same-state weather render differed by 18 pixels. These are DSP
  and renderer proofs, not human mix/hardware/Windows acceptance. All 163 retained
  artifacts, including initial silent-capture and shutdown-resource failures,
  are indexed in `native-audiovisual/evidence/lane/manifest.json`.
- Package integration: explicit audio JSON export filters, asset provenance and
  CC0 music notices; external PCK probes for stream types, lengths and loop
  bounds; expanded graphical startup coverage for every new objective map/mode
  pairing. Package generation awaits the fully tested composition.

### Source limits carried into the product

- Ordinary source rooms edge-trigger jump. Hornet Space is an upward pulse,
  not held continuous ascent; native input does not synthesize repeated edges.
- Seat assignment remains source-driven. Passengers retain the source's
  chassis-relative yaw, and Titan's mounted cannon remains a ray weapon.
- Existing announcer recordings do not constitute arbitrary spoken narrative,
  wave numbers or custom vehicle alarms. Source narrative text keeps generic
  objective cues. Music's bounded native arrangement is distinguished from an
  exact port of every browser scheduling detail.
- Cosmetic weather cannot alter authority, movement, damage or gameplay RNG.
  Its precipitation must have one native owner so existing map effects are not
  doubled.

## Final integration queue

1. Objective lane: focused source/native completion, timeout and rematch checks;
   common Assault vehicle composition and Combined Arms launcher contracts.
2. Vehicle lane: all-kind/seat fixtures, separate arranged Room jump-edge oracle,
   and a natural-entry journey with three distinct native processes sharing one
   source hull as driver, gunner and passenger. Raw wire evidence is bounded,
   compressed and retained outside Git with hash manifests; each role has private
   settings and Career roots.
3. Audiovisual lane: parser/runtime checks, source weather vectors, bounded
   lifecycle/long-round tests, same-state weather captures, and actual native DSP
   PCM capture. Virtual output is not human listening or Windows acceptance.
4. Parent: reconcile focused fixes; import one fresh integrated checkout; run the
   full native aggregate, server tests and lint serially; retain reports and
   refresh hosted CI. Build Windows and Linux from the same reviewed revision,
   then verify extracted Linux behavior and both artifact manifests.

At integration `2887962d`, all three implementation streams and their prepared
fixtures are present. Source `game/`, `server/` and `public/` bytes are unchanged
from the accepted pre-expansion `04d940a4` baseline. The native CI time budget is
45 minutes for the expanded serial gate inventory; this is a deadline, not a
claim that unrun gates have passed.

The three focused lanes have now released their slots. Parent integration
`b8127f4a` is running the **271-gate** full native suite in the isolated validation
checkout. No consolidated export has yet been produced at this checkpoint.

### Integrated failures retained before export

The first full run stopped at social-scene cleanup (69/271 gates executed).
The second progressed through social and stopped at identity-Horde cleanup.
The shared vehicle visual node now allocates only when bound to a live scene;
weather generators explicitly release playback on exit. Both formerly failing
fixtures and the shared-shot/independent-audio fixtures passed after that repair.

A diagnostic sweep at `b5abb584` exercised the remaining 196 gates and retained
11 failures under `native-consolidated/evidence/diagnostic-1/`. It is not a full
aggregate pass. Follow-up ownership is bounded: the audio lead repairs older
scene lifetimes and source-map metadata lookup; the vehicle lead investigates
the integrated crew fixture; the UI worker investigates real-click and Home
contracts. Parent `e66a2197` keeps on-foot respawn releases in the infantry
lifecycle while preserving all mounted lease transitions. Final clean aggregate,
server/lint and package acceptance are still required.

The integrated crew failure was traced to a physically queued entry arriving
after previously held movement had already carried the passenger out of range;
source correctly refused it. `723bc8b1` keeps natural input but waits for the
released movement packet's source ACK and stationary pose before E, with bounded
physical reapproach on a miss. Its rerun is pending the serial slot. The lobby
fixture's synthetic click now includes complete pointer/mask coordinates and
fails promptly instead of indexing a missing result (`d85c4701`). Neither
repair changes source admission or seat assignment.
