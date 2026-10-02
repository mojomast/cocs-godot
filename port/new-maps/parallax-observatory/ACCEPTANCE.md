# Parallax Observatory — source and native acceptance

Geometry: `906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554`.
Recipe: `e949e43d5546ec8b0c9024810f1da6229152e370ad640ecf27ecb54c05f2e23d`.

## Source authority

- Deterministic standalone generation; no legacy overhead expansion.
- 123 terrain surfaces, 60 source blocks, five complete nonwalkable ceiling slabs and 3,380 individual source wall/cliff triangles.
- 688/688 source navigation nodes connected; all 21 gameplay targets supported, clear and reachable.
- Six routes walked both directions with zero measured floor-height error. Real upper/lower flag-carrier journeys, flag return and health pickup pass.
- Completed source DM, team DM, CTF, KOTH, uplink and holdout rounds. Source zone/damage fixtures include deliberate placement; they are distinct from the native normal-input evidence below.
- Sustained movement verifies ground, upper and sloped parapets, both block faces, open vault passages and gallery clearance. Original quad-wall regression and its triangulation correction are retained in the evidence root.
- Separate seeded built-in AI observations: a bot captured a CTF flag within 90 seconds; KOTH bots captured and scored. Human seat 0 is passive. Bot movement distances include respawn displacement and are not precise travelled-path measurements. This bounded observation is not a broad balance claim.

## Actual Blender assets

First actual images were rejected locally; the retained iterations document the architecture revision. The master retains 24,619 editable objects, seven export batches and eight cameras. The `.blend` is outside Godot; its fresh-process reopen receipt is in `provenance.json`.

| Measurement | Actual | Limit |
|---|---:|---:|
| GLB triangles | 148,239 | 160,000 |
| GLB bytes | 8,646,208 | 16,000,000 |
| Material batches | 7 | 7 |

Final GLB/master byte hashes are recorded in `provenance.json` and the asset manifest, and checked by `audit-art.mjs`.

Overview and archive, polar-hall, pump-vault and arrival eye views were actually inspected. The revised map has three enclosed instrument interiors, a columned arcade, service gallery, six institute wings, faceted roof lanterns, dishes and armillary rings, source-colliding cliff masonry and readable tier crosslinks. Counts alone are not visual-quality evidence; retained images are the review artifact.

## Native physics and production rounds

Production `map.gd` loads the explicit nested GLB, with seven mesh/surface batches and no duplicate fallback floor rendering. All gameplay colliders come from the source arena: 3,563 shape nodes / 4,686 triangles.

- Exact source/native terrain-wall triangle multisets match.
- 859 route support rays and standing capsules pass.
- Direct GLB barycentric checks cover all 859 exact center points with maximum floor error below 0.8 micrometres. Six temporary native art-ray seam cases use a documented 1 cm X/Z offset; authority center rays pass without offset.
- Both-face capsule contacts stop approximately 0.4200–0.4203 m from ground/upper/ramped parapets and vault walls, matching the 0.42 m radius. Isolated collision layers distinguish target-wall contact from adjacent parapets.
- All five ceilings stop upward capsules; real arch rays and traversable routes remain clear.

Hosted fixtures use real native `Input.parse_input_event` key/mouse events, the unchanged production sampler, WebSocket, source `Match`, native snapshots and HUD. Node reads positions for navigation but injects no actor positions, health, flags, scores or objective state. Opposition is a controlled passive wire peer, moved by ordinary wire input to the duel site for DM/TDM.

| Mode | Source seconds | Terminal condition |
|---|---:|---|
| Deathmatch | 91.68 | Five frags |
| Team deathmatch | 87.07 | Five frags |
| CTF | 95.92 | Upper outbound + lower flag-carry return, capture |
| KOTH | 47.33 | Objective score |
| Uplink | 75.02 | Objective score |
| Holdout | 76.10 | Objective score |

These six modes are the advertised capabilities. The table records the original 640×400 graphical, non-capturing fixtures. They are functional input fixtures, not autonomous native matchmaking or competitive-balance evidence. The later full-viewport visual fixtures use cautious crouched input and have different journey durations; their HUD, source outcomes and actual capture cadence are recorded separately in `VISUAL.md` and `visual-validation.json`.

## Reproduction and evidence

```sh
node tools/godot-multiplayer/new-maps/parallax-observatory/generate.mjs --check
node port/new-maps/parallax-observatory/acceptance.mjs
node port/new-maps/parallax-observatory/wall-contacts.mjs
node port/new-maps/parallax-observatory/audit-art.mjs
node port/new-maps/parallax-observatory/native-journey.mjs ctf
```

Native tests require the exclusive heavy slot, pinned Godot 4.5.2 and `LP_NUM_THREADS=1`. Review uses CPU Cycles in Blender 4.5.14 and llvmpipe for Godot; there is no GPU performance claim.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/`. Failed builds, import crashes and rejected input-driver attempts remain there. Headless pointer capture did not exercise keyboard movement; accepted input fixtures run under Xvfb. The editor import succeeded with `--headless --single-threaded-scene --recovery-mode --import` after earlier editor crashes.

Parent retains package/export closure and extracted platform gates. Original seven map assets/data and frozen source cores were byte-compared unchanged. Shared bindings are delivered separately from owned map assets/tests.
