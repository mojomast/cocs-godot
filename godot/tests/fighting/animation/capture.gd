extends SceneTree
## Deterministic side-on phase PNGs. Run only in the granted native/render slot.

const Visual = preload("res://fighting/visuals/fighter_visual.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var arguments := OS.get_cmdline_user_args()
	var operator := "meta"
	var clip := "stand_h"
	var victim_id := ""
	var output := "user://fighting-animation-captures"
	for index: int in range(arguments.size() - 1):
		match arguments[index]:
			"--operator": operator = arguments[index + 1]
			"--clip": clip = arguments[index + 1]
			"--victim": victim_id = arguments[index + 1]
			"--output": output = arguments[index + 1]
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	root.add_child(world)
	var visual := Visual.new()
	world.add_child(visual)
	if not visual.configure(operator):
		push_error(visual.unavailable_reason)
		quit(1)
		return
	var victim: Visual = null
	var pair: Dictionary = {}
	if not victim_id.is_empty():
		victim = Visual.new()
		world.add_child(victim)
		if not victim.configure(victim_id):
			push_error(victim.unavailable_reason)
			quit(1)
			return
		var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
		for entry: Dictionary in roster["operators"]:
			if entry["id"] == operator:
				var move: Dictionary = entry["moves"][clip]
				pair = move.get("throw", move.get("counter", {}))
		if pair.is_empty():
			push_error("Paired capture requires a throw/counter clip")
			quit(1)
			return
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.2, 1.1, 6.0)
	camera.look_at(Vector3(0.2, 1.1, 0.0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.075, 0.09, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	world.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.22, 0.25)
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Visual.ASSET_ROOT + operator + ".json"))
	if not manifest["clips"].has(clip):
		push_error("Unknown clip: " + clip)
		quit(1)
		return
	var shots: Array = []
	for knot: Array in manifest["clips"][clip]["seek_keys"]:
		var frame := float(knot[0])
		visual.present({"animation": clip, "animation_frame": frame, "facing": 1}, 0.0)
		if victim != null:
			victim.present({"animation": "victim_" + operator + "_" + clip, "animation_frame": frame,
				"x": int(pair.get("victim_x", 600)), "y": int(pair.get("victim_y", 0)), "facing": -1}, 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("%s-%s-frame-%06.2f.png" % [operator, clip, frame])
		var image := root.get_texture().get_image()
		if image.save_png(path) != OK:
			quit(1)
			return
		shots.append({"frame": frame, "authored_seconds": knot[1], "image": path})
	var file := FileAccess.open(output.path_join(operator + "-" + clip + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"operator": operator, "clip": clip, "shots": shots,
		"content_hashes": manifest["content_hashes"], "art_accepted": false}, "\t") + "\n")
	quit(0)
