# Visual identity trilogy — preproduction design

Units metres; X east, Z south, Y up. Graybox owns source surfaces/blocks. Presentation consumes the same geometry; decorative skyline cannot become invisible source cover. This document precedes art production. The following budgets and layouts are hypotheses, not measured acceptance.

## Lacuna Court / Deathmatch

Playable footprint 56×48, X ±28, Z ±24. Four protected cardinal/quadrant spawn pockets and two intersecting loops around split acoustic masses. At least two exits per principal space. Central open court ~14×12, 8–20 m typical engagement. One ~30 m perimeter view interrupted by a flank entry. Two 1.5 m high terraces reached by broad 1:6 ramps; no overlapping accessible decks. Cover heights 2.6–4 m, most routes >=4 m wide. Rocket and health opposite sides, armor at flank, not all in a bunker.

```
N  spawn NW -- cut/ramp -- north listening gallery -- spawn NE
        |       [crescent wall]    |           |
W    copper lane ---- resonance court ---- indigo lane E
        |         [split resonator]            |
S  spawn SW ------ dry lower loop --------- spawn SE
```

Landmark: two separated thick stone arcs, indigo insert faces and copper radial slots. Static distant acoustic sail outside boundary. Material board: chalk #ded4bd, pale cut stone #b7b0a0, indigo #202c59, copper #ad7045. Broad light floor, dark functional pockets; no blinding white emission.

## Vermilion Fold / Domination

Playable footprint 64×56. Mirror-balanced starting travel geometry, asymmetric pavilion silhouettes. Team spawns west/east, paired heights. Three capture sites along north/centre/south: Fan/alpha (0,-17), Crown/bravo (0,0), Pleat/charlie (0,17), radius 3.5. At least three radial entrances each. Opaque offset retaining blocks prevent a single spot directly watching every site. Safer outer rotation west/east versus exposed central cross-route. Initial authority uses one human plus five bots (3v3), future 4v4 through approved config only.

```
                 FAN alpha
          /-------------------\
west spawn -- retaining  retaining -- east spawn
          \------ CROWN -------/
          /                   \
       safe flank        safe flank
          \------ PLEAT -------/
```

Landmark: fixed crown of folded opaque vermilion ribbons, ivory tension supports; a broad fan over alpha, serial jade pleats at charlie. Material board: vermilion #b84a38, ivory #e3dcc8, jade #244d48, hardware #343943. Shape marks A / B / C always distinct from surface trim. Markers and HUD use source-returned coordinates and state, never recipe-owned scoring. Fairness gate: repeated actual-controller runs in both directions from both starts, include diagonal approach and rotation, disclose tolerances.

## Nacre Engine / Horde

Playable footprint 60×52. Four broad approach mouths, connected outer retreat ring, two cross-links around a nonwalkable central memory housing; recovery alcoves have two exits. Minimum wave approach width 6 m. Static nested arches overhead are decorative/nonwalkable; never source walkable surfaces. Pearl combat floor, ultramarine opaque perimeter, amber service inserts. No water volume in fighting space. Largest NPC display clearance is conservative >=3.2 m height at route mouths; actual production actor/boss tests remain required.

```
             north wave approach
        shell gallery ---- recovery
         |    \            /    |
west ----|   [memory housing]    |---- east
         |    /            \    |
        retreat ring ---- recovery
             south wave approach
```

Landmark: horizontal nacre memory drum with segmented annular shell plates. Thick elliptical vault ribs, sparse noninteractive amber channels. Material board: pearl #d3cbbc, ultramarine #142b4a, amber #b88b43, joints #394a55. Source controls enemies/waves/defeat. One human only; upgrades shown only if actual adapter exposes the source action. Boss/endless and peak load unaccepted until tested.

## Shared resource and camera contracts

One JSON recipe per map, deterministic Node compiler outputs canonical arena plus render geometry metadata/hash. Single-cell floor is tessellated where needed; cover is source blocks with exact visible extents. Add visual shells only after matching graybox checks. Spatial batching by material in 12 m cells; preserve map-only build/load interfaces. No source registry edits. Inspection scene is labelled inspection and is not a gameplay controller.

Fixed cameras per map: entrance (spawn eye -> landmark); landmark oblique; combat at 1.6 m; objective/pickup at eye level; worst-sector elevated overview. Capture 960×640, 1280×800, 1920×1080. Place actual existing operator visuals at 10/25 m only in explicitly labelled readability fixtures. Final ADS/FX pictures must come from integrated production client.

Initial hypotheses: <=120 visible material-cell surfaces, <=150k visible triangles per map, <=32 MiB unique texture allocation, <=64 MiB lightmaps if baked, one shadowed directional key and <=2 unshadowed local lights. <=2,048 decorative particles High / <=256 Low shared per map, default zero until quality-manager integration; no per-prop process or per-frame mesh rebuilding. 60 Hz / 16.67 ms target at 1080p on identified desktop GPU is NOT verified on this host. Record geometry build/load, warm median/p95, cold shader stalls, actual draw calls, memory, actor/particle concurrency separately. No GPU device exposed here; llvmpipe comparisons do not certify the hardware target.

Parent owns shared native DM/zone/Horde authority hooks, launcher/menu/package routes and production client map-loading seam. Lane supplies source-compatible data and tests, proposed hooks, assets, evidence; never widens existing locked contracts silently. Independent final review is not replaced by these direct audits.
