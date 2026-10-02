# Switchyard: authored robot workshop pack

Status: **actual production completed under grant ROBOT-ASSET-PRODUCTION-20261002-D**.
Seed `31027`. Nine real runtime GLBs, nine editable masters and three skeletal
reference GLBs are built/reopened/imported. See ACCEPTANCE for immutable stage
receipts, native captures, measured budgets and parent promotion handoff.

## Bodies

| Cosmetic identity | Existing model / roles | Authored anatomy |
| --- | --- | --- |
| Needle Surveyor | skirmisher; Horde lancer/spitter | Narrow split breastplate on a keel, offset ceramic survey counterweight, exposed rear spine, long piston bipod and light receiver |
| Caisson Guard | bulwark; Horde brute/bulwark | Broad crossbeam, ceramic shoulder laminates, suspended belly, short heavy bipod, three overlapping shield scutes and protected rear grip |
| Kiln Tender | mortar; Horde mortar | Low split-saddle quadruped, underside pressure hatch, service-fork artillery cradle, four distributed piston links |

These are skins, not new AI types or abilities. The tender's fork is tooling
around the existing artillery cradle, not an extra attack. Existing actors,
health, hit scales, shot origins, shield mitigation and tell events remain source-owned.

Common workshop language: teal enamel, recessed graphite mechanisms, satin steel
axles/fasteners, warm ceramic replaceable plates, cyan enclosed coolant, amber
status slit. RobotVisual's existing exposed/damage/telegraph optic overrides and
shield flash remain active. Team disposition stays with existing actor UI; this
pack does not infer hostile/friendly status from decorative paint.

Rear radiator, underside service panels, segmented cable harness, retaining studs,
parallel piston rods and bevelled plates are source-authored, not recolors of
the previous robot pack. LOD1 removes small harness/fastener work; LOD2 fuses
shins into hip assemblies exactly as the existing far-distance gait expects.
Visual quality at combat distance is a mandatory post-build review, not inferred
from this inventory or triangle counts.

## Rig / integration architecture

`tools/godot-robots/recipe.py` is pure deterministic source geometry. `build.py`
authors three assembled one-weight skeletons, five editable reference clips per
skin and six prop masters in `tools/godot-robots/masters/` **outside Godot**.
It also exports joint-local rigid meshes for the current native pipeline to
`godot/robot_assets/switchyard/generated/`. The skeletal inspection GLBs stay
beside the masters. This explicit adapter avoids extracting skinned mesh data
and losing skin transforms in RobotVisual's existing mesh replacement loader.

`skin_adapter.gd.install_role(robot)` is called by the Campaign and Horde factories
**after configure**, deterministically mapping the three supported roles.
It validates every assembly before any replacement, rejects mismatched model IDs
and absent exports, retains originals for restore, and leaves native pivots and
material overrides intact. Reapply after model identity changes. The helper
retains stock fallback for missing/unmapped art. `select_stock(robot)` explicitly
restores the baseline and disables automatic reinstallation. A three-line
RobotVisual hook re-applies an opted-in pack on identity changes; unmapped roles
restore the original untextured material. Do not subclass RobotVisual in the
shared factory: Horde uses exact `get_script() == RobotVisual` checks for stepping
and corpse processing. The small shared factory/terrain/identity hooks are isolated
in a separate integration commit for parent review.

Runtime animation remains the existing Godot pipeline: distance-based gait,
source-grounded two-link IK, bounded turret pitch, weapon attack/recoil, shield
windup/exposure, damage reaction and .8-second corpse lifetime. Runtime idle is
the existing planted pose; authored reference idle micro-motion is only in the
master clips. Native per-skin idle adoption, if desired, needs a reviewed hook
after engine acceptance; it is not currently connected. Reference walk clips
are editable pose studies, not claims of final foot planting; runtime Motion's
62%-stance solver supplies real contact.

## Secondary workshop props

Relay console, repair dock, battery rack, blast shutter frame, cargo stack and
cable junction share enamel/steel/ceramic materials and retaining fasteners.
Each exports one joined surface, reusable by PackedScene or MultiMesh installation.
They contain no physics or gameplay nodes. `workshop.gd` now installs all six as
shallow service fixtures on six explicitly named existing Emberline metal cover
faces. Fixture depth is normalized to .10m, projecting .115m from the existing
surface; source blocks remain visibly behind the open frame/dock. These are
wall service assemblies, not new doors, walkable crates or gameplay repair stations.
Their volumes remain editable/full-depth in the standalone GLBs. The native
rebuild test proves six deterministic mounts, no duplicates and no added collider.

Measured budgets and exact bytes are in ACCEPTANCE and the real package receipt.
No frozen source, hitbox, palette outside this pack, Parallax geometry, or other
production unit was modified. Smooth coating is the explicit Moth finish role;
normal textures are deliberately absent. The exported palette uses named `Col`
as COLOR_0, multiplied by real neutral Moth detail on the sole local UV channel.
