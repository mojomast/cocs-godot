# Architectural revision 3 — staging design record

This records source-only staging at `8d248904`. A subsequent explicit heavy-slot grant authorized production; see [REVISION3-PRODUCTION.md](REVISION3-PRODUCTION.md) and current acceptance receipts. The prototype from `afbe57dc` / `ec041aee` is retained in Git and an immutable external asset archive. Runtime paths now hold the promoted revision-three candidate.

## Candidate design

* Crusher house: a 62 m long process enclosure wraps the actual drums. A jagged folded roof, receiving hopper/chute faces, deep drum bays and a protected returning maintenance aisle create building mass around machinery. Large truck portals preserve the freight threshold.
* Central processing passage: unequal angled walls and a folded canopy cover the middle freight segment, with an independent diagonal uphill service cut. Intake approach, covered transfer and furnace handoff are distinct intended encounter spaces; their visual readability still requires native review.
* Furnace district: warm ore/brick-colored buttresses support segmented arched kiln fronts, backed by a service enclosure and loading canopy around the existing process towers. Open apron and maintenance inclines remain clear.
* Cooling: closed shell around the retained barrel vault, machinery recesses and central/side access. Assay: a different asymmetric steep roof, gables, multiple partitioned rooms and genuine empty inspection-window apertures. The exporter omits the assay's former barrel-vault detailing and adds matching pitched rafters.
* Geology: unequal broad stratified exterior benches replace the author's repeated perimeter teeth; stepped foundation beds integrate selected interior rock islands. These are candidate architectural changes, not an inspected appearance claim.

All overheads remain non-walkable source triangles. No overlapping support floors or whole-gallery AABB blockers are introduced. Existing freight path, vehicle loop, gameplay markers and six modes are retained. Two extra route variants add the protected crusher aisle and diagonal service cut.

## Identity / source proof

```text
candidate geometry 8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f
candidate recipe   3c7f9242bb7c98000871b27d58d14c719a4867e1a9fc625b106c97f7c1c608eb
```

Candidate files are isolated under `tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/`: recipe, arena/wrapper/probes JSON, builder, grant-gated author and source receipts. **334 surfaces, 2,320 wall triangles, ten route variants**. Source validation passes each route in both directions, all markers, navigation connectivity, Puma mounted service lap, payload delivery and all six controlled rounds. New architecture tests drive actors into crusher/transfer/assay walls from both sides and check blocking rays, four district ceilings and open inspection windows versus blocking lintels.

Failed source attempts are preserved externally: the transfer north wall initially pinched freight clearance; a cooling bank occluded an inspection window; the old assay-vault ceiling-height expectation needed adjustment for the taller pitched roof. Geometry and source assertions were corrected before passing. Python syntax and all asserted exporter substitutions were checked without importing `bpy`.

```sh
node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/build.mjs --check
FOUNDRY_CANDIDATE=1 node port/new-maps/gravemill-foundry/source-check.mjs
FOUNDRY_CANDIDATE=1 node port/new-maps/gravemill-foundry/round-check.mjs
node tools/godot-multiplayer/new-maps/gravemill-foundry/revision3/architecture-check.mjs
```

Native test drivers now live in `godot/tests/new_maps/gravemill_foundry/`; the Node journey helper targets the relocated scene. Candidate probe JSON is isolated in revision3, outside exported runtime data. The accepted probe JSON remains with the checkpoint for reproducibility until a reviewed candidate activation moves it to the test tree.

## Next explicit grant gates

1. Export with `revision3/author.py`, `LP_NUM_THREADS=1`, serial work. Its asserted substitutions redirect recipe, wrapper, master, GLB and default evidence into revision3 destinations. It does not promote candidate art or overwrite checkpoint artifacts.
2. Reopen candidate master; measure materials/draws/triangles/nodes and bounded CPU cost. Existing ≤8 batch and <180k triangle ceilings remain; no minimum part/triangle claim substitutes for architectural review.
3. Inspect overview plus distinct eye-level crusher, cooling, assay and furnace images. Iterate meaningful building mass, protected flanks and geological integration after viewing, rather than assuming source geometry achieves the brief.
4. Activate candidate only through a separately reviewed promotion; revalidate production native candidate probe positions, new contacts/apertures, hosted DM/payload/Puma-zone and affected six-mode proofs. Source-only receipts are not native acceptance.
5. Check wide native HUD and **760×520 at UI 150%**. Capture a continuous representative three-district segment ≥20 seconds if feasible and report actual capture cadence. The old walkthrough was **4.46 seconds**, not 43 seconds; 43 was its captured-frame count. A requested trailer is parent-owned.

The historical next-pass gates above are fulfilled or explicitly qualified by the production record; they are not a claim that staged source proof alone establishes native acceptance.
