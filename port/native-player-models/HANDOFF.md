# Player/operator model candidate — orchestrator handoff

Status: RECOVERED, REVERIFIED AND VISUALLY REVIEWED CANDIDATE; GAMEPLAY INTEGRATION ON HOLD.
Update: the user subsequently requested a playable Windows demo. Recovery commit
`72a58c9` is included in the primary branch as `e396106`; package builds can now
explicitly select `--operator-models candidate`, applying the preload only in
staging. The default source renderer and the remaining visual/performance findings
are unchanged. See `../native-windows-package/PLAY.md` for the demo.
The lead inspected all 40 matched PNGs directly, plus the fresh live screenshot and both fresh release-preview images. Close-range form is improved; distant variant/team-stripe readability and rendering cost keep this candidate off the gameplay path. See REVIEW.md for the decision and evidence scope. Full animated-character, full game package and hardware performance acceptance remain open.

Original baseline: 2af744f8f2eef2087d056844dd7f973336215de2
Recovery/review baseline: d3062057cbfe433b8d953f1dc6fd51398b05ba1f
Branch: review/recovered-player-models
Worktree: /tmp/opencode/cocs-player-model-review
Commit: `git log -1 --format=%H -- port/native-player-models/HANDOFF.md`.
Recovered owned paths: godot/player_models/, godot/tests/player_models/, port/native-player-models/. The lead also updates the lane ownership record on this review branch. Shared gameplay/package hooks remain an unapplied patch.

## Recovery provenance

The original `/tmp/opencode/cocs-player-model-improvement` directory was absent. Its surviving Git index yielded 230 staged files, recovered read-only with per-file blob IDs and SHA256 in RECOVERY.json. Original index and binary staged diff are retained at `/tmp/opencode/player-model-recovery/`; the external index/branch were not altered or pruned. The user authorized finalizing this recovered snapshot.

The reported final run `1790052840993851473` and patch SHA256 `2145f1134c26d7e2bff44d1e39232b65af858b90ee3b428b526be34e7b05f262` were unavailable. They are not represented as recovered or verified. The recoverable prior run is `1790052615104436728`, and its staged patch hash was `f6405980a6818819e0e9844a0cbf61e1a82f62fea291a003a67c35957f7ec166`.

The lead regenerated zero-context hooks against the current baseline and fixed verify.py to generate/check that format on every run. Model and test input hashes and canonical geometry match the recoverable prior verification exactly. Fresh results below supersede the missing final run without fabricating its provenance.

## What exists

Original native flat-normal ArrayMesh geometry built from bounded, inspectable, data-only recipes. No Blender dependency, imported asset, networked generator, @tool script, collision or gameplay authority. author_recipes.py deterministically authors recipes.json; builder.gd validates exact schema, finite dimensions/counts/operations/materials and required semantic parts, and caches shared geometry. candidate.gd keeps instance-owned materials, direct semantic mesh children, stable Helmet/Muzzle instances, -Z forward, source-compatible ±0.9m Y bounds and <=0.7m width. Snapshot identity changes select precomputed meshes without rebuilding nodes.

Three authored geometry variants: Claude/Warden (symmetric ceramic/shield intent), Grok/Outrider (narrower helmet/chest and asymmetric shoulder/chest), Meta/Bulwark (broader chest/helmet/shoulders and larger pack). Canonical mesh/transform hashes differ. Recognition at gameplay distance is NOT yet visually established. ChatGPT, Gemini, DeepSeek, Mistral, Kimi and Qwen use the Warden chassis with their existing palettes; unknown identity gets the documented pale fallback. Red/blue shell and one/two visible stripes coexist with identity accents. Static two-hand readiness/grip only; no skeletal animation, walk cycle, recoil or claimed aiming system. Generic compatibility weapon retained, no reserved weapon redesign.

## Real verification results

Fresh numerical/staged evidence: evidence/1790061184437178759/
- Pinned Godot 4.5.2.stable.official.6ce3de25a; semantic export and private editor import passed.
- 112,013 release-safe checks per clean geometry build. These count per-triangle assertions as checks, not independent test cases. Finite arrays/transforms, nondegeneracy, CW/outward normals, bounds, schema negatives, all-nine+unknown IDs, numeric/string teams, material isolation, stable updates, cache reuse and palm/weapon AABB contact passed. AABB contact is not visual grip approval.
- Twice rebuilt authored JSON byte-identically from clean outputs. Two clean engine imports/rebuilds produced identical canonical vertex/normal/transform records. Input hashes are in result.json. No random choice; seed zero is only provenance.
- Existing unmodified entity_visuals.gd passed against the candidate: 72 checks. presentation.gd replay and local_lifecycle.gd also passed against the privately patched candidate, not just the old model.
- `git apply --check --unidiff-zero port/native-player-models/integration.patch` passed. Zero-context generation avoids whitespace-only context lines inside the saved patch; final staged whitespace check is recorded by the recovery review. No aggregate verifier claim.

Fresh live evidence: evidence/live-1790061203072908510/; historical live-1790052536564062185/ retained.
- Unchanged createGameServer defaults (normal-rate simulation), owned dynamic loopback listener, actual Session scene and candidate preload in private staging.
- 1,800 recipient snapshots correlated; 3,430 remote movement transitions and 2,440 yaw transitions. Source position+0.9, source bodyYaw, interpolated rendered position/yaw, identity and stable actor instances checked.
- Ordinary host protocol requested Team Deathmatch, 2 bots, 60 seconds, frag limit 100. Source results at time 60.0166666666645 and a second start are retained. Old round instances freed and actor registry cleared: one verified clean restart. No injected damage/death/poses/results or accelerated simulation.
- live.json.gz preserves all recipient snapshots, rendered poses and start/results transitions; live.json.sha256 hashes the decompressed original. Screenshot uses an explicitly controlled observer camera in the real Meridian map, not a human first-person playthrough. Remote visibility/removal edge cases additionally have inherited synthetic fixtures; do not label those fixtures live deaths/despawns.
- Server/display exit statuses are retained in cleanup.json (both zero). Owned port 43401 was checked closed. Temporary staged projects removed.

Fresh release-resource evidence: evidence/release-1790061295968348521/; historical release-1790052475017876998/ retained.
- Existing tools/godot-package/build.py preset read-only, private copy with JSON inclusion. Pinned local Linux release template; template/binary/PCK hashes retained.
- Exported executable+PCK archived and extracted to a fresh directory; original staged project/cache and pre-extraction package deleted before launch.
- Release executable loaded the candidate recipe/resources and generated 960x640 and 1280x800 images, completion marker present, exit 0.
- This is an editor-free CANDIDATE PREVIEW export, not a complete Node-backed game distribution or public binary. Source main_scene was changed only in private staging. No Blender/source-cache dependency. The lead directly inspected both fresh exported images.

## Renders and measured cost

Recovered matched PNGs and historical raw frame samples: evidence/render-1790052439614620418/. All 40 PNGs now directly reviewed; render/performance measurements were not rerun during recovery.
40 PNGs: baseline/candidate, two resolutions, front at 3/10/25m, side, back, perspective, top, underside, attachment and silhouette. Exact camera vectors are in preview.gd. Camera FOV is 65 degrees vertical; side/back rotate each actor at its own center to avoid lineup occlusion, keeping a shared camera. Solid reference pole is 1.8m; no claim of 0.1m ruler subdivisions. Matched baseline/candidate have the same stage, lights, exposure defaults and camera. Live Meridian observer adds map-lit context separately. No articulated-pose fixture implemented.

METRICS.json is computed from retained raw samples. Per candidate: 46 mesh instances/surfaces, 47 nodes, 2,760 triangles (8.85x old 312), four materials, zero texture bytes. Old model: 26 meshes/surfaces, 27 nodes. Warm CPU construction medians (11 samples): 1/16/32 candidates = 493/7,900/16,070 us versus baseline 113/1,735/3,518 us. The extra geometry is a real cost, not a free quality improvement.

Synthetic population at 1280x800 on llvmpipe Compatibility, 100 frame intervals per case:
- 1 actor: old/candidate median 2.004/2.364 ms; 28/48 total draw calls.
- 16 actors: 3.7015/8.3705 ms; 411/731 calls.
- 32 actors: 6.153/14.865 ms; 819/1459 calls. Candidate p95 16.995 ms.
Counters include the stage/reference/UI. This shared software-rendering host is NOT hardware GPU performance acceptance, a complete game-scene benchmark, or an FPS guarantee. Batching/LOD may be warranted before release; preserved named parts currently favor inspectability over draw-call minimization. No universal frame budget or statistical significance claimed.

## Historical visual review blocker and failure history

Discovery browser vision successfully inspected the existing entities.png fixture and actual gameplay.png. The latter contained no sufficiently clear operator to judge identity. Original candidate/release PNG review attempts subsequently failed: browser_navigate returned HTTP 500 from http://127.0.0.1:9377/tabs; read-only diagnostic GET returned running=true/tabs=[] and an isolated create-tab request returned Internal server error. browser_vision had no session. No service restart or shared-browser takeover attempted. Local evidence HTTP service returned 200, then was stopped. That original inspection blocker is now bypassed by direct image reads; REVIEW.md records the actual findings. Zero geometry/art repair iterations were made during recovery.

Retained failures/superseded attempts:
1. Initial triangle winding emitted inward normals. Numeric outward-normal test failed with exit 1. Fixed triangle emission, not the test. initial-winding-failure.log.gz retained.
2. First staged replay omitted generated catalog data; catalog/decode gate failed. Fixed harness to run locked semantic exporter; inherited tests untouched. evidence/1790051671739892150/ retained.
3. First graphical run completed captures but ALSA initialization emitted ERROR; harness correctly failed despite Godot exit 0. Added explicit Dummy audio, since this is visual-only evidence. render-1790051867713191645/ retained.
4. Initial side lineup could occlude variants; final fixture rotates individual actors. Earlier renders retained. Added explicit silhouette capture. This is fixture repair, not claimed image-based art refinement.
5. First live attempt reached 85-second deadline with default 300-second match. It verified source movement but FAILED round acceptance. live-1790052107396195893/ retained. Harness now submits normal supported 60-second host config; no rule edits.
6. Earlier passing live run retained at live-1790052286734496615/; final run additionally verifies stable nodes and explicit old-instance destruction/round transition receipts.
7. Historical delegation/auth failures remain in PROGRESS.md. No delegated implementation or independent art review is claimed.

## Unapplied integration

integration.patch has two minimal hooks: presentation.gd preload selects candidate.gd; existing package include_filter adds player_models/*.json. Current SHA256 `6158f7795f1d6d6ccd6b8fe275e381aeed1fd218499a204c2a650453e49def4b`. Use `git apply --check --unidiff-zero port/native-player-models/integration.patch`. These hooks pass against review baseline d306205; the patch is applied only in temporary verification staging. Gameplay integration remains on HOLD per REVIEW.md.

## Commands (from this worktree)

export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
python3 -B port/native-player-models/verify.py
python3 -B port/native-player-models/render.py
python3 -B port/native-player-models/live.py
python3 -B port/native-player-models/release.py
"$GODOT_BIN" --path godot res://player_models/preview.tscn

Graphical runners own/reap private Xvfb (-nolisten tcp -nolisten unix), use isolated XDG/HOME, and inherit only PATH/locale/software-renderer settings. Generation/testing do not need network. Live runner accesses only its owned loopback server and uses primary node_modules read-only in staging. Release runner uses pinned installed template, no package download. All temporary staging is removed; raw evidence retained. No background worker should be left running after delivery.

## Required remaining acceptance / human smoke

The lead has opened all matched views at both native sizes. Next work is stronger non-color team and variant readability, plus lower render cost with matched before/after measurements. REVIEW.md records concrete findings. At most three localized art repairs per candidate, preserving failures and rerunning numerical/live/export evidence after geometry changes. Geometry-hash differences alone do not establish recognition.

On a coordinated human graphical display, launch preview. Then have the lead apply the reviewed patch only in private staging, launch ordinary Team Deathmatch via existing tools/godot-dev/launch.mjs, approach and turn around remote actors, inspect their motion/grip/teams, reach results/restart and leave. Check window focus and hardware rendering/audio separately. No animation, human usability, complete Linux game packaging, full aggregate verification or legal redistribution clearance is supplied by this candidate. Final integration/release publication remains with the orchestrator.
