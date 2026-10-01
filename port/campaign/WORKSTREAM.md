# Four-level biome campaign workstream

## User requirements

- Four connected single-player campaign levels in the visual family of Canopy
  Divide and Basalt Reach, substantially larger than those 96 × 80 m arenas.
- Target 5–10 minutes of first-playthrough gameplay per level.
- A continuous story, authored pacing and varied gameplay objectives.
- Multiple recognizably different robot-style enemy models and combat roles.
- Flash subagents research best practice first; Astra subagents implement.

## Delivery constraints

- Keep established multiplayer and other native modes working. New campaign
  content is explicitly port-owned; original locked authoritative source bytes
  stay unchanged.
- Integration branch `feature/relay-campaign` starts at `5db21753`.
- Isolated Astra worktrees: `campaign/worlds`, `campaign/runtime`,
  `campaign/robots`, `campaign/client`, `campaign/packaging`.
  Commit scoped changes for integration.
- Serialize engine imports, rendering, heavyweight verification and exports.
- Preserve unrelated untracked files and the existing published biome preview.
- Validate real campaign transitions, player death/retry, checkpoint state,
  objectives, encounters and final ending. Scripted timing or route budgets are
  not evidence of observed human 5–10 minute playthroughs.
- Build both platform artifacts from the same pinned revision; publish actual
  export screenshots and record package acceptance honestly.

Flash research completed before the five Astra implementation lanes launched.
See [research](RESEARCH.md) and the [shared implementation contract](CONTRACT.md).
Packaging/route integration ownership is delegated to `campaign/packaging`;
the orchestrator owns integration verification, evidence and final exports.

## Integration preparation

The source semantic export completed on the integration checkout. The first
pinned-editor import completed its asset scan/import work but crashed on editor
shutdown (signal 11). An incremental retry with `LP_NUM_THREADS=1` exited zero.
Both logs are retained under
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/`; this baseline failure
preceded integration of any campaign runtime code.

An independent Astra interface review identified and clarified feet-vs-centre
coordinates, visual-vs-hitbox scaling, base Match respawn/timeout behavior,
NativeClient chapter validation/input-reset behavior, actor-ID model reuse and
mandatory-route versus drawn-polyline distance. These clarifications were sent
to the relevant implementation lanes before integration.

## Integration progress

All five first implementation commits have been integrated. Initial results:

- 58 launcher/package identity tests passed.
- All four chapters passed real owned-authority native smoke: movement, firing,
  input ACKs, first-person/effects, robot instances and matching geometry hash.
- Authority/mission tests and route closure passed.
- Robot, death-presentation, ground-warning, campaign model/client and terrain
  Godot contracts passed. The session fixture initially needed an explicit
  WeakRef type and cleanup of the newly added ground-warning node; corrected.
- The first world pass passed 13 source movement/route tests, Godot support
  queries and twelve renders. Visual review requested a second pass because
  the chapters shared an overly similar terrace-corridor layout.

The second world pass is integrated: four distinct footprints, original biome
surface/foliage assets, a stitched landscape collar, exact chapter handoff
heights, and 14/14 source route tests. The live graphical acceptance fixtures
are integrated too. The orchestrator now owns the heavy verification slot for
final collision/ending/cache checks, native smokes, compact UI review, full
regression verification and exports.

Initial integration logs are retained under the campaign evidence root in
`integration-first/` and `integration-live-first/`; failures are preserved.

## Final integration repair checkpoint

Revised-world native smokes pass on all four chapters. The first final focused
pass caught a blocked Crown guardian placement, fixture assertion issues, and
compact-screen HUD/capture failures. Runtime repair `c03cd249` passes **23/23
Node tests**, including all-four scripted progression, final Continue, actual
hitscan/projectile volumes, cache behavior and guardian placement across five
seeds. See `integration-final-focused/node-authority-repair-2.log`.

Client repair `a64979d5` fixes the actual briefing camera, compact layout,
scrollable comms, modal actions, waypoint placement and boss readout. All four
maps passed both wide/compact profiles: **82 captures, zero failures**. Every
gameplay capture has three robots, one danger ring, visible first person, ACKs
and active control eligibility. Both Crown profiles verify real Continue →
fresh start → ending results. Evidence: `live-captures/run-wBDkBR/` (compact)
and `live-captures/run-kZEpPZ/` (wide). Initial failed graphical evidence remains
in `live-captures/run-tjyEKy/`. The orchestrator now owns the heavy slot.

Parent change `adea4b65` enables camera-driven robot LOD in actual play and adds
three live-camera checks. All **267 robot checks** and the updated session
contracts pass. A compact campaign UI gate is registered in `verify.py`.

After the client releases its slot: generate the axis/meridian GLB probes,
run the full canonical keep-going verifier with explicit source derivative,
repair relevant failures, commit one runtime identity, export both platforms,
verify extracted packages and recorded Git identity, render release-PCK evidence,
and publish a separate Quiet Relay testing prerelease. Existing published tags
and archives retain their prior identities.

## User art feedback and pending integration

The owner reviewed the public
[development screenshot gallery](https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-gallery-2026-09-30)
and requested an Astra revision of the monotonous, repeated jagged terrain.
The worlds lane (`ses_f0bf6227cffewV7OwI2Pg2zL4h`) is revising actual ridge
geometry and skyline composition in its isolated `campaign/worlds` worktree:
broader landforms, varied crests and wall profiles, per-biome geology, selective
outcrops and less uniformly repeated scenery. Routes, encounters, collision
agreement and chapter continuity remain acceptance requirements. New same-camera
comparison renders will be shared publicly when verified.

The canonical run at `51136196` completed **288/291 gates**. Its three failures
were the expanded route-count/menu expectations and the menu's implicit default
changing with display order. Exact expectations are updated; invalid preferences
now explicitly retain Combat as their safe default. All affected focused checks
pass. Full logs and verification-generated files are preserved under
`canonical-51136196/` outside the checkout. Integrated follow-ups:

- `57488031` → `7e643693`: persistent per-map daylight, since AV owns
  audio/particles and does not install the missing live world sky/sun. Includes
  lifecycle/capture regression checks; environment and session headless checks
  now pass. Graphical confirmation will use the forthcoming revised terrain.
- `925e15ea` → `610aaa99`: exact expanded route/menu test expectations;
  all eight focused parser tests pass.

The terrain-variety revision `c6c3a0e1` is integrated as `5c14ab41`: twenty
source terrain tests and Godot physics/render checks pass. Same-camera comparison
images and twenty revised views are retained in `terrain-variety/`; comparisons
and contact sheets are uploaded to the public development gallery.

The integrated `5c14ab41` authority, terrain, environment, session and all four
native smoke runs pass, including revised geometry hashes. Evidence lives in
`integrated-5c14ab41/`. Its graphical run `captures/run-0uYhBT/` failed: the
lighting assertion counts two environments/three suns after first-person setup,
and some software-rendered gameplay frames lose pointer capture/weapon display.
The capture-repair Astra lane (`ses_f0bf53d86ffeAtBriqa8u8lJtq`) now owns the
exclusive heavy slot to diagnose these failures and verify a scoped repair.
Production input/focus safeguards and effective world lighting remain required.

Export waits for final integrated graphical acceptance. The existing screenshot
gallery is explicitly work in progress, with earlier images retained and labelled.

## Additional user request: melee kick response

The owner confirmed the existing kick and requested swoosh/smack impact audio,
fresh-press-only input with a short rapid-tap cooldown, authoritative enemy
knockback and a confirmed-hit shockwave. See [MELEE.md](MELEE.md). Two isolated
Astra lanes own mechanics/input and shared native audio/VFX. Capture repair
continues to own the heavy slot; these lanes are initially edit-only. Export
also waits for this requested upgrade's integrated acceptance.

## Additional user request: operator detail textures

The owner requested armor-panel and circuit-board texture detail on the playable
operator models. Isolated Astra lane `campaign/operator-textures`
(`ses_f0b620f69ffesvd6lTn1bhtHmt`) owns an explicit native material/detail layer
across the nine identities, keeping source GLB provenance and rigging intact.
The intended finish includes panel seams, fasteners, vents and selective recessed
circuit details, with team colors and silhouettes readable at gameplay distance.
Matched before/after captures, identity/team/pose checks and material resource
costs are required before integration. The lane initially edits only while the
capture-repair lane holds the heavy slot. Kick work continues independently.

## Additional user request: distinct robot voice quips

The owner requested a distinctive voice-like sound for each enemy. Isolated
Astra lane `campaign/robot-voices` (`ses_f0b609999ffe9BcN6uRYikiXfY`) owns six
synthetic vocal identities, contextual authoritative-state/event admission,
spatial playback, repetition limits and session cleanup. Short formant/syllabic
quips should distinguish personalities rather than repitching a common beep.
The lane will supply individual audio previews and a labelled audition reel.
It owns new campaign voice modules and minimal campaign session hooks; shared
weapon/kick feedback remains with the melee lane. Heavy tests await slot release.

## Additional user request: splashy animated damage numbers

The owner requested creative animated numeric damage indicators. Isolated Astra
lane `campaign/damage-numbers` (`ses_f0b5b1ff2ffeh76nLiUS96d0SI`) owns shared
native presentation: authoritative outgoing-hit numbers at targets and distinct
incoming player-damage numbers near the HUD. Direction is a brief splash,
squash/stretch pop, slight arc/tumble and fade, with bounded burst aggregation
and heavier treatment for larger real hits. Requirements include no invented
critical hits, duplicate replay or enemy-vs-enemy clutter, readable compact UI,
reduced-motion behavior, lifecycle cleanup and a rendered animation preview.
This lane starts from integrated melee mechanics/feedback; engine work awaits
the capture-repair lane's heavy-slot release.

Operator texture implementation `a04c5c16` is integrated as `bb79136f` and its
runtime gate is registered. It uses cached face-fitted overlay UVs and four shared
authored textures, preserving original GLBs and adding no overlay draw calls.
Import/runtime checks and before/after renders remain pending the heavy slot.

## Additional user request: epic orchestral score

The owner rejected the music they heard and requested an epic orchestral feel.
Isolated Astra lane `campaign/orchestral-score`
(`ses_f0b5a382cffemwXzsQGV35HbnL`) owns a substantive composition/orchestration
revision using the existing sampled strings, brass and orchestral percussion.
The direction is coherent themes, string ostinatos, brass phrases, low strings,
timpani/cymbal builds, quieter exploration and a stronger Warden finale. A
45–90 second audition showing the transitions is required for subjective review;
automated audio/timing tests do not establish musical quality. Heavy rendering
and audio baking remain serialized behind capture repair.

Robot voice implementation `25006b95` is integrated as `e543ab66`, with a
registered runtime gate. Forty-eight baked clips and the six-voice audition reel
pass deterministic generation, peak and uniqueness checks. Engine integration
and subjective listening are still pending.

## Additional user request: Sol scripted events and recurring puppy

The owner explicitly requested Sol subagents for more scripted events, operator
NPCs and a recurring pettable puppy. `STORY_EVENTS.md` defines the additive
authority/client contract. Sol authority lane `ses_f0b551e14ffecYoeyDSA3smVhk`
owns staged chapter content, authoritative interaction and continuity; Sol client
lane `ses_f0b551dceffey79hEa9L61i9Pp` owns friendly operator staging, Patch the
puppy's articulated model/reactions and contextual UI. Both use isolated branches
from `63251774`, initially edit-only while capture repair owns the heavy slot.

Damage-number implementation `8247678c` is integrated as `c474e687`, with its
runtime gate registered. It consumes authoritative damage totals (including
absorption), groups same-target hits in fixed 100 ms windows, and bounds animated
draw slots to sixteen. Parse checks passed; runtime and wide/compact/reduced-motion
visual checks remain pending. Reproduction commands are in `docs/damage-numbers.md`.

Sol story authority `838228cf` + `c50bb373` is integrated as `753b72e3` +
`0be8260e`: sixteen phase/proximity beats, Mara/Ivo continuity and Patch petting
with source visibility and a one-second reaction cooldown. Twelve isolated
lightweight tests passed. Review requested a follow-up to cache supported story
placements across retries and preserve existing navigation-cache tests. Client
`02427e22` remains isolated pending fixes for JSON numeric transport, operator
feet anchoring, actual rig joints, puppy mesh cost and modal/focus UI behavior.

Sol story client `02427e22` + `643d9ab1` is now integrated as `4f46799d` +
`0dc108e9`; its runtime gate is registered. The reviewed issues have code fixes
and probes, but engine checks have not run. No completed visual/petting evidence
is claimed yet.

## Serialized verification queue

The capture-repair lane remains the sole owner of heavy engine work. Once it
returns, integrate its scoped repair and run an editor import before the new
runtime tests: melee mechanics/controls/feedback, operator textures, robot voices,
damage numbers, story authority/client and campaign session contracts. Then
produce the promised audio exports and operator/damage/story graphical previews,
followed by actual-authority petting and all four integrated campaign captures.
The orchestral lane still owes its composition commit and audition artifact.

The new explicitly audited melee derivative is `0326b435`; source verification
has passed in the parent checkout. The broad canonical run at `51136196` predates
all these gameplay/presentation additions. A fresh canonical acceptance pass is
needed on final integrated inputs before committing one export identity and
building/verifying Linux and Windows serially. Earlier failed logs and existing
published releases remain retained.

Story placement-cache follow-up `fee59843` is integrated as `8bd4f0f9`. One
arena-keyed cache covers operator and puppy placement, with terrain-surface,
route and anchor identity invalidation. The terrain support grid now invalidates
with replaced surfaces. All fifteen isolated navigation/story/authority checks
passed, retaining zero repeated triangle reads and no navigation rebuild on retry.

Orchestral source revision `a91a5a8c` is integrated as `e6dabc10`. **This checkout
requires the pending generated stem assets before music playback or export.**
Render with `tools/godot-audiovisual/orchestral_score.py`, validate with
`orchestral_verify.py`, import, then run the score-form/lifetime tests and the
actual-engine audition described in `docs/orchestral-score-20260930.md`. The
parent has instructed the capture-repair lane to finish its current command,
return its scoped fix/results and release the slot; repeating all old-base
captures is superseded by the forthcoming full integrated acceptance pass.

## Music render and trailer / attract-demo request

The heavy slot returned with capture repair `eae68904`, integrated as `8b1bacbc`.
Its old-base eight profile runs/82 PNGs passed; later additions remain unverified.
The parent rendered all four orchestral PCM stems, passed the stem integrity,
headroom and phase verifier, and completed editor import without errors. The
first engine score test exposed a strict inferred-Variant warning in its WeakRef
fixture; an explicit type fixes it. A paced PulseAudio audition and score/lifetime
checks are running serially; the initial failure is retained.

The owner now also requests a cinematic campaign trailer and main-menu attract
demo. Astra `campaign/trailer` (`ses_f0b446962ffeoJrAVel3PjJYIz`) owns storyboard,
actual in-engine capture and music-synced editing/MP4/Theora production. Sol
`campaign/menu-attract` (`ses_f0b44196bffeLTLjawLXO4kDmZ`) owns background menu
playback, focus/settings lifecycle and silent-video integration. The owner
clarified that the demo must play beneath the usable menu, like original COCS:
no fullscreen takeover, idle delay or input consumption. Both lanes received this
correction; the menu cut omits promotional title overlays.
Both initially edit only while music audition holds the heavy slot. The trailer
must feature terrain, combat, operator NPCs, petting Patch, robots and the finale,
with authored text overlays and documented scripted in-engine footage.

Music preview completed: the four stems are committed in `5258591d` with explicit
uncompressed PCM import settings. Score-form and menu rapid-lifetime tests pass.
Actual Godot/PulseAudio 72-second audition passes at 44.1 kHz stereo with no
dropped capture frames. A linearly level-adjusted MP3 (roughly -16 LUFS, dynamics
retained) and raw WAV are published on the development gallery release. Evidence:
`orchestral-score/audition-results-4.json`, `quiet-relay-orchestral-preview.wav.json`
and `mp3-linear-encode.log`. Earlier parse/import/audio-server failures are retained.
Music quality remains subject to the owner's listening feedback.

Trailer tooling `7997aa0b` is integrated as `3622c734`. After focused integration
checks, the trailer lane received the **exclusive heavy slot** and parent head
`19884ca1` to render sample shots, repair actual capture issues and produce the
finished MP4 plus silent menu Theora. Parent engine/build work pauses until that
handoff. The lane owns the final media task, not only the prepared scripts.

Focused integration at `bfb91314` passed Node melee/story/campaign, melee feedback,
damage numbers and settings. Repairs in `19884ca1` fix strict GDScript typing,
floating-point test comparison and explicit robot voice PCM import settings.
Operator textures, story presentation and campaign session then passed; robot
voices passed **238 checks / zero failures** after PCM import. Menu background
contracts exposed six failures; the Sol menu lane is correcting them in isolation
without engine work while the trailer owns the slot. All failures are retained in
`feature-integration-bfb91314/` and `repair-1/`.

Menu follow-up `1e55bfaa` is integrated as `c4e33142`: only the headless mock
media seam bypasses the virtual minimized-window state. Real minimized/unfocused
windows remain paused. The menu runtime contracts must be rerun once the trailer
releases the slot; actual Theora-under-interface acceptance waits for its media.

## Corrected menu requirement: live engine rendering

The owner clarified that the menu demo must be a scripted scene rendered in
Godot, **not a video**; the trailer remains MP4. Both lanes received the override.
The trailer lane retains the exclusive heavy slot for video production and will
export compact verified authority replay data instead of Theora. The Sol menu
lane replaces VideoStream playback with isolated real 3D rendering behind the
usable interface. `ATTRACT_DEMO.md` defines their shared replay contract. Earlier
Theora plans are historical and superseded; no menu video will be installed.

The owner requested operator-detail screenshots immediately. The trailer lane,
which owns the heavy slot, is instructed to finish its current safe command and
prioritize the real operator texture gallery under
`operator-textures/rendered-20260930/`, then return images for parent review and
public upload. Trailer progress is preserved and will resume after that handoff.

Operator gallery completed: **164 original PNGs plus three comparison crops**.
Parent reviewed Claude/Grok before-after and the nine-identity roster; thirteen
selected images are published with the `operator-details-` prefix on the gallery
release. No operator render fixes were needed. Trailer checkpoint `0ba1bfed`
integrated as `f1dc8d91`; all thirteen authority receipts and Patch/fire/terrain
samples passed in that lane. The exclusive slot has returned to the trailer
lane for final MP4 and the live-menu JSON, with Theora explicitly canceled.
The old video-background menu contracts passed after the window-state fix; the
replacement engine-demo component will require its own runtime verification.

Live menu implementation `eb4e5b74` is integrated as `f60137bc`. Static review
identified asynchronous build readiness, descendant processing during pause,
story-operator visibility and camera/event fidelity issues. The Sol lane owns a
follow-up correction and meaningful runtime fixture, still edit-only while the
trailer has the exclusive slot. Live menu rendering is not yet accepted.

Menu hardening `dc86ea29` is integrated as `172a574b`: construction holds the
replay clock, paused worlds stop descendant processing, interrupted builds reset,
and production story rendering includes Mara, Ivo and Patch. Parent review also
renames the readiness flag to avoid Node's `ready` signal and includes the last
frame when consuming replay events. Engine and visible-menu acceptance remain
queued behind the trailer's exclusive render job and packaged replay asset.

Trailer is complete and public: `quiet-relay-trailer.mp4` on the gallery release,
48 seconds, 960×540/24 fps, H.264/stereo AAC, 15,639,711 bytes. Parent reviewed the
all-shot contact sheet before publication. All thirteen captures, MP4 decode and
authority action receipts passed; final decoded audio is -16.03 LUFS / -2.20 dBTP.
Evidence is `/home/mojo/.tmp-on-disk/cocs-trailer-evidence-20260930/`, preserving
earlier framing and AAC-headroom failures. Trailer commits `cd986a29`, `cec6663e`,
`00718672` integrated as `e95ac445`, `8c735cff`, `a3d848eb`.

The live menu replay asset is committed: four clips, eighteen seconds, 216
snapshots, all 230 source events retained exactly once. No menu video exists.
The Sol menu lane now owns the **exclusive heavy slot** to import, repair, run
contracts and capture the actual in-engine scene beneath usable menu controls.
Parent full-verifier/build work waits for that slot to return.

## Owner feedback: operator gestures in the trailer

The owner reports flapping hands and requests proper gestures. The Astra trailer
lane is correcting production story/operator animation and will render a revised
trailer, preserving the first published cut. Its initial work is edit-only while
the Sol menu lane completes its current bounded acceptance and releases the
heavy slot. The correction must use deliberate pose transitions, restrained
joint motion and deterministic animation timing shared by campaign, live menu
and trailer. Revised motion must be reviewed in rendered samples before encoding
and publishing `quiet-relay-trailer-v2.mp4`.

Live menu follow-up `0cad738d` integrated as `280b93c4`. Actual private-viewport
render/lifecycle checks passed **56/56**, menu contracts **970/970**, settings
**50/50**. Parent inspected Mara/Patch menu screenshots in `live-menu-engine/run-5/`:
the real 3D scene is visible behind readable controls. Editor import aborted on
shutdown with a double-free after finishing asset imports; later focused runtime
and graphical checks passed. Preserve and revisit this during full verification.
The visible live-menu fixture is registered in the canonical verifier.

The exclusive heavy slot is now granted to Astra for gesture motion samples and
the revised trailer. Parent will publish the replacement only after inspecting
the corrected motion; the original video is retained as earlier evidence.

Gesture correction completed: `0bed35d4` and `bc4c61ac` integrated as `0264d488`
and `f8d8ab45`. Parent reviewed timed Mara/Ivo motion strips showing relaxed rest,
deliberate greeting and settled arms. Production gesture regression passed 7,615
checks; existing story presentation passed; live-menu gesture spot passed 12/12.
The 48-second `quiet-relay-trailer-v2.mp4` and both gesture GIFs are public on the
gallery release. Four affected shots were recaptured (432 frames), with 720
verified unaffected frames reused; prior master/evidence remain intact. Revised
MP4: 15,661,031 bytes, SHA-256
`287f501c68e6df26d86064d0eedb9c7868fba6050613905ead32e5bf05dbe939`,
-16.03 LUFS / -2.20 dBTP, unchanged audio stream. Evidence is
`/home/mojo/.tmp-on-disk/cocs-trailer-evidence-20260930-r2/`.
The heavy slot has returned to parent for complete integrated verification.

Canonical run at `5d724abd` executed **300/300** gates: **293 passed, seven
failed**. Full before/after reports are archived in `canonical-5d724abd/`.
Three closure failures share a missing reviewed `story.mjs` packaging entry;
parent added that exact adapter and explicit replay/orchestral JSON export paths.
All ten focused closure tests now pass with the selected source derivative.
The protocol failure was solely `-0` versus `0` in an in-memory comparison;
the regression now checks every combat frame through the real JSON transport
boundary (test-only change, runtime/provenance bytes untouched), pending rerun.

The Sol lane owns the exclusive heavy slot to fix actual async terrain teardown
(`_build_terrain` resumed after its node was freed) and investigate two resources
remaining at campaign-environment exit. The Horde accelerated upgrade fixture
also timed out amid stale-input resets; parent will investigate after slot release.
No packaging/release acceptance is claimed while these gates remain unresolved.

Menu lifetime repair `fdaf5b25` is integrated as `4e2d8483`: bounded incremental
terrain construction replaces suspended coroutines. Mid-build scene removal,
player-flow controls and verbose campaign environment checks pass without their
previous errors; two detached environment-fixture nodes are now freed. Menu
contracts pass 970/970 and visible replay/lifecycle passes 56/56 again. Evidence:
`live-menu-lifetime/run-1/` and `run-2/`. The new lifetime gate is registered.
Parent owns the heavy slot and is running the corrected source transport test and
the original Horde upgrade fixture before deciding whether further fixes are needed.

Focused source transport suite now passes **88/88** tests. The Horde upgrade
fixture reproduces its timeout: nine input resets occur before the synthetic key
is delivered, and the observer remains in its readiness stage. Both failures are
preserved (`canonical-5d724abd/`, `repair-4e2d8483/`). Astra now owns the exclusive
engine slot for a bounded diagnosis and repair of this final failing gate,
retaining actual engine input, authority acknowledgement and unchanged input TTL.

Horde fixture repair `133a6291` integrated as `d4acfded`. Profiling established
software-render stalls crossing the unchanged 250 ms input TTL; rendering this
fixture's 3D view at half scale while retaining 640×480 UI/input resolves them.
Exact canonical and screenshot-enabled checks passed 23/23 harness and 41/41
native checks, with real parsed KEY_2 input applying Overcharge once and no
post-delivery resets. Source gameplay/protocol bytes and deadlines are unchanged.
Evidence and rejected profiling attempts remain in `horde-upgrade-repair/`.
Parent now owns the heavy slot for a fresh full integrated canonical run.

## Owner-requested Blender enemy upgrade

The owner explicitly requested a **Sol subagent to install Blender and improve
the enemy models**. Lane `campaign/enemy-blender`, session
`ses_f0ac2321effeoS4WFZuHWdCa4t`, works in
`/home/mojo/.tmp-on-disk/cocs-enemy-blender-20260930` from `82168aae`.
It owns user-local official Blender installation, original hard-surface upgrades
for all six robot classes, production asset/LOD integration and matched actual
Godot before/after renders. Existing gameplay hitboxes, rigs/animation behaviors
and authority remain the integration contract.

The lane may install/download and prepare code while parent canonical run
`canonical-82168aae` owns the heavy slot; Blender generation/render and Godot
acceptance wait for explicit handoff. Final downloadable builds follow the new
art integration and acceptance. The current public trailer remains the earlier
enemy-model version until refreshed after review.

Blender lane first pass `710f9267` delivered six editable Blender sources and GLB
assemblies with 447 robot checks reported passing, plus death/tell checks and a
ten-second Warden animation. Parent reviewed the matched gallery and closeups:
silhouettes and layered armor are improved, but Scrapper/Mortar upper-front armor
shows jagged surface intersections. A scoped geometry correction is assigned
before integration/publication. Blender 4.5.14 LTS is installed under
`/home/mojo/.tmp-on-disk/cocs-blender-toolchain/` with upstream checksum recorded.
The lane ran its first heavy work before the required slot grant; any overlapping
canonical timing failures must be treated as potentially contended evidence.
It is now explicitly edit-only until parent releases the slot. Parent has not
merged the new models into the still-running canonical identity.

The superseded `canonical-82168aae` run was deliberately stopped at **225/301**
gates to prioritize the requested model revision. Its complete partial reports
and interruption reason are archived; 76 gates were unrun. The two observed
failures (`native-live`, `native-lifecycle`) are fixed-port collisions on 4332,
not animation failures. Canonical verification now explicitly selects ephemeral
ports rather than inheriting a shell's fixed port. The unrelated listener is left
alone. Sol has the exclusive heavy slot to regenerate the corrected turntables
and Mortar muzzle and verify matching renders before the art is integrated.

Blender enemy models are integrated: `710f9267` → `94ce7c7d`, then corrected
geometry `7cff4ec5` → `cce419a1`. Final diagnosis was the dark chassis frame
breaking through beveled shoulders; the fix recesses it, moves vents onto exposed
side armor and corrects turret-cylinder orientation. Parent inspected corrected
Scrapper/Mortar closeups. All six GLBs and editable `.blend` sources are committed.
Lane acceptance: 447/447 robot checks, death and telegraph checks; all three LODs
reviewed for affected models. Warden tops out at 5,564 triangles / sixteen draws.

Nine public assets with prefix `robot-blender-` are on the development gallery:
matched comparison, lineup, six closeups and the ten-second Warden animation.
Original/first-pass/diagnostic renders remain preserved. Parent owns the heavy
slot for import and final integrated acceptance with the corrected assets.

## Parallel Sol Blender world fidelity work

The owner expanded the task to **parallel Sol subagents** using Blender for
single-player map, structure and asset fidelity. The older canonical run at
`78f770c0` is intentionally interrupted after **93/301 gates, zero failures**;
208 gates are unrun. Its reports and interruption reason are preserved in
`canonical-78f770c0/`. Final verification follows the new world art integration.

- Architecture: `campaign/blender-structures`, session
  `ses_f0aa034f5ffei0zMTa7jQeNF1F`, worktree
  `/home/mojo/.tmp-on-disk/cocs-blender-structures-20260930`. Owns original
  Blender modular structures, `structure_art.gd`, structural GLBs/source assets,
  tests, and its single integration hook in `campaign/terrain.gd`.
- Biome/environment: `campaign/blender-environment`, session
  `ses_f0aa034d2ffeiVza812xj2A21Z`, worktree
  `/home/mojo/.tmp-on-disk/cocs-blender-environment-20260930`. Owns natural props,
  campaign-local surface detail, `environment_art.gd`, GLBs/source assets and
  tests. Parent adds its terrain hook after merge to avoid concurrent file edits.

Both lanes target all four chapters with matched player-height/vista evidence,
editable Blender sources, game-ready instanced/LOD assets and route-safe staging.
Authoritative terrain, collision, navigation, objectives and character animation
contracts stay intact. Blender export may run in parallel at **one thread/process
per lane**; architecture has the first exclusive Godot import/render slot.
Environment waits for explicit Godot handoff. Parent starts no competing heavy
verification/builds. The current public trailer and galleries predate this work.

The owner added a **third Sol lane for better, more unique weapons**:
`campaign/blender-weapons`, session `ses_f0a9d2847ffe27Qc82NglxKMXL`, worktree
`/home/mojo/.tmp-on-disk/cocs-blender-weapons-20260930` from `78f770c0`.
It owns original Blender weapon art for the complete player arsenal, first-person
and world presentation, preserving IDs, gameplay, muzzle/ADS/grip/reload anchors,
finishes and source-export provenance. It must provide actual rendered normal/
ADS comparisons and animation checks with editable source models.

Weapon work begins with inspection/design/code while the first two lanes hold
the two single-thread Blender export slots. Parent grants weapon generation when
one is released. Godot rendering remains serialized: architecture first,
environment next, then weapons, unless explicitly reassigned. All three agents
work concurrently in isolated worktrees; no parent heavy verifier/build runs.

Environment lane delivered edit/export checkpoint `41817d5a`: fifteen editable
Blender sources and compact GLBs, a four-biome decorator and campaign ground
shader. Import, runtime acceptance and actual before/after renders are pending
its Godot slot. Parent static review requests full prop-footprint/flank clearance,
safe replacement only after valid mesh loading, horizon preservation and actual
material-surface draw counts. The checkpoint remains unmerged until verification.
Its Blender export slot is released and explicitly granted to the weapon lane;
architecture retains the current Godot slot, environment is next.

Architecture first pass `16985275` supplies eight fitted two-LOD Blender kits,
136 replaced block visuals and reported passing structure/terrain checks.
Parent reviewed player-height captures and requested stronger visible separation
between kit families: the initial shared vented facade repeats too uniformly,
especially on stacked tall blocks, and roof-specific details are partly hidden
under common caps. The lane is refining continuous base/body/top forms and
distinct pump/abutment/refinery/receiver silhouettes before acceptance.

Environment now has the explicit exclusive Godot slot for import, tests and
four-biome rendering. Weapon generation continues on one Blender slot; architecture
may regenerate the refinement on the second single-thread Blender slot but awaits
Godot permission. Parent keeps `16985275` unmerged pending that visual refinement.

Architecture refinement export `09017079` is ready: distinct family forms and
base/shaft/top profiles, forty bounded GLBs with editable sources. This is an
export checkpoint, not rendered acceptance. Parent requested a static coverage
check so every runtime-selected profile resolves to a GLB (relay/outpost currently
have top-only exports) and updated tests for the new naming/budgets. Environment
still owns Godot; weapon rendering is next, with structural-refinement checks
afterward unless weapon generation is not ready when the slot becomes free.

Environment acceptance completed and merged with its tested first-pass architecture
dependency: `16985275` → `60179f97`; environment `41817d5a`, `d990a65a`,
`a382fb03`, `c1e497e4` → `32ae99a9`, `67076f90`, `6b1c3f50`, `8e3e6e87`.
All-four-map environment, terrain and structure checks passed in that lane;
parent reviewed the combined comparison/detail sheets. Collision/route heights
are unchanged, with safe whole-batch replacement, footprint screening, imported
materials and root placement correction. Structure refinement `09017079` plus
profile coverage `aa81b235` remain queued for rendered acceptance before merge.
Both world-art contracts are registered in the canonical verifier.

Weapon lane now has the exclusive Godot import/render slot. Environment has
released it; architecture refinement waits for weapons to finish. Parent avoids
competing engine/build work. Combined final galleries and trailer refresh follow
the accepted structure and weapon revisions rather than publishing intermediate
architecture as the finished result.

Weapon first pass `c80487fb` contains twenty GLBs and editable first/world masters
for ten classes, preserving canonical exports through an explicit native art layer.
Lane checks passed (910 ADS, 482 handling, source/grip/finish/reticle contracts).
Parent reviewed normal/ADS/world captures and found visually detached rear sight
posts on the Pulse Rifle plus a largely blank camera-facing receiver. A scoped
mount/detail refinement is requested before accepting and publishing the assets;
rear-facing breech treatments must read as closures rather than extra muzzles.
The weapon lane may regenerate Blender assets but waits for another Godot grant.

Architecture now has the exclusive Godot slot for its distinct-family refinement,
including combined environment artwork and collision/terrain checks. Weapon first
pass remains unmerged pending corrected rendered review.

Weapon fidelity follow-up `5fbfd805` is exported on top of `c80487fb`: physical
sight/optic mounts, visible Pulse action detail and closed Scattergun/Grenade rear
breeches. Static geometry/source-hash audit passes; updated Godot renders and
ADS/framing/handling checks await the slot after architecture. The prior weapon
screenshots explicitly predate this correction. Blender export slot is released.

Refined architecture runtime checkpoint `1423f3cf` passes structure/environment/
terrain checks and supplies eight closeups. Parent review confirms distinct family
faces, but found visible segment gaps in refinery towers (the 0.97-height beveled
cores leave a gap between profiles) and a pump foundation above sloping ground.
A final bounded correction must bridge profile cores continuously and ground the
lowest foundation across the footprint while staying inside original colliders.
No further art direction expansion is requested; these are physical assembly fixes.

Weapons now owns the exclusive Godot slot for the `5fbfd805` sight/action/breech
revision and fresh normal/ADS/world renders. Architecture may export its bounded
fix with one Blender thread, but waits for the next Godot grant. Final structure
merge/publication waits for corrected grounding and continuity captures.

Weapon revision-2 completed and reviewed: `c80487fb` → `5fbfd805` → `72657eec`
integrated as `be5387a4` → `9146f920` → `5c436cf6`. Parent inspected the corrected
Pulse sight mount/action and all-ten first-person/world sheets, and reran the GLB
source/budget/distinctness audit successfully. Final lane framing passes at two
resolutions, ADS 910 and handling 482; art/finish/grip/source contracts pass.
Seven `weapon-blender-*` gallery images/clips are published on the existing
development gallery, with updated notes. Canonical verifier now includes the
native art override and static source/GLB audit. Final integrated verification
remains pending; these are scripted gallery/animation captures.

Architecture has the exclusive Godot slot for final `e418e343` grounding/core
continuity acceptance and fresh `final-grounded/` captures. Weapons released the
slot; parent is performing integration/docs/media work only until it returns.

Final architectural assembly accepted at `7e7096a7` (including `e418e343`) and
merged as `fae19d27`. Structure/environment/terrain checks pass all four maps;
parent reviewed fresh pump grounding, refinery support continuity and Crown
receiver/route captures. Forty GLBs retain collider bounds; foundations cover nine
footprint samples. Nine `world-blender-final-*` screenshots are published on the
development gallery. Full evidence is in `structures/final-grounded/`, preserving
every earlier iteration. All three Sol art lanes have completed and released
their engine/export slots. Parent resumes serialized integrated verification,
trailer refresh and final package work with all reviewed art now integrated.

## Owner-requested landmark polish — 2026-10-01

After viewing Rootfall, the owner identified the railway-track-looking fallen
relay and requested a Sol agent to tighten it up and address other noticed issues.
New lane `campaign/world-prop-polish`, session `ses_f0a55fad0ffeXJTmYVe55ZQBTq`,
works at `/home/mojo/.tmp-on-disk/cocs-world-polish-20261001` from `e2818781`.
It will replace the old procedural ladder-like mast with recognizable Blender
communications wreckage and audit the four maps for concrete prop readability,
grounding, support and intersection defects, including the Crown receiver bowl.
Authoritative collision, routes, terrain and source provenance stay intact.

Canonical verification of `e2818781` is already running, with evidence at
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/canonical-e2818781/`.
It retains the exclusive heavy slot. The new lane begins inspection/design/code
and waits for explicit Blender/Godot permission after that run completes. Its
new before/after evidence belongs in
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20261001/world-prop-polish/`.
The current aggregate covers the accepted pre-polish art, not the future revision.

Canonical `e2818781` completed all **305 gates: 289 passed, 16 failed**. Full
before/after reports and generated combat fixtures are externally archived; parent
restored only tracked verifier outputs afterward. Fourteen failures are renderer
error cases; sampled traces consistently show a null-material error during
`operator_visual.gd:set_weapon()` freeing the prior world weapon. Grips,
presentation and live-mode traces agree; career wrappers also reject engine errors.
The native Blender art test passes but does not cover the failing lifetime pattern
adequately. Investigate per-instance material disposal rather than suppress errors.
Two independent failures remain: compact campaign capture pixel matching (the
visible weapon is present, but matched/opaque=1232/1564; long subtitle leaves only
four unoccluded samples), and Horde's graphical input fixture (post-delivery
stale-input resets despite the applied choice). Preserve input TTL and rendering
assertion intent when fixing those tests; do not simply lower acceptance thresholds.

The landmark polish Sol now has explicit permission for Blender exports and the
exclusive Godot slot. Parent audits/fixes unrelated code while engine reruns wait
for that lane to release the slot. Final aggregate will include the polish and
verified lifetime/capture/fixture corrections.

Landmark polish `5b9eb18e` is reviewed and integrated as `65327249`: Rootfall's
Blender triangular mast wreck rests on terrain and its relay saddle, with sampled
flank clearance 2.65 m; Crown's open receiver bears on the existing buttresses
and clears the fin sector. All four lane terrain/environment/structure checks,
new landmark acceptance and twenty source-route tests pass. Six `landmark-*`
screenshots are published in the development gallery. No active art lane remains.

The owner explicitly prioritized a playable Windows/Linux test build immediately
after this polish. Trailer refresh is deferred until those downloads are available.
Parent reproduced the world-weapon material teardown failure, then made only
finish-tinted roles instance-private; immutable hardware retains cached imported
materials. The previously failing 450-case grip test now passes without engine
errors. The affected-gate rerun is in progress with evidence under
`cocs-campaign-evidence-20261001/verification-repairs/`. Compact capture repair
adds subpixel-aware comparison and supplemental HUD-free composition evidence
when the deliberately long subtitle fully occludes the narrow weapon; full-UI
screenshots and the color/coverage assertions remain. Engine validation is pending.

Focused repair validation is complete: all fourteen material-error gates pass
after rerunning the two career journeys with fresh owned evidence directories;
Horde's real KEY_2/ACK/no-post-delivery-reset check also passes without changes to
the input TTL or fixture. The expanded art contract passes switching, teardown
and independent actor finish slots. The compact capture now passes using the
same late-frame click path for supplemental proof, retaining freshness/epoch
safety. Its first failed supplemental frame is preserved; image readback had
crossed the TTL before the proof frame. Final passing evidence:
`verification-repairs/compact-final/run-eIVrrO/` (2026-10-01 evidence root).

Parent is proceeding with a fresh complete canonical run, then serialized Linux
and Windows exports and extracted-package checks. Final source/art identity must
remain fixed across those steps; report outputs are archived/restored separately.

## Playtest exports and next expansion

Final identity `614e11ad` completed **306 canonical gates, 305 passed**. The only
remaining failure is the intermittent llvmpipe Horde upgrade post-delivery input
timeout; selection was accepted and the prior focused rerun passed. All campaign
gates pass. To deliver the requested testing build, that limitation is explicitly
recorded rather than representing the aggregate as all-green.

Both Linux/Windows exports succeeded from that exact identity. Extracted manifests
and file hashes pass; generated resource hash matches across platforms. Linux's
23 native launch/cleanup cases and all eight release-PCK campaign map/profile
captures pass. Evidence is in
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20261001/exports-614e11ad/`.
Archives/checksums/manifests/screenshots are uploaded to draft
`quiet-relay-playtest-2026-10-01`; Windows runner `36819034670` is pending.
Final acceptance JSON and publication follow that result. The trailer refresh
remains deferred. Parent reviewed packaged Rootfall gameplay and compact Crown UI.

While these artifacts were building, the owner requested a new expansion:
Blender multiplayer maps for every mode, varied settings and complex playable
geometry including an urban map, plus new robot enemies throughout Horde and a
sprawling scripted survival map. Three parallel Sol lanes start from `614e11ad`
in isolated worktrees, with details and resource ownership recorded at
`/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/WORKSTREAM.md`:

- Urban/shared map integration: `ses_f0a216563ffecU5AKK7LRnpjbG`,
  `expansion/mp-urban`, `/home/mojo/.tmp-on-disk/cocs-mp-urban-20261001`.
- Nonurban worlds: `ses_f0a20dbd6ffessvYoMnKoRaK5B`, `expansion/mp-worlds`,
  `/home/mojo/.tmp-on-disk/cocs-mp-worlds-20261001`.
- Robot Horde: `ses_f0a2032a7ffeXurQGXEp7rPDw6`, `expansion/horde-robots`,
  `/home/mojo/.tmp-on-disk/cocs-horde-robots-20261001`.

Urban now owns the Godot slot and one Blender export slot; worlds owns the
second Blender slot and waits for Godot; Horde continues code/static work until
explicit permission. These changes target a later build, preserving this campaign
playtest identity. Parent must relay the shared map contract once the urban lane
delivers it, and review genuine mode-specific gameplay/collision/network coverage.

## Campaign playtest published

Public prerelease:
https://github.com/mojomast/cocs-godot/releases/tag/quiet-relay-playtest-2026-10-01

- Windows: `cocs-native-windows.zip`, 109,471,360 bytes, SHA-256
  `65e8e7ba1503c289f1e86e56ab6342a9451832034834072b6d09e70d3bfbb45d`.
- Linux: `cocs-native-linux.tar.gz`, 69,312,028 bytes, SHA-256
  `98a760df0e3cb928eeeb98308425d0695fe41e56676a5ffae4e6715aa4f4bc65`.
- Both packages remain exact runtime identity `614e11ad`; later documentation
  commits do not imply rebuilt binaries. Checksums, manifests, acceptance JSON,
  platform smoke reports and four actual release-PCK gameplay fixtures accompany
  the downloads.

Windows run `36819034670` attempt 1 passed fourteen cases (including the first
three chapters) then disconnected during Crown startup. Attempt 2 passed all
23 cases with the unchanged archive. Both results are preserved under the export
evidence root; the initial failure's cause is unconfirmed and disclosed publicly.
Linux passed 23 cases and all eight release-PCK graphical map/profile captures.
Full source suite remains accurately reported as 305/306, with the intermittent
Horde input fixture failure retained. Human campaign timing/balance and real-GPU
performance remain for the requested owner playtest. The parallel multiplayer/
robot-Horde expansion continues separately with the previously assigned slots.
