extends SceneTree
## Real shell/stage/core/FX; input-only case playback after training placement.
const Shell = preload("res://fighting/main.gd")
var output := "user://animation-gameplay"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var operators: Array = ["meta", "mistral"]
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size()-1):
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--operators": operators = Array(args[i+1].split(","))
	DirAccess.make_dir_recursive_absolute(output)
	var shell := Shell.new()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.set_process(false)
	shell.operators = operators
	shell.mode = "training"
	shell.stage_id = "basalt-reach"
	shell.start_match()
	assert(shell.active, shell.error_text)
	var events: Array = []
	var shots: Array = []
	var cases := {"throw":32,"tech":32,"super":256,"special1":8,"heavy":4,"walk":0}
	for label: String in cases:
		shell.simulation.training_reset({"fighters":[{"x":-330,"y":0,"meter":1000},{"x":330,"y":0,"meter":0}]})
		shell.effects.reset()
		shell.fx_event_floor = 0
		for visual in shell.visuals: visual.reset()
		for tick: int in range(90):
			var held := int(cases[label]) if tick == 0 else 0
			var tech := label == "tech" and tick == 11
			var a := {"axis_x":1 if label == "walk" and tick < 45 else 0,"axis_y":0,"held":held,"pressed":held}
			var b := {"axis_x":0,"axis_y":0,"held":32 if tech else 0,"pressed":32 if tech else 0}
			shell.state = shell.simulation.step([a,b])
			assert(shell.simulation.last_error.is_empty())
			shell._present_snapshot_effects()
			shell._update_hud()
			shell._process(1.0/60.0)
			for event: Dictionary in shell.state.events:
				events.append({"case":label,"tick":tick,"event":event})
			await process_frame
			await RenderingServer.frame_post_draw
			# 30fps short motion proof, not hundreds of synthetic match captures.
			if tick % 2 == 0:
				var path := output.path_join("%s-%03d.png" % [label, tick/2])
				assert(root.get_texture().get_image().save_png(path) == OK)
				shots.append(path)
	var file := FileAccess.open(output.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"operators":operators,"stage":"basalt-reach","events":events,"shots":shots,"actual_core":true,"fps":30},"\t"))
	shell._teardown_world()
	shell.free()
	quit(0)
