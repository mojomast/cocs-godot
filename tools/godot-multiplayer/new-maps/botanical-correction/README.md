# Source-only successors to frozen U

Branch starts at `243223d3`. U masters/exports/receipts, accepted authorities,
and the three U source recipes are immutable inputs. No engine or heavy-slot
supervisor is started or queued by this source task. A new grant is required.

## Helix revision-4 — third independently confirmed P1

The original five tangential arches had faithful transforms but no intended
supports. The source regression reads the real frozen U GLB, excludes the
rib's own evaluated triangles, and reproduces the >8.7m gap at rib70's outer
end. It does not reinterpret that missing geometry as a transform error.

The replacement is a low, radial pavilion frame: five transverse semicircular
arches at the same 70/76/82/88/94° stations and radius87, inner/outer arch radius
5.8/6.6m, springY19, crownY25.6. Their paired feet are at radius80.8/93.2 on
the **original Y16 terrace**, with .8m radial / .8m tangential posts, 3.02m tall.
Posts support each complete .8×.6m rib end section with 2cm bearing overlap.
Two slim .18m-radius longitudinal eaves and one crown ridge join the stations;
they are not arbitrary long beams reaching toward unrelated distant geometry.
The central canopy route at radius86 retains over 8m frame headroom. All five
arches keep their 28-segment detailed profile. The inherited thin pavilion,
south ridge and every one of the 5,240 decorative meshes remain unchanged.

One new `greenhouse_frame` consumer descriptor expands both render geometry and
real Kit-derived collision for every post, rib, eave and ridge. All ten named
end sections are tested against their **intended posts**, and all named pipe
joint rings against the correct eave/crown station. The static graph has 18
members and 35 named attachment edges, all reachable from ground. Post footprint
corners have original y16 support; old route/nav/spawn/objective data and heights
are preserved. Finite .42m / 1.8m capsules on every original 25cm route sample
and nav point test every new member triangle, not merely member footprints.
Including the immutable U fixture's mode spawns/objectives/camera points, this
is **49,553 finite-capsule samples** against the new frame. The frozen-U negative
test examines all ten actual end centres with their own rib triangles excluded:
six lack attachment within 4cm; the rib70 outer gap is >8.7m.

`measure_future.py` and `verify_future.py` are prepared for a new grant: the
former measures the **new** reopened master; the latter matches every evaluated
triangle against actual GLB bytes and reruns attachment tests on measured member
vertices with 0.1mm precision. Entire world authority shell coverage is included.
Neither has been run with an engine or successor artifacts; their actual/native
validation remains pending. U's source fixture and U reports are unchanged.

## Parallax districts-v4

U's east portal runs from x48 to x44 at y12, but the court stops at x46, leaving
an unsupported 2m gap. The uncut x48 retaining wall rises to the east-instrument
terrace, y17.5 at z−34. A changed camera or shortened ray cannot fix it.

The successor replaces the local ground with one complete x44..52,
z−37.5..−30.5 landing at y12, and a x47..52 graded connection north to z−63,
y24. Grade is 12/25.5 (25.2°), below the existing 0.48-radian maximum. It joins
the original upper terrace and court with new authored nav nodes. The six-metre
portal and all U route endpoints remain fixed. The cut avoids the x54 old route;
old nav/support heights are tested to 1e−8m barycentric precision. Lightwell
descent and candidate floor-union material priority are preserved. The same
canonical terrain triangles feed collision and the render shell. Accepted
cliff decorations in the excavated footprint are removed through the existing
bounded craft-cut mechanism; domes/dishes are protected by lineage regression.

## Vesper urban-v3

The U discrepancy comes from `author_blender.py:170`: a second, legacy
`row-roof-parapet` brick box (.45m deep, .7m tall), behind the new Kit parapet
(.35m deep, .9m tall). It is NOT a Blender transform or wall-normal extrusion.

The successor names all 60 legacy parapets by exact canonical bounds. Six ends
are replaced by the existing renovated Kit parapets. The other 54 get exact
source collision and render-shell triangles. `base_craft.py` consumes this
**opt-in Vesper policy only**, checks every captured legacy name/material/bound,
and removes the duplicate craft contribution. Old recipes without that policy
take the original path. There is no global wall thickness or tolerance change.

## Reproduce (pure source only)

```sh
node tools/godot-multiplayer/new-maps/botanical-correction/generate.mjs
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/test_correction.py
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/test_greenhouse.py
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/test_archived_fixture.py
node --test tools/godot-multiplayer/new-maps/botanical-correction/correction.test.mjs
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py parallax-observatory plan
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py vesper-viaduct plan
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py helix-conservatory plan
```

Portable Python tests cover the complete anticipated source scene: authority shell, blocks,
pieces, accepted craft and real unmodified Kit triangles. Tests cover the whole
portal width/standing height in both directions, .42m-radius / 1.8m finite
capsules against actual source triangles, all retained parapet faces, and every
legacy authority wall triangle across both worlds. These are source predictions,
not actual successor export or native acceptance.

### Explicit archived regressions (no rejected-bundle merge)

The archive root is **always a frozen repository/worktree root**, with the
repository-relative layout recorded in `archived_fixture.py`. It is not an
`evidence/` directory or a map artifact directory. Set it explicitly:

```sh
COCS_BOTANICAL_U_FIXTURE_ROOT=/home/mojo/.tmp-on-disk/cocs-map-variety-botanical-astra \
  python3 -B tools/godot-multiplayer/new-maps/botanical-correction/verify_archived_u.py
```

This read-only command reproduces all three actual-U failures and runs the full
**49,553** successor-frame capsule checks: 16,790 source-derived route/nav points
plus all **32,763** pinned U fixture points, including mode spawns, team
objectives and supported cameras. Portable `test_greenhouse.py` runs the 16,790
source-derived route/nav samples; it does not claim archived mode-anchor coverage.
No covered mode anchors were replaced with stubs or silently dropped. The full
coverage moved to the explicit archive command and remains mandatory for it.

The five GLB/evaluated/probe inputs are SHA256-pinned to the actual `243223d3`
inventory in `archived_fixture.py`. Every file is checked before its bytes are
parsed, and all inputs are preflighted before the archived tests start. Missing
root/file, wrong bytes, unpinned paths and symlink escapes fail closed. There is
no repository-local fallback, search, download or skip. Portable loader tests
exercise these failure cases without requiring any archived assets.

For an explicitly requested refresh of full-count source evidence, use the same
environment assignment with `source_evidence.py`; it now fails before writing
when the pinned archive is unavailable. **This integration follow-up leaves
`source-evidence.json` frozen at `da2e53eb`**, including that baseline's dependency
hashes and null successor artifact identities. Current fixture/test input changes
are recorded separately in `fixture-input-provenance.json`; no geometry JSON or
baseline source evidence is regenerated during independent geometry review.

## Future heavy commands — documentation only, NOT queued

With a new explicit grant and its own nonwaiting-lock/PGID supervisor, run
serially using pinned Blender 4.5.14, `-b -t 1 --python-exit-code 1`,
LP_NUM_THREADS=1 and OMP_NUM_THREADS=1. The script is:

`--python tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py -- MAP build`

Then `-- MAP reopen-export`. Build refuses existing successor outputs. Each
successor master is under `MAP/revisions/NEW_REVISION/masters/`; exports and
distinct build/reopen reports are under `port/new-maps/MAP/variety/NEW_REVISION/`.
Do not invoke the released U supervisor or U `produce.py`/`prepare_stage.py`:
their closed hashes and stage paths intentionally remain the old U candidates.

Under that same future owned supervisor, run pinned Blender with
`--python tools/godot-multiplayer/new-maps/botanical-correction/measure_future.py -- MAP`,
then pure `python3 -B tools/godot-multiplayer/new-maps/botanical-correction/verify_future.py MAP`.
Use distinct future attempt IDs; retain every failed output before another
attempt. Bound build to 1800s, reopen/measurement to 900s each, pure export proof
to 180s. Later import remains bounded to 900s, native tests 60–180s and captures
300s/map. No supervisor command is executed by these instructions.

Future evaluated proof, native staging and new exact-hash Binder profile must
use a fresh `botanical-correction/ATTEMPT_ID/MAP` namespace. Before any acceptance,
repeat actual full-scene triangle/material/winding comparison, **all** authority
shell coverage (including retained legacy parapets), full-aperture rays/capsules,
routes, imported pixel readback, service lifecycle and matched cameras. Keep
0.1mm numeric precision / at most 4cm deliberate bevel tolerance. No successor
GLB, master, staged hash or native receipt exists at this source checkpoint.

## Parent integration

For frozen Helix U source integration, approved `68e3f21e` plus `bdef2baf` supplies
the fixture, UV/tangent exporter corrections, camera/precision/lifecycle checks,
and collection/release tools. Neither requires wholesale `243223d3` artifact
promotion. The successor policy in `base_craft.py` is a separate prerequisite
for Vesper urban-v3, unused by frozen Helix. No shared Kit/adapter/runtime files
are edited. Keep successor corrective commits separate from frozen artifact
selection and independent Helix review. 150k triangles remains advisory.

For Helix revision-4, the new `kit_expander.py` handler and `source_geometry.py`
solid classification are additionally required. They are opt-in by the new class
and do not change existing U directives. Parallax/Vesper source correction is
commit `f358e497`; the separate following Helix commit adds this assembly.
No parent shared completion document is modified here.

## Final source verification

- Corrective tests: 8 geometry Python, 5 greenhouse Python, 5 Node tests.
- Compatibility: 27 existing map-variety Python, 8 U fixture Python, 25 existing
  map-variety Node tests, and all three standalone Kit source checks pass.
- Frozen U artifact inventory (264 hashes), original authorities and receipts
  are verified byte-for-byte; no new native receipt exists.
- Successor generation and source evidence are deterministic. Source estimates
  are 147,378 / 144,585 / 40,614 triangles (Helix / Parallax / Vesper); actual
  modifier/export counts remain pending and may exceed 150k.
- `source-evidence.json` carries exact new geometry/source dependency hashes,
  pending artifact identities, and all ten source attachment sections.

`3002a9ba` additionally requires all twelve canonical parapet boundary triangles
before suppressing the legacy craft box. A missing side fails closed. The
complete anticipated render scene is also tested with bidirectional capsules on
the entire new Parallax grade using exact sloped-plane capsule contact geometry.

### Fixture portability follow-up

The counts above describe the reviewed `da2e53eb` baseline. After separating the
archived cases, portable suites contain **7 geometry + 4 greenhouse + 5 loader
Python tests**. The explicit archive command preserves the three actual-failure
regressions and full 49,553-point coverage. Node/geometry helpers are unchanged.

Parent integration is selective: apply source commits `f358e497`, `3002a9ba`,
`da2e53eb`, then this fixture follow-up, on top of the already integrated U
source prerequisites (`c7cd4331` / `fb2af58d`, corresponding to `68e3f21e` /
`bdef2baf`). Do **not** merge all U ancestry or the rejected `243223d3` bundle
to supply tests. Run the archive command against the frozen worktree above.
Existing imports of source helpers from `map_variety` and U fixture source
`botanical-stage/geometry.py` remain required; this follow-up adds no engine,
runtime, adapter, geometry-helper or model dependency.
