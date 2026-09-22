extends SceneTree
## Real rendered evidence for the player FX lane.
##
## World geometry, material classification and map occlusion come from the real
## semantic catalog (meridian-exchange). Confirmed events come from the recorded
## server capture (tests/protocol/captured.json) and the recorded source fixture
## (tests/combat_shields/source.json). A small explicitly labelled fixture set
## covers low health, death and the four material families, because the recorded
## matches did not include those local transitions. Every frame is measured
## against a clean baseline so the script fails if a cue does not render.
const Feedback = preload("res://world/combat_feedback.gd")
const Rig = preload("res://first_person/rig.gd")
const Client = preload("res://net/client.gd")
const Catalog = preload("res://world/catalog.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
const Overlay = preload("res://world/combat_overlay.gd")
const Surface = preload("res://player_fx/surface.gd")

var size := Vector2i(960, 640)
var output := ""
var verified := 0
var measurements: Dictionary = {}
var failures: Array[String] = []
var label_text: Label

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
	var force_capture := true
	var snapshot_watch := Watch.new()
	func can_capture_pointer() -> bool: return true
	func _process(_delta: float) -> void:
		# Xvfb focus churn can reset the mode between capture awaits; the reticle
		# policy itself still reads the real capture state.
		if force_capture: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func check(ok: bool, message: String) -> void:
	verified += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_CAPTURE: " + message)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	create_timer(240.0).timeout.connect(func() -> void: push_error("PLAYER_FX_CAPTURE watchdog"); quit(1))
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

func shield_frame(index: int) -> Dictionary:
	return recorded("res://tests/combat_shields/source.json").frames[index]

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

func capture(label: String, description: String) -> Image:
	label_text.text = "PLAYER FX · %s\n%s\nrecorded/source fixture events · real semantic map geometry · %dx%d" % [label, description, size.x, size.y]
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(output.path_join("%s-%dx%d.png" % [label, size.x, size.y])) == OK, "saved " + label)
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
	return {"changed_pixels": changed, "mean_delta": total / float(maxi(1, rect.size.x * rect.size.y)), "max_delta": maximum, "changed_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}

func edge_roi(angle: float) -> Rect2i:
	var margin := float(mini(size.x, size.y)) * Overlay.EDGE_MARGIN_FRACTION
	var half := Vector2(maxf(24.0, size.x * 0.5 - margin), maxf(24.0, size.y * 0.5 - margin))
	var point := Vector2(size) * 0.5 + Overlay.frame_point(half, angle)
	return Rect2i(Vector2i(point) - Vector2i(70, 70), Vector2i(140, 140))

func run() -> void:
	check(not output.is_empty(), "output directory required")
	if not failures.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = size
	var catalog := Catalog.new()
	check(catalog.open(), "semantic catalog opens")

	var context := Context.new()
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
	var floor := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(140, 0.4, 140)
	floor.mesh = slab
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("232c36")
	floor.material_override = floor_material
	floor.position = Vector3(0, -0.2, 0)
	context.world.add_child(floor)
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
	context.camera.position = Vector3(24, 2.0, -22)
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

	var feedback := Feedback.new()
	context.add_child(feedback)
	feedback.set_process(false)
	feedback.audio_feedback.set_muted(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Determinism probe: two identical frames establish the render noise floor
	# before any cue is compared against a baseline.
	var noise_a := await capture("noise-floor-a", "determinism probe frame A")
	var noise_b := await capture("noise-floor-b", "determinism probe frame B")
	var noise_centre := difference(noise_a, noise_b, Rect2i(Vector2i(size) / 2 - Vector2i(80, 80), Vector2i(160, 160)))
	measurements.noise_floor = {"whole": difference(noise_a, noise_b, Rect2i(0, 0, size.x, size.y)), "centre": noise_centre}

	# --- Normal play: real recorded events on the real map geometry. ----------
	var local := {"id": 0, "x": 24, "y": 2.0, "z": -22, "health": 100, "maxHealth": 100, "dead": 0, "protection": 0, "yaw": 0, "pitch": 0, "weapon": 0, "grounded": true}
	var remote := {"id": 1, "x": 28, "y": 1.0, "z": -34, "health": 100, "dead": 0}
	var state := {"mapId": "meridian-exchange", "time": 1.0, "over": false, "actors": [local, remote]}
	context.rig.apply_actor(local, true)
	context.rig.apply_aim(false)
	for step in range(80): context.rig.advance(1.0 / 60.0)
	context.camera.fov = float(context.rig.get_aim_state(75.0).fov)
	feedback.apply_state(state)
	feedback._process(0.016)
	var clean_hip := await capture("hip-clean", "hip baseline: no cue")

	# Recorded source frame 0: local shot confirms a hit (hit marker + tracer).
	var source: Dictionary = recorded("res://tests/combat_integration/source.json")
	feedback.apply_state(source.frames[0].state)
	feedback.apply_events(source.frames[0].events, 0)
	feedback.flush_effects()
	feedback._process(0.05)
	var hip_hit := await capture("hip-hit", "recorded source frame 0: confirmed local hit")
	check(difference(clean_hip, hip_hit, Rect2i(Vector2i(size) / 2 - Vector2i(40, 40), Vector2i(80, 80))).changed_pixels > 10, "confirmed hit marker renders at the centre")

	# Recorded server shot 164 lands on the real foundation top face.
	feedback.clear_round()
	feedback.apply_state(state)
	feedback.apply_events([recorded_shot(164)], 0)
	feedback.flush_effects()
	feedback.advance(0.03)
	feedback._process(0.016)
	var impact_image := await capture("hip-impact-ground", "recorded server shot 164 on the real foundation (ground family)")
	var impact_roi := Rect2i(Vector2i(context.camera.unproject_position(Vector3(29.654, 0.6, -30.069))) - Vector2i(90, 90), Vector2i(180, 180))
	var impact_delta := difference(clean_hip, impact_image, impact_roi)
	measurements.impact_ground = impact_delta
	check(impact_delta.changed_pixels > 20, "confirmed ground impact renders at the authoritative endpoint")
	# Drain the impact before later cue-isolation measurements; the short-lived
	# billboard otherwise animates inside the centre isolation region.
	feedback.impacts.reset()

	# ADS with a live damage-direction cue: reticle follows the ADS policy and
	# the edge cue must never intrude into the centre of the sight picture.
	context.rig.apply_aim(true)
	for step in range(120): context.rig.advance(1.0 / 60.0)
	context.camera.fov = float(context.rig.get_aim_state(75.0).fov)
	feedback.advance(0.02)
	feedback._process(0.016)
	var ads_clean := await capture("ads-clean", "ADS baseline at %.2f weight" % float(context.rig.get_aim_state(75.0).weight))
	measurements.ads_rig = {"state": context.rig.get_aim_state(75.0), "mouse_mode": int(Input.mouse_mode), "overlay_visible": feedback.overlay.visible}
	check(float(context.rig.get_aim_state(75.0).weight) >= 0.98, "rig reached full ADS for the capture")
	feedback.apply_events([{"id": 700, "type": "damage", "actor": 0, "source": 1, "amount": 12}], 0)
	feedback.flush_effects()
	feedback.advance(0.05)
	feedback._process(0.016)
	var ads_arc := await capture("ads-damage-direction", "ADS + bearing to actor 1: edge arc, reticle hidden")
	var angle := float(feedback.player_fx.model().direction_angle)
	check(absf(angle) > 0.0, "ADS damage direction has a real bearing")
	var ads_delta := difference(ads_clean, ads_arc, edge_roi(angle))
	measurements.ads_direction = ads_delta
	check(ads_delta.changed_pixels > 30, "damage-direction arc renders in the expected edge region during ADS")
	check(context.rig.get_aim_state(75.0).ready, "ADS policy keeps the reticle hidden at full weight")

	# Sight-picture isolation: with the animated weapon and ambient particle
	# weather hidden, adding every player-state cue at once must not change a
	# single centre pixel.
	context.rig.apply_actor({}, false)
	feedback.world_particles.visible = false
	feedback.shields.visible = false
	feedback.player_fx.clear_round()
	local.health = 100.0
	feedback.apply_state(state)
	feedback._process(0.016)
	var sight_clean := await capture("sight-picture-clean", "rig hidden baseline for the centre isolation check")
	local.health = 18.0
	feedback.apply_state(state)
	feedback.apply_events([{"id": 701, "type": "damage", "actor": 0, "source": 1, "amount": 10, "shieldBreak": true}], 0)
	feedback.flush_effects()
	feedback.advance(0.05)
	feedback._process(0.016)
	var sight_cues := await capture("sight-picture-cues", "rig hidden: direction, low health and break cues active")
	var sight_centre := Rect2i(Vector2i(size) / 2 - Vector2i(80, 80), Vector2i(160, 160))
	var sight_delta := difference(sight_clean, sight_cues, sight_centre)
	measurements.sight_picture = sight_delta
	check(sight_delta.changed_pixels == 0 and sight_delta.max_delta == 0.0, "no player-state cue touches the sight picture centre")
	feedback.world_particles.visible = true
	feedback.shields.visible = true
	context.rig.apply_actor(local, true)
	for step in range(80): context.rig.advance(1.0 / 60.0)

	# --- Explicit fixture frames for local transitions. ------------------------
	context.rig.apply_aim(false)
	for step in range(120): context.rig.advance(1.0 / 60.0)
	context.camera.fov = float(context.rig.get_aim_state(75.0).fov)
	feedback.clear_round()
	feedback.apply_state(state)
	feedback.world_particles.visible = false
	feedback._process(0.016)
	var healthy := await capture("low-health-clean", "fixture baseline: healthy at full health")
	local.health = 18.0
	feedback.apply_state(state)
	feedback._process(0.016)
	var beat := 0
	for step in range(240):
		feedback.advance(1.0 / 60.0)
		if float(feedback.player_fx.model().heartbeat) > 0.85 * float(feedback.player_fx.low_health):
			beat = step
			break
	feedback._process(0.016)
	var low_image := await capture("low-health", "fixture: public health 18/100, heartbeat peak at frame %d" % beat)
	check(beat > 0, "heartbeat reached its visible peak")
	var low_delta := difference(healthy, low_image, Rect2i(0, 0, size.x, size.y))
	measurements.low_health = low_delta
	check(low_delta.changed_pixels > 200, "low-health edge tint renders")
	var low_centre := difference(healthy, low_image, Rect2i(Vector2i(size) / 2 - Vector2i(70, 70), Vector2i(140, 140)))
	measurements.low_health_centre = low_centre
	check(low_centre.changed_pixels < 40, "low-health tint leaves the combat centre visually stable")
	feedback.world_particles.visible = true
	local.health = 100.0

	# Shield break from a recorded source damage event with shieldBreak true.
	feedback.clear_round()
	context.client.actor_id = 1
	feedback.apply_state(shield_frame(2).snapshot.state)
	feedback._process(0.016)
	var break_clean := await capture("shield-break-clean", "fixture baseline before the recorded break")
	feedback.apply_events(shield_frame(3).events.items, 1)
	feedback.flush_effects()
	feedback.advance(0.05)
	feedback._process(0.016)
	var break_image := await capture("shield-break", "recorded source armor break (shieldBreak true)")
	var break_delta := difference(break_clean, break_image, Rect2i(0, 0, size.x, size.y))
	measurements.shield_break = break_delta
	check(break_delta.changed_pixels > 200, "shield-break cue renders distinctly")

	# Elimination and genuine protected respawn.
	var alive_state := {"mapId": "meridian-exchange", "time": 4.0, "over": false, "actors": [
		{"id": 1, "x": 2, "y": 0, "z": -4, "health": 300, "maxHealth": 300, "dead": 0, "protection": 0},
		{"id": 0, "x": 0, "y": 0, "z": -12, "health": 100, "dead": 0}]}
	var dead_state := {"mapId": "meridian-exchange", "time": 4.2, "over": false, "actors": [
		{"id": 1, "x": 2, "y": 0, "z": -4, "health": 0, "maxHealth": 300, "dead": 1, "protection": 0},
		{"id": 0, "x": 0, "y": 0, "z": -12, "health": 100, "dead": 0}]}
	feedback.apply_state(alive_state)
	feedback._process(0.016)
	var death_clean := await capture("death-clean", "fixture baseline: alive")
	feedback.apply_state(dead_state)
	feedback.advance(0.25)
	feedback._process(0.016)
	var death_image := await capture("death", "fixture: local death transition")
	check(difference(death_clean, death_image, Rect2i(0, 0, size.x, size.y)).changed_pixels > 200, "elimination cue renders")
	var respawn_state := {"mapId": "meridian-exchange", "time": 4.5, "over": false, "actors": [
		{"id": 1, "x": 2, "y": 0, "z": -4, "health": 300, "maxHealth": 300, "dead": 0, "protection": 1.5},
		{"id": 0, "x": 0, "y": 0, "z": -12, "health": 100, "dead": 0}]}
	feedback.apply_state(respawn_state)
	feedback.advance(0.3)
	feedback._process(0.016)
	var respawn_image := await capture("respawn", "genuine spawn protection 1.5 s mirrored by the materialize cue")
	check(difference(death_clean, respawn_image, Rect2i(0, 0, size.x, size.y)).changed_pixels > 200, "materialize cue renders")

	# --- Material family gallery: explicit fixture shots at named surfaces. ----
	feedback.clear_round()
	context.client.actor_id = 0
	var fixture_blocks := [
		{"x": -6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "metal"},
		{"x": -2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "rock", "material": "stone"},
		{"x": 2, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "crate", "material": "ice"},
		{"x": 6, "z": 0, "w": 3, "h": 4, "d": 0.6, "kind": "tree", "material": "ground"},
	]
	var fixture_map: Dictionary = {"id": "player-fx-gallery", "biome": "urban", "blocks": fixture_blocks}
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
	context.world.visible = true
	map_root.visible = false
	feedback.world_particles.visible = false
	feedback.shields.visible = false
	context.camera.position = Vector3(0, 2.6, -8)
	context.camera.look_at(Vector3(0, 2.0, 0))
	context.camera.fov = 90.0
	feedback.player_fx.clear_round()
	feedback.impacts.configure(context.camera, fixture_query)
	feedback.impacts.set_map(fixture_map)
	feedback.impacts.set_quality(2)
	var gallery_clear := await capture("materials-clean", "fixture baseline before the material gallery")
	var families := {}
	for index in range(fixture_blocks.size()):
		var block: Dictionary = fixture_blocks[index]
		feedback.impacts.consume([{"id": 800 + index, "type": "shot", "actor": 1, "hit": false,
			"from": {"x": 0, "y": 2.0, "z": -8}, "to": {"x": block.x, "y": 2.0, "z": block.z - 0.3}}], 0)
	feedback.impacts.advance(0.04)
	for effect: Dictionary in feedback.impacts.effects:
		if effect.remaining > 0.0: families[effect.family] = true
	var gallery := await capture("materials", "fixture shots: metal, stone, ice and ground surfaces")
	map_root.visible = true
	feedback.world_particles.visible = true
	feedback.shields.visible = true
	gallery_root.visible = false
	var gallery_delta := difference(gallery_clear, gallery, Rect2i(0, 0, size.x, size.y))
	measurements.materials = gallery_delta
	check(gallery_delta.changed_pixels > 100, "material impacts render across four surfaces")
	check(int(feedback.impacts.snapshot().active) == 4, "fixture gallery kept all four family impacts active")
	for family: String in ["metal", "stone", "ice", "ground"]:
		check(families.has(family), "gallery rendered the " + family + " family")

	measurements.size = [size.x, size.y]
	measurements.rendering = {"method": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name()}
	measurements.checked = verified
	measurements.failures = failures
	FileAccess.open(output.path_join("measurements-%dx%d.json" % [size.x, size.y]), FileAccess.WRITE).store_string(JSON.stringify(measurements, "\t") + "\n")
	print("PLAYER_FX_CAPTURE_%s size=%dx%d checks=%d failures=%d" % ["OK" if failures.is_empty() else "FAIL", size.x, size.y, verified, failures.size()])
	quit(0 if failures.is_empty() else 1)
