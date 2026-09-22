# Native DM geometry contract

Generated assets: `godot/native_arenas/generated/{prism-foundry,aurora-basin,cinder-array}.json`.
Envelope: `{schemaVersion:1,id,name,geometryHash,arena,spawnPoints,routes,colliderSources}`.
`geometryHash` is SHA-256 of canonical JSON of `arena` only: recursively sort object keys lexicographically, preserve array order, serialize with Node `JSON.stringify` number semantics. Envelope id/name exactly match arena id/name.
`arena` is the raw source Match arena dictionary: `id,name,bounds,spawns` (XZ pairs), `pickups` (kind/X/Z triples), `navNodes` (XZ pairs), `blocks`, `terrain:{maxSlope,surfaces,walls}`, `voidY`, `nextGen:false`.
`spawnPoints` contains `{x,y,z}` native feet positions; routes contain named sampled XYZ points. Runtime must use the envelope's `arena`, not the envelope itself.

Native map scripts: `res://native_arenas/maps/<id>.gd`; API `build()` (idempotent), `get_arena_id()`, `get_spawn_points()` (Array[Vector3]), `configure_dm()` (idempotent alias for build). Original exploration scenes remain available. Source gameplay uses one highest support per XZ: DM adaptations visibly fill underdeck/crown/tunnel overlaps and do not claim walk-under/walk-over support.

Geometry authoring and native/source parity verification are complete for the retained generated assets. The requested Aurora spatial-navigation optimization is awaiting the authority owner's schema adjustment; see NAVIGATION-INTEGRATION.md. The compiler requests `nextGen:true` for Aurora and refuses to publish it while the public validator requires false. README.md identifies blocked-volume probes, route checks, and integration limitations.
