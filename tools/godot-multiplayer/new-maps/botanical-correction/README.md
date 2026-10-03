# Source-only successors to frozen U

Branch starts at `243223d3`. U masters/exports/receipts, accepted authorities,
and the three U source recipes are immutable inputs. No engine or heavy-slot
supervisor is started or queued by this source task. A new grant is required.

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
node --test tools/godot-multiplayer/new-maps/botanical-correction/correction.test.mjs
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py parallax-observatory plan
python3 -B tools/godot-multiplayer/new-maps/botanical-correction/asset_author.py vesper-viaduct plan
```

Python tests first read the **actual frozen U GLBs** and reproduce both failures.
They then test the complete anticipated source scene: authority shell, blocks,
pieces, accepted craft and real unmodified Kit triangles. Tests cover the whole
portal width/standing height in both directions, .42m-radius / 1.8m finite
capsules against actual source triangles, all retained parapet faces, and every
legacy authority wall triangle across both worlds. These are source predictions,
not actual successor export or native acceptance.

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
