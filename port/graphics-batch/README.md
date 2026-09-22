# Native graphics development batch

Owner requested parallel implementation, then expanded scope to multiple new
maps, Moth scenery, shaders and massive-particle experiments, with autonomous
overnight continuation. This report is an in-progress integration record.

## Integrated first wave

Runtime composition at `a0db160`:

- All 101 exact baked Moth texture planes, bounded registry and native surface
  materials; original support triangles grouped by their material identity.
- Nine-map Compatibility atmosphere and texture-aware world materials.
- Ten source-derived first-person weapon GLBs, isolated rendering viewport,
  procedural hands, source-event recoil and authoritative reload presentation.
- Public-event Moth effects attached to existing combat feedback. The public
  actor array is read-only; boundary cleanup replaces its reference.
- Native-only exploration controller for the additional showcase maps. Existing
  combat scenes retain Node movement and gameplay authority.

`port/reports/verification.json`: **96 gates passed** after repairing detached
session initialization. `evidence/aggregate-first-failure/` retains the failure;
`evidence/integration-preflight/` retains an earlier indentation/import error.
The walker fixture's original exact floating-point comparison also failed; the
bounded-angle assertion now uses approximate equality, without runtime changes.

## Graphical and live evidence

`capture.py` records exact static overview/spawn camera pairs for all nine maps
at 960×640 and 1280×800. These are renderer fixtures, not gameplay runs.

- `evidence/baseline/`: original world appearance, 36 images and hashes.
- `evidence/textures-only/`: intermediate Moth material integration.
- `evidence/integrated-world/`: Moth materials plus atmosphere and corrected
  Compatibility vertex-color handling. Ember floors/roof undersides are readable;
  Tidal snow remains bright, with visible pattern detail.

The lead directly inspected integrated Ember 1280×800, Tidal/Sunscar/Asterion
960×640 and both centered live Meridian captures. Lane-level image reviews and
their exact scope remain in the individual handoffs. All captures here use Linux
OpenGL Compatibility/llvmpipe, not Windows graphics or hardware performance.

`live.py` stages a private project and launches an unchanged normal-rate Node
authority on its own loopback port. Test automation sends ordinary protocol input;
it never inserts simulation state. Each run reaches natural results and restarts:

| Run | Snapshots | Movement transitions | Public events | Starts |
|---|---:|---:|---:|---:|
| `live-meridian` | 1862 | 1512 | 5352 | 2 |
| `live-meridian-centered` | 1862 | 1810 | 5893 | 2 |

The first automated path wandered outside useful map framing. The second uses
ordinary steering toward the arena centre; both image pairs and full compressed
snapshot/event evidence are retained. These runs observed weapon0 only. Other
weapon switching/reload acceptance comes from `port/native-first-person/`, not
an invented claim about the shared live run. Full FX correlation, all mode-specific
graphics lifecycles and new maps/labs remain under integration review.

## Active expanded lanes

See `port/handoffs/ACTIVE_LANES.md` for exclusive ownership and branches:
Prism Foundry showcase, Aurora Basin, Cinder Array, massive particle laboratory,
Moth shader laboratory, existing-map Moth scenery, standalone launcher routes,
and independent shared-runtime review.

The new maps are additive native exploration scenes. The five planned native-only
routes do not create Node authorities or broaden the locked nine-map catalog.
Massive particle counts are explicit experiment settings with measured backend,
instance counts and frame-time results; normal combat defaults stay bounded.

## Remaining integration work

1. Review and integrate each remaining lane, preserving failures and provenance.
2. Complete scene/resource and lifecycle checks, inspect new maps at eye level,
   and report actual particle count/performance limits.
3. Rebuild after final runtime changes, inspect exact packaged resources, run
   native Windows verification and publish a new playable artifact when accepted.
4. Update the release matrix and ownership record with final evidence/status.

First intermediate Windows export succeeded; exact PCK was inspected with the
pinned **Linux release template** from an unrelated working directory. It resolved
all 101 Moth planes, ten weapon GLBs, nine maps and nine source scenes, with no
test/probe resources shipped. This is resource/export acceptance, not native
Windows graphics acceptance. Build provenance is retained in
`evidence/windows-first-export/`; the archive is not the final expanded-map demo.

Independent shared-runtime review found no P0/P1 issue. It identified missing
combined-arms infantry composition and a possible inherited terrain depth-priority
sign issue; both are delegated for bounded implementation/verification. Its stale
VFX documentation example now releases the public-actor reference without mutation.

Campaign remains deferred. The external pulse-rifle preview reservation and the
user's untracked procedural-model research remain preserved.
