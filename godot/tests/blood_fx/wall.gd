extends Node3D
## Rendered wall-spatter fixture on a REAL locked map (meridian-exchange) using the
## normal world/viewer.gd arena renderer, not a laboratory stage.
##
## Arranged source fixture, never live gameplay: a remote operator is hit and then
## killed 1.2 m in front of a real 11.5 x 7 m building wall, with the camera 6 m
## back on the wall's face side, then the camera moves behind the wall for the
## far-side negative control. Reports floor vs wall marks per event, wall-region
## changed pixels, and the rendered cost of a stain-heavy frame.
##
##   godot --path godot --rendering-method gl_compatibility --resolution 960x640 \
##     res://tests/blood_fx/wall.tscn -- --width=960 --height=640 --output=/abs/prefix

const Viewer = preload("res://world/viewer.gd")
const Controller = preload("res://blood_fx/controller.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")

const MAP_ID := "meridian-exchange"
## Real block: x [-11.5, 0], y [0, 7], z [-28.0, -27.4] (kind "building").
## The body stands at z = -26.2, so z = -27.4 is the face it sees.
const WALL_FACE_Z := -27.4
const WALL_MIN_X := -11.3
const WALL_MAX_X := -0.3
const WALL_MIN_Y := 0.15
const WALL_MAX_Y := 6.6
const VICTIM := Vector3(-5.8, 0.0, -26.2)
const SHOOTER := Vector3(-5.8, 0.0, -21.4)
const FRONT_CAMERA := Vector3(-5.8, 2.3, -21.4)
const BACK_CAMERA := Vector3(-3.0, 2.0, -30.0)

var viewer := Viewer.new()
var controller := Controller.new()
var label := Label.new()
var prefix := ""
var width := 960
var height := 640
var quality := "High"
var phase := 0
var elapsed := 0.0
var busy := false
var serial := 400
var clean_front: Image
var hit_shot: Image
var death_shot: Image
var stains_only: Image
var clean_back: Image
var clean_back_repeat: Image
var back_after: Image
var samples := PackedFloat64Array()
var sampling := false
var sampled_live := 0
var front_quad := PackedVector2Array()
var back_quad := PackedVector2Array()
var draw_calls_clean := 0
var draw_calls_live := 0
var draw_calls_spatter := 0
var death_marks_dump: Array = []
var spatter_marks_dump: Array = []
var wall_pixel_probe: Dictionary = {}
var record: Dictionary = {}
var marks_before: Dictionary = {}
var per_event: Array = []

var schedule := [0.16, 0.40, 0.70, 1.10, 1.45, 1.60, 1.95, 2.20, 2.60, 2.75]


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): prefix = arg.trim_prefix("--output=")
		if arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		if arg.begins_with("--quality="): quality = arg.trim_prefix("--quality=")
	get_window().size = Vector2i(width, height)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Engine.max_fps = 20
	Engine.time_scale = 0.12
	add_child(viewer)
	if not viewer.load_map(MAP_ID):
		push_error("wall fixture could not load " + MAP_ID)
		get_tree().quit(1)
		return
	viewer.set_process(false)
	viewer.selector.hide()
	viewer.label.hide()
	viewer.camera.position = FRONT_CAMERA
	viewer.camera.look_at(Vector3(-5.8, 1.5, WALL_FACE_Z))
	viewer.camera.fov = 70.0
	viewer.camera.current = true
	add_child(controller)
	var map: Dictionary = viewer.catalog.resolve_map(MAP_ID)
	var configured: Dictionary = controller.configure(viewer.camera, SurfaceQuery.semantic_provider(map))
	controller.set_quality(quality)
	controller.set_active(true, false)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	label.position = Vector2(14, 12)
	label.add_theme_font_size_override("font_size", 15 if width <= 960 else 18)
	label.add_theme_color_override("font_color", Color("e6eef6"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	# Static text: every pixel comparison below is a rendered control.
	label.text = "BLOOD FX WALL SPATTER FIXTURE · arranged source fixture on %s, not live gameplay\n%s · %dx%d · real locked map with world/viewer.gd" % [MAP_ID, quality, width, height]
	layer.add_child(label)
	print("BLOOD_FX_WALL_SETUP " + JSON.stringify({"configured_ok": configured.get("ok", false),
		"surface_ready": configured.get("surface_ready", false), "fixture": true, "live_gameplay": false,
		"map": MAP_ID, "wall_face_z": WALL_FACE_Z, "viewport": [width, height]}))


func _state() -> Dictionary:
	return {"time": maxf(0.1, elapsed), "mapId": MAP_ID, "over": false, "actors": [
		{"id": 1, "x": SHOOTER.x, "y": SHOOTER.y, "z": SHOOTER.z, "health": 100.0, "maxHealth": 100.0},
		{"id": 2, "x": VICTIM.x, "y": VICTIM.y, "z": VICTIM.z, "health": 100.0, "maxHealth": 100.0},
	]}


func _damage(victim: int, source: int, amount: float) -> Dictionary:
	serial += 1
	return {"type": "damage", "id": serial, "actor": victim, "source": source, "amount": amount, "shield": 0.0}


func _death(victim: int, position: Vector3, killer: int, direction: Vector3) -> Dictionary:
	serial += 1
	return {"type": "death", "id": serial, "actor": victim, "pos": {"x": position.x, "y": position.y, "z": position.z},
		"killer": killer, "direction": {"x": direction.x, "y": direction.y, "z": direction.z},
		"overkill": 10.0, "seed": 5.0}


func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## 1/255 channal difference: any real pixel change counts, static frames are zero.
func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.0039: changed += 1
	return changed


## Projected wall-face quad, taken while the matching camera is active.
func wall_quad(face_z: float) -> PackedVector2Array:
	var quad := PackedVector2Array()
	for corner: Vector3 in [Vector3(WALL_MIN_X, WALL_MIN_Y, face_z), Vector3(WALL_MAX_X, WALL_MIN_Y, face_z),
			Vector3(WALL_MAX_X, WALL_MAX_Y, face_z), Vector3(WALL_MIN_X, WALL_MAX_Y, face_z)]:
		quad.append(viewer.camera.unproject_position(corner))
	return quad


## Changed pixels inside a projected quad: proves a region changed, not the frame.
func region_changed(a: Image, b: Image, quad: PackedVector2Array) -> int:
	if quad.size() != 4: return -1
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in quad:
		low = low.min(point)
		high = high.max(point)
	# Screen-space winding depends on the camera side, so normalise it first.
	var winding := 0.0
	for i in 4:
		var q0: Vector2 = quad[i]
		var q1: Vector2 = quad[(i + 1) % 4]
		winding += q0.x * q1.y - q1.x * q0.y
	var sign := 1.0 if winding >= 0.0 else -1.0
	var changed := 0
	for y in range(maxi(0, int(low.y)), mini(a.get_height(), int(high.y) + 1)):
		for x in range(maxi(0, int(low.x)), mini(a.get_width(), int(high.x) + 1)):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) <= 0.0039: continue
			var inside := true
			for i in 4:
				var p0: Vector2 = quad[i]
				var p1: Vector2 = quad[(i + 1) % 4]
				if sign * (p1 - p0).cross(Vector2(x, y) - p0) < 0.0: inside = false
			if inside: changed += 1
	return changed


func _draw_calls() -> int:
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


## Live marks sitting on the wall's far face plane with a normal pointing away
## from the body. This is the numeric far-side control: any value above zero is a
## mark drawn through the wall.
func far_face_marks() -> int:
	var count := 0
	var far_plane := WALL_FACE_Z - 0.6
	for slot: Dictionary in controller.stain_slots:
		if slot.remaining <= 0.0: continue
		var position: Vector3 = slot.node.global_position
		var normal: Vector3 = slot.node.global_transform.basis.z
		if normal.z < -0.6 and position.x > WALL_MIN_X - 0.6 and position.x < WALL_MAX_X + 0.6 			and absf(position.z - far_plane) < 0.4:
			count += 1
	return count


## Live marks with their plane, for the report and for the far-side control.
func mark_dump() -> Array:
	var out: Array = []
	for slot: Dictionary in controller.stain_slots:
		if slot.remaining <= 0.0: continue
		var position: Vector3 = slot.node.global_position
		var normal: Vector3 = slot.node.global_transform.basis.z
		out.append({"x": snappedf(position.x, 0.01), "y": snappedf(position.y, 0.01), "z": snappedf(position.z, 0.01),
			"nx": snappedf(normal.x, 0.01), "ny": snappedf(normal.y, 0.01), "nz": snappedf(normal.z, 0.01),
			"size": snappedf(maxf(slot.node.scale.x, slot.node.scale.y), 0.01), "surface": int(slot.surface)})
	return out


func _counts() -> Dictionary:
	var snapshot: Dictionary = controller.snapshot()
	return {"marks_wall": int(snapshot.marks_wall), "marks_floor": int(snapshot.marks_floor),
		"marks_slope": int(snapshot.marks_slope), "stains_live": int(snapshot.stains_live),
		"stains_wall": int(snapshot.stains_wall), "stains_floor": int(snapshot.stains_floor),
		"placed": int(snapshot.stains_placed)}


func _delta(kind: String) -> Dictionary:
	var now := _counts()
	return {"event": kind, "wall": int(now.marks_wall) - int(marks_before.marks_wall),
		"floor": int(now.marks_floor) - int(marks_before.marks_floor),
		"slope": int(now.marks_slope) - int(marks_before.marks_slope),
		"live_after": int(now.stains_live)}


func _process(delta: float) -> void:
	if sampling: samples.append(delta * 1000.0)
	if phase >= schedule.size() or busy: return
	elapsed += delta
	if elapsed < float(schedule[phase]): return
	busy = true
	var current := phase
	phase += 1
	await _step(current)
	busy = false


func _step(current: int) -> void:
	match current:
		0:
			controller.apply_state(_state(), 1)
			controller.set_active(true, false)
		1:
			clean_front = await _capture()
			if not prefix.is_empty(): clean_front.save_png(prefix + "-clean-front.png")
			front_quad = wall_quad(WALL_FACE_Z)
			draw_calls_clean = _draw_calls()
			sampling = true
		2:
			marks_before = _counts()
			controller.apply_events([_damage(2, 1, 34.0)], 1)
		3:
			hit_shot = await _capture()
			if not prefix.is_empty(): hit_shot.save_png(prefix + "-impact.png")
			per_event.append(_delta("impact_jet_reaches_wall"))
			front_quad = wall_quad(WALL_FACE_Z)
		4:
			marks_before = _counts()
			controller.apply_events([_death(2, Vector3(VICTIM.x, 1.2, VICTIM.z), 1, Vector3(0, 0, -1))], 1)
		5:
			death_shot = await _capture()
			if not prefix.is_empty(): death_shot.save_png(prefix + "-death.png")
			per_event.append(_delta("death_next_to_wall"))
			sampled_live = int(_counts().stains_live)
			draw_calls_live = _draw_calls()
			death_marks_dump = mark_dump()
		6:
			# Stains only: fluid alpha gain zero, so the wall-region metric below
			# can only come from stain quads.
			controller.reset()
			controller.apply_state(_state(), 1)
			controller.set_active(true, false)
			controller.settings.density = 0.0
			marks_before = _counts()
			controller.apply_events([_death(2, Vector3(VICTIM.x, 1.2, VICTIM.z), 1, Vector3(0, 0, -1))], 1)
		7:
			stains_only = await _capture()
			if not prefix.is_empty(): stains_only.save_png(prefix + "-spatter-only.png")
			per_event.append(_delta("death_stains_only"))
			draw_calls_spatter = _draw_calls()
			spatter_marks_dump = mark_dump()
			wall_pixel_probe = _pixel_probe(stains_only, front_quad)
			# Negative control: behind the wall, looking at its far face.
			controller.reset()
			controller.apply_state(_state(), 1)
			controller.set_active(true, false)
			viewer.camera.position = BACK_CAMERA
			viewer.camera.look_at(Vector3(-5.8, 1.5, WALL_FACE_Z - 0.5))
		8:
			clean_back = await _capture()
			clean_back_repeat = await _capture()
			if not prefix.is_empty():
				clean_back.save_png(prefix + "-back-clean.png")
			back_quad = wall_quad(WALL_FACE_Z - 0.6)
			marks_before = _counts()
			controller.apply_events([_death(2, Vector3(VICTIM.x, 1.2, VICTIM.z), 1, Vector3(0, 0, -1))], 1)
		9:
			back_after = await _capture()
			if not prefix.is_empty(): back_after.save_png(prefix + "-back-after.png")
			per_event.append(_delta("death_behind_wall_control"))
			_finish()


## Independent pixel probe: project the first wall mark of the spatter-only
## phase and read the rendered pixel there in the clean and spatter frames. Must
## run while the FRONT camera is active.
func _pixel_probe(spatter: Image, quad: PackedVector2Array) -> Dictionary:
	var probe := {}
	if spatter_marks_dump.is_empty() or clean_front == null or quad.size() != 4: return probe
	for mark: Dictionary in spatter_marks_dump:
		if int(mark.surface) != 2 or float(mark.nz) < 0.6: continue
		var world := Vector3(float(mark.x), float(mark.y), float(mark.z))
		var point := viewer.camera.unproject_position(world)
		var x := clampi(int(point.x), 0, width - 1)
		var y := clampi(int(point.y), 0, height - 1)
		probe = {"mark": [mark.x, mark.y, mark.z], "screen": [x, y],
			"clean": clean_front.get_pixel(x, y).to_html(false),
			"spatter": spatter.get_pixel(x, y).to_html(false),
			"inside_wall_quad": region_changed(clean_front, spatter, quad) > 0}
		break
	return probe


func _finish() -> void:
	var snapshot: Dictionary = controller.snapshot()
	var samples_sorted := samples.duplicate()
	samples_sorted.sort()
	var median_ms := 0.0
	var max_ms := 0.0
	if not samples_sorted.is_empty():
		median_ms = samples_sorted[samples_sorted.size() / 2]
		max_ms = samples_sorted[-1]
	var wall_changed := region_changed(clean_front, stains_only, front_quad)
	var back_changed := region_changed(clean_back, back_after, back_quad)
	var back_full := difference(clean_back, back_after)
	var static_delta := difference(clean_back, clean_back_repeat)
	var static_region := region_changed(clean_back, clean_back_repeat, back_quad)
	var far_marks := far_face_marks()
	var wall_marks: int = 0
	var floor_marks: int = 0
	for entry: Dictionary in per_event:
		if entry.event == "death_next_to_wall":
			wall_marks = int(entry.wall)
			floor_marks = int(entry.floor)
	record = snapshot.duplicate(true)
	record.merge({
		"fixture": "arranged source fixture on a real locked map with world/viewer.gd, not live gameplay",
		"live_gameplay": false, "map": MAP_ID, "requested_viewport": [width, height],
		"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"renderer": RenderingServer.get_video_adapter_name(), "rendering_method": RenderingServer.get_current_rendering_method(),
		"godot": Engine.get_version_info().string, "hardware_gpu_measured": false,
		"software_renderer_note": "llvmpipe software rendering; not hardware acceptance",
		"wall_face_z": WALL_FACE_Z, "marks_per_event": per_event, "death_marks": death_marks_dump, "spatter_marks": spatter_marks_dump,
		"death_wall_marks": wall_marks, "death_floor_marks": floor_marks,
		"wall_region_changed_pixels": wall_changed,
		"spatter_only_changed_pixels": difference(clean_front, stains_only),
		"far_side_region_changed_pixels": back_changed, "far_side_full_frame_changed_pixels": back_full,
		"far_side_negative_control_ok": back_changed <= maxi(4, static_region),
		"far_side_mark_count": far_marks,
		"static_full_frame_delta_pixels": static_delta, "static_far_region_delta_pixels": static_region,
		"draw_calls_clean": draw_calls_clean, "draw_calls_after_death": draw_calls_live,
		"draw_calls_spatter_only": draw_calls_spatter,
		"stain_draw_calls_estimate": draw_calls_spatter - draw_calls_clean,
		"samples": samples_sorted.size(), "sampled_live_stains": sampled_live,
		"frame_median_ms": median_ms, "frame_max_ms": max_ms,
		"frame_time_note": "scaled simulated frame time; Engine.time_scale=0.12 with a 20 fps ceiling",
		"front_quad": front_quad, "back_quad": back_quad,
		"wall_pixel_probe": wall_pixel_probe,
		"stain_pool": controller.settings.stain_pool, "stain_cap": snapshot.stain_cap,
		"screenshots": [prefix + "-clean-front.png", prefix + "-impact.png", prefix + "-death.png",
			prefix + "-spatter-only.png", prefix + "-back-clean.png", prefix + "-back-after.png"],
	}, true)
	var ok := wall_marks >= 2 and floor_marks >= 1 and wall_changed > 0 \
		and back_changed <= maxi(4, static_region) and far_marks == 0 and int(record.stains_wall) >= 2 \
		and front_quad.size() == 4 and back_quad.size() == 4
	print("BLOOD_FX_WALL ", "PASS" if ok else "FAIL", " ", JSON.stringify(record))
	if not prefix.is_empty():
		var file := FileAccess.open(prefix + ".json", FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t") + "\n")
	get_tree().quit(0 if ok else 1)
