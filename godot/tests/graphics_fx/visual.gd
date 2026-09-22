extends SceneTree

const FX = preload("res://graphics_fx/moth_world.gd")
const Fixtures = preload("res://tests/graphics_fx/fixture_library.gd")
var failures := 0
var evidence: String

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame: int in range(5): await process_frame
	await RenderingServer.frame_post_draw

func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	node.position = pos
	parent.add_child(node)
	return node

func label(parent: Node, text: String, at: Vector3) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = 32
	node.pixel_size = 0.009
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	node.position = at
	parent.add_child(node)

func changed(a: Image, b: Image) -> int:
	var count := 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var av := a.get_pixel(x, y)
			var bv := b.get_pixel(x, y)
			if absf(av.r - bv.r) + absf(av.g - bv.g) + absf(av.b - bv.b) > 0.025: count += 1
	return count

func run() -> void:
	evidence = OS.get_environment("MOTH_VFX_EVIDENCE")
	check(not evidence.is_empty(), "evidence output directory required")
	var resources := Fixtures.resources()
	for key: String in resources:
		var source_image: Image = resources[key].frames[1].get_image()
		source_image.resize(384,384,Image.INTERPOLATE_NEAREST)
		source_image.save_png(evidence.path_join("source-" + key + ".png"))
	# Isolated renderer proof: actual source texture against a known solid field.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.17, 0.22)
	viewport.add_child(environment)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 6)
	camera.look_at(Vector3.ZERO)
	var fx := FX.new()
	viewport.add_child(fx)
	fx.configure_resources(resources)
	fx.set_process(false)
	var event := {"id":1,"type":"explosion","pos":{"x":0,"y":0,"z":0}}
	await settle()
	var base := viewport.get_texture().get_image()
	fx.consume([event])
	await settle()
	var frame_zero := viewport.get_texture().get_image()
	fx.advance(0.08)
	await settle()
	var near := viewport.get_texture().get_image()
	check(changed(frame_zero,near) > 50, "source sequence frame change produces different real pixels")
	near.save_png(evidence.path_join("alpha-near.png"))
	var near_pixels := changed(base, near)
	check(near_pixels > 150, "real textured effect is visibly rendered")
	# Projected card spans about 92 px at 6m. Four rectangular card corners must
	# retain the field; center coverage is deliberately non-uniform, not a square.
	for point: Vector2i in [Vector2i(84,84), Vector2i(171,84), Vector2i(84,171), Vector2i(171,171)]:
		check(near.get_pixelv(point).is_equal_approx(base.get_pixelv(point)), "card corner is transparent")
	var tones := {}
	for y: int in range(80,176):
		for x: int in range(80,176): tones[near.get_pixel(x,y).to_rgba32()] = true
	check(tones.size() > 50, "soft alpha / detailed color rather than a flat card")
	camera.position = Vector3(0,0,12)
	await settle()
	var far := viewport.get_texture().get_image()
	far.save_png(evidence.path_join("alpha-far.png"))
	var far_pixels := changed(base,far)
	check(far_pixels > 30 and far_pixels < near_pixels / 2, "world-size distance falloff remains visible")
	camera.position = Vector3(8,6,6).normalized() * 6
	camera.look_at(Vector3.ZERO)
	await settle()
	var angled := viewport.get_texture().get_image()
	angled.save_png(evidence.path_join("alpha-angled.png"))
	var angled_pixels := changed(base,angled)
	check(absf(float(angled_pixels - near_pixels)) / near_pixels < 0.08, "billboard retains silhouette at oblique camera angle")
	var blocker := box(viewport, camera.position.normalized() * 2, Vector3(5,5,5), Color(0.25,0.3,0.35))
	await settle()
	var blocked := viewport.get_texture().get_image()
	fx.visible = false
	await settle()
	var blocked_base := viewport.get_texture().get_image()
	check(changed(blocked,blocked_base) == 0, "opaque world geometry occludes FX; depth test stays enabled")
	blocker.free()
	fx.visible = true
	fx.advance(0.419)
	await settle()
	check(changed(base,viewport.get_texture().get_image()) < angled_pixels / 4, "end-of-life alpha fades")
	fx.advance(1)
	await settle()
	check(changed(base,viewport.get_texture().get_image()) == 0, "expired effect leaves no pixels")
	viewport.free()
	# Readable two-row visual fixture, independent of the source game scene.
	var world := Node3D.new()
	root.add_child(world)
	var world_camera := Camera3D.new()
	world.add_child(world_camera)
	world_camera.fov = 48
	world_camera.position = Vector3(4.0,9.0,16)
	world_camera.look_at(Vector3(0,1,-3.5))
	for x: int in range(-8,9):
		for z: int in range(-12,5):
			box(world,Vector3(x, -0.1, z),Vector3(0.97,0.1,0.97), Color(0.13,0.18,0.22) if (x+z)%2 == 0 else Color(0.2,0.25,0.29))
	var display_fx := FX.new()
	world.add_child(display_fx)
	display_fx.configure_resources(resources)
	display_fx.set_process(false)
	var fixture := Fixtures.events()
	display_fx.consume(fixture.events, 7, fixture.actors)
	display_fx.consume([
		{"id":20,"type":"explosion","pos":{"x":-1.8,"y":1.5,"z":-8}},
		{"id":21,"type":"damage","actor":10,"amount":12},
	],7,[{"id":10,"x":-5.4,"y":0.5,"z":-8}])
	display_fx.advance(0.08)
	for z: float in [0.0,-8.0]:
		label(world,"CONFIRMED\nDAMAGE",Vector3(-5.4,0.3,z))
		label(world,"EXPLOSION",Vector3(-1.8,0.3,z))
		label(world,"TELEPORT",Vector3(1.8,0.3,z))
		label(world,"HEAL",Vector3(5.4,0.3,z))
	var overlay := Label.new()
	overlay.text = "MOTH WORLD FX / SOURCE-INFORMED FIXTURE\nBaked RGBA + mask/exposure | normal alpha | billboard | world depth\nNear / far rows · Godot 4.5.2 Compatibility · no glow"
	overlay.position = Vector2(20,16)
	overlay.add_theme_font_size_override("font_size",18)
	root.add_child(overlay)
	await settle()
	var image := root.get_texture().get_image()
	var size := image.get_size()
	image.save_png(evidence.path_join("fixture-%dx%d.png" % [size.x,size.y]))
	var report := {"fixture":true,"size":[size.x,size.y],"near_changed_pixels":near_pixels,"far_changed_pixels":far_pixels,
		"angled_changed_pixels":angled_pixels,"alpha_color_tones":tones.size(),"failures":failures,
		"renderer":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(evidence.path_join("render-%d.json" % size.x),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("MOTH_VFX_RENDER ",JSON.stringify(report))
	quit(0 if failures == 0 else 1)
