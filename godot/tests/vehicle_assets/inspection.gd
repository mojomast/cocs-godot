extends SceneTree
const Puma = preload("res://vehicles/puma.gd")
const Chassis = preload("res://combined_arms/chassis.gd")
const Adapter = preload("res://vehicle_assets/attachment.gd")
var scene := Node3D.new()
var camera := Camera3D.new()
var label := Label.new()
var out := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): out = arg.trim_prefix("--evidence=")
	call_deferred("run")

func capture(name: String, details: Dictionary) -> void:
	label.text = name + " · authored GLB rigid assemblies · staged inspection"
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out.path_join(name+".png"))
	print("VEHICLE_INSPECTION ",JSON.stringify({"name":name,"error":error,"ticksMs":Time.get_ticks_msec(),"frame":Engine.get_frames_drawn(),"camera":str(camera.global_position),"details":details}))
	if error != OK: quit(2)

func run() -> void:
	root.size = Vector2i(1280,800)
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("687985")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7d6e0")
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("78827a")
	floor_material.roughness = 0.9
	floor_mesh.material_override = floor_material
	scene.add_child(floor_mesh)
	scene.add_child(camera)
	camera.current = true
	camera.fov = 42
	var layer := CanvasLayer.new()
	scene.add_child(layer)
	label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",22)
	layer.add_child(label)
	for kind: String in ["puma","titan","scout"]:
		var host: Node3D = Puma.new() if kind == "puma" else Chassis.new(kind)
		scene.add_child(host)
		if host.get_meta("authored_vehicle","") != kind:
			push_error("Required inspection art absent: "+kind)
			quit(2)
			return
		Adapter.set_team(host,Color("dfc98d"))
		Adapter.apply_source_pose(host,{"yaw":0.0,"turretYaw":0.0})
		var targets: Array = [host,host.turret]+host.wheels
		for lod in 3:
			for target: Node3D in targets:
				for child: Node in target.get_children():
					if child is MeshInstance3D and child.visible and not child.has_meta("range_begin"):
						child.set_meta("range_begin",child.visibility_range_begin)
						child.set_meta("range_end",child.visibility_range_end)
					if child is MeshInstance3D and child.has_meta("range_begin"):
						var selected: bool = float(child.get_meta("range_begin")) == [0.0,24.0,65.0][lod]
						child.visible = selected
						child.visibility_range_begin = 0
						child.visibility_range_end = 0
			camera.position = Vector3(5.2,3.6,6.5) * (1.25 if kind == "titan" else 0.8 if kind == "scout" else 1.0)
			camera.look_at(Vector3(0,.65,0))
			await capture(kind+"-lod%d-close" % lod,{"forcedLod":lod,"purpose":"compare actual topology at equal visual scale"})
		# Restore ranges for actual camera-distance transition captures.
		for target: Node3D in targets:
			for child: Node in target.get_children():
				if child is MeshInstance3D and child.has_meta("range_begin"):
					child.visible = true
					child.visibility_range_begin = child.get_meta("range_begin")
					child.visibility_range_end = child.get_meta("range_end")
		for distance: float in [22.0,26.0,63.0,67.0]:
			camera.position = Vector3(.6,.22,.8).normalized()*distance
			camera.look_at(Vector3(0,.7,0))
			await capture(kind+"-distance-%d" % int(distance),{"distance":distance,"forcedLod":false})
		root.size = Vector2i(760,520)
		label.add_theme_font_size_override("font_size",26)
		camera.position = Vector3(-4,2.1,-6)
		camera.look_at(Vector3(0,.65,0))
		await capture(kind+"-compact-rear",{"purpose":"rear mechanical readability; not gameplay HUD"})
		root.size = Vector2i(1280,800)
		label.add_theme_font_size_override("font_size",22)
		host.queue_free()
		await process_frame
	print("VEHICLE_INSPECTION_COMPLETE")
	quit()
