extends SceneTree
## Rendered contract tests: imported geometry, source policy, articulated contacts,
## source-world muzzle reprojection, lifecycle, actual HUD, and resize/FOV changes.
const Rig = preload("res://first_person/rig.gd")
const HUD = preload("res://ui/game_hud.gd")
var directory := ""
var failures: Array[String] = []
var checks := 0
var metrics: Array[Dictionary] = []
var rig: Node
var camera: Camera3D
var hud: Node
var caption: Label
var actor := {"id":7,"weapon":0,"health":100,"maxHealth":100,"armor":25,"ammo":[99,6,6,10,28,6,10,12,10,32],"frags":3,"deaths":1}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func box(parent: Node, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)

func step(frames: int) -> void:
	for frame: int in frames:
		rig.advance(1.0 / 60.0)
		camera.fov = rig.get_aim_state(75.0).fov
	# Flush source-camera projection into isolated viewport without changing time.
	rig.advance(0)

func capture(state: String) -> void:
	caption.text = "NATIVE ADS FIXTURE | %s | %s | FOV %.2f | %dx%d" % [rig.manifest.weapons[actor.weapon].name, state, camera.fov, root.size.x, root.size.y]
	hud.apply_state({"mapName":"ADS anchor/pose verification", "config":{"mode":"deathmatch"},"actors":[actor]},7)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("%dx%d-weapon-%d-%s.png" % [root.size.x,root.size.y,actor.weapon,state]))

func measure(label: String, settled: bool) -> void:
	var center := Vector2(root.size) / 2.0
	var points: Dictionary = rig.get_sight_screen_positions()
	var rear_error: float = points.rear.distance_to(center)
	var front_error: float = points.front.distance_to(center)
	var rear: Vector3 = rig.anchors.SightRear.global_position
	var front: Vector3 = rig.anchors.SightFront.global_position
	var axis_error := rad_to_deg((front - rear).normalized().angle_to(Vector3.FORWARD))
	var muzzle_error := 0.0
	var muzzle_pixels: Array = []
	for index: int in rig.get_muzzle_count():
		var mapped: Transform3D = rig.get_muzzle_world_transform(index)
		var pixel: Vector2 = rig.get_muzzle_screen_position(index)
		muzzle_error = maxf(muzzle_error, camera.unproject_position(mapped.origin).distance_to(pixel))
		muzzle_pixels.append([pixel.x,pixel.y])
		check(mapped.is_finite(), "finite muzzle transform " + label)
	check(muzzle_error < 0.01, "source-world muzzle reprojection " + label)
	var right_error: float = rig.wrists[1].global_position.distance_to(rig.anchors.GripRight.global_position)
	check(right_error < 0.00001, "right grip constrained " + label)
	if settled:
		check(rear_error < 0.01 and front_error < 0.01 and axis_error < 0.001, "ADS center/axis " + label)
		check(rig.wrists[-1].global_position.distance_to(rig.anchors.GripSupport.global_position) < 0.00001, "left support constrained " + label)
	metrics.append({"label":label,"weapon":actor.weapon,"size":[root.size.x,root.size.y],"fov":camera.fov,"weight":rig.aim_weight,"rear_error_px":rear_error,"front_error_px":front_error,"sight_axis_error_degrees":axis_error,"muzzle_mapping_error_px":muzzle_error,"muzzle_pixels":muzzle_pixels,"right_grip_error_m":right_error})

func run() -> void:
	if directory.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	root.title = "Native ADS verification"
	var world := Node3D.new()
	root.add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(2, 1.6, 4)
	camera.rotation = Vector3(-0.025, 0.12, 0.015)
	camera.h_offset = 0.03
	camera.v_offset = 0.02
	world.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -20, 0)
	world.add_child(sun)
	box(world, Vector3(0,-0.2,-10), Vector3(40,0.4,45), Color("34434a"))
	box(world, Vector3(0,3,-14), Vector3(22,6,1), Color("708488"))
	for x: int in [-6,6]:
		box(world,Vector3(x,2,-5),Vector3(2,4,5),Color("475b65"))
		box(world,Vector3(x,4,-5),Vector3(2.1,0.15,5.1),Color("65acb7"))
	for z: int in range(-12,4,2): box(world,Vector3(0,0.02,z),Vector3(0.06,0.01,0.9),Color("93aaa5"))
	rig = Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	hud = HUD.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.root.show()
	hud.status_panel.hide()
	var layer := CanvasLayer.new()
	layer.layer = 4
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24,70)
	layer.add_child(caption)
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		hud.resize()
		check(hud.layer > rig.overlay.layer, "HUD composited above isolated weapon")
		for id: int in 10:
			actor.weapon = id
			actor.reloading = false
			rig.apply_actor(actor,true)
			rig.apply_aim(false)
			step(90)
			await capture("hip")
			measure("hip", false)
			var camera_before := camera.transform
			check(rig.apply_aim(true), "local ADS accepted weapon %d" % id)
			step(4)
			check(rig.aim_weight > 0 and rig.aim_weight < 0.99, "animated enter weapon %d" % id)
			await capture("enter")
			step(100)
			check(rig.get_aim_state().ready, "settled ready weapon %d" % id)
			check(camera.transform == camera_before, "ADS never writes authoritative aim")
			await capture("ads")
			measure("ads", true)
			var image: Image = rig.viewport.get_texture().get_image()
			var occluded := 0
			# The front post terminates AT the aiming point. Sample the target gap
			# immediately above it; no opaque scope caps/receiver may fill it.
			for x: int in range(size.x/2-2,size.x/2+2):
				for y: int in range(size.y/2-6,size.y/2-2):
					if image.get_pixel(x,y).a > 0.1: occluded += 1
			check(occluded == 0, "open sight target gap weapon %d size %s" % [id,size])
			metrics.back()["target_gap_opaque_pixels"] = occluded
			for fov: float in [55.0,95.0]:
				camera.fov = fov
				rig.advance(0)
				measure("fov-%.0f" % fov,true)
			step(1)
			rig.apply_events([{"id":id+100*size.x,"time":float(id+100*size.x),"type":"shot","actor":7,"weapon":id}],7)
			rig.advance(0)
			check(rig.recoil > 0, "source shot gives physical recoil")
			await capture("recoil")
			measure("recoil",false)
			step(90)
			measure("recovered",true)
			rig.apply_aim(false)
			step(4)
			check(rig.aim_weight > 0 and rig.aim_weight < 0.99, "animated exit")
			await capture("exit")
			rig.apply_aim(true)
			step(90)
			actor.reloading = true
			actor.reloadDuration = 2.0
			actor.reloadTimer = 1.0
			rig.apply_actor(actor,true)
			check(not rig.apply_aim(true), "reload rejects ADS")
			step(90)
			await capture("reload")
			measure("reload",false)
			check(rig.aim_weight == 0, "reload recovers hip")
			check(rig.wrists[-1].global_position.distance_to(rig.anchors.GripReload.global_position) < 0.00001, "reload hand follows moving feed")
			if id == 3:
				var muzzle: Node3D = rig.anchors.Muzzle0
				check(muzzle.get_parent() == rig.parts["barrel-assembly"], "muzzle belongs to moving break-action barrel")
				check((-muzzle.global_basis.z).angle_to(-rig.pivot.global_basis.z) > 0.2, "physical barrel axis follows open hinge")
				var flare: Node3D = rig.flash.get_child(0)
				check(flare.global_position.distance_to(muzzle.global_transform * Vector3(0,0,-0.025)) < 0.00001, "fallback flash follows animated muzzle")
			actor.reloading = false
			rig.apply_actor(actor,true)
			rig.apply_aim(true)
			step(90)
			measure("reload-recovered",true)
	# Eligibility resets do not need a render loop or a snapshot ADS flag.
	for field: String in ["dead","spectating","vehicleId","health"]:
		var hidden := actor.duplicate()
		hidden[field] = 0 if field == "health" else 9 if field == "vehicleId" else true
		rig.apply_actor(hidden,true)
		check(not rig.apply_aim(true) and rig.aim_weight == 0 and rig.get_muzzle_count() == 0, "immediate eligibility reset " + field)
		rig.apply_actor(actor,true)
		rig.apply_aim(true)
		step(90)
	rig.apply_actor(actor,false)
	check(not rig.apply_aim(true) and rig.aim_weight == 0, "stale/focus caller gate resets ADS")
	rig.reset()
	check(not rig.showing and rig.get_muzzle_world_transform() == Transform3D.IDENTITY and not rig.get_muzzle_screen_position().is_finite(), "restart invalidates anchor API")
	var result := {"checks":checks,"failures":failures,"metrics":metrics}
	FileAccess.open(directory.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("NATIVE_ADS ",JSON.stringify({"checks":checks,"failures":failures,"images":120,"measurements":metrics.size()}))
	quit(0 if failures.is_empty() else 1)
