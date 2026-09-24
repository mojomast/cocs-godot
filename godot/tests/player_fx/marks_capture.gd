extends SceneTree
## Rendered evidence for the impact-FX lane (persistent marks + blast treatment).
##
## Real map geometry: the semantic catalog's meridian-exchange is built as meshes
## and confirmed through the composition's own occlusion (exactly the path the
## live game uses). The four-family gallery and the blast floor are explicit
## fixtures mirroring the existing player-fx capture harness, because the locked
## semantic maps do not contain every material family on one camera.
##
## Every scenario captures a clean baseline, a `before` frame with the new mark
## pool disabled (previous transient-flash behaviour) and an `after` frame with
## the full treatment, then measures changed pixels. Run under xvfb+llvmpipe:
##
##   xvfb-run -a -s "-screen 0 960x640x24" "$GODOT_BIN" --path godot \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://tests/player_fx/marks_capture.gd -- \
##     --size=960x640 --output=/path/to/port/native-impact-fx/evidence/render-x/960x640
const Feedback = preload("res://world/combat_feedback.gd")
const Rig = preload("res://first_person/rig.gd")
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
const Surface = preload("res://player_fx/surface.gd")
const MarkPool = preload("res://player_fx/mark_pool.gd")
const MarkShader = preload("res://player_fx/mark.gdshader")

const IMPACT_ROI := 110
const BLAST_ROI := 190

var size := Vector2i(960, 640)
var output := ""
var verified := 0
var measurements: Dictionary = {}
var failures: Array[String] = []
var label_text: Label
var context: Node3D
var feedback: Node3D
var label_prefix := ""
var next_id := 9000

class Watch:
	var value := false
	func stale() -> bool: return value

class Context extends Node3D:
	var camera := Camera3D.new()
	var rig: Node
	var client: Node
	var world := Node3D.new()
	var current_id := "meridian-exchange"
	var phase := 3
	var application_focused := true
	var snapshot_watch := Watch.new()
	func can_capture_pointer() -> bool: return true

func check(ok: bool, message: String) -> void:
	verified += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_MARKS_CAPTURE: " + message)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	create_timer(600.0).timeout.connect(func() -> void: push_error("PLAYER_FX_MARKS_CAPTURE watchdog"); quit(1))
	call_deferred("run")

func recorded(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func recorded_shot(id: int) -> Dictionary:
	var capture := recorded("res://tests/protocol/captured.json")
	for record: Dictionary in capture.frames:
		if record.get("direction") != "server": continue
		var frame: Variant = record.get("frame")
		if not frame is Dictionary or frame.get("type") != "events": continue
		for event: Variant in frame.get("items", []):
			if event is Dictionary and event.get("id") == id and event.get("type") == "shot": return event.duplicate(true)
	return {}

func color_for(family: String) -> Color:
	match family:
		"ice": return Color("a8dcec")
		"metal": return Color("8a97a8")
		"ground": return Color("8b7a5f")
		_: return Color("a8a196")

func build_map(parent: Node3D, catalog: Catalog, id: String) -> void:
	var map: Dictionary = catalog.resolve_map(id)
	for block: Dictionary in map.get("blocks", []):
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(block.w, block.h, block.d)
		node.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color_for(Surface.classify(map, "", str(block.get("kind", "")), false))
		node.material_override = material
		node.position = Vector3(block.x, block.h * 0.5, block.z)
		parent.add_child(node)

func capture(label: String, description: String, save_as := "") -> Image:
	label_text.text = "IMPACT FX · %s\n%s\nrecorded/source fixture events · real semantic map geometry · %dx%d" % [label, description, size.x, size.y]
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var name := label if save_as.is_empty() else save_as
	check(image.save_png(output.path_join("%s-%dx%d.png" % [name, size.x, size.y])) == OK, "saved " + name)
	return image

func difference(a: Image, b: Image, area: Rect2i) -> Dictionary:
	var changed := 0
	var total := 0.0
	var maximum := 0.0
	var rect := area.intersection(Rect2i(0, 0, size.x, size.y))
	var min_point := Vector2i(size.x, size.y)
	var max_point := Vector2i.ZERO
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta > 0.02:
				changed += 1
				min_point.x = mini(min_point.x, x)
				min_point.y = mini(min_point.y, y)
				max_point.x = maxi(max_point.x, x)
				max_point.y = maxi(max_point.y, y)
			total += delta
			maximum = maxf(maximum, delta)
	var bounds := Rect2i() if changed == 0 else Rect2i(min_point, max_point - min_point + Vector2i.ONE)
	return {"changed_pixels": changed, "mean_delta": total / float(maxi(1, rect.size.x * rect.size.y)),
		"max_delta": maximum, "changed_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}

func whole() -> Rect2i:
	return Rect2i(0, 0, size.x, size.y)

func roi_at(point: Vector3, radius: int) -> Rect2i:
	var screen: Vector2 = context.camera.unproject_position(point)
	return Rect2i(Vector2i(screen) - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2))

func reset_pool() -> void:
	feedback.impacts.reset()

func shot_event(at: Vector3, from: Vector3, actor: int = 1) -> Dictionary:
	next_id += 1
	return {"id": next_id, "type": "shot", "actor": actor, "hit": false,
		"from": {"x": from.x, "y": from.y, "z": from.z},
		"to": {"x": at.x, "y": at.y, "z": at.z}}

func explosion_event(at: Vector3, weapon: int, alt := false) -> Dictionary:
	next_id += 1
	var event := {"id": next_id, "type": "explosion", "weapon": weapon,
		"pos": {"x": at.x, "y": at.y, "z": at.z}}
	if alt: event["alt"] = true
	return event

func advance_seconds(node: Node3D, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var step := minf(remaining, 1.5)
		node.advance(step)
		remaining -= step

func run() -> void:
	check(not output.is_empty(), "output directory required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = size
	var catalog := Catalog.new()
	check(catalog.open(), "semantic catalog opens")

	context = Context.new()
	root.add_child(context)
	context.add_child(context.camera)
	context.add_child(context.world)
	context.client = Client.new()
	context.add_child(context.client)
	context.client.set_process(false)
	context.client.actor_id = 0
	var map_root := Node3D.new()
	context.world.add_child(map_root)
	build_map(map_root, catalog, "meridian-exchange")
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("0d1420")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c8d8e8")
	environment.environment.ambient_light_energy = 0.9
	context.world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.2
	context.world.add_child(sun)
	context.camera.current = true
	context.camera.fov = 75.0
	context.camera.position = Vector3(28.2, 3.4, -28.2)
	context.camera.look_at(Vector3(29.654, 0.6, -30.069))
	context.rig = Rig.new()
	context.add_child(context.rig)
	context.rig.attach_to(context.camera)
	context.rig.set_process(false)
	context.rig.reduced_motion = true
	label_text = Label.new()
	label_text.position = Vector2(28, 22)
	label_text.add_theme_font_size_override("font_size", 16)
	label_text.add_theme_color_override("font_color", Color("e8f4ff"))
	label_text.add_theme_color_override("font_shadow_color", Color.BLACK)
	label_text.add_theme_constant_override("shadow_offset_x", 2)
	label_text.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label_text)

	feedback = Feedback.new()
	context.add_child(feedback)
	feedback.set_process(false)
	feedback.audio_feedback.set_muted(true)
	# Ambient composition particles/sprites are other owners' visuals; hiding them
	# for the run keeps the measured pixel deltas about this lane's marks.
	feedback.world_particles.visible = false
	feedback.moth_effects.visible = false

	var local := {"id": 0, "x": 24, "y": 2.0, "z": -22, "health": 100, "maxHealth": 100, "dead": 0, "protection": 0, "yaw": 0, "pitch": 0, "weapon": 0, "grounded": true}
	var state := {"mapId": "meridian-exchange", "time": 1.0, "over": false, "actors": [local]}
	context.rig.apply_actor(local, true)
	context.rig.apply_aim(false)
	for step in range(80): context.rig.advance(1.0 / 60.0)
	context.camera.fov = float(context.rig.get_aim_state(75.0).fov)
	feedback.apply_state(state)
	check(feedback.occlusion.ready, "composition confirmed the semantic map")
	feedback.quality_controls.select_quality(2)
	check(int(feedback.impacts.mark_limit()) == 72, "composition wired F9 Extreme to the mark pool")

	measurements.rendering = {"method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"uniforms": _uniform_names()}

	# --- determinism probe ---------------------------------------------------
	var noise_a := await capture("noise", "determinism probe frame", "noise-a")
	var noise_b := await capture("noise", "determinism probe frame", "noise-b")
	measurements.noise_floor = difference(noise_a, noise_b, whole())

	# --- real map: recorded server shot 164 on the real foundation -----------
	var recorded: Dictionary = recorded_shot(164)
	check(not recorded.is_empty() and recorded.get("hit") == false, "recorded server shot loaded")
	var endpoint := Vector3(29.654, 0.6, -30.069)
	var recorded_roi := roi_at(endpoint, IMPACT_ROI)
	var recorded_clean := await capture("recorded-clean", "clean baseline before the recorded shot")

	feedback.impacts.marks.set_enabled(false)
	reset_pool()
	feedback.impacts.consume([recorded.duplicate(true)], 0)
	feedback.impacts.advance(0.04)
	measurements.recorded_before_counters = {"shown": int(feedback.impacts.counters.shown), "marks_placed": int(feedback.impacts.counters.marks_placed)}
	var recorded_before := await capture("recorded-before", "transient flash only (mark pool disabled): the previous behaviour")
	advance_seconds(feedback.impacts, 0.4)
	var recorded_before_settled := await capture("recorded-before-settled", "0.44 s later, mark pool disabled: the previous behaviour leaves nothing behind")
	feedback.impacts.marks.set_enabled(true)

	var first := recorded.duplicate(true)
	first.id = 8101
	reset_pool()
	feedback.impacts.consume([first], 0)
	feedback.impacts.advance(0.04)
	check(int(feedback.impacts.counters.marks_placed) == 1, "recorded shot placed one persistent mark")
	var recorded_after := await capture("recorded-after", "fresh persistent ground pock from the recorded server shot")
	advance_seconds(feedback.impacts, 0.36)
	var recorded_after_settled := await capture("recorded-after-settled", "0.4 s later: the flash is gone, the shader pock persists")
	measurements.recorded = {
		"clean_to_after": difference(recorded_clean, recorded_after, recorded_roi),
		"before_to_after": difference(recorded_before, recorded_after, recorded_roi),
		"before_to_after_settled": difference(recorded_before_settled, recorded_after_settled, recorded_roi),
		"whole_clean_to_after": difference(recorded_clean, recorded_after, whole()),
		"counters": feedback.impacts.snapshot().counters,
	}
	check(int(measurements.recorded.clean_to_after.changed_pixels) > 40,
		"recorded mark renders at the authoritative endpoint")
	check(int(measurements.recorded.before_to_after_settled.changed_pixels) > 40,
		"persistent mark renders after the previous transient flash would have vanished")

	# Aged mark: 75% through the documented lifetime.
	advance_seconds(feedback.impacts, feedback.impacts.mark_life() * 0.75 - 0.4)
	check(int(feedback.impacts.snapshot().marks_live) == 1, "mark still live at 75% of its lifetime")
	var recorded_aged := await capture("recorded-aged", "the same mark aged to 75% of its lifetime: faded, soot cooling")
	measurements.recorded_aged = {"settled_to_aged": difference(recorded_after_settled, recorded_aged, recorded_roi)}
	check(int(measurements.recorded_aged.settled_to_aged.changed_pixels) > 10, "aging visibly changes the mark")

	# --- material gallery: metal / stone / ice / ground ----------------------
	var fixture_blocks := [
		{"x": -6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "metal"},
		{"x": -2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "rock", "material": "stone"},
		{"x": 2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "ice"},
		{"x": 6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "tree", "material": "ground"},
		{"x": 0, "z": 0, "w": 30, "h": 0.4, "d": 30, "kind": "foundation", "material": "stone"}]
	var fixture_map: Dictionary = {"id": "impact-fx-gallery", "biome": "urban", "blocks": fixture_blocks}
	var fixture_query := Occlusion.new()
	check(fixture_query.configure(context.camera, fixture_map), "gallery occlusion configured")
	var gallery_root := Node3D.new()
	context.add_child(gallery_root)
	for block: Dictionary in fixture_blocks:
		var wall := MeshInstance3D.new()
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(block.w, block.h, block.d)
		wall.mesh = wall_mesh
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_color = color_for(str(block.material))
		wall.material_override = wall_material
		wall.position = Vector3(block.x, block.h * 0.5, block.z)
		gallery_root.add_child(wall)
	map_root.visible = false
	context.camera.position = Vector3(0, 2.4, -6)
	context.camera.look_at(Vector3(0, 2.0, 0))
	context.camera.fov = 85.0
	feedback.impacts.configure(context.camera, fixture_query)
	feedback.impacts.set_map(fixture_map)
	var face := -0.3
	var targets: Array[Vector3] = [Vector3(-6, 2.6, face), Vector3(-2, 2.6, face), Vector3(2, 2.6, face), Vector3(6, 2.6, face)]
	var shooter := Vector3(0, 2.0, -6)

	reset_pool()
	var materials_clean := await capture("materials-clean", "fixture baseline before the four-family gallery")
	feedback.impacts.marks.set_enabled(false)
	reset_pool()
	for target: Vector3 in targets:
		feedback.impacts.consume([shot_event(target, shooter)], 0)
	feedback.impacts.advance(0.04)
	var materials_before := await capture("materials-before", "four surfaces, transient flash only (previous behaviour)")
	feedback.impacts.marks.set_enabled(true)

	reset_pool()
	for target: Vector3 in targets:
		feedback.impacts.consume([shot_event(target, shooter)], 0)
	feedback.impacts.advance(0.04)
	check(int(feedback.impacts.snapshot().marks_live) == 4, "all four family marks are live")
	var families := {}
	for slot: Dictionary in feedback.impacts.marks.slots:
		if slot.remaining > 0.0: families[str(slot.family)] = true
	for family: String in ["metal", "stone", "ice", "ground"]:
		check(families.has(family), "gallery placed the " + family + " family")
	var materials_after := await capture("materials-after", "persistent metal/stone/ice/ground marks (Top: flash, Bottom: shader decal)")
	advance_seconds(feedback.impacts, 0.5)
	var materials_settled := await capture("materials-settled", "the same four marks after the flashes fade: shader damage alone")
	measurements.materials = {
		"clean_to_after": difference(materials_clean, materials_after, whole()),
		"before_to_after": difference(materials_before, materials_after, whole()),
		"clean_to_settled": difference(materials_clean, materials_settled, whole()),
		"counters": feedback.impacts.snapshot().counters,
	}
	check(int(measurements.materials.clean_to_after.changed_pixels) > 200,
		"material marks render across the four surfaces")

	# Close-up relief read on the stone wall (proves the pock is lit geometry).
	context.camera.position = Vector3(-2, 2.6, -1.5)
	context.camera.look_at(Vector3(-2, 2.6, 0))
	context.camera.fov = 70.0
	reset_pool()
	var relief_clean := await capture("relief-clean", "close-up baseline on the stone wall")
	feedback.impacts.consume([shot_event(Vector3(-2, 2.6, face), shooter)], 0)
	feedback.impacts.advance(0.04)
	var relief_after := await capture("relief-after", "close-up stone pock: dark dish, bright dust rim, radial cracks")
	advance_seconds(feedback.impacts, 0.5)
	var relief_settled := await capture("relief-settled", "close-up stone pock after the flash: the persistent shader damage alone")
	measurements.relief = {"clean_to_after": difference(relief_clean, relief_after, whole()),
		"clean_to_settled": difference(relief_clean, relief_settled, whole())}
	check(int(measurements.relief.clean_to_after.changed_pixels) > 400, "close-up pock renders its relief detail")
	check(int(measurements.relief.clean_to_settled.changed_pixels) > 400, "close-up pock persists after the flash")

	# --- wall edge: a corner-overhanging mark is skipped ---------------------
	context.camera.position = Vector3(0, 2.4, -6)
	context.camera.look_at(Vector3(0, 2.0, 0))
	context.camera.fov = 85.0
	var edge_point := Vector3(-4.55, 3.2, -0.31)
	var edge_roi := roi_at(edge_point, IMPACT_ROI)
	reset_pool()
	var edge_clean := await capture("edge-clean", "wall-edge baseline before the corner shot")
	feedback.impacts.marks.set_enabled(false)
	reset_pool()
	feedback.impacts.consume([shot_event(edge_point, shooter)], 0)
	feedback.impacts.advance(0.04)
	var edge_before := await capture("edge-before", "corner shot, transient flash only")
	feedback.impacts.marks.set_enabled(true)
	reset_pool()
	feedback.impacts.consume([shot_event(edge_point, shooter)], 0)
	feedback.impacts.advance(0.04)
	check(int(feedback.impacts.counters.marks_skipped_edge) == 1, "corner-overhanging mark was skipped, not drawn")
	check(int(feedback.impacts.counters.marks_placed) == 0, "no mark floated past the wall edge")
	var edge_after := await capture("edge-after", "corner shot with marks enabled: flash only, no floating decal")
	measurements.edge = {
		"clean_to_after": difference(edge_clean, edge_after, edge_roi),
		"before_to_after": difference(edge_before, edge_after, edge_roi),
		"counters": feedback.impacts.snapshot().counters,
	}
	check(int(measurements.edge.before_to_after.changed_pixels) == 0,
		"edge skips change zero pixels versus the previous behaviour")

	# --- blasts ---------------------------------------------------------------
	# Fixture explosion 1.2 m over the confirmed gallery floor. `before` has the
	# mark pool disabled (engine puff only); `after` adds scorch + shockwave.
	var blast_point := Vector3(0, 1.2, -1.0)
	var blast_floor := Vector3(0, 0.4, -1.0)
	var blast_roi := roi_at(blast_floor, BLAST_ROI)
	context.camera.position = Vector3(0, 3.4, -9)
	context.camera.look_at(Vector3(0, 0.8, -1.0))
	context.camera.fov = 80.0
	reset_pool()
	var blast_clean := await capture("blast-clean", "blast baseline over the confirmed floor")
	feedback.impacts.marks.set_enabled(false)
	reset_pool()
	feedback.impacts.consume([explosion_event(blast_point, 1)], 0)
	feedback.impacts.advance(0.05)
	var blast_before := await capture("blast-before", "explosion, mark pool disabled: engine puff only")
	feedback.impacts.marks.set_enabled(true)
	reset_pool()
	feedback.impacts.consume([explosion_event(blast_point, 1)], 0)
	feedback.impacts.advance(0.05)
	check(int(feedback.impacts.counters.scorches_placed) == 1, "explosion placed the scorch")
	check(int(feedback.impacts.counters.shockwaves_placed) == 1, "large blast placed the shockwave band")
	var blast_after := await capture("blast-after", "large blast: scorch + dust puff + shockwave band on the floor")
	advance_seconds(feedback.impacts, 0.9)
	var blast_settled := await capture("blast-settled", "the same blast 0.95 s later: puff and band gone, scorch remains")
	measurements.blast = {
		"clean_to_after": difference(blast_clean, blast_after, blast_roi),
		"before_to_after": difference(blast_before, blast_after, blast_roi),
		"before_to_settled": difference(blast_before, blast_settled, blast_roi),
		"counters": feedback.impacts.snapshot().counters,
	}
	check(int(measurements.blast.before_to_after.changed_pixels) > 300, "scorch + shockwave render on the confirmed floor")
	check(int(measurements.blast.before_to_settled.changed_pixels) > 150, "scorch persists after the puff fades")
	# Small blast: same floor, no shockwave band.
	reset_pool()
	var small := explosion_event(Vector3(1.5, 1.2, -1.0), 4)
	feedback.impacts.consume([small], 0)
	feedback.impacts.advance(0.4)
	var small_roi := roi_at(Vector3(1.5, 0.4, -1.0), BLAST_ROI)
	var blast_small := await capture("blast-small-after", "small (plasma) blast: scorch only, no shockwave band")
	measurements.blast_small = {"clean_to_after": difference(blast_clean, blast_small, small_roi),
		"shockwaves_placed": int(feedback.impacts.counters.shockwaves_placed)}
	check(int(feedback.impacts.counters.shockwaves_placed) == 0, "small blast added no shockwave")

	# --- recycled pool --------------------------------------------------------
	context.camera.position = Vector3(0, 2.4, -6)
	context.camera.look_at(Vector3(0, 2.0, 0))
	context.camera.fov = 85.0
	reset_pool()
	for index in range(140):
		var target: Vector3 = targets[index % targets.size()]
		feedback.impacts.consume([shot_event(target + Vector3(0, (index % 5) * 0.12 - 0.24, 0), shooter)], 0)
	var recycled := await capture("recycled-after", "140 shots into a 72-slot pool: oldest marks recycled, no pool growth")
	measurements.recycled = {"counters": feedback.impacts.snapshot().counters,
		"pool_nodes": feedback.impacts.marks.get_child_count(),
		"marks_live": int(feedback.impacts.snapshot().marks_live)}
	check(int(measurements.recycled.pool_nodes) == 72, "recycled pool never grew past the Extreme cap")
	check(int(measurements.recycled.counters.marks_recycled) > 0, "recycling is counted")
	check(int(measurements.recycled.marks_live) == 72, "recycled pool stays full")

	# --- F9 quality table: pool size, lifetime, submitted quads, frame cost ---
	var quality_table := {}
	for level in range(3):
		feedback.quality_controls.select_quality(level)
		check(int(feedback.impacts.mark_limit()) == int(MarkPool.LIMITS[level]), "F9 level %d wired to the mark pool" % level)
		reset_pool()
		var fill: int = int(MarkPool.LIMITS[level])
		for index in range(fill):
			feedback.impacts.consume([shot_event(targets[index % targets.size()], shooter)], 0)
		var frame_start := Time.get_ticks_usec()
		for step in range(60): feedback.impacts.advance(1.0 / 60.0)
		var frame_cost := float(Time.get_ticks_usec() - frame_start) / 60.0
		var level_image := await capture("quality-%s" % ["low", "high", "extreme"][level],
			"F9 %s: cap %d, lifetime %.0f s, %d live marks" % [["Low", "High", "Extreme"][level],
				int(feedback.impacts.mark_limit()), feedback.impacts.mark_life(), int(feedback.impacts.snapshot().marks_live)])
		quality_table[str(level)] = {
			"pool": feedback.impacts.marks.get_child_count(), "limit": int(feedback.impacts.mark_limit()),
			"life_seconds": feedback.impacts.mark_life(), "marks_live": int(feedback.impacts.snapshot().marks_live),
			"submitted_marks": int(feedback.impacts.snapshot().marks_live),
			"advance_us_per_frame": frame_cost,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"crack_detail": level > 0,
		}
		measurements["quality_%d" % level] = {"changed_pixels": difference(materials_clean, level_image, whole()).changed_pixels}
	# Baseline draw calls with the mark pool empty, same camera.
	reset_pool()
	await capture("quality-empty", "same camera, mark pool empty: draw-call baseline")
	measurements.quality_baseline = {
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	}
	measurements.quality = quality_table
	feedback.quality_controls.select_quality(2)

	# --- composition wiring: the real flush path feeds the marks ------------
	context.camera.position = Vector3(24, 2.0, -22)
	context.camera.look_at(Vector3(29.654, 0.6, -30.069))
	# Fresh public state: the composition's freshness watchdog drains after
	# 0.8 s without it, so this frame re-proves the live wiring. The gallery
	# rebound the impact owner, so rebind it to the real map the composition
	# still holds (same map key, so _configure_map does not redo it).
	state.time = 2.0
	feedback.apply_state(state)
	feedback.impacts.configure(context.camera, feedback.occlusion)
	feedback.impacts.set_map(catalog.resolve_map("meridian-exchange"))
	reset_pool()
	var wired := recorded_shot(164).duplicate(true)
	wired.id = 8600
	feedback.apply_events([wired], 0)
	feedback.flush_effects()
	check(int(feedback.impacts.counters.marks_placed) == 1, "composition flush_effects routes the shot to a mark")
	feedback._update_metrics()
	check(feedback.quality_controls.metrics.has("impact_marks_live"), "F10 metrics report impact_marks_live")
	measurements.wiring = {"marks_placed": int(feedback.impacts.counters.marks_placed),
		"impact_marks_live": feedback.quality_controls.metrics.get("impact_marks_live", -1),
		"impact_marks_recycled": feedback.quality_controls.metrics.get("impact_marks_recycled", -1),
		"impact_counters": feedback.quality_controls.metrics.get("impact_counters", "")}

	measurements.size = [size.x, size.y]
	measurements.checked = verified
	measurements.failures = failures
	FileAccess.open(output.path_join("measurements-%dx%d.json" % [size.x, size.y]), FileAccess.WRITE).store_string(JSON.stringify(measurements, "\t") + "\n")
	print("PLAYER_FX_MARKS_CAPTURE_%s size=%dx%d checks=%d failures=%d adapter=%s" % ["OK" if failures.is_empty() else "FAIL",
		size.x, size.y, verified, failures.size(), RenderingServer.get_video_adapter_name()])
	quit(0 if failures.is_empty() else 1)

func _uniform_names() -> Array:
	var names: Array = []
	for entry: Dictionary in MarkShader.get_shader_uniform_list():
		names.append(str(entry.get("name", "")))
	return names
