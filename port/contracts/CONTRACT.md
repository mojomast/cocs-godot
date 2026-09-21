# Shared implementation contract — v0.1

## Three-increment continuation contract

Lead owns this serial batch: (1) authoritative local death/respawn state and safe control gating, (2) bounded server-event combat feedback, (3) terminal round/connection cleanup and restart regression gates. Work is limited to godot/, tools/godot-dev/, port/ docs/reports; existing source gameplay, dependencies and nine-map source lock remain unchanged. Protocol remains v3 JSON, coordinates remain +Y up/-Z forward. Each increment receives native targeted tests and a separate commit; integration runs the full verifier. Synthetic lifecycle/event cases are explicitly marked and never described as live kills or respawns. Headless gates do not establish graphical acceptance. No push or deployment.

Source and exact nine-map allowlist: source-lock.json and map-selection.json. Source pin is the v8.8 DESTINATIONS deployed tree; branch main is descriptive, never a moving build input. The registry delta is against the parent of the authored DESTINATIONS commit. No old maps may become fallback content.

No subagent facility was exposed in this session; the lead performs lanes serially. Future agents: A owns tools/godot-export and generated content; B owns godot/world, presentation, ui, audio; C owns godot/net, simulation, protocol/simulation tests and tools/godot-fixtures. Lead owns contracts, project wiring, development launcher and all existing source/config edits. Shared game/server files remain unchanged.

Godot 4.5.2 stable official (6ce3de25a), Compatibility renderer, typed GDScript; corresponding 4.5.2 templates. One source unit = one metre, +Y up, -Z forward, quaternion xyzw in source/glTF; construct Godot Quaternion(x,y,z,w). No global mirror. Spawn arrays are [x,z], not [x,y,z]. Block h is top of zero-based solid; debug boxes are centred at y=h/2. Authoritative support is terrain triangles, not sampled terrain.height.

Semantic schema v1: {schema_version, omitted_optional_fields, source_map}. Every source-map root field survives. terrain.height is replaced by source support_triangles, wall_triangles and wall_segments, with original surfaces/maxSlope/void metadata retained. Only explicitly recorded structures[].color undefined is omitted to preserve the renderer-default meaning; helper triangle material:undefined is omitted. Other lossy types are errors. This is a diagnostic format, not a replacement Match input.

Manifest v1: pinned source, schema/exporter/Godot versions, coordinate convention and ordered map entries with id/name/modes/path/SHA256/bytes/counts/world_glb. world_glb is initially null. Content kind is semantic-diagnostic and release_ready=false until visual/resource and gameplay gates pass. Generated output is disposable, never hand-edited.

PortCatalog.open()->bool and resolve_map(id:String)->Dictionary fail closed. Viewer loads only catalog entries; semantic debug visuals must never be reported as original materials or complete fidelity. World load/unload owns a single replaceable Node3D root. Future presentation consumes decoded snapshots without becoming authoritative.

Wire: protocol 3, delta advertisement 0, JSON text WebSocket frames; 60Hz simulation, 30Hz snapshots. Actor identity comes from lobby.players[].actorId, not peer ID. Snapshot acks keys are strings. Prediction disabled. Validate requested map at configuration/lobby/start/state transitions, rejecting substitution. Explicit mode membership required before hosting. Race/soccer/LATTICE gameplay must not be silently replaced by infantry.

First geometry gate: real browser WebGL builder export, native Godot import and visual review. First playable gate remains separate: one native client with source server and bots, then two clients, pickup/death/respawn/results/restart. A diagnostic viewer or protocol smoke is not that gate.
