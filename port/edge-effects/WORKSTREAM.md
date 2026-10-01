# Edge hit detection, round impact marks and shader effects

Owner reports unreliable hit detection around edges and square borders on bullet
holes, and requests an Astra subagent to repair both and add weapon effects and
shaders. This extends the combined targeting/variety/animation update.

## Current resource grant

Runtime **`1c1f6e34607cd1935629009dcfe2a9ae9316271a`** exported successfully
for both platforms. All 1,647 shared build inputs and generated resources match.
Fresh Linux extraction passed 23 base + 44 expansion cases. Windows additional
original-launcher Crown workflow `36936475680` passed 3/3 instrumented starts;
trace teardown observations are retained. Full Windows suite `36936434712` is
still pending. Release `quiet-relay-targeting-animation-2026-10-01` remains draft.

Exported Linux Crown compact capture passed on unchanged archive attempt two.
Attempt one's long-subtitle mask left only 14 unoccluded gun pixels (11 matches),
too few for a stable composition comparison. The external fixture now requests
the existing HUD-free supplemental proof below 100 unoccluded pixels, retaining
its strict >100 opaque / >80% matching proof requirement. Parent inspected the
gameplay, supplemental and ending images. This test-only correction does not
change exported bytes. Both attempts remain in combined evidence `packaged-capture/`.

Combined canonical acceptance finished: **333/337 initially passed**, with four
fixture issues corrected and **4/4 focused reruns passing**. The fixes free the
new detached interlude director, update native collision expectations to the
reviewed rock-box/facade-triangle contract, and select the original Rootfall mast
by authored site instead of the first decorative wreck node. No runtime fix was
needed for these failures. Initial aggregate, all logs and focused receipts are
preserved in `/home/mojo/.tmp-on-disk/cocs-combined-update-evidence-20261001/`.
This is not an all-green-first-run claim. Parent now owns export and platform
acceptance; every agent has released the engine.

**Implemented and integrated:** Astra `6700aac1` is parent `4d700437`.
Astra released all engine processes. Parent owns the serialized engine for the
combined canonical run, packaging and extracted-platform acceptance.

Confirmed causes: campaign facade-containing boxes blocked visible air; blocked
muzzle events carried the camera actor candidate; an 18cm cover impact was
suppressed by a 60cm cue cutoff; the square border came from a uniform dust quad.
The implementation adds campaign facade-triangle weapon cover, corrected event
classification, real contact queries, radial effects and four production shader
families. Parent reviewed `review-final.png` and published it and the paired
square/round images plus source wall mark to the existing gallery release.

Lane acceptance: 52 Node tests, 1,041 source/native structural-face comparisons,
239 all-weapon effect checks, and 366 Compatibility checks including 72 pixel
mask cases. Parent added explicit facade JSON/module package provenance and
canonical source/native/render gates. Package manifest/closure tests passed
47/47 after repairing two newly exposed data-inventory/rederivation omissions;
all three attempt logs are retained under `/tmp/opencode/edge-package-closure-tests*`.

Combined canonical verification is running from `33b6016e`, with keep-going
enabled and log `/tmp/opencode/combined-animation-edge-verification.log`.
No new game archive has yet been published. The following grant notes are history.

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
