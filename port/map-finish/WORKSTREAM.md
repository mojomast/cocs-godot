# Sol map surface and environment finishing

Owner explicitly requested Sol subagents to apply proper surface texturing, Moth
environments, variation, wear, signage and missing visual details to the new maps.
Four `openai/gpt-6.1-sol` workers are running in the background, with no nested
agents. The implementation contract is [CONTRACT.md](CONTRACT.md).

| Lane | Session | Branch | Owned result |
|---|---|---|---|
| Shared runtime | `ses_f022e500bffebtq1Cb9LHX7oqY` | `map-finish/shared-20261002` | Real Moth material binding, scenery/sign helpers, detail settings, bounded cleanup, resource/coverage diagnostics, minimal loader integration |
| Helix | `ses_f022dd12bffeowq5P2KYPvHqS6` | `map-finish/helix-20261002` | Botanical arcology surfaces, damp garden/patinated irrigation detail, clean archive treatment, pollen and district wayfinding |
| Gravemill | `ses_f022d579affe0tLGkayHYC5L7O` | `map-finish/foundry-20261002` | Crusher abrasion, cooling deposits, assay finishes, furnace soot/heat wear, industrial signage and bounded dust/ash/vents |
| Parallax | `ses_f022cb9dfffewAyp3OA0X1br9y` | `map-finish/parallax-20261002` | Coastal weathering, calibrated instrument finishes, differentiated archive/pump dressing, scientific labels and restrained environmental detail |

Worktrees are `/home/mojo/.tmp-on-disk/cocs-map-finish-<lane>-20261002`.
Shared/Helix/Foundry start at `3d2a4901`. Parallax starts from its isolated map
branch with the same contract cherry-picked as `cb224bcb`; its original assets
and bounded interior revision remain isolated until reviewed production acceptance.

## Real baseline and acceptance

Parent parsed actual production GLBs: Helix has ten materials, Gravemill eight,
Parallax seven; all have zero image textures. Custom map loading bypasses the
usual Moth surface/scenery pass. Architecture acceptance did not cover this gap.

Use existing baked Moth pixels, normal/data maps and world-space triplanar material
families to avoid unnecessary geometry/UV rebuilds. Colour replacement alone is
insufficient. Every surface needs a resolved assignment or a documented intentional
exclusion. Wear and environmental placements must match real geometry and usage;
signage must be useful and readable, not merely decorative text scattered in space.

Workers own independent map profiles/assets; the shared worker owns the common
binder. Preserve original GLBs/masters, source collision, verified routes, vehicle
clearance and prior evidence. Inspect missing detail within the requested visual
finish scope, with bounded additions rather than restarting map architecture.

**Current heavy owner remains the integration Astra**, grant
`FINISH-COMBINED-NATIVE-20261002-A`. The four Sol workers are source-only until an
explicit serial grant. Real native before/after district views, player-height
closeups, low/full detail, gameplay readability and teardown/reload are required
before calling the finish accepted. Frame capture cadence is not GPU performance.

## First source handoffs

Helix `9a4f0033` is merged as `04a141e2`: nine opaque material assignments,
intentional glass preservation, 46 face-mounted panels, 13 signs and 48 pollen
motes. Its validator resolves 32 actual Moth PNG resources and checks quad corners
against GLB triangles, plus six negative probes. Foundry `7ed49f44` is merged as
`5894f0c9`: eight material assignments, 37 panels, 20 signs and 32 localized motes;
1,425 footprint samples and exported-face mount checks passed on the lane.

Both use v1 profiles and preserve accepted geometry/assets. Shared owner received
the actual commits for binder integration and Helix's soft wear-mask extension
request. Native finished appearance, detail switching and lifecycle remain unrun.
