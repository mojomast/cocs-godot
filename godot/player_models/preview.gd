extends Node3D
const Candidate = preload("res://player_models/candidate.gd")
const Baseline = preload("res://world/actor_visual.gd")
var camera: Camera3D
var actors: Node3D
var caption: Label
var floor_mesh: MeshInstance3D
var output := ""
var env: Environment

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var environment := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("252d3a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b6c9df")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40,-30,0)
	key.light_energy = 1.1
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15,145,0)
	fill.light_energy = 0.5
	add_child(fill)
	floor_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(20,.04,20)
	floor_mesh.mesh = mesh
	floor_mesh.position.y = -.93
	floor_mesh.material_override = Candidate.material(Color("535d69"))
	add_child(floor_mesh)
	actors = Node3D.new()
	add_child(actors)
	camera = Camera3D.new()
	camera.fov = 65
	camera.current = true
	add_child(camera)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(20,15)
	caption.add_theme_font_size_override("font_size",18)
	canvas.add_child(caption)
	populate(false,3)
	camera.position = Vector3(2,1.1,-4)
	camera.look_at(Vector3(0,0,0))
	if not output.is_empty(): call_deferred("capture_single" if "--single" in OS.get_cmdline_user_args() else "capture_all")
	else: caption.text = "Candidate | Claude / Grok / Meta | static grip fixture, not animation"

func populate(old: bool,count: int) -> void:
	for child: Node in actors.get_children():
		actors.remove_child(child)
		child.free()
	for i: int in range(count):
		var actor: Node3D = Baseline.new() if old else Candidate.new()
		actor.apply_identity({"character":["claude","grok","meta"][i%3],"team":0 if i%2==0 else 1})
		actors.add_child(actor)
		actor.position = Vector3((i%8 - min(count-1,7)/2.0)*1.05,0,int(i/8)*1.4)
	# Solid 1.8m scale pole, present in both matched models.
	var reference := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.025,1.8,.025)
	reference.mesh = box
	reference.position = Vector3(-1.7,0,0)
	reference.material_override = Candidate.material(Color("e8e5ce"))
	actors.add_child(reference)

func shot(label: String,position: Vector3,target: Vector3 = Vector3.ZERO) -> void:
	camera.position = position
	camera.look_at(target,Vector3.FORWARD if absf(position.y)>2.9 and absf(position.z)<.1 else Vector3.UP)
	caption.text = label + " | static fixture | 1.8m reference | FOV 65 vertical"
	for frame: int in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")
	if error != OK:
		push_error("capture failed")
		get_tree().quit(1)

func capture_single() -> void:
	for dimensions: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		get_window().size = dimensions
		await shot("release-%dx%d"%[dimensions.x,dimensions.y],Vector3(2,1.1,-4))
	print("PLAYER_MODEL_RELEASE_RENDER_OK")
	get_tree().quit(0)

func capture_all() -> void:
	var metrics := []
	for dimensions: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		get_window().size = dimensions
		for old: bool in [true,false]:
			populate(old,3)
			var prefix := ("baseline" if old else "candidate")+"-%dx%d-"%[dimensions.x,dimensions.y]
			for distance: float in [3.0,10.0,25.0]:
				await shot(prefix+"front-"+str(int(distance))+"m",Vector3(0,0,-distance))
			for actor: Node3D in actors.get_children(): actor.rotation.y = PI/2
			await shot(prefix+"side",Vector3(0,.15,-3.8))
			for actor: Node3D in actors.get_children(): actor.rotation.y = PI
			await shot(prefix+"back",Vector3(0,.15,-3.8))
			for actor: Node3D in actors.get_children(): actor.rotation.y = 0
			await shot(prefix+"perspective",Vector3(2,1.1,-4))
			await shot(prefix+"top",Vector3(0,3.8,0))
			floor_mesh.visible = false
			await shot(prefix+"underside",Vector3(0,-3.8,0))
			floor_mesh.visible = true
			await shot(prefix+"attachment",Vector3(1.1,.4,-2.0),Vector3(.1,.05,-.25))
			var black := Candidate.material(Color.BLACK)
			black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for actor: Node3D in actors.get_children():
				for part: MeshInstance3D in actor.get_children(): part.material_override = black
			env.background_color = Color("e5e8ec")
			floor_mesh.visible = false
			await shot(prefix+"silhouette",Vector3(0,0,-3))
			env.background_color = Color("252d3a")
			floor_mesh.visible = true
			for count: int in [1,16,32]:
				populate(old,count)
				camera.position = Vector3(0,3,-10)
				camera.look_at(Vector3(0,0,2))
				caption.text = "Synthetic population " + str(count)
				for warm: int in range(20): await get_tree().process_frame
				var samples := []
				var draws := []
				var previous := Time.get_ticks_usec()
				for frame: int in range(100):
					await RenderingServer.frame_post_draw
					var now := Time.get_ticks_usec()
					samples.append(now-previous)
					previous = now
					draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
					await get_tree().process_frame
				metrics.append({"baseline":old,"count":count,"size":[dimensions.x,dimensions.y],"frame_usec":samples,"draw_calls":draws,"renderer":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method()})
	var file := FileAccess.open(output+"/render-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics))
	print("PLAYER_MODEL_CAPTURE_OK output=",output)
	get_tree().quit(0)
