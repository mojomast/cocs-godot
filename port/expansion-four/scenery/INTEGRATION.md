# Parent-owned integration hook

Pack/source commit: `36358d96`.

The separate composition commit adds one preload and four build lines to
`godot/campaign/terrain.gd`, immediately after the existing biome decorator.
It depends on `36358d96`; review/cherry-pick separately from the authored pack.
The production scene's normal terrain rebuild owns lifetime. The new adapter
only adds a child called `BiomeExpansionFour`; original terrain, structure,
facade collider and environment builders keep their existing order and ownership.

Until all six imported GLB files for a chapter exist, its pack load returns false
and the child remains empty. After a granted build the same hook supplies the
pack to the real campaign scene. The inspection runner also handles a parent
choosing to leave this hook unapplied by explicitly installing the same adapter
on the production world for matched art inspection.

Parent acceptance remains required before shipping newly built GLBs. Runtime
dependency closure includes `biomes/expansion/catalog.json`, `scenery_pack.gd`
and all accepted chapter GLBs. Masters and all runners are outside runtime export
ownership. Parent may bind `set_reduced_detail(bool)` to its shared quality
setting after native review; this lane does not edit shared settings/ambience.

Canonical campaign hashes and JSON recipe bytes are unchanged: placements are
new presentation metadata under a separate pack identity. A later source change
must update its real provenance and rerun matching source acceptance, not bypass
the adapter's chapter SHA checks.

No native acceptance is attached to this composition commit. Explicit engine
grant, build/reopen/import, production art inspection and connected walk/shot
checks are still pending; see `ACCEPTANCE.md` for exact commands.
