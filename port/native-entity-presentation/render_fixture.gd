extends SceneTree

# Controlled render fixture of the production presentation classes, NOT gameplay.
const Presentation = preload("res://world/presentation.gd")
const Pickups = preload("res://world/pickups.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b2c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6cee6")
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.4
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.8
	camera.position = Vector3(0, 5.5, -10)
	camera.look_at(Vector3(0, 0.6, 0))
	var view := Presentation.new()
	scene.add_child(view)
	var actors: Array = []
	var chars: Array = ["chatgpt", "claude", "kimi", "meta", "mistral"]
	var teams: Array = [-1, 0, 1, -1, -1]
	var yaws: Array = [0.0, -0.3, 0.3, PI / 2, PI]
	for i: int in range(chars.size()):
		actors.append({"id": i, "x": (2 - i) * 1.5, "y": 0, "z": 1.1, "health": 100, "dead": 0, "character": chars[i], "team": teams[i], "bodyYaw": yaws[i]})
	view.apply_state({"actors": actors}, -1)
	var pickups := Pickups.new()
	scene.add_child(pickups)
	var sources: Array = []
	var kinds: Array = ["health", "armor", "rocket", "rail", "overcharge"]
	for i: int in range(kinds.size()):
		sources.append({"id": i, "x": (2 - i) * 1.5, "y": -0.35, "z": -1.65, "wait": 0, "kind": kinds[i]})
	pickups.apply_state({"pickups": sources})
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(11, 0.1, 7)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("25394c")
	floor_node.material_override = material
	scene.add_child(floor_node)
	var ui := CanvasLayer.new()
	scene.add_child(ui)
	var title := Label.new()
	title.position = Vector2(40, 28)
	title.add_theme_font_size_override("font_size", 26)
	title.text = "NATIVE ENTITY PRESENTATION / CONTROLLED RENDER FIXTURE"
	ui.add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(40, 70)
	subtitle.text = "Production actor + pickup classes · original primitive geometry · Godot 4.5.2\nCharacter visors / red one-stripe + blue two-stripe armor / forward, side and rear silhouettes"
	ui.add_child(subtitle)
	var footer := Label.new()
	footer.position = Vector2(40, 735)
	footer.text = "Medical case   /   pointed shield   /   twin rockets   /   supply cells   /   power core\nSynthetic layout for art inspection. This image is not live gameplay or pickup-collection evidence."
	ui.add_child(footer)
	for i: int in range(4): await RenderingServer.frame_post_draw
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		quit(1)
		return
	var result: Error = root.get_texture().get_image().save_png(output)
	print("PORT_ENTITY_RENDER_FIXTURE saved=", result == OK)
	quit(result)
