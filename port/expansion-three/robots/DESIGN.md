# Switchyard: authored robot workshop pack

Status: **READY FOR BLENDER** (source only). Seed `31027`. No asset exports,
masters, screenshots, engine imports, or runtime selection have been produced.
Parallax owns the heavy slot per BRIEF; wait for explicit parent grant.

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

`skin_adapter.gd.install(robot, skin)` is called explicitly **after configure**.
It validates every assembly before any replacement, rejects mismatched model IDs
and absent exports, retains originals for restore, and leaves native pivots and
material overrides intact. Reapply after model identity changes. The helper
does not register skins globally or touch shared factories. Parent may expose
local selection when assets pass acceptance. Do not subclass RobotVisual in the
shared factory: Horde uses exact `get_script() == RobotVisual` checks for stepping
and corpse processing. No shared integration commit is necessary at this stage.

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
They contain no physics or gameplay nodes. Installation is optional and deferred:
solid dressings must sit within reviewed existing geometry; open frame/dock
clearances remain visibly and physically open. No invisible blocker is authored.

Targets (not measurements): robots 14k/8.5k/5.5k triangles and 13/13/9 draws by
LOD; props <=3k triangles, one draw each, <=24 instances per workshop. Real
receipt checks and gameplay cost measurements must precede acceptance.
