extends SceneTree
## Rendered alt-fire evidence at 1280x800: the four projectile alt bodies in
## flight, their distinct exhaust ribbons, and their pooled impacts on the real
## meridian-exchange semantic map through the shipping combat composition.
##
## Captures run under a private Xvfb (GL Compatibility). Every image is compared
## against a clean baseline and against primary fire so the distinctness claim is
## a measured pixel delta, not a description. Pool/draw costs are sampled at all
## three F9 quality levels. Nothing here reads or writes aim, ammo, damage,
## endpoints or any authoritative value.
##
##   python3 tools/godot-dev/xvfb_run.py "$GODOT_BIN" --path godot \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://tests/weapon_effects/alt_fire_capture.gd -- \
##     --output=/path/to/port/native-alt-fire/evidence
const Projectiles = preload("res://world/projectiles.gd")
const Feedback = preload("res://world/combat_feedback.gd")
const Audio = preload("res://world/audio_feedback.gd")
const Catalog = preload("res://world/catalog.gd")
const Client = preload("res://net/client.gd")
const Surface = preload("res://player_fx/surface.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")

const WIDTH := 1280
const HEIGHT := 800
const BODY_ROI := 110
const IMPACT_ROI := 190
const BLAST_AT := Vector3(0, 1.0, -2.2)

class Watch:
	var value := false
	func stale() -> bool: return value

class Context extends Node3D:
	var camera := Camera3D.new()
	var client: Node
	var world := Node3D.new()
	var current_id := "meridian-exchange"
	var phase := 3
	var application_focused := true
	var snapshot_watch := Watch.new()
	func can_capture_pointer() -> bool: return true

var output := ""
var feedback: Node3D
var context: Context
var catalog: Catalog
var caption: Label
var failures: Array[String] = []
var checks := 0
var next_id := 5000
var metrics: Dictionary = {"bodies": [], "trails": [], "impacts": [], "budgets": [], "audio": []}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	create_timer(900.0).timeout.connect(func() -> void: push_error("ALT_FIRE_CAPTURE watchdog"); quit(1))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("ALT_FIRE_CAPTURE: " + message)

func cube(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	node.position = at
	parent.add_child(node)

func color_for(family: String) -> Color:
	match family:
		"ice": return Color("a8dcec")
		"metal": return Color("8a97a8")
		"ground": return Color("8b7a5f")
		_: return Color("a8a196")

func build_map(parent: Node3D, id: String) -> void:
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

func alt_row(id: int, kind: String, pos: Vector3, dir: Vector3, extra: Dictionary = {}) -> Dictionary:
	var row := {"id":id, "owner":0, "weapon":Projectiles.ALT_WEAPONS[kind], "alt":true, "altId":kind,
		"pos":{"x":pos.x,"y":pos.y,"z":pos.z}, "dir":{"x":dir.x,"y":dir.y,"z":dir.z}}
	row.merge(extra, true)
	return row

func rocket_row(id: int, weapon: int, pos: Vector3, dir: Vector3) -> Dictionary:
	return {"id":id,"owner":0,"weapon":weapon,"pos":{"x":pos.x,"y":pos.y,"z":pos.z},"dir":{"x":dir.x,"y":dir.y,"z":dir.z}}

func capture(name: String, note: String) -> Image:
	caption.text = "ALT FIRE · %s\n%s\n1280x800 · private Xvfb · GL Compatibility" % [name, note]
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output.path_join("%s.png" % name)) == OK, "saved " + name)
	return image

func difference(a: Image, b: Image, area: Rect2i) -> Dictionary:
	var changed := 0
	var total := 0.0
	var maximum := 0.0
	var rect := area.intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta > 0.02: changed += 1
			total += delta
			maximum = maxf(maximum, delta)
	return {"changed_pixels": changed, "mean_delta": total / float(maxi(1, rect.size.x * rect.size.y)), "max_delta": maximum}

func roi_at(point: Vector3, radius: int) -> Rect2i:
	var screen: Vector2 = context.camera.unproject_position(point)
	return Rect2i(Vector2i(screen) - Vector2i(radius, radius), Vector2i(radius * 2, radius * 2))

func sheet(name: String, files: Array, columns: int, cell: Vector2i) -> void:
	var rows := int(ceil(float(files.size()) / float(columns)))
	var image := Image.create(columns * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("0b1118"))
	for index: int in files.size():
		var source := Image.load_from_file(output.path_join("%s.png" % files[index]))
		source.convert(Image.FORMAT_RGBA8)
		source.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		image.blit_rect(source, Rect2i(Vector2i.ZERO, cell), Vector2i((index % columns) * cell.x, (index / columns) * cell.y))
	image.save_png(output.path_join("%s.png" % name))

func stats(sound: AudioStreamWAV) -> Dictionary:
	var peak := 0.0
	var square_sum := 0.0
	var samples: int = sound.data.size() / 2
	for index: int in samples:
		var sample: float = sound.data.decode_s16(index * 2) / 32768.0
		peak = maxf(peak, absf(sample))
		square_sum += sample * sample
	return {"seconds":sound.get_length(), "peak":peak, "rms":sqrt(square_sum / maxi(1, samples))}

func advance_effects(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var dt: float = minf(remaining, 1.0 / 60.0)
		if is_instance_valid(feedback.weapon_effects): feedback.weapon_effects.advance(dt)
		feedback.advance(dt)
		remaining -= dt

# --- 1. Bodies ---------------------------------------------------------------
func capture_bodies() -> void:
	# A slightly raised camera so the flat mine reads as a disc, not an edge.
	context.camera.position = Vector3(0, 2.6, 1.3)
	context.camera.look_at(Vector3(0, 1.35, -0.9))
	context.camera.fov = 62.0
	var direction := Vector3(1.0, 0.25, 0.4).normalized()
	var robot := Vector3(0.62, 1.45, -0.9)
	var primary_point := Vector3(-0.75, 1.45, -0.9)
	# Primary baseline: two rockets, then each alt beside a primary rocket.
	feedback.projectiles.apply_state({"time":0.0,"rockets":[]})
	var clean := await capture("body-clean", "empty lane before any projectile")
	feedback.projectiles.apply_state({"time":0.0,"rockets":[
		rocket_row(9001, 1, primary_point, direction), rocket_row(9002, 1, robot, direction)]})
	var primary_image := await capture("body-primary-rocket", "primary Rocket Launcher projectile · baseline pair")
	var primary_roi := roi_at(robot, BODY_ROI)
	var files: Array = ["body-primary-rocket"]
	for kind: String in Projectiles.ALT_KINDS:
		feedback.projectiles.apply_state({"time":0.0,"rockets":[
			rocket_row(9003, 1, primary_point, direction), alt_row(9004, kind, robot, direction, {"arm":0.2})]})
		var note := "%s alt body beside the primary rocket" % kind
		var image := await capture("body-%s" % kind, note)
		var delta := difference(clean, image, primary_roi)
		var vs_primary := difference(primary_image, image, primary_roi)
		check(delta.changed_pixels > 400 and float(delta.max_delta) > 0.25, "alt %s body is visible against the empty lane" % kind)
		check(vs_primary.changed_pixels > 400 and float(vs_primary.max_delta) > 0.25, "alt %s body differs from the primary body in the same lane" % kind)
		var body_mesh: Mesh = feedback.projectiles.alt_meshes[kind]
		var tint: Color = Projectiles.ALT_ACCENTS[kind]
		metrics.bodies.append({"kind":kind, "weapon":Projectiles.ALT_WEAPONS[kind], "surfaces":body_mesh.get_surface_count(),
			"roi_pixels_changed":delta.changed_pixels, "max_delta":delta.max_delta, "vs_primary_pixels":vs_primary.changed_pixels,
			"vs_primary_max_delta":vs_primary.max_delta, "aabb":str(body_mesh.get_aabb()), "tint":tint.to_html(false)})
		files.append("body-%s" % kind)
		if kind == "mine":
			# The arming read: once the source `arm` field elapses the eye blinks.
			feedback.projectiles.apply_state({"time":0.1,"rockets":[
				rocket_row(9003, 1, primary_point, direction), alt_row(9004, "mine", robot, direction, {"arm":0.0})]})
			feedback.projectiles._process(0.35)
			var blink: MeshInstance3D = feedback.projectiles.markers[9004].get_node_or_null("Blink")
			check(blink != null and blink.visible, "armed mine shows its blinking sensor eye")
			await capture("body-mine-armed", "mine armed · sensor eye blinking, low flat stance")
			files.append("body-mine-armed")
	# Primary non-rocket sphere (thrown grenade) for contrast.
	feedback.projectiles.apply_state({"time":0.0,"rockets":[
		rocket_row(9005, 1, primary_point, direction), rocket_row(9006, 5, robot, direction)]})
	await capture("body-primary-grenade", "primary Grenade Launcher projectile · generic sphere")
	files.append("body-primary-grenade")
	sheet("body-sheet-1280x800", files, 3, Vector2i(426, 266))

# --- 2. Trails ---------------------------------------------------------------
func capture_trails() -> void:
	context.camera.position = Vector3(0, 2.3, 3.4)
	context.camera.look_at(Vector3(0, 1.55, -0.4))
	context.camera.fov = 72.0
	feedback.projectiles.apply_state({"time":0.0,"rockets":[]})
	var clean := await capture("trail-clean", "clean flight lane before any trail")
	var files: Array = []
	for kind: String in ["primary", "cluster", "mortar", "mine", "bomb"]:
		feedback.projectiles.clear_round()
		var node: MeshInstance3D = null
		for step: int in 5:
			var pos := Vector3(-3.0 + float(step) * 1.0, 1.6, -0.5)
			var row: Dictionary
			if kind == "primary":
				row = rocket_row(31, 1, pos, Vector3.RIGHT)
			else:
				row = alt_row(31, kind, pos, Vector3.RIGHT, {"arm":0.0,"mine":kind == "mine"})
			feedback.projectiles.apply_state({"time":float(step) * 0.05, "rockets":[row]})
			feedback.projectiles._process(0.05)
			node = feedback.projectiles.markers[31]
		var record: Dictionary = feedback.projectiles.flight[31]
		var span: Vector3 = record.trail[0] - record.trail[-1]
		var mid: Vector3 = (record.trail[0] + record.trail[-1]) * 0.5
		var roi := roi_at(mid, 280)
		var note := "%s trail mid-flight · ribbon %.2f m" % ["primary rocket" if kind == "primary" else kind, span.length()]
		var image := await capture("trail-%s" % kind, note)
		var delta := difference(clean, image, roi)
		check(delta.changed_pixels > 300, "trail %s leaves a visible ribbon" % kind)
		var ribbon_visible: bool = (node.get_child(0) as MeshInstance3D).visible
		check(ribbon_visible, "trail %s ribbon draw is live" % kind)
		var tint := Color("ffad61")
		var head_width: float = Projectiles.TRAIL_WIDTH_HEAD
		if kind != "primary":
			tint = Projectiles.ALT_TRAILS[kind]["tint"]
			head_width = float(Projectiles.ALT_TRAILS[kind]["head"])
		metrics.trails.append({"kind":kind, "ribbon_m":span.length(), "roi_pixels_changed":delta.changed_pixels,
			"points":record.trail.size(), "tint":tint.to_html(false), "head_width":head_width })
		files.append("trail-%s" % kind)
	feedback.projectiles.clear_round()
	sheet("trail-sheet-1280x800", files, 3, Vector2i(426, 266))

# --- 3. Impacts --------------------------------------------------------------
func impact_event(kind: String, extra: Dictionary = {}) -> Dictionary:
	next_id += 1
	var event := {"id":next_id, "time":10.0, "type":"explosion", "weapon":1, "pos":{"x":BLAST_AT.x,"y":BLAST_AT.y,"z":BLAST_AT.z}}
	if kind != "primary":
		event["weapon"] = Projectiles.ALT_WEAPONS[kind]
		event["alt"] = true
		event["altId"] = kind
	event.merge(extra, true)
	return event

func capture_impacts() -> void:
	# Real semantic confirmation path on an explicit fixture gallery (the same
	# approach the player_fx capture uses): a confirmed foundation floor plus four
	# family walls. Explosions reuse the landed pooled scorch/shockwave, this lane
	# only adds the transient alt burst on top.
	var fixture_blocks := [
		{"x": -6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "metal"},
		{"x": -2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "rock", "material": "stone"},
		{"x": 2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "ice"},
		{"x": 6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "tree", "material": "ground"},
		{"x": 0, "z": 0, "w": 30, "h": 0.4, "d": 30, "kind": "foundation", "material": "stone"}]
	var fixture_map: Dictionary = {"id":"alt-fire-gallery", "biome":"urban", "blocks":fixture_blocks}
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
	context.camera.position = Vector3(0, 2.2, -5.2)
	context.camera.look_at(Vector3(0, 0.9, -2.2))
	context.camera.fov = 68.0
	# The composition first sees the gallery identity (which drains the previous
	# map state), then its occlusion is pointed at the fixture. The shipping
	# confirmation code path is unchanged.
	feedback.apply_state({"mapId":"alt-fire-gallery","time":1.0,"over":false,"actors":[]})
	feedback.occlusion.configure(context.camera, fixture_map)
	feedback.impacts.configure(context.camera, feedback.occlusion)
	feedback.impacts.set_map(fixture_map)
	check(feedback.occlusion.ready, "composition confirmed the gallery floor")
	check(feedback.impacts.limit() == 12, "High impact burst pool wired")
	check(feedback.impacts.mark_limit() == 44, "High mark pool wired")
	var roi := roi_at(Vector3(BLAST_AT.x, BLAST_AT.y - 0.8, BLAST_AT.z), IMPACT_ROI)
	var files: Array = []
	var tick := 1
	var clean := await capture("impact-clean", "clean gallery floor before any explosion")
	for kind: String in ["primary", "cluster", "mortar", "mine", "bomb"]:
		tick += 1
		# Rendered captures are slow; refresh the public frame so the composition's
		# freshness window stays open through every scenario.
		feedback.apply_state({"mapId":"alt-fire-gallery","time":float(tick),"over":false,"actors":[]})
		feedback.weapon_effects.reset()
		feedback.impacts.reset()
		var before_scorch: int = int(feedback.impacts.counters.scorches_placed)
		var event := impact_event(kind)
		feedback.apply_events([event], 0)
		feedback.flush_effects()
		advance_effects(0.05)
		var note := "%s explosion · pooled burst at +0.05 s" % ("primary rocket" if kind == "primary" else kind)
		var image := await capture("impact-%s" % kind, note)
		var delta := difference(clean, image, roi)
		check(delta.changed_pixels > 500, "impact %s paints a measurable burst" % kind)
		advance_effects(0.30)
		await capture("impact-%s-settled" % kind, "%s explosion · settled scorch and shockwave" % kind)
		var scorch: int = int(feedback.impacts.counters.scorches_placed) - before_scorch
		check(scorch == 1, "impact %s reuses the pooled player_fx scorch" % kind)
		var shards := 0
		var cards := 0
		for slot: Dictionary in feedback.weapon_effects.slots:
			if int(slot.kind) == 12: shards += 1
			elif int(slot.kind) in [13,14,15,16,2,4,10]: cards += 1
		metrics.impacts.append({"kind":kind, "burst_blasts":feedback.weapon_effects.blasts, "shards":shards,
			"scorches_placed":scorch, "shockwaves":int(feedback.impacts.counters.shockwaves_placed),
			"marks_live":int(feedback.impacts.counters.marks_live), "puffs":int(feedback.impacts.counters.puffs),
			"roi_pixels_changed":delta.changed_pixels, "max_delta":delta.max_delta, "cards":cards})
		files.append("impact-%s" % kind)
	# The cluster's bomblet events stagger three small bursts around the shell.
	tick += 1
	feedback.apply_state({"mapId":"alt-fire-gallery","time":float(tick),"over":false,"actors":[]})
	feedback.weapon_effects.reset()
	feedback.impacts.reset()
	var bomblets: Array = []
	for index: int in 3:
		# Split in the open lane in front of the walls so each bomblet floor is
		# confirmed rather than occluded by the family gallery; the z offsets stay
		# shallow so the semantic probe snaps to the floor's top face.
		var offset := Vector3((float(index) - 1.0) * 0.9, 0.0, -0.5 - (0.4 if index == 1 else 0.0))
		bomblets.append(impact_event("cluster", {"bomblet":index, "pos":{"x":BLAST_AT.x + offset.x,"y":BLAST_AT.y,"z":BLAST_AT.z + offset.z}}))
	feedback.apply_events(bomblets, 0)
	feedback.flush_effects()
	advance_effects(0.02)
	await capture("impact-cluster-split", "cluster shell splits into three staggered bomblet pops")
	check(feedback.weapon_effects.blasts == 3 and feedback.weapon_effects.blast_shards == 0, "cluster split uses three pooled pops")
	advance_effects(0.5)
	await capture("impact-cluster-split-settled", "cluster split settled · three small scorches")
	check(int(feedback.impacts.counters.scorches_placed) == 3, "cluster split leaves three pooled scorches")
	files.append("impact-cluster-split")
	sheet("impact-sheet-1280x800", files, 3, Vector2i(426, 266))

# --- 4. Costs at the three F9 levels ----------------------------------------
func budget_scenario(level: int) -> void:
	var names: Array = ["Low", "High", "Extreme"]
	feedback.quality_controls.select_quality(level)
	feedback.weapon_effects.reset()
	feedback.impacts.reset()
	feedback.projectiles.clear_round()
	feedback.apply_state({"mapId":"alt-fire-gallery","time":6.0,"over":false,"actors":[]})
	var events: Array = []
	for kind: String in ["cluster", "mortar", "mine", "bomb"]:
		events.append(impact_event(kind))
	for index: int in 3:
		events.append(impact_event("cluster", {"bomblet":index}))
	feedback.apply_events(events, 0)
	feedback.flush_effects()
	var rows: Array = []
	var kinds: Array = ["cluster", "mortar", "mine", "bomb"]
	for index: int in 48:
		var kind: String = kinds[index % kinds.size()]
		var x: float = -1.8 + float(index % 8) * 0.5
		var y: float = 0.9 + float(index / 8) * 0.45
		var z: float = -3.4 + float(index % 3) * 0.6
		rows.append(alt_row(600 + index, kind, Vector3(x, y, z), Vector3.FORWARD, {"arm":0.2}))
	feedback.projectiles.apply_state({"time":5.0, "rockets":rows})
	advance_effects(0.06)
	feedback.projectiles._process(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	var shards := 0
	for slot: Dictionary in feedback.weapon_effects.slots:
		if int(slot.kind) == 12: shards += 1
	var record := {
		"level":level, "name":names[level],
		"markers":feedback.projectiles.markers.size(), "flash_slots":feedback.weapon_effects.slots.size(),
		"lines":feedback.weapon_effects.lines.size(), "shards":shards, "burst_blasts":feedback.weapon_effects.blasts,
		"impact_pool":feedback.impacts.snapshot().pool, "impact_limit":feedback.impacts.limit(),
		"marks_live":int(feedback.impacts.counters.marks_live), "marks_limit":feedback.impacts.mark_limit(),
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	}
	check(int(record.markers) <= Projectiles.MAX_PROJECTILES, "F9 %s projectile pool bounded" % names[level])
	check(int(record.flash_slots) <= 64, "F9 %s flash pool bounded" % names[level])
	check(int(record.impact_pool) == int(record.impact_limit), "F9 %s burst pool preallocated" % names[level])
	check(int(record.marks_limit) == [20, 44, 72][level], "F9 %s mark pool follows the quality table" % names[level])
	check(int(record.draw_calls) > 0, "F9 %s reports live draw calls" % names[level])
	metrics.budgets.append(record)
	await capture("budget-%s" % names[level].to_lower(), "48 alt projectiles + 7 alt blasts · F9 %s pool/draw cost" % names[level])

# --- 5. Audio cue table ------------------------------------------------------
func audio_table() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_muted(true)
	for kind: String in Projectiles.ALT_KINDS:
		for cue: String in ["launch", "explosion"]:
			var seconds: float = audio._cue_seconds(cue, Projectiles.ALT_WEAPONS[kind], kind)
			var sound: AudioStreamWAV = audio._make_sound(cue, seconds, Projectiles.ALT_WEAPONS[kind], kind)
			var data := stats(sound)
			check(sound.get_length() > 0.10 and sound.get_length() <= 0.52, "alt %s %s length bounded" % [kind, cue])
			check(float(data.peak) > 0.40 and float(data.peak) <= 0.65, "alt %s %s peak contract" % [kind, cue])
			var primary_key := "explosion" if cue == "explosion" else "%s/%d" % [cue, Projectiles.ALT_WEAPONS[kind]]
			var primary: AudioStreamWAV = audio._make_sound(cue, audio._cue_seconds(cue, Projectiles.ALT_WEAPONS[kind]), Projectiles.ALT_WEAPONS[kind])
			var primary_data := stats(primary)
			var distinct: bool = absf(sound.get_length() - primary.get_length()) > 0.004 \
				or absf(float(data.peak) - float(primary_data.peak)) > 0.004 \
				or absf(float(data.rms) - float(primary_data.rms)) > 0.004
			check(distinct, "alt %s %s differs from primary fire" % [kind, cue])
			metrics.audio.append({"kind":kind, "cue":cue, "seconds":sound.get_length(), "peak":data.peak, "rms":data.rms,
				"primary_key":primary_key, "primary_seconds":primary.get_length(),
				"primary_peak":primary_data.peak, "primary_rms":primary_data.rms})
	audio.free()

func run() -> void:
	check(not output.is_empty(), "output directory required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(WIDTH, HEIGHT)
	catalog = Catalog.new()
	var opened := catalog.open()
	check(opened, "semantic catalog opens: " + catalog.error)
	if not opened: quit(1); return
	context = Context.new()
	root.add_child(context)
	context.add_child(context.camera)
	context.add_child(context.world)
	context.client = Client.new()
	context.add_child(context.client)
	context.client.set_process(false)
	context.client.actor_id = 0
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
	var caption_layer := CanvasLayer.new()
	caption_layer.layer = 4
	root.add_child(caption_layer)
	caption = Label.new()
	caption.position = Vector2(24, 18)
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("e8f4ff"))
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption_layer.add_child(caption)
	feedback = Feedback.new()
	context.add_child(feedback)
	feedback.set_process(false)
	feedback.audio_feedback.set_muted(true)
	feedback.world_particles.visible = false
	feedback.moth_effects.visible = false
	var map_root := Node3D.new()
	context.world.add_child(map_root)
	build_map(map_root, "meridian-exchange")
	await process_frame
	feedback.apply_state({"mapId":"meridian-exchange","time":0.0,"over":false,"actors":[]})
	if is_instance_valid(feedback.projectiles): feedback.projectiles.set_process(false)
	if is_instance_valid(feedback.weapon_effects): feedback.weapon_effects.set_process(false)
	# The feedback is already configured by _ready (parent exposes camera/world).
	check(is_instance_valid(feedback.projectiles) and is_instance_valid(feedback.weapon_effects), "shipping composition ready")
	await capture_bodies()
	await capture_trails()
	map_root.visible = false
	await capture_impacts()
	for level: int in [0, 1, 2]: await budget_scenario(level)
	audio_table()
	metrics["checks"] = checks
	metrics["failures"] = failures
	metrics["godot"] = Engine.get_version_info().string
	metrics["adapter"] = RenderingServer.get_video_adapter_name()
	FileAccess.open(output.path_join("alt-fire-metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t") + "\n")
	print("ALT_FIRE_CAPTURE ", JSON.stringify({"checks":checks,"failures":failures,"bodies":metrics.bodies.size(),"trails":metrics.trails.size(),"impacts":metrics.impacts.size(),"budgets":metrics.budgets.size(),"audio":metrics.audio.size()}))
	quit(0 if failures.is_empty() else 1)
