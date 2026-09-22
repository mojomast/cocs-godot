# Native actor and pickup presentation

Implemented on `native-entity-presentation`, based on `d06b681`.

## Visible changes

- Actors are compact armored operators with separated limbs, helmet/visor,
  backpack, and a forward-facing generic primitive carbine. Character palettes
  follow the existing nine character colors; unknown characters use neutral gray.
- Team 0/red and team 1/blue override armor while preserving character-colored
  visors/badges. One/two chest stripes also distinguish the teams. Numeric wire
  values, including Godot JSON floats, and string team IDs are supported.
- Health: green medical case and white cross. Armor: blue pointed shield.
  Rockets: orange-tipped twin rockets. Other weapons: gold supply cells.
  Powerups: violet crystal. Close-range, depth-tested labels identify exact kinds.
- All geometry/materials are new GDScript-generated work; no model download,
  texture dependency, exporter change, or reserved pulse-rifle asset is involved.

## Contracts retained

Actor roots remain `Node3D`s in `actors`, centered at source `y + 0.9`, with
1.8 m vertical bounds and 0.7 m body width. Forward is -Z and follows body yaw.
The small weapon projects forward of the body. Authority/lifecycle visibility,
self hiding, remote interpolation, local actor dictionaries, HUD strings, and
snapshot counters retain their existing paths. HUD number formatting is unchanged.

Pickup roots remain stable through positive-wait hiding and authoritative return,
including snapshot reorder. Their child geometry is also retained when kind is
unchanged. Missing IDs are still removed; round reset frees everything. No local
timer, collision, pickup rule, or actor animation was introduced. Labels cull at
12 m and honor depth. Identity changes update existing actor materials; an
authoritative pickup kind change rebuilds children without replacing its root.

## Verification

Pinned binary: `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`.

All five tests exit 0; full output is in [tests.txt](tests.txt):

| Test under `godot/tests/protocol/` | Result |
| --- | --- |
| `presentation.gd` | 6 recorded states, 1 results state |
| `local_lifecycle.gd` | 15 checks |
| `pickups.gd` | 374 checks across 6 recorded states + synthetic lifecycle |
| `remote_motion.gd` | 14 checks |
| `entity_visuals.gd` | 52 focused checks |

The new checks cover bounds/cardinal orientation, material isolation and wire team
identity, zero-health hiding, self visibility, stable actor/pickup geometry,
authoritative-only pickup return, kind replacement, label depth/range, and cleanup.

## Actual images, inspected with the image-read tool

- [composition.png](composition.png): **controlled render fixture**, explicitly
  labeled in-image. Production presentation classes arranged for close inspection;
  front, three-quarter, side, rear, team identities and all five pickup forms.
- [native-pickup.png](native-pickup.png): actual shipped native session on a private
  loopback authority. A marksman supply pickup is visible at about 3.44 m after
  ordinary input-driven movement. Snapshot 56, 3 actors, 20 pickups, healthy local.
- [native-actor.png](native-actor.png): same native session, looking toward a live
  remote operator about 15.78 m away. Snapshot 87. The close marksman pickup also
  demonstrates labels/forms against the arena backdrop.

These images establish presentation, not a new collection/death/respawn acceptance
claim. The native session uses the baseline diagnostic environment and HUD; the
environment/setup agents' later changes are not included. Native capture output is
in [native.txt](native.txt). The only renderer warning is unsupported V-Sync under
llvmpipe. The fixture output is in [render.txt](render.txt).

## Reproduce and integrate

With existing generated semantic assets and dependencies available, run from repo
root:

```sh
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 node port/native-entity-presentation/capture.mjs
```

The small capture runner owns an isolated Xvfb abstract socket, temporary HOME/XDG
directories, loopback server, and Godot processes. It bounds child lifetime and
cleans them up. Native spawn/AI positions vary between runs. It uses the shipped
session and only supplies normal mouse/key input; no snapshot or position edits.
Generated assets and Node dependencies were read through symlinks to the primary
checkout; no shared display or package installation was used.

Integration surface: only `presentation.gd` and `pickups.gd` gain visual factory
calls; the new scripts must travel with them. Actor roots are now composite
`Node3D`s rather than `MeshInstance3D`s, as allowed by the documented API and tests.
Consumers should use the root transform/visibility, not assume a root `.mesh`.
Crowd-scale draw-call optimization and animated locomotion remain future work.
