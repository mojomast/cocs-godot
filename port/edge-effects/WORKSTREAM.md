# Edge hit detection, round impact marks and shader effects

Owner reports unreliable hit detection around edges and square borders on bullet
holes, and requests an Astra subagent to repair both and add weapon effects and
shaders. This extends the combined targeting/variety/animation update.

## Current resource grant

Physics Sol completed native acceptance and explicitly released all engine
processes. **Astra now has the exclusive Godot slot**, granted after final Sol
commit `cd15d7b3` (integrated as `c391b3d9`). Sol made no controller/FX production
changes during acceptance; Astra's implementation ownership is clear. Parent
remains engine-idle until Astra releases the slot.

## Ownership and resources

- Astra: `ses_f06b5ec31ffeX85Xf9bXNZguTV`, `openai/gpt-6-astra`.
- Branch: `improvement/edge-effects`, baseline `7f150681`.
- Worktree: `/home/mojo/.tmp-on-disk/cocs-edge-effects-20261001`.
- Evidence: `/home/mojo/.tmp-on-disk/cocs-edge-effects-evidence-20261001/`.
- Owns impact marks, impact/occlusion consistency, weapon FX/shaders and selected
  production world shader integration. Authority changes require a demonstrated
  defect and explicit port-owned provenance.
- **Research/code/Node only initially.** Physics Sol retains exclusive Godot until
  its explicit release. Parent grants Astra the slot afterward.
- Preserve Sol's casing gravity and any supplemental native fixes. First-person,
  vehicle, workshop and actor animation remain with their existing lanes.

## Acceptance

1. Reproduce edge failures on cover and actor silhouettes, distinguish source
   damage/collision from visual impact errors, and repair demonstrated causes.
   Include exact-edge, near-parallel, grazing, corner and inside/outside cases
   with cover-first ordering and fast projectile sweeps.
2. Render round/irregular bullet holes with transparent corners, proper surface
   alignment, depth and edge handling on bright/dark surfaces and grazing views.
   Verify the shipping Compatibility renderer and source-confirmed placement.
3. Add distinct, bounded weapon effects and purposeful shaders actually used in
   gameplay. Preserve readable aim/enemy tells, quality settings, finite pools,
   event deduplication and scene/pause cleanup.
4. Inspect rendered comparisons and source-event-backed shot results. Separate
   deterministic/native acceptance from human feel and hardware performance.

Existing public runtime `091b1333` predates these and the other pending passes.
Parent owns final integration, package closure, combined verification and release.
