extends SceneTree
## Persistent impact-mark contracts for the player FX lane.
##
## Covers only the new surface-damage system: the shader/mark pool exist and are
## preallocated, marks land on authority-confirmed surfaces (recorded server shot
## on the real semantic map), dedup, occlusion/far/edge skips, F9 caps and
## lifetimes, oldest-live recycling, explosion scorch + puff + shockwave, and the
## documented evidence-only enable switch. Nothing here asserts gameplay state.
const Impacts = preload("res://player_fx/impacts.gd")
const MarkPool = preload("res://player_fx/mark_pool.gd")
const Surface = preload("res://player_fx/surface.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
const MarkShader = preload("res://player_fx/mark.gdshader")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_MARKS: " + message)

func _initialize() -> void: call_deferred("run")

func recorded_shot(id: int) -> Dictionary:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	for record: Dictionary in capture.frames:
		if record.get("direction") != "server": continue
		var frame: Variant = record.get("frame")
		if not frame is Dictionary or frame.get("type") != "events": continue
		for event: Variant in frame.get("items", []):
			if event is Dictionary and event.get("id") == id and event.get("type") == "shot": return event.duplicate(true)
	return {}

func pool_nodes(impacts: Node3D) -> int:
	return impacts.marks.get_child_count()

## impacts.advance() clamps a single step to 2 s (matching the world frame
## contract); tests that span a whole lifetime must step through it.
func advance_seconds(impacts: Node3D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.5)
		impacts.advance(step)
		remaining -= step

func run() -> void:
	# --- resources -----------------------------------------------------------
	check(MarkShader != null, "mark shader resource loads")
	# Headless uses the dummy rasterizer, which parses but does not compile the
	# shader into a uniform list; the rendered capture harness asserts the live
	# uniform list. Here the source contract is checked directly.
	var source := FileAccess.get_file_as_string("res://player_fx/mark.gdshader")
	for key: String in ["uniform int family", "uniform int kind", "uniform float seed", "uniform float opacity",
			"uniform float age", "uniform float detail", "uniform float progress", "damage_height"]:
		check(source.contains(key), "mark shader source declares " + key.split(" ")[-1])

	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(24, 2.0, -22)
	camera.look_at(Vector3(29.654, 0.6, -30.069))
	var impacts: Node3D = Impacts.new()
	root.add_child(impacts)
	var catalog := Occlusion.Catalog.new()
	check(catalog.open(), "catalog opens")
	var map: Dictionary = catalog.resolve_map("meridian-exchange")
	var query := Occlusion.new()
	check(query.configure(camera, map), "semantic map configured")
	impacts.configure(camera, query)
	impacts.set_map(map)

	# --- documented F9 caps and lifetimes ------------------------------------
	check(impacts.mark_limit() == 44 and is_equal_approx(impacts.mark_life(), 14.0), "High defaults: 44 marks, 14 s")
	impacts.set_quality(0)
	check(impacts.mark_limit() == 20 and is_equal_approx(impacts.mark_life(), 6.0), "Low: 20 marks, 6 s")
	impacts.set_quality(1)
	impacts.set_quality(2)
	check(impacts.mark_limit() == 72 and is_equal_approx(impacts.mark_life(), 22.0), "Extreme: 72 marks, 22 s")
	var preallocated := pool_nodes(impacts)
	check(preallocated == 72, "Extreme preallocates the whole mark pool")

	# --- recorded server shot on real map geometry ---------------------------
	impacts.reset()
	check(impacts.snapshot().marks_live == 0, "reset drains live marks")
	var recorded: Dictionary = recorded_shot(164)
	check(not recorded.is_empty(), "recorded server shot loaded")
	impacts.consume([recorded], 0)
	check(int(impacts.counters.shown) == 1, "recorded shot still draws its burst")
	check(int(impacts.counters.marks_placed) == 1 and int(impacts.counters.marks_live) == 1,
		"recorded shot places exactly one persistent mark")
	check(impacts.snapshot().marks_live == 1 and impacts.snapshot().mark_kind == MarkPool.POCK,
		"snapshot reports the live pock")
	check(impacts.last_family == Surface.GROUND, "mark family follows the authoritative surface")
	# The mark quad lies in the confirmed plane, offset along the normal.
	var live_slot := {}
	for slot: Dictionary in impacts.marks.slots:
		if slot.remaining > 0.0: live_slot = slot
	check(not live_slot.is_empty(), "mark slot is live")
	if not live_slot.is_empty():
		var node: MeshInstance3D = live_slot.node
		var normal: Vector3 = node.global_transform.basis.z
		check(absf(normal.y) > 0.9, "ground mark normal is vertical")
		check(node.visible, "mark node visible")
		check(node.material_override is ShaderMaterial and node.material_override.shader == MarkShader,
			"mark uses the dedicated ShaderMaterial")
	impacts.consume([recorded], 0)
	check(int(impacts.counters.marks_placed) == 1 and int(impacts.counters.deduped) == 1,
		"replayed public ID never places a second mark")

	# --- no per-impact allocation -------------------------------------------
	var nodes_before := pool_nodes(impacts)
	var effects_before: int = impacts.effects.size()
	for index in range(200):
		impacts.consume([{"id": 2000 + index, "type": "shot", "actor": 3, "hit": false,
			"from": {"x": 24, "y": 2.0, "z": -22}, "to": {"x": 29.654, "y": 0.6, "z": -30.069}}], 0)
	check(pool_nodes(impacts) == nodes_before, "placing many marks never grows the pool")
	check(impacts.effects.size() == effects_before, "placing many marks never grows the burst pool")
	check(int(impacts.counters.marks_live) <= impacts.mark_limit(), "live marks stay inside the cap")
	check(int(impacts.counters.marks_recycled) > 0, "a full pool recycles the oldest mark")
	check(impacts.snapshot().marks_live == impacts.mark_limit(), "recycling keeps the pool full, not over")

	# --- occlusion, behind-viewer and distance skips -------------------------
	var blocks := [
		{"x": 0, "z": 0, "w": 10, "h": 5, "d": 1, "kind": "building"},
		{"x": 0, "z": 6, "w": 10, "h": 5, "d": 1, "kind": "building"},
		{"x": 0, "z": 100, "w": 10, "h": 5, "d": 1, "kind": "building"}]
	var wall_map: Dictionary = {"id": "fixture", "blocks": blocks}
	var wall_query := Occlusion.new()
	check(wall_query.configure(camera, wall_map), "occlusion fixture configured")
	camera.position = Vector3(0, 2.5, -5)
	camera.look_at(Vector3(0, 2.5, 6))
	impacts.reset()
	impacts.configure(camera, wall_query)
	impacts.set_map(wall_map)
	var behind_wall: Dictionary = {"id": 3001, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}
	impacts.consume([behind_wall], 0)
	check(int(impacts.counters.marks_skipped_occluded) == 1 and int(impacts.counters.marks_placed) == 0,
		"an occluded contact is never marked")
	camera.position = Vector3(0, 2.5, 4)
	camera.look_at(Vector3(0, 2.5, 10))
	var visible_shot := behind_wall.duplicate(true)
	visible_shot.id = 3002
	impacts.consume([visible_shot], 0)
	check(int(impacts.counters.marks_placed) == 1, "the same contact in view is marked")
	var far_shot := visible_shot.duplicate(true)
	far_shot.id = 3003
	far_shot["to"] = {"x": 0, "y": 2.5, "z": 99.5}
	impacts.consume([far_shot], 0)
	check(int(impacts.counters.marks_skipped_far) == 1 and int(impacts.counters.marks_placed) == 1,
		"an over-distance contact is never marked")

	# --- wall edge: shrink once or skip, never draw floating past the edge ----
	# A mark centred on the top-right corner of a small wall block cannot fit at
	# full or half size in any orientation: the contract is "skip, counted".
	var edge_blocks := [{"x": 0, "z": 6, "w": 2, "h": 2, "d": 1, "kind": "building"}]
	var edge_map: Dictionary = {"id": "edge-fixture", "blocks": edge_blocks}
	var edge_query := Occlusion.new()
	check(edge_query.configure(camera, edge_map), "edge fixture configured")
	camera.position = Vector3(0.95, 1.95, 3.0)
	camera.look_at(Vector3(0.95, 1.95, 5.5))
	impacts.reset()
	impacts.configure(camera, edge_query)
	impacts.set_map(edge_map)
	var edge_before := int(impacts.counters.marks_placed)
	var edge_skipped_before := int(impacts.counters.marks_skipped_edge)
	var edge_shot: Dictionary = {"id": 3100, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0.95, "y": 1.95, "z": 3.0}, "to": {"x": 0.95, "y": 1.95, "z": 5.5}}
	impacts.consume([edge_shot], 0)
	var placed_now := int(impacts.counters.marks_placed) - edge_before
	var skipped_now := int(impacts.counters.marks_skipped_edge) - edge_skipped_before
	check(placed_now + skipped_now == 1, "a wall-edge contact is either shrink-marked or skipped")
	check(skipped_now == 1, "a corner-overhanging mark is skipped instead of floating past the edge")

	# --- lifetime and retirement --------------------------------------------
	# Back on the wide fixture wall, in view, so the shot is a real contact.
	camera.position = Vector3(0, 2.5, 4)
	camera.look_at(Vector3(0, 2.5, 10))
	impacts.reset()
	impacts.configure(camera, wall_query)
	impacts.set_map(wall_map)
	var lifetime: float = impacts.mark_life()
	impacts.consume([{"id": 3200, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}], 0)
	var created := int(impacts.counters.marks_placed)
	check(created == 1 and impacts.snapshot().marks_live == 1, "fresh mark is live")
	advance_seconds(impacts, lifetime * 0.5)
	check(impacts.snapshot().marks_live == 1, "mark lives through half its documented lifetime")
	advance_seconds(impacts, lifetime * 0.6)
	check(impacts.snapshot().marks_live == 0, "mark retires at the end of its documented lifetime")
	check(int(impacts.counters.marks_expired) == 1, "retirement is counted")
	var hidden := true
	for slot: Dictionary in impacts.marks.slots:
		if slot.node.visible: hidden = false
	check(hidden, "retired mark nodes are hidden")

	# --- F9 quality shrink/grow without leaking ------------------------------
	var high_nodes := pool_nodes(impacts)
	impacts.set_quality(0)
	check(pool_nodes(impacts) == 20 and impacts.mark_limit() == 20, "Low shrinks the mark pool to 20 nodes")
	impacts.set_quality(2)
	check(pool_nodes(impacts) == 72 and impacts.mark_limit() == 72, "Extreme restores 72 nodes")
	check(high_nodes == 72, "no hidden duplicate nodes survive a quality switch")

	# --- explosion treatment -------------------------------------------------
	camera.position = Vector3(0, 3.0, -6)
	camera.look_at(Vector3(0, 0, 0))
	var floor_blocks := [{"x": 0, "z": 0, "w": 30, "h": 0.4, "d": 30, "kind": "foundation"}]
	var floor_map: Dictionary = {"id": "blast-fixture", "blocks": floor_blocks}
	var floor_query := Occlusion.new()
	check(floor_query.configure(camera, floor_map), "blast floor fixture configured")
	impacts.reset()
	impacts.configure(camera, floor_query)
	impacts.set_map(floor_map)
	var explosion: Dictionary = {"id": 4001, "type": "explosion", "weapon": 1, "pos": {"x": 0, "y": 1.6, "z": 0}}
	impacts.consume([explosion], 0)
	check(int(impacts.counters.blasts_seen) == 1, "explosion event seen")
	check(int(impacts.counters.scorches_placed) == 1, "explosion places one scorch on the confirmed floor")
	check(int(impacts.counters.shockwaves_placed) == 1, "large blast adds the shockwave band")
	check(int(impacts.counters.puffs) == 1, "explosion adds the dust puff")
	check(impacts.snapshot().blast == "large", "Rocket Launcher blast classifies as large")
	var scorch_slot := {}
	for slot: Dictionary in impacts.marks.slots:
		if slot.remaining > 0.0 and slot.kind == MarkPool.SCORCH: scorch_slot = slot
	check(not scorch_slot.is_empty() and float(scorch_slot.size) >= 2.0, "scorch uses the large blast size")
	if not scorch_slot.is_empty():
		check(absf(scorch_slot.node.global_position.y - 0.4) < 0.08, "scorch sits on the confirmed floor plane")
	var ring_slot := {}
	for slot: Dictionary in impacts.marks.slots:
		if slot.remaining > 0.0 and slot.kind == MarkPool.RING: ring_slot = slot
	check(not ring_slot.is_empty() and float(ring_slot.life) <= 1.0, "shockwave band is short-lived")
	var small: Dictionary = {"id": 4002, "type": "explosion", "weapon": 4, "pos": {"x": 1, "y": 1.6, "z": 0}}
	impacts.consume([small], 0)
	check(int(impacts.counters.shockwaves_placed) == 1, "small blast never adds a shockwave")
	check(int(impacts.counters.scorches_placed) == 2, "small blast still scorches the floor")
	# No floor below the blast: nothing is fabricated.
	var void_map: Dictionary = {"id": "void-fixture", "blocks": []}
	var void_query := Occlusion.new()
	check(not void_query.configure(camera, void_map), "empty fixture is not a map (ready false)")
	var death_map: Dictionary = {"id": "death-fixture", "blocks": floor_blocks}
	var death_query := Occlusion.new()
	death_query.configure(camera, death_map)
	impacts.configure(camera, death_query)
	impacts.set_map(death_map)
	impacts.consume([{"id": 4003, "type": "death", "actor": 2, "style": "headpop", "weapon": 0,
		"pos": {"x": 0, "y": 1.0, "z": 0}}], 0)
	check(int(impacts.counters.death_scorches) == 0, "a non-burning death never scorches the ground")
	impacts.consume([{"id": 4004, "type": "death", "actor": 2, "style": "combust", "weapon": 1,
		"pos": {"x": 0, "y": 1.0, "z": 0}}], 0)
	check(int(impacts.counters.death_scorches) == 1, "an authoritative fire death leaves a scorch")
	check(impacts.snapshot().blast == "death", "snapshot names the death scorch")

	# --- evidence-only enable switch ----------------------------------------
	camera.position = Vector3(0, 2.5, 4)
	camera.look_at(Vector3(0, 2.5, 10))
	impacts.reset()
	impacts.configure(camera, wall_query)
	impacts.set_map(wall_map)
	impacts.marks.set_enabled(false)
	impacts.consume([{"id": 4100, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}], 0)
	check(int(impacts.counters.marks_placed) == 0 and int(impacts.counters.shown) == 1,
		"the capture switch suppresses marks while the burst still draws")
	impacts.marks.set_enabled(true)

	# --- reset permits a fresh round's reused IDs ---------------------------
	impacts.reset()
	check(impacts.snapshot().marks_live == 0 and int(impacts.counters.marks_placed) == 0, "reset drains marks and counters")
	impacts.consume([{"id": 4200, "type": "shot", "actor": 3, "hit": false,
		"from": {"x": 0, "y": 2.5, "z": -2}, "to": {"x": 0, "y": 2.5, "z": 5.5}}], 0)
	check(int(impacts.counters.marks_placed) == 1, "fresh round accepts a reused ID once")

	impacts.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_MARKS_OK checks=", checks)
	else:
		print("PLAYER_FX_MARKS_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
