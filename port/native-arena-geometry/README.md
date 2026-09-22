# Native deathmatch geometry

**Integration status: blocked on the public schema's `nextGen:false` restriction.** The compiler now requests source spatial navigation for Aurora; actual-schema validation correctly refuses to replace its generated asset until the authority owner accepts boolean `nextGen`. See [NAVIGATION-INTEGRATION.md](NAVIGATION-INTEGRATION.md). The retained, schema-valid Aurora asset has route-thinned navigation but still takes 19.511s to construct cold. The spatial candidate takes 1.947s for cold navigation alone; it is not yet a passing native-constructor or live-smoke result. Prism and Cinder are unaffected by this pending navigation switch.

Three separate DM wrappers reuse the original map builders and assets:

| Arena | DM adaptation | Source navigation |
|---|---|---:|
| Prism Foundry | Visible reactor service banks seal the mezzanine underside; turbine and garden inclines connect the upper loop; coolant pod ramps and lower turbine plinths connect the side lanes. | 378 connected nodes |
| Aurora Basin | Continuous ice buttresses support the crown and lookout; opaque safety panels, four supply pods and a solid pressure-ridge core provide cover; shallow snow transitions and an eastern flank connect the lake and outer lanes. | 796 retained / 303 spatial candidate |
| Cinder Array | The bore becomes a sealed sloping basalt causeway; cooling crosslink and transfer chord create multiple circuits; five reactor service covers break long firing lanes. | 369 connected nodes |

Each arena has **six spread spawn positions**, nine valid collectible weapon kinds, ammunition, three health and three armor pickups. Source Pulse remains the infinite-ammo starter, so all ten weapons use their existing source behavior. Pickups are distributed deterministically by farthest-point spacing over verified authored routes. This is a layout distribution, not a claim of competitive balance established by a player study.

## API and authority boundary

See [CONTRACT.md](CONTRACT.md). Generated files are the three envelope JSON assets in `godot/native_arenas/generated/`; the raw Match arena is `envelope.arena`. Hashing and pre-write validation call the delivered `port/native-arenas/schema.mjs` exports directly. No protocol, authority implementation, source gameplay, nine-map registry, original exploration map, or shared session file is changed by this lane.

Wrappers expose idempotent `build()`, `configure_dm()`, `get_arena_id()` and `get_spawn_points()`. The last API returns validated generated XYZ feet coordinates. Authoring seeds use a separate method so a rebuild cannot accidentally reuse stale generated spawn positions. Prism subclasses the existing builder without needing a change to `godot/showcase/demo.gd`.

## Geometry semantics

COCS chooses the highest walkable support at an XZ coordinate. These variants therefore **do not support stacked walk-under/walk-over routes**. Sealed underdeck/buttress/causeway volumes are visible meshes with native collision. Unsupported lower paths are not advertised or included as nav routes. Decorative scenery retains the original builders' collision policy.

The exporter collects actual `CollisionShape3D` records in world space. Boxes and convex hulls are exported as outward faces; concave shapes export their actual triangles. Analytic cylinders are replaced in native physics with the same 64-sided hull used by source export. Native concave backface collision is enabled to match two-sided source rays, including the original ice arches' inward-wound sections. Unsupported shape classes fail the export instead of silently disappearing.

Ray geometry retains the full collider mesh, including scenery outside the playable bounds. Walkable support is clipped to the combat bounds and cut out under blocking solids. Nonwalkable faces remain available to rays and ceiling queries. `blocks` is intentionally empty: elevated or angled volumes are never misrepresented as source ground-to-top AABBs.

Source movement walls use its documented two-point **segment/height-band** format; ray collision uses exact surface triangles. Collider face projections are split into at most 0.6m pieces, with buried seams and joins onto nearby slope support removed. Flat contiguous pieces are merged. These are movement bands, not a claim that the source capsule solver equals Godot's solver at every arbitrary surface point. Source `walkEdge` independently retains its 30cm step and 6.5m connection limits. The tested spawn and route corridor samples agree with native physics; see the scope below.

## Verification

Run from repository root with the pinned Godot 4.5.2 binary:

```sh
node tools/godot-native-arenas/rebuild.mjs --check-determinism
node --test port/native-arenas/tests/actual-maps.mjs
node tools/godot-native-arenas/movers.mjs
node tools/godot-native-arenas/capture.mjs
```

`rebuild.mjs` dumps native collision, compiles through the actual authority schema, checks deterministic arena hashes, probes Godot physics, then runs source parity assertions. `verification.json` records per-map hashes and results.
At the current schema gate, rebuilding intentionally stops before replacing Aurora. After the authority owner's boolean adjustment, run one rebuild without the determinism flag to adopt the new navigation mode, then the listed checks. `navigation-candidate.mjs` independently measures the source graph and checks pruning/coverage without writing generated assets or bypassing schema for a native match.
Omit `--check-determinism` for an intentional geometry edit; use it afterward to prove a repeat export preserves the newly accepted hashes. The separate `res://tests/native_arenas/geometry/unsupported.gd` negative fixture must exit **1** with `Unsupported DM collider: SphereShape3D`; its expected rejection log is retained.

Verified geometry scope:

- All 18 spawn feet positions and every sampled authored route point: 749 native/source floor comparisons.
- 3,748 native/source ray comparisons: four horizontal directions and upward headroom per point, plus a sealed-volume probe per map.
- Every route's source `walkEdge`, safe spawn clearance, all pickup kinds, fully connected source navigation graphs, and the source's 6.5m graph-edge limit.
- Idempotent native map builds and public authority schema validation.
- Live source matches are exercised by the authority owner's `actual-maps.mjs`, separately from floor/ray fixtures.

The actual-map gate passed all three source constructors, real AI/combat, round results and restart checks. The first passing round set recorded 591/161/406 shots and 1/5/5 kills for Prism/Aurora/Cinder respectively; these are deterministic test-round observations, not balance targets. Cinder's real source round also recorded three falls, consistent with exposed lava-side platform edges.

The three sealed-volume probes enter Prism's west service bank from `(-12,1.5,4)`, Aurora's crown buttress from `(16,1.5,-25)`, and Cinder's sealed bore from `(7,13.5,-24)`. Both native ray collision and source ray/movement obstruction must block them. Ascents, standing headroom and the alternate upper routes are tested separately.

Graphical evidence uses the actual native DM scene, live Node authority, five real bots, shared public actor presentation and a visible first-person rig. Current `evidence/final/` images carry the delivered `geometryHash` per map: Aurora at 960×640, 1280×720, 1280×800 and 1920×1080; Cinder and Prism at 1280×720 and 1920×1080 (Prism's 1920×1080 pass, which previously aborted, now completes). Each `<map>.log` records `geometryHash`, `first_person:true`, `msaa:"disabled"` and the software renderer (`gl_compatibility`, `llvmpipe …`, Xvfb). The stale pre-navigation Aurora set (old hash `909daa29…`) is retained in `evidence/pre-navigation-fix/`; `evidence/final/README.md` maps files to hashes. The capture script changes look direction only; camera translation follows authoritative snapshots. Early Aurora evidence used a warm navigation cache and cannot establish cold startup success. **The current runner no longer prewarms**. MSAA is disabled in the current software-rendered fixture; llvmpipe still triggers stale-input cancellation, so the fixture explicitly retries capture after queued network events, retaining normal focus/lifecycle checks. These images establish rendering, not smooth interactive performance. Map runtime defaults are unchanged by capture settings. Results are from Linux GL Compatibility/llvmpipe, not Windows performance claims.

The 2026-09-22 trap-fix lane changed the compiler's movement-wall rules on top of the retained geometry (see `port/native-arena-trap-fix/REPORT.md` and the Cinder follow-up `port/native-arena-trap-fix/REPORT-cinder-fix.md`): one-sided burial and terrace handling of wall bands, raised band bottoms over lower floors, walkable-topped DM guard rails and service covers, a `dm_walkable` cap on the adapted guard barriers, a jump-clearable trim for low thin guard bands, and the Cinder spatial-navigation opt-in (required so the walkable guard caps do not bake isolated nav islands). Those edits change every `geometryHash`; the values below and in `verification.json` are the re-accepted delivered hashes of this revision.

## Provenance and resolved failures

Initial source/native testing exposed disconnected exploration-height lips and narrow grid-only pockets, internal ramp skirt walls, and the inward-wound ice arch collision discrepancy. The variants gained shallow transitions, dense flank nodes and visible core fills; the compiler now separates support, movement bands and exact two-sided rays. The first full parity pass retained 75 Aurora ray failures; the second pass fixed them by retaining outside-bounds ray geometry and enabling native concave backfaces. Original failure output is retained with the evidence.

First-person image review additionally caught coplanar filler caps fighting the existing Aurora deck and Cinder bore surfaces. The visible foundations now meet the underside of the original slabs, preserving their top surface instead of overlaying a second material. Pre-fix screenshots are retained in `evidence/pre-visual-fix/`.

See [INTEGRATION.md](INTEGRATION.md) for the resolved startup configuration mismatch and measured cold navigation preparation cost. Runtime performance and arbitrary off-route collision have not been claimed as exhaustively verified.
