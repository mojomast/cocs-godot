# LATTICE instrument family — Astra lane

## Delivered implementation

`godot/lattice_assets/world_layer.gd` is attached by the three-line seam at the
end of `world_demo.gd::_ready`. It builds six deterministic faceted recipes using
the **same four-ring, octagonal beveled prism mesh builder as the players**.
The runtime assets are authored geometry and palette materials, not paid Moth
outputs. Latest Mothbake recipes/workflow are included; baking is deferred to
the parent's serial resource slot. No screenshot or human visual acceptance is
claimed.

| Family | Silhouette / reading | Mesh instances | Triangles |
| --- | --- | ---: | ---: |
| HQ | Split bastion crown, shoulder vents, three command vanes | 22 | 1,320 |
| Front | Paired arrowhead wings, single central blade | 18 | 1,080 |
| Relay | Four-tine antenna cage around a narrow signal crystal | 22 | 1,320 |
| Economy / siphon | Twin pressure vessels, six exchanger fins, manifold | 22 | 1,320 |
| Depot | Open service rails, six sleepers, four ground inlays | 12 | 720 |
| Operations | Three sealed cartridges with pale latches | 6 added per terminal | 360 added |

All archetypes share dark keel / armor shell / pale trim / narrow identity accent.
No random mesh generation, animation, particles, lights, shadows, collision,
navigation regions, interaction bodies, RPCs, authority changes or resource spend
are introduced. Meshes are reused through the existing geometry cache. Recipes
are a finite code-defined set; received data cannot supply mesh dimensions.

The ground marks are at 0.01–0.083 m; all central instrument geometry is above
3.2 m. This leaves the authored interaction column and infantry sightline clear
without rendering fake cover. These are hovering tactical instruments, not
buildings, vehicle proxies or capture-radius rings. Jump/roof-level visual
occlusion and readability still require human/QA review. Culling ends at 115 m.

### Materials and team language

* **Asterion:** navy graphite `263343`, cool ceramic armor `9caebb`, bone-alloy
  trim `d5d9cb`, pale aqua identity `74d5cf`; roughness .72, armor/trim metallic .28.
* **Monsoon:** deep green graphite `233933`, oxidized green armor `57796b`, aged
  brass trim `c6a976`, soft mineral identity `b7d29b`; roughness .86, metallic .12.
* Identity and contest emission energy is .12, matching the restrained player
  treatment. They do not create scene lights.
* Owner **0** uses player red `f05c58` and **one bar**; owner **1** uses player
  blue `4d9fff` and **two bars**. Explicit null owner uses one white diamond.
  Missing/invalid owner displays none of those marks. Explicit boolean contested
  adds two amber side clamps while retaining the independently reported owner.
* No flashing or inferred takeover, activation, capture percentage, supply flow,
  depot ownership, vehicle availability, wave progress or terminal completion.

### Counts and resource budgets

Both maps have 2 HQ + 2 front + 2 economy + 1 relay + 4 depots: **194 meshes /
11,640 triangles** if every marker were drawn. Operations adds three six-piece
cartridge assemblies: **212 meshes / 12,720 triangles**. State marks and distance
culling reduce actual draws, but the conservative instance counts above are the
budget, not a measured benchmark. Each prism is 60 triangles / 180 unindexed
vertices. Maximum single recipe is 22 parts; test cap is 24. Maximum catalog
acceptance is 16 objectives, 8 depots, 3 Operations sockets. Four structural
materials, neutral/contest/unknown shared materials are cached per map; owner
material is private per instrument. Operations construction currently allocates
then prunes the base recipe once at binding; it is not repeated on snapshots.

## Placement and recipient boundary

The runtime reads `catalog.resolve_map(current_id)`, whose normal catalog path
verifies semantic map identity and hash. It never hardcodes these coordinates.
The exact source-derived fixture is
`godot/tests/lattice/fixtures/flagship_assets.json`; it is authored geometry
evidence, **not a recorded network result**.

| Objective | Asterion x,z | Monsoon x,z |
| --- | --- | --- |
| hq-0 / hq-1 | -104,0 / 104,0 | same |
| front-0 / front-1 | -52,-8 / 52,8 | -52,12 / 52,-12 |
| econ-n / econ-s | 8,-32 / -8,32 | -8,-32 / 8,32 |
| relay-0 | 0,0 | same |

All these authored ground y values are 0. Both maps author depots at
(-104,-56), (104,56), (-64,-56), (64,56), and y=0. Source terminals are at the
relay and both HQs, associated by `nodeId`, exact xyz and Operations mode. Static
depot markings ignore the source's initial `team` field.

Position evidence: `game/destination-lattice-maps.mjs:67–84,104–107`; the terrain
service decks at z=±64 and the lateral wings do not intersect these sockets.
`port/contracts/map-selection.json` corroborates objective x/z (landmark y is
ground+9, not placement y). Source lock remains
`515daf07589150dd3241f4ae1425cc1b093912f5`; lane base is `4c87c2ec`.
Generated catalog files are absent in this clean worktree, so a generated-catalog
runtime comparison remains for serial verification.

Only a matching recipient projection (map, mode, known node id and exact
authored x/z, plus y if supplied) reveals an objective instrument. Unknown
positions are refused, not repaired or guessed. Missing nodes hide on the next
snapshot; empty projection, stale snapshots, lobby/results/errors hide recipient
instruments in the layer's process callback. Static depot inlays remain authored
scenery. No projection objects are mutated. Parent session handlers are connected
before the asset observer, so the observer sees the updated session phase.

## Latest Mothbake and bounded candidate delivery

Pinned official upstream: **93e182557c7c47b75c556477127fb27686fea20d** (2026-09-25),
read-only checkout `/home/mojo/.tmp-on-disk/mothbake-lattice-20260925`.
Read and followed current README, `docs/GODOT_EXPORT.md`, upgrade plan and
`examples/local-first` APIs. No dependency on the old game `scripts/moth-bake.mjs`.

1. `mothbake/manifest.json`: two explicitly **hand-authored local recorded** 5×5
   structure grids; raw-grid + 64×64 low-strength normal bakes. The engine id is
   an offline fixture routing identity, not evidence of a provider request.
   Zero submissions and zero spending are enforced in this manifest.
2. `mothbake/variations.json`: 4 candidates, 64×64, fixed seed 20260925, panel
   density {2,4}, wear {.08,.22}, variation .15, relief .35. Conventional
   baseline plus aligned color/height/OpenGL +Y normal/roughness/wear maps.
3. `mothbake/workflow.mjs`: checks upstream HEAD, resolves a finite plan, prepares
   hash-verified candidates, requires a real approval record, faithfully rebuilds
   approved pixels, uses the new transactional Godot exporter and validates pack
   hashes/references. It intentionally does not invoke Godot or auto-approve art.

The recorded grids are independent authored relief studies; the four local
material variations are procedural metal-family candidates. Neither is passed
off as the other or installed as approved textures in the running scene.
Roughness and wear are synthesis heuristics, not recovered physical properties.
Wear is packaged and not wired to an unrelated material property. Godot's
OpenGL +Y normal convention must remain unchanged. Player-style meshes currently
have no UV/tangent channel, so adopting baked normal maps needs an explicit
triplanar/tangent adapter and visual approval; the palette runtime is complete
without these candidates.

### Serial commands (not executed in this lane)

From this worktree, with a free parent resource slot:

```bash
MOTH=/home/mojo/.tmp-on-disk/mothbake-lattice-20260925
ASSETS=godot/lattice_assets/mothbake
node "$MOTH/bin/mothbake.mjs" run --config "$ASSETS/manifest.json" --out "$ASSETS/recorded-bake"
node "$MOTH/bin/mothbake.mjs" inspect --out "$ASSETS/recorded-bake"
node "$MOTH/bin/mothbake.mjs" rebuild --config "$ASSETS/manifest.json" --out "$ASSETS/recorded-bake"
node "$ASSETS/workflow.mjs" "$MOTH" "$ASSETS/candidates" prepare
node "$MOTH/bin/mothbake.mjs" workbench --out "$ASSETS/candidates"
# Human reviews/approves exact candidate content in the workbench, then:
node "$ASSETS/workflow.mjs" "$MOTH" "$ASSETS/candidates" finalize
```

Keep raw archive manifests/hashes, emitted files and candidate provenance with
the eventual delivery. Recorded/local work may not create remote journal
transitions; `inspect` reports actual local evidence, never fabricated job IDs.
The Godot delivery pointer is `candidates/delivery/godot/current.json`, with
projects under its referenced `versions/` directory. Generic CLI `export` uses
a different pointer/layout and is not the Godot exporter.

The user has now supplied a key outside the repository and authorized generous
credits. **Credential blocker resolved; paid generation not run.** Current
authenticated catalog discovery and an exact validated spending plan are still
required before a live recipe is frozen. A suitable bounded live exploration is
four low-strength Asterion ceramic / Monsoon drainage-relief candidates, retaining
the faceted silhouette and map/team palettes. Actual price, engine version,
backend and useful visual improvement remain unknown until discovery/results.
Parent must schedule discovery/submission serially and retain journal job IDs and
raw hashes. Never log/source credentials into manifests, artifacts or commits.

## Verification

Passed here (static/offline only):

* Mothbake `validate`: 2 recorded jobs, valid.
* `plan`: recorded=2, submissions=0, estimated credits=0, admission allowed;
  fingerprint `d233ab6cc7d760da5df195d307095821b87ac8e73d07586a26d58312ab166571`.
* `run --dry`: no API calls and no writes.
* Local workflow `--dry`: four finite candidates, no generation/writes;
  plan `6232b869ffda5d4f5c68e1534da2f7b7ec020dadc3ab367db633c1fdf941f815`.
* Node syntax check for the workflow; JSON parsing and Git whitespace checks.
* Authored fixture x/y/z compared to source declarations without executing the
  map generator; fixture source pin compared to `port/contracts/source-lock.json`.

Added, **not run**: `godot/tests/lattice/flagship_asset_contract.gd`. It checks
source-shaped placements, finite budgets, no physics/nav/light subtree, unknown
vs neutral ownership, distinct team marks, contest clearing, mismatched position
and map refusal, Operations mode counts and stale-state clearing.

Serial parent command after normal content preparation:

```bash
godot --headless --path godot --script res://tests/lattice/flagship_asset_contract.gd
```

Also pending: GDScript engine parse/import, live recipient integration, both-map
PvP/Operations screenshots, near/far/team/neutral/contest readability, performance
measurement, local bake/rebuild/export execution, authenticated Moth plan/results,
and human/QA acceptance. No builds, broad suites, benchmarks, Godot processes,
imports or renders were launched in this lane.
