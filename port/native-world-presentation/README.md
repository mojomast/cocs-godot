# Native world presentation

Implemented on `feat/native-world-presentation`, isolated from primary at
`d06b681`. Default `viewer.gd` and its inheriting native session now use this
Godot-native presentation. It is an intentional stylized interpretation of the
nine authored maps, following the pragmatic porting direction in `port/README.md`.

## Visible changes

- Procedural sky, directional shadows, readable ambient fill and light distance
  fog; no GLB sky dependency, textures, downloaded assets or extra packages.
- Material families use generated `blocks.kind`, terrain `material` and
  `surfaceId`, plus authored `sky`, `background`, `color` and `floorColor`.
  Low-contrast world-space panel seams provide scale without UV imports.
- Segment-local cornices, plinths and window strips preserve doorway gaps.
  Cover edge accents, simple tree crowns and depth-tested authored landmark
  labels make routes easier to recognize. Trim is batched by material using
  MultiMesh; decorative nodes have no process loops or collision.
- Distant city silhouettes or faceted ridges sit outside the authored bounds;
  a lowered background ground plane removes the black void around the map.
- Ion uses authored centerline dashes; Aurora uses its authored pitch bounds,
  halfway line and center circle. These are **visual layouts, not native mode
  implementations**.
- Normal views omit spawn beams and coordinate axes. `--diagnostic-markers`
  explicitly restores them. `StaticPickupMarkers` remains available with the
  same child count/positions, now using small faceted orbs; the existing session
  continues hiding that group in favor of authoritative pickups.

| Map | Native palette/environment |
| --- | --- |
| Meridian Exchange | Warm civic dusk, pale masonry, charcoal trim, cyan accents, city skyline |
| Verdant Reliquary | Muted moss/limestone, green daylight and forest ridges |
| Ember Crucible | Ash and iron, orange accents, warm volcanic night haze |
| Tidal Citadel | Blue-gray naval stone, ice/snow surface separation, cold daylight and ridges |
| Sunscar Convoy | Sandstone, earth tracks, copper dusk and canyon silhouettes |
| Asterion Relay | Blue-violet orbital night, pale relay masonry and cyan accents |
| Monsoon Foundry | Green-gray industrial daylight, dirt/grass/concrete separation |
| Ion Speedway | Blue-black night asphalt, cyan rail edges and centerline markings |
| Aurora Stadium | Teal pitch, cool floodlit-night palette and white field markings |

All solid positions/dimensions and terrain vertex positions remain exact. Terrain
winding is adapted to Godot and explicit source normals are retained. A tiny
fragment-depth priority resolves coplanar floor/roof flicker without displacing
vertices. An ordinary-material shadow-only mesh handles elevated support
surfaces separately; zero-height ground does not self-cast, eliminating the
grazing-angle shadow banding found during screenshot review.

## Executed checks

Pinned engine: `4.5.2.stable.official.6ce3de25a`, Compatibility renderer.
Generated assets were copied from primary `godot/content/generated` without
editing their bytes or the export tools.

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT_BIN" --headless --path godot --editor --import --quit
"$GODOT_BIN" --headless --path godot -- --smoke
"$GODOT_BIN" --headless --path godot -- --smoke --diagnostic-markers
"$GODOT_BIN" --headless --path godot \
  --script "$PWD/port/native-world-presentation/compatibility.gd"
python3 port/native-world-presentation/capture.py port/native-world-presentation/after
# Optional: all nine locked-map overviews, using the same private renderer.
python3 port/native-world-presentation/capture.py /tmp/opencode/native-world-review --all
```

- Editor import passed.
- [Normal smoke](smoke.log) and [marker smoke](diagnostic-markers.log): all nine
  maps, two load/unload cycles, unknown map rejected, no engine/script errors.
- [Compatibility](compatibility.log): **1,341 solids and 17,166 triangles** checked
  against generated assets; exact transforms, dimensions and vertex positions,
  marker group API, skies and absence of local collision all passed.
- Real graphical captures used a private Xvfb display and Mesa llvmpipe, with
  60-second process bounds and owned-process cleanup. The launcher uses Linux
  abstract X sockets (`-nolisten tcp -nolisten unix`) because this environment's
  pathname X socket directory is not writable. No shared desktop was used.
  Logs contain the driver's unsupported-VSync warning; final runs contain no
  engine/script errors.

## Image-reviewed evidence

These are offline native renderer captures, with identical cameras before and
after. The baseline uses the viewer from `d06b681`. All six images were opened
and reviewed; iterations corrected blown-out masonry/snow, roof flicker and
ground self-shadow banding before the final captures below.

| View | Baseline | Native result |
| --- | --- | --- |
| Meridian overview | [Before](before/meridian-exchange-overview.png) | [After](after/meridian-exchange-overview.png) |
| Meridian street-height | [Before](before/meridian-exchange-street.png) | [After](after/meridian-exchange-street.png) |
| Tidal overview | [Before](before/tidal-citadel-overview.png) | [After](after/tidal-citadel-overview.png) |

## Remaining gaps

The semantic architecture and distant silhouettes are deliberately simple;
window strips and floating landmark lettering are native abstractions. Signs
respect depth and may be occluded from some routes. Broader walk-through review,
hardware performance measurement remain useful follow-up work. A subsequent
independent all-nine-map overview review is recorded in
[`../reports/native-world-independent/README.md`](../reports/native-world-independent/README.md);
it is not a gameplay walkthrough. Native actors/weapons/audio, objective state,
vehicles and special modes belong to their respective implementation lanes;
these screenshots do not establish live gameplay acceptance. The historical
`--visual-probe` remains a separate GLB diagnostic.
