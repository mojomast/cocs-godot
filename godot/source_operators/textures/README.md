# Native operator surface detail

Original SVG artwork authored for this repository (2026-09-30), applied only to
the existing articulated `ArmorDetail` presentation overlays on all nine playable
identities. This is **native presentation material detail**, not a source export.

`generated/manifest.json` explicitly records that the original `robotModel`
construction does not apply procedural textures. Its nine GLBs and source hashes
are preserved. Source anatomy, rigid joint owners, weapon attachments, collision
and source LOD masks retain their existing ownership.

## Treatment

- Breastplates, pauldrons, thighs, shins and knees: inset panel outlines,
  stepped seams, slotted fasteners, service markings and a few short edge chips.
- Bracers and belt equipment: bounded service-board windows, dark gasket,
  copper traces, contact pads, chip pins and discrete components.
- Rib guards, face guard and radiator: recessed cooling slots with bright lips.
- Broad plate paint still multiplies the existing neutral identity or team color.
  Red/blue/neutral switches rebind cached materials, including same-identity
  changes. Circuit traces are passive; existing sensor/visor emission is retained.

`surface_detail.gd` fits each panel to the flat front/back faces of the existing
bevelled prism. It compensates for the builder's taper and bevel dimensions.
Bevels and narrow sides sample bare paint. UVs are stored in the rigid mesh, so
animation cannot slide a world-space projection over a joint. There is no runtime
image generation, shader clock, added geometry, extra surface or extra draw call.
The original flat normals remain; recess depth is painted, not displaced geometry.

## Cost

Three 512×512 albedo textures plus one shared 256×256 roughness texture, with
explicit mipmap import settings and lossless storage. Conservative RGBA8 GPU
budget including complete mip chains: **4.33 MiB total**, shared by every identity,
team and instance (actual driver formats can be smaller). No normal texture.
Materials are cached by finite style/color/metallic/roughness keys. Meshes are
cached by finite existing size recipes. Each textured prism adds 180 Vector2 UVs
(1,440 bytes); triangles and overlay node count are unchanged. Source LOD 2 still
hides all overlays at the existing distance threshold.

## Verification and matched gallery

Completed checks include SVG XML parsing, all nine original GLB SHA-256 hashes,
editor import and the integrated `textures.gd` runtime contracts. The integration
corrected one strict inferred-type error in the test fixture; the passing log is
`feature-integration-bfb91314/repair-1/textures.log` under the campaign evidence
root. Compatibility visual evaluation remains pending the screenshot capture.

After the heavy slot is granted, import the project, then run:

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/source_operators/textures.gd
godot --headless --path godot --script res://tests/source_operators/check.gd
godot --headless --path godot --script res://tests/source_operators/grips.gd
OPERATOR_EVIDENCE=/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/operator-textures godot --path godot --rendering-method gl_compatibility --script res://tests/source_operators/texture_gallery.gd
```

The gallery reuses the native operator render stage. It writes 164 matched PNGs:
all nine identities × neutral/red/blue × normal-distance/close/posed × before/after,
plus a mixed nine-identity roster pair. The before state uses each overlay's exact
original untextured material; geometry, source pose, camera and light match.
Normal views use 4.5 m and close/pose views 2.3 m. Screenshots are intended for
parent review/publication; no screenshots or public URLs are claimed yet.
