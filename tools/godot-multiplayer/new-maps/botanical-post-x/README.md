# Post-X source diagnosis — no heavy grant consumed

Branch `astra/botanical-post-x-source`, based on X artifact commit `171ffddb`, in
an isolated worktree. **No Blender, Godot, import, rendering, server, subagents,
supervisor restart or queued heavy work was used.** Future Foundry Y is another
owner's lane. Existing X/U files and X_HANDOFF are immutable.

Parent's subsequent independent review approves **Helix and Parallax qualified
staging** and the Vesper parapet repair, while withholding Vesper for the 184
contacts. This source follow-up preserves those decisions. It does not upgrade
Vesper or claim new native basis proof for Parallax.

## Recommendation

**Run the prepared native movement journeys before changing Vesper geometry.**
The authoritative production controller already traverses both complete stair
runs, across five lanes, in both directions at walk and sprint. The X test was
a static finite capsule-placement test, not that controller's movement rule.
All 184 overlaps are real and are reproduced analytically; none is a 5mm seam
or floating-point excuse. Keep the X static gate failed and append future
dynamic results separately. No contact allowlist, lifted route point, radius
shrink, global movement change or speculative urban-v4 is justified by the
current source evidence.

If native CharacterBody journeys fail, retain those responses and propose a
reviewed urban-v4 with genuinely matching collision/render geometry. A naive
continuous civic ramp would change old nav support: at nav490 a 12→24 linear
grade gives Y13.772727… instead of the fixed Y13.8. It cannot be slipped in as
an identity-preserving collider-only change. No urban-v4/hash/bindings were
emitted here; all existing authority, route, spawn/objective heights are intact.

## Vesper: exact root cause and contact delta

`contacts-evidence.json` reconstructs all **368** accepted/candidate records at
the same 184 failed positions from the SHA-pinned X native diagnostic. Every
reported contact is reproduced by finite segment/triangle distance against its
exact source collider. `WorldMap.build` naming/count rules identify the accepted
wall bodies, not guesses based on collider names.

- **170 civic contacts** occur in both worlds (80 tread contacts in each of the
  accepted/candidate route fixtures, plus five nav contacts in each).
- **14 candidate roof-step contacts** occur at the new 2/14m treads.
- At **13** of those roof positions accepted has no contact. These are
  `candidate-route:roof-access-ramp:2:{4,7,11,14,18,21,25,28,31,38,42,45}` and
  `candidate-route:roof-access-ramp:3:1`.
- The remaining `candidate-route:roof-access-ramp:2:35`, foot
  `[18,22.5714285714286,56.25]`, contacts candidate `roof-ramp-step-4` but accepted
  **OverheadSide2104/2105**: `central-row-16-45-1602/1603`, two wall triangles at
  Z56 spanning X8..24, Y14.7..37.3. Thus accepted **171** versus candidate **184**
  means 13 additional *positions*, not 13 copies of the same collision geometry.

Concrete counterexample: nav490 foot `[32,13.8,30.9090909091]` lies before
`civic-stair-12`, whose tread is X30..34, Z31..31.5, Y13.95. The X .41m/1.7m
capsule at foot+5cm intersects its leading edge by **0.0869451087m**. The actual
game-envelope .42m/1.8m capsule intersects by **0.0873373138m**. This is substantial
lower-cap/tread overlap; increasing precision tolerance cannot fix it.

### Production movement facts, not an invented step algorithm

- `game/data.mjs:61`: `RULES.dt=1/60`, radius **.42**, height **1.8**, gravity26.
- `game/core.mjs:175`: standing eye **1.45**, base height1.8, terminal multiplier
  **2.2**; sprint/crouch/slide behavior is unchanged.
- `core.mjs:108–129`: highest-floor query plus lower-layer selection for real
  support under overhead surfaces.
- `core.mjs:329–344`: horizontal/vertical subdivisions use .18m bound; a grounded,
  nonascending actor snaps to terrain when `abs(f-y)<.25`; horizontal admission
  requires `f-y<.3`. Gravity/floor landing follows each subdivision.
- `obstructed` uses blocks and terrain wall segments. **It is not a complete
  rounded-capsule sweep against horizontal terrain triangles.** Consequently the
  lower hemisphere can overlap the next tread in X's static query while the
  actual authoritative step rule moves the feet onto that tread at the next
  centre crossing. We execute this exact production function, not an emulation.
- Native multiplayer sessions (`multiplayer_worlds/demo.gd` → `world/session.gd`)
  send input to the authoritative server and consume positions. They do not use
  the exploration CharacterBody as the combat movement owner.
- `godot/exploration/walker.gd` is explicitly exploration-only: radius **.35**,
  height1.8, camera1.6, speed6/sprint10, gravity20, floor snap.3, safe margin.02,
  maximum floor angle46°. Its `step()` calls `move_and_slide()` without explicit
  stair lift. It must be tested natively; source JS success does not prove it.

### Deterministic production execution

`movement.mjs` imports and runs the unchanged `moveActor`, actual floor query,
block/wall collision and terrain BVH. The source identities are pinned.

- Civic run: X **30.5,31.25,32,32.75,33.5**, Z24↔66, full 80 steps and landings.
- Roof run: X **16.5,17.25,18,18.75,19.5**, Z51↔70, all 14 steps and landings.
- Walk8 and sprint11, both directions, 60Hz. No resets, jumps, position lifts or
  endpoint nudges are inserted between frames.
- **80 trials / 27,930 consecutive frames**. All **60 required** accepted-civic,
  candidate-civic and candidate-roof trials pass: **13,530 frames**, zero stalled
  frames, grounded at every response, exact centre support within 1e−7m, no
  wall/block obstruction, no upper-body headroom-ray hits. Max step changes are
  .15m civic / .142857…m roof, both below the actual strict .25 snap rule.
- The other 20 are negative accepted-roof comparisons: all fail to reach the
  candidate-only roof goal. These do not redefine accepted routes or mutate its
  terrain. A separately injected real wall also stops the production mover.
- Upper headroom rays use centre and four .42m footprint corners, starting above
  the explicit .25m step band to height1.8. This is **not** a claim that the full
  lower capsule is statically clear; the contact fixture proves the opposite.

`movement-evidence.json` retains every response. All radii, eye offsets and rules
are labelled. Existing 2.2-terminal, slide, sprint, crouch and jump tests pass.

## Parallax: localized UV basis qualification

`parallax_tangent.py` reads only the explicitly selected, SHA-pinned X GLB. Pure
corner-angle/basis math follows approved R7 `10d9938f` semantics, factored here
without importing or modifying R7 files or copying Foundry artifact pins.

`parallax-tangent-evidence-v2.json` confirms:

- Mesh `art.accepted-craft.saltstone.001`, primitive0, tangent accessor48,
  indexed local triangle **11823**, vertices **24049/24050/24051**.
- Area **.09058172586082947**, UV determinant **−.04529086293041473**; nondegenerate.
- Normal **[0,1,0]** at all three corners; actual exported UV derivatives
  **dP/du=[2,0,0]**, **dP/dv=[0,0,2]**.
- `cross(N,+X)=[0,0,−1]`, so the glTF derivative-consistent tangent is
  **[1,0,0,−1]**, not a copied neighbor **[1,0,0,+1]**.
- Normal texture uses TEXCOORD_0, scale .4000000059604645, no UV transform;
  node `kit.authority.saltstone.00` has identity transform. No hidden channel,
  mirrored node or normal-texture UV transform explains the sign difference.
- Each of these three vertices is indexed **only by this one triangle**. The
  two nonzero neighbors have correct +X direction but derivative-inconsistent
  +1 handedness. Fixing only the zero while leaving the other two +1 would leave
  conflicting handedness within this local face.

**Proposed bounded repair:** review a new `parallax-tangent-local-v1` visual
successor with three entries derived as [1,0,0,−1] (the zero plus those two local
neighbors). The in-memory plan changes **five bytes within 48 permitted tangent
bytes**; all other binary bytes, images/materials, indices, positions, normals
and UVs remain identical. No other primitive is rewritten, no vertex is split,
and **no repaired GLB/master was written**. Artifact hash remains null. This
three-corner proposal needs review; it is not an applied change or a claim that
every tangent in the original export follows the UV derivative.

Parent's limited stage approval is based on localized nondegenerate geometry
and valid neighbor directions, not merely inheritance. Godot's
`meshes/ensure_tangents=true`, tangent array presence, texture pixels and Binder
restoration do **not** establish that it repaired a supplied zero vector.
`tangent_readback.gd` is prepared to record the actual imported incident corners,
normal-map material fields and transforms. Native BINORMAL convention and any
fallback must be checked from that readback and, if required, a bounded normal
map basis visualization. No engine parse or native proof has been performed here.

## Reproducible source checks

```sh
node --test tools/godot-multiplayer/new-maps/botanical-post-x/movement.test.mjs game/arena-movement.test.mjs
python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-post-x -p 'test_*.py'
```

Expected: **12 Node tests** (2 corrective + 10 movement) and **8 Python tests**.
The Python fixture test creates/removes only its unique source-only scratch
namespace. No artifacts or engine parsing are involved.

Archived evidence generation is explicit and fail-closed: set
`COCS_BOTANICAL_X_FIXTURE_ROOT` to the **frozen repository root**, not the map
folder. Exact SHA256 is checked before parsing; no search/download/fallback.
`diagnose_contacts.py`, `parallax_tangent.py` and evidence outputs are write-once.
Their committed portable fixtures let ordinary tests run without X archives.

`verify_frozen.py OUTPUT.json` additionally requires explicit
`COCS_BOTANICAL_U_FIXTURE_ROOT` and verifies pinned inventories before all files.
`frozen-integrity.json`: **all 600 X and all 264 U files match**. Selectively apply
only these post-X source commits; do not merge X/U artifact ancestry.

## Future commands — NOT executed or queued

After a **new explicit grant to this lane**, with an owned bounded supervisor,
nonwaiting shared lock, LP_NUM_THREADS=1 / OMP_NUM_THREADS=1 and Godot4.5.2:

```sh
BRIDGE=tools/godot-multiplayer/new-maps/botanical-post-x
ATTEMPT=vesper-controller-01
python3 -B "$BRIDGE/prepare_native.py" "$ATTEMPT"
# Above is source-only setup. It prints six bounded command specifications.
# OWNED_RUNNER must belong to the new grant. Never restart X or use Y's slot.
python3 -B "$OWNED_RUNNER" run 900 "$GODOT" --headless --single-threaded-scene --path godot --editor --import --quit
for CASE in accepted-civic-r035 accepted-civic-r042 candidate-civic-r035 candidate-civic-r042 candidate-roof-r035 candidate-roof-r042
do
  python3 -B "$OWNED_RUNNER" run 180 "$GODOT" --headless --path godot \
    --script "res://tests/new_maps/botanical_post_x/$ATTEMPT/controller_journey.gd" -- \
    --fixture="res://tests/new_maps/botanical_post_x/$ATTEMPT/" --case="$CASE" || break
done
```

Six separate groups × ten trials = **60 native journeys**, each bounded at180s
with an internal170s timer. .35 uses the unmodified exploration capsule; .42 is
explicitly a test-only authoritative-size envelope on that same controller.
Only initial placement uses 5cm separation; subsequent movement is exclusively
`Walker.step`, with no manual stair lift. Per-frame positions, velocities,
floor support, collision normals and reset counts are recorded. Arrival requires
the real landing, grounded, within the controller's .02 safe margin + .001m;
no one-tread vertical forgiveness. Failed groups return nonzero and retain their
receipts. Retries require a new namespace.

For tangent readback, under that future grant stage an exact-hash **reference
copy**, not a claimed successor, of X Parallax into a fresh
`godot/tests/new_maps/botanical_post_x/ATTEMPT/parallax-reference.glb`. Import it
with compression disabled and UID retained using the reviewed policy; then:

```sh
python3 -B "$OWNED_RUNNER" run 60 "$GODOT" --headless --path godot \
  --script res://tests/new_maps/botanical_post_x/tangent_readback.gd -- \
  --source="res://tests/new_maps/botanical_post_x/$ATTEMPT/parallax-reference.glb" \
  --output="res://tests/new_maps/botanical_post_x/$ATTEMPT/parallax-basis.json"
```

The script pins original X bytes and refuses overwrite. It records imported
arrays; it does not assert a renderer handedness convention or claim a repaired
basis from `ensure_tangents`. Both new GDScript entrypoints are **source-prepared,
not engine-parsed**. Native traversal, new tangent repair/export, renderer basis
readback and any urban-v4 geometry remain future work requiring authorization.
