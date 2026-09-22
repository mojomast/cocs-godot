extends SceneTree
## Rendered review of the ten exported world weapons on the actual source
## operators, including the post-pose hand pass.
##
## Wide captures use the real window at 1280x800 and 960x640. Comparison
## captures are SubViewport cells with one weapon per cell, each cell its own
## world, so every weapon is rendered from the identical relative camera - that
## is what makes the ten silhouettes comparable at 10 m and 25 m. Cells are
## assembled into 1280x800 and 960x640 sheets with Image.blit_rect.
const Visual = preload("res://source_operators/operator_visual.gd")
const CHARACTER := "claude"
const WEAPON_COUNT := 10
var evidence := ""
var environment: Environment

func _init() -> void:
	call_deferred("run")

func settle(frames: int = 2) -> void:
	for i: int in range(frames): await process_frame
	await RenderingServer.frame_post_draw

func camera_look(camera: Camera3D, target: Vector3, offset: Vector3) -> void:
	camera.position = target + offset
	camera.look_at(target)

func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("25313d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	return env

func add_light(parent: Node) -> void:
	var light := DirectionalLight3D.new()
	parent.add_child(light)
	light.position = Vector3(-3,5,-4)
	light.look_at(Vector3.ZERO)
	light.light_energy = 2.0

func add_floor(parent: Node, size: float = 120.0) -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(size,size)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color("374652"); floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	parent.add_child(floor_mesh)

func spawn_actor(parent: Node, weapon: int, position: Vector3, yaw: float, character: String = CHARACTER) -> Visual:
	var actor := Visual.new()
	actor.automatic_animation = false
	actor.local_id = -99
	parent.add_child(actor)
	actor.position = Vector3(position.x, 0.9, position.z)
	actor.rotation.y = yaw
	actor.apply_actor({"id":weapon,"character":character,"team":2,"health":100,"dead":0,"weapon":weapon,
		"x":position.x,"y":0.0,"z":position.z,"yaw":yaw,"bodyYaw":yaw,"pitch":0.0,"vx":0.0,"vz":0.0,
		"grounded":true,"ads":false,"reloading":false,"crouching":false,"shots":0,"moveSpeed":8.0,"eyeHeight":1.45})
	actor.advance(1.0/60.0)
	return actor

func capture_window(file: String, size: Vector2i) -> void:
	root.size = size
	await settle(3)
	root.get_texture().get_image().save_png(evidence.path_join(file))

func run() -> void:
	evidence = OS.get_environment("OPERATOR_EVIDENCE")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if evidence.is_empty(): push_error("OPERATOR_EVIDENCE is required"); quit(1); return
	environment = make_environment()
	var stage := Node3D.new(); root.add_child(stage)
	var world := WorldEnvironment.new(); world.environment = environment; stage.add_child(world)
	add_light(stage)
	add_floor(stage)
	var camera := Camera3D.new(); camera.fov = 50.0; camera.near = 0.05; camera.far = 200.0
	stage.add_child(camera); camera.make_current()
	var actors: Array[Visual] = []
	for i: int in range(WEAPON_COUNT):
		actors.append(await spawn_actor(stage, i, Vector3((i-4.5)*1.04, 0, 0), PI))
	# Family line: all ten weapons with the post-pose hands in one frame.
	for actor: Visual in actors: actor.select_distance(7.0)
	camera_look(camera, Vector3(0,1.05,0), Vector3(0,0.42,7.0))
	await capture_window("detail-line-1280x800.png", Vector2i(1280,800))
	await capture_window("detail-line-960x640.png", Vector2i(960,640))
	# Left and right receiver faces: feed and handguard vs port and rail.
	camera_look(camera, Vector3(-2.1,1.12,0), Vector3(-1.25,0.20,1.60))
	await capture_window("detail-left-1280x800.png", Vector2i(1280,800))
	camera_look(camera, Vector3(-2.1,1.12,0), Vector3(1.35,0.16,1.60))
	await capture_window("detail-right-1280x800.png", Vector2i(1280,800))
	# Close-up on weapons 3, 4 and 7 with both hands on the weapon.
	camera_look(camera, Vector3(-2.1,1.12,0), Vector3(0.55,0.06,2.30))
	await capture_window("detail-hands-1280x800.png", Vector2i(1280,800))
	for actor: Visual in actors: actor.free()
	# Identical-camera comparison sheets.
	# close: 3/4 front-right at 1.45 m, FOV 50 - receiver, rail/optic, muzzle.
	# silhouette: near-profile from the right at gameplay FOV for 10 m and 25 m.
	# grip: 0.5 m from the front-left and front-right where the hands wrap.
	var wanted := OS.get_environment("DETAIL_SHEETS")
	if wanted.is_empty(): wanted = "close,silhouette-10m,silhouette-25m,grip,feed"
	if wanted.contains("close"): await sheet("close", "weapon", 1.45, Vector3(0.34,0.18,0.92), 50.0)
	if wanted.contains("silhouette-10m"): await sheet("silhouette-10m", "weapon", 10.0, Vector3(0.95,0.06,0.30), 75.0)
	if wanted.contains("silhouette-25m"): await sheet("silhouette-25m", "weapon", 25.0, Vector3(0.95,0.06,0.30), 75.0)
	if wanted.contains("grip"): await sheet("grip", "grip", 0.95, Vector3(-0.62,0.42,0.66), 50.0)
	if wanted.contains("feed"): await sheet("feed", "feed", 0.62, Vector3(-0.80,0.22,0.55), 50.0)
	quit()

func sheet(name: String, aim: String, distance: float, direction: Vector3, fov: float) -> void:
	# One cell per weapon, identical relative camera in every cell, at both
	# reviewed resolutions (5x2 cells of 256x400 and of 192x320).
	await sheet_size(name, aim, distance, direction, fov, Vector2i(256,400), Vector2i(1280,800))
	await sheet_size(name, aim, distance, direction, fov, Vector2i(192,320), Vector2i(960,640))

func sheet_size(name: String, aim: String, distance: float, direction: Vector3, fov: float, cell: Vector2i, out_size: Vector2i) -> void:
	var columns: int = 5
	var rows: int = 2
	var sheet_image := Image.create(out_size.x, out_size.y, false, Image.FORMAT_RGBA8)
	sheet_image.fill(Color("131a20"))
	# Same frames, central crop at 2x, so a distance read can be inspected
	# without changing the rendered field of view.
	var crop_image := Image.create(out_size.x, out_size.y, false, Image.FORMAT_RGBA8)
	crop_image.fill(Color("131a20"))
	for i: int in range(WEAPON_COUNT):
		var view := SubViewport.new()
		view.size = cell
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var world := WorldEnvironment.new(); world.environment = environment; view.add_child(world)
		add_light(view)
		add_floor(view, 40.0)
		var actor := await spawn_actor(view, i, Vector3.ZERO, PI)
		var weapon: Node3D = actor.world_weapon
		var muzzle: Node3D = weapon.find_child("Muzzle",true,false)
		var grip_right: Node3D = weapon.find_child("WeaponGripRight",true,false)
		var grip_left: Node3D = weapon.find_child("WeaponGripLeft",true,false)
		var target: Vector3 = (muzzle.global_position + grip_right.global_position) * 0.5 + Vector3(0,0.02,0)
		if aim == "grip" and grip_left != null: target = grip_left.global_position
		if aim == "feed" and grip_left != null: target = (grip_left.global_position + muzzle.global_position) * 0.5
		var camera := Camera3D.new(); camera.fov = fov; camera.near = 0.02; camera.far = 160.0
		view.add_child(camera)
		actor.select_distance(distance)
		camera_look(camera, target, direction.normalized() * distance)
		camera.make_current()
		for frame: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		if image.get_size() != cell: image.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		var slot_size := Vector2i(out_size.x / columns, out_size.y / rows)
		if cell != slot_size: image.resize(slot_size.x, slot_size.y, Image.INTERPOLATE_LANCZOS)
		sheet_image.blit_rect(image, Rect2i(Vector2i.ZERO, slot_size), Vector2i((i % columns) * slot_size.x, int(i / columns) * slot_size.y))
		var crop_size := Vector2i(cell.x / 2, cell.y / 2)
		var crop := image.get_region(Rect2i(Vector2i((cell.x - crop_size.x) / 2, (cell.y - crop_size.y) / 2), crop_size))
		crop.resize(slot_size.x, slot_size.y, Image.INTERPOLATE_LANCZOS)
		crop_image.blit_rect(crop, Rect2i(Vector2i.ZERO, slot_size), Vector2i((i % columns) * slot_size.x, int(i / columns) * slot_size.y))
		view.free()
	var file: String = "%s-%dx%d.png" % [name, out_size.x, out_size.y]
	sheet_image.save_png(evidence.path_join(file))
	crop_image.save_png(evidence.path_join("%s-crop-%dx%d.png" % [name, out_size.x, out_size.y]))
