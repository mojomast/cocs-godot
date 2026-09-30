extends SceneTree
## Deterministic renderer fixture, not a live-server gameplay capture. Every
## image comes from the Godot viewport; before/sequence share the same scene.
const Numbers = preload("res://world/damage_numbers.gd")
var output := ""
var compact := false
var quiet := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--compact": compact = true
		if arg == "--reduced-motion": quiet = true
	call_deferred("run")

func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)

func run() -> void:
	assert(not output.is_empty(), "Pass --output=/absolute/evidence/directory")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(760, 520) if compact else Vector2i(1280, 800)
	root.content_scale_factor = 1.5 if compact else 1.0
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1, 0)
	camera.current = true
	var target := MeshInstance3D.new()
	target.mesh = CapsuleMesh.new()
	target.position = Vector3(0, 1, -8)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("344b60")
	target.material_override = material
	world.add_child(target)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var label := Label.new()
	label.text = "DAMAGE / RENDERER FIXTURE\nExact event totals · outgoing 13 → 84 · incoming −19"
	label.position = Vector2(22, 18)
	label.add_theme_font_size_override("font_size", 15)
	layer.add_child(label)
	var crosshair := Label.new()
	crosshair.text = "+"
	layer.add_child(crosshair)
	await process_frame
	crosshair.position = root.get_visible_rect().size*0.5-Vector2(5, 12)
	var fx := Numbers.new()
	layer.add_child(fx)
	fx.configure(camera, func(_from: Vector3, _to: Vector3) -> bool: return false)
	fx.reduced_motion = quiet
	await save_frame("before")
	var actors := [{"id":2,"x":0.0,"y":0.0,"z":-8.0}]
	for frame in 25:
		if frame == 0: fx.consume([{"id":1,"type":"damage","actor":2,"source":1,"amount":12.25}], 1, actors)
		if frame == 2: fx.consume([{"id":2,"type":"damage","actor":2,"source":1,"amount":0.25}], 1, actors)
		if frame == 5: fx.consume([{"id":3,"type":"damage","actor":1,"source":null,"amount":19}], 1, actors)
		if frame == 7: fx.consume([{"id":4,"type":"damage","actor":2,"source":1,"amount":84}], 1, actors)
		await save_frame("frame-%03d" % frame)
		fx.advance(1.0/30.0)
	fx.advance(1.0)
	await save_frame("after")
	print("DAMAGE_NUMBERS_CAPTURE_OK ", output)
	quit(0)
