extends SceneTree
## Lit, animated inspection fixture. --capture=/absolute/path.png exits after capture.
const Robot = preload("res://campaign/robot_visual.gd")
var robots: Array[Node3D] = []
var time: float = 0.0
var stage: int = -1
var capture_path: String = ""
var frames: int = 0
var fixed_pose: int = -1
var gallery_lod: int = 0
var focus: int = -1
var frames_dir: String = ""

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--pose="): fixed_pose = int(arg.trim_prefix("--pose="))
		if arg.begins_with("--lod="): gallery_lod = clampi(int(arg.trim_prefix("--lod=")), 0, 2)
		if arg.begins_with("--focus="): focus = clampi(int(arg.trim_prefix("--focus=")), 0, 5)
		if arg.begins_with("--frames-dir="): frames_dir = arg.trim_prefix("--frames-dir=")
	root.size = Vector2i(1600, 1000)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101d2b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8aa7c0")
	env.environment.ambient_light_energy = 0.65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	scene.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_color = Color("ffddba")
	key.light_energy = 2.1
	key.shadow_enabled = true
	scene.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 0)
	rim.light_color = Color("70baff")
	rim.light_energy = 1.1
	scene.add_child(rim)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(9, 10, 17)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	if focus >= 0:
		camera.position = Vector3(3.2, 2.8, 5.6)
		camera.look_at(Vector3(0, 0.8, 0))
		camera.size = 3.7
	camera.current = true
	for i: int in range(6):
		if focus >= 0 and i != focus: continue
		var x: float = 0.0 if focus >= 0 else (i % 3 - 1) * 4.5
		var z: float = 0.0 if focus >= 0 else (-2.8 if i < 3 else 2.8)
		var pedestal := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.85; mesh.bottom_radius = 1.95; mesh.height = 0.18; mesh.radial_segments = 12
		pedestal.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("29394a")
		material.metallic = 0.3; material.roughness = 0.7
		pedestal.material_override = material
		pedestal.position = Vector3(x, -0.09, z)
		scene.add_child(pedestal)
		var robot := Robot.new()
		scene.add_child(robot)
		robot.position = Vector3(x, 0.9, z)
		robot.rotation.y = PI - 0.25
		robot.automatic_animation = false
		robot.automatic_lod = false
		robot.configure({"id":i, "npcModel":Robot.IDS[i], "health":100, "vx":2.0, "shots":0, "npcProfile":{"scale":1.35 if i == 5 else 1.0}})
		robots.append(robot)
		robot.set_lod(gallery_lod)
		var label := Label3D.new()
		label.text = "%02d / %s" % [i + 1, str(Robot.IDS[i]).to_upper()]
		label.position = Vector3(x, 0.08, z + (1.4 if focus >= 0 else 1.8))
		label.rotation_degrees.x = -65
		label.font_size = 46; label.pixel_size = 0.008
		label.modulate = Color("e3c49a")
		scene.add_child(label)
	var title := Label.new()
	title.text = "THE QUIET RELAY  /  SECURITY AUTOMATA\nSix articulated chassis · source-state animation · manual three-band LOD"
	title.position = Vector2(44, 30)
	title.add_theme_font_size_override("font_size", 27)
	root.add_child(title)
	var note := Label.new()
	note.text = "Synthetic gallery: locomotion → authority windup → shot/recovery → death → reset   |   Not live gameplay evidence"
	note.position = Vector2(44, 940)
	note.add_theme_font_size_override("font_size", 18)
	root.add_child(note)

func _process(dt: float) -> bool:
	if robots.is_empty(): return false
	var step: float = dt if capture_path.is_empty() and frames_dir.is_empty() else 1.0 / 60.0
	time += step
	frames += 1
	var next: int = fixed_pose if fixed_pose >= 0 else int(time / 2.0) % 5
	if next != stage:
		stage = next
		for robot: Node3D in robots:
			var actor: Dictionary = robot.snapshot.duplicate(true)
			actor.health = 0 if stage == 3 else 100
			actor.vx = 2.0 if stage == 0 else 0.0
			for field: String in ["artilleryWindup", "phalanxWindup", "flankWindup", "bossStompWindup"]: actor.erase(field)
			if stage == 1:
				match robot.model_id:
					"mortar": actor.artilleryWindup = 0.25
					"sentinel": actor.phalanxWindup = 0.12
					"skirmisher": actor.flankWindup = 0.1
					"warden": actor.bossStompWindup = 0.2
			if stage == 2: actor.shots = int(actor.get("shots", 0)) + 1
			robot.apply_actor(actor)
	for robot: Node3D in robots: robot.advance(step)
	if not frames_dir.is_empty() and frames % 5 == 0 and frames <= 600:
		var frame_path: String = "%s/frame-%03d.png" % [frames_dir, frames / 5 - 1]
		capture_frame(frame_path, frames == 600)
	if not capture_path.is_empty() and frames == 45:
		await RenderingServer.frame_post_draw
		var error: int = root.get_texture().get_image().save_png(capture_path)
		print("CAMPAIGN_ROBOT_GALLERY capture=", capture_path, " error=", error)
		quit(error)
	return false

func capture_frame(path: String, last: bool) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	if last:
		print("CAMPAIGN_ROBOT_GALLERY clip_frames=120 path=", frames_dir)
		quit()
