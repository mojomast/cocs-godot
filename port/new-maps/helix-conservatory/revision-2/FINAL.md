# Helix revision 2 — final production follow-up

Revision 2 is promoted to the runtime authority/GLB on the existing `e731fd53` runtime base. No feature merge, source pin change, new mode advertisement or original-world asset rewrite. Source candidate hash is unchanged from `4c486a9e`:

`f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`

## Built and inspected

Blender 4.5.14 exported the exact revision-2 recipe. The editable master was reopened and checked: **25 mesh objects**, **22 recipe batches**, **10 materials**, plus three converted labels. Master is `tools/godot-multiplayer/new-maps/helix-conservatory/masters/revision-2/helix-conservatory.blend`. Runtime GLB is `godot/multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb`.

GLB SHA-256: `0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88`.

Master SHA-256: `6431fe4bd9a199ba780f92ba01f8a74185a6408e4c4e9f34a973b76718a91b08`.

Actually inspected overview, archive, filtration, pavilion and central specimen views. Archive is a curved vaulted stack gallery; filtration has asymmetrical tall pressure vessels and stepped roof/pipe silhouettes; pavilion has a glazed barrel canopy and curved low enclosure. The central root/helix specimen defines a landmark and ground crossfire. They are distinct spatial forms, not identical recolored halls. The art remains stylized and faceted; sparse peripheral areas and some distant steel-edge aliasing remain visible. No claim of photorealism or parent final aesthetic approval.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-conservatory-evidence-20261002/`.

Inspected images:

- `revision-2-final/overview.png`
- `revision-2-final/archive-eye.png`
- `revision-2-final/irrigation-eye.png`
- `revision-2-final/pavilion-eye.png`
- `revision-2-final/lightwell-eye.png`
- `revision-2-ctf-03/frame-0800.png` — source-carried flag, carrier lock, actual return walk.
- `revision-2-ctf-03/results.png` — **760×520 / UI 150%**, 1:0, flags at base, round ended.
- `revision-2-domination-01/frame-0200.png` — live compact traversal/status.
- `revision-2-domination-02/results-normal.png` — normal **1280×800 / UI 100%** source result.

The scoped Helix HUD layout wraps the top labels at viewport width; gameplay and objective text are readable at compact scale. The inherited ability description is intentionally in a scroll panel (`PlayerAbilityReadout`); the entire long kit description is not simultaneously visible. Parent's shared experience UX remains outside this map follow-up.

## Changed geometry independently verified

Godot 4.5.2 imported the new GLB with compression/automatic LOD disabled. Native production collider triangle multiset matches the authoritative recipe. **37,056 total / 37,008 unique collision triangles, 7,562 collision shapes**. Visual comparison has zero missing/extra recipe triangles; maximum imported vertex deviation **0.088152mm**. Visual total **138,580 triangles** (137,928 recipe + 652 text), **25 static mesh nodes / surfaces**. New six both-side district body contacts stop at **0.420287–0.421464m**, within 1.31mm of source contact gaps, with matching blocking rays. Portal/glazing rays pass; solid walls/ceiling block. Report: `revision-2/production-validation.json` and evidence `revision-2-final/native-physics.json`.

Shadowed 1440×900 architectural inspection measured **74–113 draw calls** and **459,133–690,258 rendered primitives** including shadow passes. The <100 static-surface target is met (25); shadow-pass total draw calls are explicitly higher. Gameplay runs use shadows off and 0.5 internal 3D scale, leaving UI at full window resolution. These settings are evidence-preset choices, not changes to production geometry.

## Five new hosted native proofs

All run through native keyboard/mouse event parsing → ordinary input sampler → production WebSocket → source simulation → native snapshots/results. Controlled wire opponent; no actor positions, health, scores or objectives were injected. All new reports carry revision-2 hash; no original-generation proof is inherited.

| Mode | Evidence directory | Source finish |
|---|---|---|
| CTF | `revision-2-ctf-03` | capture, 123.667s, 1:0 |
| Deathmatch | `revision-2-deathmatch-02` | five kills, 94.8s |
| Team Deathmatch | `revision-2-teamdeathmatch-01` | five kills, 92.2s |
| Domination | `revision-2-domination-01` | occupancy win, 40.9s |
| KOTH | `revision-2-koth-01` | occupancy win, 100.067s |

An additional Domination run (`revision-2-domination-02`, 39.7s) verifies normal/compact result capture. Arsenal/Juggernaut remain source-only. The previous four-autonomous-bot CTF 0:0 timeout is historical and remains documented: no forced win or new autonomous-completion claim.

Final source tests **15/15**, including twenty routes, source/native-authoring correspondence, new district contact/drape checks and seven scoring-completed source modes. Routing/options checks **16/16**. Frozen `game/`, `server/`, reviewed derivative and old world-art tree have no diff from `e731fd53`. Prior failures remain under `revision-2-ctf-01`, `revision-2-ctf-02`, `revision-2-deathmatch-01`: software-render/input feedback latency caused target orbiting. Bounded harness correction uses crouch input and 2.5m intermediate waypoint arrival tolerances; CTF target tolerance remains 0.65m. No source geometry or simulation was changed to force these outcomes.

## Continuous footage and actual cadence

`revision-2-ctf-continuous.mp4` encodes **every captured rendered gameplay frame** using measured monotonic timestamp intervals in `revision-2-ctf-03/capture-times.json` and `revision-2-ctf.ffconcat`; VFR H.264. This replaces the original one-image-per-second sampled evidence.

CTF: **1,530 frames / 118.548 seconds between first and last capture = 12.898Hz**, median gap **76ms**, p95 **92ms**, maximum **207ms**. Source round time is 123.667s; the capture starts after receipt of the first controllable pose and stops before results. DM/TDM/zone captures average **12.24–12.37Hz**, maximum gaps **196–200ms**. Video encoder FPS is not presented as gameplay FPS. **The desired ≥15fps walkthrough was not reached on this single-thread llvmpipe recording setup.** Actual continuous capture is provided with this limitation; no real-GPU or human-performance certification.

Remaining parent gates: aesthetic acceptance, package closure/manifest/export verification, real-GPU profiling, human competitive balance and optional future Arsenal/Juggernaut native bindings. All current tests remain under `godot/tests/new_maps/helix_conservatory/`, outside the runtime art directory. No package allowlists/verifiers changed. The only shared follow-up is the Helix-scoped compact label layout, isolated in its own commit; existing mode routing remains unchanged.
