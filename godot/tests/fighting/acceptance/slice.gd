extends "res://tests/fighting/acceptance/journeys.gd"
## First native visual proof: one real Meta/Mistral stage, input-only combat and
## throw tech, actual rig/FX composition. Never a substitute for contact anatomy.
var world: Node3D
var visuals: Array = []
var effects: Variant
var camera: Variant
var cadence: Array = []
var captures: Array = []
var last_frame_usec := 0
var capture_tags := {}
var live_pause_exercised := false

func render_tick(sim: Variant, inputs: Array, phase_label: String) -> Dictionary:
	var state: Dictionary = sim.step(inputs)
	var authoritative: Dictionary = sim.save_state().duplicate(true)
	for actor in 2:
		visuals[actor].present(state.fighters[actor], 0.0)
		effects.present_fighter(state.fighters[actor], visuals[actor])
	effects.consume(state.events, state.fighters)
	var accepted := int(effects.metrics().accepted)
	effects.consume(state.events, state.fighters)
	expect(effects.metrics().accepted == accepted, "real event batch duplicate never accepted twice")
	effects.present_projectiles(state.projectiles, state.fighters)
	effects.advance(1.0 / 60.0)
	camera.present(state.fighters, Vector2(root.size))
	expect(equal(authoritative, sim.save_state()), "native rig/FX/camera cannot mutate combat state")
	var metrics: Dictionary = effects.metrics()
	if metrics.active > 0 and not live_pause_exercised:
		effects.set_paused(true)
		effects.advance(10.0)
		expect(effects.metrics().active == metrics.active, "paused LIVE FX survives beyond every authored lifetime")
		effects.set_paused(false)
		live_pause_exercised = true
	expect(metrics.active <= metrics.mesh_slots and metrics.peak_active <= metrics.mesh_slots, "measured live FX pool bounded")
	expect(effects.get_child_count() == metrics.pool_nodes, "actual FX nodes match bounded pool")
	await process_frame
	await RenderingServer.frame_post_draw
	var now := Time.get_ticks_usec()
	if last_frame_usec > 0:
		cadence.append({"simulation_tick": state.tick, "render_frame": Engine.get_frames_drawn(), "delta_usec": now - last_frame_usec})
	last_frame_usec = now
	var wanted := ""
	if state.phase == "fight" and not capture_tags.has("neutral"):
		wanted = "neutral"
	for event in state.events:
		if event.type in ["hit", "projectile_hit", "throw_tech", "throw_break", "throw_start", "throw_grab"]:
			var tag: String = phase_label + "-" + event.type
			if not capture_tags.has(tag):
				wanted = tag
				if event.type in ["hit", "projectile_hit"]:
					var found_contact := false
					for child in effects.get_children():
						if child is MeshInstance3D and child.visible:
							var point := Vector2(child.position.x, child.position.y)
							found_contact = found_contact or point.distance_to(Vector2(float(event.x), float(event.y)) / 1000.0) < 0.001
					expect(found_contact, "actual impact FX uses authoritative 1000-unit contact")
	if not wanted.is_empty():
		var directory := OS.get_environment("FIGHTING_ACCEPTANCE_EVIDENCE")
		var image := root.get_texture().get_image()
		var filename := "meta-mistral-" + wanted + ".png"
		expect(not image.is_empty(), "native frame readback nonempty")
		if not directory.is_empty():
			expect(image.save_png(directory.path_join(filename)) == OK, "native PNG saved")
		capture_tags[wanted] = true
		captures.append({"file": filename, "utc": Time.get_datetime_string_from_system(true), "simulation_tick": state.tick,
			"render_frame": Engine.get_frames_drawn(), "monotonic_usec": now, "fighters": state.fighters,
			"events": state.events, "fx": metrics, "units_per_metre": 1000})
	return state

func _run() -> void:
	success_marker = "FIGHTING_ACCEPTANCE_SLICE_OK"
	report_scope = "first Meta/Mistral native stage/combat/throw-tech slice; contact anatomy, audio and human art review unrun"
	for path in ["res://fighting/core/simulation.gd", "res://fighting/visuals/fighter_visual.gd", "res://fighting/effects/director.gd", "res://fighting/stages/backdrop.gd", "res://fighting/presentation/camera.gd", "res://fighting/assets/operators/meta.glb", "res://fighting/assets/operators/mistral.glb"]:
		if not FileAccess.file_exists(path):
			unrun.append("missing dependency " + path)
	if not unrun.is_empty():
		finish()
		return
	root.size = Vector2i(1280, 800)
	world = Node3D.new()
	root.add_child(world)
	var stage_script: Variant = load("res://fighting/stages/backdrop.gd")
	var stage: Variant = stage_script.new()
	world.add_child(stage)
	if not expect(stage.build("basalt-reach"), "actual native Basalt stage builds"):
		finish()
		return
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	world.add_child(light)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.18, 0.23)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	world.add_child(environment_node)
	var camera_script: Variant = load("res://fighting/presentation/camera.gd")
	camera = camera_script.new()
	world.add_child(camera)
	camera.current = true
	var visual_script: Variant = load("res://fighting/visuals/fighter_visual.gd")
	for oid in ["meta", "mistral"]:
		var visual: Variant = visual_script.new()
		world.add_child(visual)
		if not expect(visual.configure(oid), oid + " real native rig configure"):
			finish()
			return
		visuals.append(visual)
	var effect_script: Variant = load("res://fighting/effects/director.gd")
	effects = effect_script.new()
	world.add_child(effects)
	effects.configure({"quality": "low", "muted": true, "session_id": "independent-slice"})
	roster = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/rules.json"))
	simulation_script = load("res://fighting/core/simulation.gd")
	var sim: Variant = fresh(["meta", "mistral"])
	var struck := false
	var throw_teched := false
	for round_case in 2:
		if round_case == 1:
			sim.start_match({"operators": ["meta", "mistral"], "stage_id": "basalt-reach", "seed": 23017, "training": false})
			effects.reset()
			expect(effects.metrics().active == 0 and effects.metrics().accepted == 0, "new match FX resets active pool and dedup")
		var issued := false
		var tech_sent := false
		for tick in 360:
			var state: Dictionary = sim.snapshot()
			var inputs := [neutral(), neutral()]
			if state.phase == "fight":
				var distance := absi(int(state.fighters[0].x - state.fighters[1].x))
				if distance > 700 and not issued:
					inputs[0] = command(int(state.fighters[0].facing))
				elif not issued:
					inputs[0] = command(0, 0, 1 if round_case == 0 else 32)
					issued = true
				if round_case == 1 and not tech_sent and str(state.fighters[1].animation).begins_with("victim_"):
					inputs[1] = command(0, 0, 32)
					tech_sent = true
			var next: Dictionary = await render_tick(sim, inputs, "strike" if round_case == 0 else "tech")
			struck = struck or (round_case == 0 and next.fighters[1].hp < state.fighters[1].hp)
			for event in next.events:
				throw_teched = throw_teched or (round_case == 1 and event.type in ["throw_tech", "throw_break"])
			if tick > 220 and issued and (struck if round_case == 0 else throw_teched):
				break
	expect(struck, "ordinary-input native strike really damages Mistral")
	expect(throw_teched, "ordinary-input native normal throw really techs")
	expect(live_pause_exercised, "pause probe exercised nonempty live FX")
	var prior_metrics: Dictionary = effects.metrics()
	effects.set_paused(true)
	effects.advance(10.0)
	expect(effects.metrics().active == prior_metrics.active, "paused FX lifetime does not advance")
	effects.set_paused(false)
	var invalid_before := int(effects.metrics().invalid)
	effects.consume([{"id": "malformed", "x": "not a coordinate"}], sim.snapshot().fighters)
	expect(effects.metrics().invalid == invalid_before + 1, "malformed FX payload rejected and counted")
	var output := OS.get_environment("FIGHTING_ACCEPTANCE_EVIDENCE")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("slice-capture-index.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"captures": captures, "cadence": cadence, "stage": stage.metrics,
				"fx": effects.metrics(), "audio": "unrun: first slice muted", "anatomy": "unrun: authored fixtures required"}, "\t"))
	checks.append({"id": "meta-mistral-native-slice", "real_strike": struck, "real_tech": throw_teched,
		"capture_count": captures.size(), "rendered_frames": cadence.size(), "fx": effects.metrics()})
	expect(captures.size() >= 3, "native neutral/contact/tech captures exist")
	finish()
