extends SceneTree
## Focused future native A/B fixture. No production/global capture modifications.
## Training placements are explicitly labelled; combat then uses core inputs.
const Shell = preload("res://fighting/main.gd")
var output := "user://camera-comparison"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := "basalt-reach"
	var operators: Array = ["meta","qwen"]
	var baseline := false
	var args := OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--baseline": baseline = true
		if i+1 >= args.size(): continue
		if args[i] == "--stage": stage = args[i+1]
		if args[i] == "--operators": operators = Array(args[i+1].split(","))
		if args[i] == "--output": output = args[i+1]
	DirAccess.make_dir_recursive_absolute(output)
	var shell := Shell.new()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.set_process(false)
	shell.mode = "training"
	shell.operators = operators
	shell.stage_id = stage
	shell.start_match()
	assert(shell.active,shell.error_text)
	# Silent visual comparison even on an audio-capable native grant.
	shell.effects.configure({"muted":true,"quality":"high"})
	var records: Array = []
	for label: String in ["neutral","jump","throw","projectile","full_range","corner_pair"]:
		var x0 := -7800 if label == "full_range" else 7000 if label == "corner_pair" else -330
		var x1 := 7800 if label in ["full_range","corner_pair"] else 330
		shell.simulation.training_reset({"fighters":[{"x":x0,"y":0,"meter":1000},{"x":x1,"y":0,"meter":0}]})
		shell.effects.reset()
		shell.camera.reset()
		shell.fx_event_floor = 0
		for visual in shell.visuals: visual.reset()
		for tick: int in 120:
			var held := (32 if label in ["throw","corner_pair"] else 8 if label == "projectile" else 0) if tick == 0 else 0
			var a := {"axis_x":0,"axis_y":1 if label == "jump" and tick == 8 else 0,"held":held,"pressed":held}
			var b := {"axis_x":0,"axis_y":0,"held":0,"pressed":0}
			shell.state = shell.simulation.step([a,b])
			assert(shell.simulation.last_error.is_empty())
			shell._present_snapshot_effects()
			shell._update_hud()
			shell._process(1.0/60.0)
			if baseline:
				# Exact prior production camera for matched evidence only.
				var left := minf(shell.state.fighters[0].x,shell.state.fighters[1].x)/1000.0
				var right := maxf(shell.state.fighters[0].x,shell.state.fighters[1].x)/1000.0
				var height := maxf(10.4/0.58,(right-left+3.2)/(float(root.size.x)/root.size.y))
				shell.camera.size = height
				shell.camera.position = Vector3(clampf((left+right)*0.5,-4,4),height*0.38,24)
			await process_frame
			await RenderingServer.frame_post_draw
			if tick%4 == 0:
				var path := output.path_join("%s-%03d.png" % [label,tick])
				assert(root.get_texture().get_image().save_png(path) == OK)
				var bounds: Array = []
				for pose in shell.camera.poses:
					var box: Rect2 = pose.envelope()
					bounds.append([box.position.x,box.position.y,box.size.x,box.size.y])
				records.append({"case":label,"tick":shell.state.tick,"image":path,"height":shell.camera.size,"center":[shell.camera.position.x,shell.camera.position.y],"pose_bounds":bounds,"fighters":shell.state.fighters,"projectiles":shell.state.projectiles})
	var file := FileAccess.open(output.path_join("camera-trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage,"operators":operators,"baseline":baseline,"training_placements":true,"viewport":[root.size.x,root.size.y],"records":records},"\t"))
	shell._teardown_world()
	shell.free()
	quit()
