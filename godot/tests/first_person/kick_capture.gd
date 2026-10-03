extends SceneTree
## Offline pose evidence only. Run AFTER exclusive native/render grant.
## This fixture does not prove input delivery or damage; use live F presses for that.
const Rig = preload("res://first_person/rig.gd")
const Motion = preload("res://first_person/kick_motion.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 75
	var rig := Rig.new()
	world.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	var output := "user://kick-capture"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output=arg.trim_prefix("--evidence-out=")
	DirAccess.make_dir_recursive_absolute(output)
	for character: String in rig.KickRig.PROFILES:
		rig.reset()
		rig.apply_actor({"id":7,"weapon":0,"health":100,"character":character}, true)
		rig.reduced_motion = "--reduced-ads" in OS.get_cmdline_user_args()
		rig.apply_aim(rig.reduced_motion)
		rig.advance(1.0)
		camera.fov = rig.get_aim_state(75.0).fov
		for strike: int in 3:
			rig.apply_events([{"type":"melee","id":strike+1,"time":1.0+strike*0.31,"actor":7,"hit":8}], 7)
			var previous := 0.0
			for moment: float in [0.035,0.065,Motion.CONTACT,0.185,Motion.DURATION]:
				rig.advance(moment-previous)
				assert(is_equal_approx(rig.weapon_camera.fov,camera.fov),"kick projection stays consistent with source ADS/FOV")
				previous = moment
				await process_frame
				await RenderingServer.frame_post_draw
				var path := "%s/%s-kick%d-%03dms.png" % [output,character,strike+1,roundi(moment*1000)]
				var error := root.get_texture().get_image().save_png(path)
				assert(error == OK)
				print("KICK_POSE ", path, " ", rig.get_kick_state())
	world.free()
	print("KICK_CAPTURE_OK captures=135")
	quit(0)
