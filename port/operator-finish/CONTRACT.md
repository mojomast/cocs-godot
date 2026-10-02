# Operator Moth-bake improvement pass

Extend the owner's Sol visual-finishing fan-out to all nine operators: chatgpt,
claude, grok, meta, gemini, deepseek, mistral, kimi and qwen. Improve actual body
surface treatment, rather than changing silhouette, animation, combat or stats.

## Existing implementation and constraints

`source_operators/surface_detail.gd` currently applies generic authored SVG panels,
service-board and vent textures to armor overlays. `operator_visual.gd` applies
team material overrides and team bars. Source GLBs contain fitted UVs; preserve
them. Fighting conversion imports source meshes and joins material/LOD groups.
No fighting GLB exists yet, so its UV preservation and final finish require native
export/animation inspection later.

Animated actors must use fitted UV or proven rest-space mappings, not map-style
world-space projection. Protect team colors/bars, operator palette, visor/sensor
emission, transparency, LOD and existing surface readability. Do not tint already
tinted textures twice or mutate shared imported material/mesh resources. Exclude
held weapons, team markers and intentionally emissive/transparent pieces unless
a precise preserve-compatible rule is provided.

## Two isolated owners

1. **Authored finish data/assets:** `godot/source_operators/moth_finish/profiles/`,
   `assets/`, `manifest.json`, authoring scripts under
   `tools/operator-finish/content/`, map-independent source checks and art notes
   under `port/operator-finish/content/`. Own all nine profiles and actual pixels.
2. **Runtime integration:** `godot/source_operators/moth_finish/binder.gd`, optional
   shaders/helpers and validators under `tools/operator-finish/runtime/`; minimal
   FPS hooks in `operator_visual.gd`/`surface_detail.gd`/`armor_detail.gd`; a separate
   minimal fighting configure hook in `fighter_visual.gd`. Own native gallery,
   animation/LOD/team/lifecycle fixtures and integration documentation.

No edits to the shared Moth registry, world/map shaders, map-finishing profiles,
source GLBs, rig geometry, animation recipes or frozen game/server authority.
Runtime worker must keep any fighting hook separate for reconciliation with the
native integration owner. Inspect material roles per operator; the same numbered
source material need not have the same meaning in every GLB.

## Profile v1

`profiles/<operator-id>.json`:

```
{
  "version": 1, "operator_id": "chatgpt",
  "bindings": [
    {"source_material": "sourceMaterial0", "role": "armor", "finish": "chatgpt-armor"}
  ],
  "overlay_finishes": {"panel": "chatgpt-panel", "board": "chatgpt-board", "vent": "chatgpt-vent"},
  "preserve_materials": [{"source_material": "sourceTeamIvory", "reason": "team identification"}]
}
```

`manifest.json` contains `version:1`, a `finishes` dictionary keyed by finish ID,
and provenance. Each finish specifies resource paths `albedo`, optional `normal`,
optional `roughness`, scalar `metallic` (0..1), `roughness_gain` (0..1),
`normal_strength` (0..1), and `albedo_mode:"modulate"`. Modulation textures must
retain enough neutral luminance and restrained chroma to preserve the original
palette/team tint. Optional maps must be omitted when unavailable, never filled
with invented resource references. Texture records/provenance must record actual
dimensions, hashes, Moth source keys/paths/hashes and deterministic derivation.
The art lane publishes actual meaningful per-operator patterns, not nine tints
of one generic tile. Additional fields require documented compatible handling.

Runtime public entry: instance `bind(root: Node3D, operator_id: String) -> Dictionary`
returning actual matched/unmatched/intentional exclusions and texture resolution;
`set_team_color(color: Color)` updates only declared team-tint surfaces;
`clear()` releases instance-owned references without deleting model geometry.
Overlay helper may expose `material_for(base, operator_id, style)` for existing
fitted detail meshes. Preserve base material identity metadata and rendering
properties while applying local overrides. Track original materials so rebinding
does not accumulate overrides or darken surfaces repeatedly. Cache keys include
all state affecting appearance; caches must have a measured/configured bound.

## Desired art result

Distinct combinations of ceramic/enamel, brushed metal, rubber/seals, recessed
panels and passive circuitry, with purposeful chips/scuffs at exposed edges,
grime in recesses, restrained manufacturer/maintenance markings and operator
identity. Wear must follow fitted panels and plausible use. Normal and roughness
details should read under moving light without drowning out character palettes.
No random all-over noise, luminous full-body outlines or unreadable microtext.

Use existing baked Moth pixels and maps through the registry or explicit
reproducible derived assets. Lightweight image composition is permitted; preserve
source provenance and originals. Heavy engine baking/export is grant-gated.

## Verification and heavy queue

Validate exact GLB material coverage, UV availability, real source assets and
reproduction, dimensions/ranges and cache/team isolation. Prepare native before/
after nine-operator gallery, closeups, two simultaneous different teams, identity
switches, LOD changes, repeated configure/free and moving/pair-animation shots.
Pixel statistics/source checks cannot certify appearance or animation attachment.

Current exclusive heavy grant remains `FINISH-COMBINED-NATIVE-20261002-A`, held by
integration Astra `ses_f0294303bffed6Fb8UJLKe4ZDz`. These Sol workers run in the
background, source-only: no Godot/Blender/import/render/audio/encoding or nested
agents. Meta/Mistral are the first future fighting visual slice, then all nine.
