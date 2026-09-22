extends SceneTree
## Matched fixed-camera graphical fixtures, using actual game HUD and source weapon exports.
const Rig = preload("res://first_person/rig.gd")
const HUD = preload("res://ui/game_hud.gd")
var directory := ""
var rig: Node
var camera: Camera3D
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func cube(parent: Node, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	node.position = at
	parent.add_child(node)

func run() -> void:
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	var world := Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 4)
	camera.fov = 75
	world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -20, 0)
	world.add_child(sun)
	cube(world, Vector3(0, -0.2, -10), Vector3(40, 0.4, 45), Color("34434a"))
	cube(world, Vector3(0, 3, -14), Vector3(18, 6, 1), Color("708488"))
	for x: int in [-6, 6]:
		cube(world, Vector3(x, 2, -5), Vector3(2, 4, 5), Color("475b65"))
		cube(world, Vector3(x, 4, -5), Vector3(2.1, 0.15, 5.1), Color("65acb7"))
	for z: int in range(-12, 4, 2): cube(world, Vector3(0, 0.02, z), Vector3(0.06, 0.01, 0.9), Color("93aaa5"))
	rig = Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.reduced_motion = true
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.root.show()
	hud.status_panel.hide()
	var layer := CanvasLayer.new()
	layer.layer = 4
	root.add_child(layer)
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 24)
	layer.add_child(cross)
	var caption := Label.new()
	caption.position = Vector2(24, 70)
	layer.add_child(caption)
	var actor := {"id":7,"weapon":0,"health":100,"maxHealth":100,"armor":25,"ammo":["∞",6,6,10,28,6,10,12,10,32],"frags":3,"deaths":1}
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		hud.resize()
		cross.position = Vector2(size) / 2.0 - Vector2(7, 17)
		for id: int in [0,1,2,3,4,5,6,7,8,9]:
			actor.weapon = id
			rig.apply_actor(actor, true)
			for i: int in 8: rig.advance(0.05)
			hud.apply_state({"mapName":"FP geometry fixture", "config":{"mode":"deathmatch"},"actors":[actor]},7)
			caption.text = "FIXTURE · %s · source-authored chassis · FOV 75" % rig.manifest.weapons[id].name
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var path := directory.path_join("fixture-%dx%d-weapon-%d.png" % [size.x,size.y,id])
			root.get_texture().get_image().save_png(path)
			var weapon_image: Image = rig.viewport.get_texture().get_image()
			var center_pixels := 0
			for x: int in range(size.x/2-24, size.x/2+24):
				for y: int in range(size.y/2-24, size.y/2+24):
					if weapon_image.get_pixel(x,y).a > 0.01: center_pixels += 1
			var instances := 0
			var triangles := 0
			for node: MeshInstance3D in rig.pivot.find_children("*", "MeshInstance3D", true, false):
				instances += 1
				for surface: int in node.mesh.get_surface_count():
					var arrays := node.mesh.surface_get_arrays(surface)
					var indices: Variant = arrays[Mesh.ARRAY_INDEX]
					triangles += (indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			measurements.append({"size":[size.x,size.y],"weapon":id,"center_48px_occupied":center_pixels,"mesh_instances":instances,"triangles_with_hands_flash":triangles})
			if center_pixels > 0:
				push_error("Weapon obscures center reticle region")
				quit(1)
				return
		# A wall between camera and gun must not occlude isolated geometry.
		cube(world, camera.position + Vector3(0,0,-0.12), Vector3(10,10,0.05), Color("435763"))
		actor.weapon = 0
		rig.apply_actor(actor,true)
		hud.apply_state({"mapName":"FP geometry fixture", "config":{"mode":"deathmatch"},"actors":[actor]},7)
		for i: int in 8: rig.advance(0.05)
		caption.text = "FIXTURE · wall 0.12m from eye · independent viewmodel depth"
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("wall-%dx%d.png" % [size.x,size.y]))
		world.get_child(world.get_child_count()-1).free()
	actor.weapon = 3
	rig.apply_actor(actor,true)
	for i: int in 8: rig.advance(0.05)
	rig.apply_events([{"id":1,"time":1.0,"type":"shot","actor":7,"weapon":3}],7)
	rig.advance(0)
	hud.apply_state({"mapName":"FP geometry fixture", "config":{"mode":"deathmatch"},"actors":[actor]},7)
	caption.text = "FIXTURE · Scattergun · injected source-shaped shot event · dual muzzle flash"
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("fixture-fire-scattergun.png"))
	actor.reloading = true
	actor.reloadDuration = 1.9
	actor.reloadTimer = 0.95
	rig.apply_actor(actor,true)
	for i: int in 8: rig.advance(0.05)
	hud.apply_state({"mapName":"FP geometry fixture", "config":{"mode":"deathmatch"},"actors":[actor]},7)
	caption.text = "FIXTURE · Scattergun · reloading=true, progress=0.5 · source barrel hinge"
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("fixture-reload-scattergun.png"))
	FileAccess.open(directory.path_join("framing-metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t")+"\n")
	print("FIRST_PERSON_FRAMING_OK images=24 sizes=960x640,1280x800 center_48px_clear=true")
	quit()
