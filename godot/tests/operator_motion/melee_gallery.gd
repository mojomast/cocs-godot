extends "res://tests/operator_motion/melee_contracts.gd"
## Actual public presentation event signal -> imported rig -> rendered phases.
## Staged accepted-event evidence, not an ordinary-input authority journey.
var output := ""
var captures := 0

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output=arg.trim_prefix("--evidence-out=")
	if output.is_empty():
		push_error("Melee gallery needs --evidence-out")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(960,640)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(0.045,0.055,0.075)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color(0.7,0.8,1)
	env.environment.ambient_light_energy=0.7
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-35,0)
	world.add_child(light)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(30,0.2,30)
	collision.shape=shape
	floor.add_child(collision)
	floor.position.y=-0.1
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=shape.size
	surface.mesh=mesh
	floor.add_child(surface)
	world.add_child(floor)
	var camera := Camera3D.new()
	camera.fov=48
	world.add_child(camera)
	camera.make_current()
	var label := Label.new()
	label.position=Vector2(20,20)
	root.add_child(label)
	var view := Presentation.new()
	world.add_child(view)
	view.set_process(false)
	var client := EventClient.new()
	world.add_child(client)
	view.bind_melee_events(client)
	await physics_frame
	await physics_frame
	for identity: String in Catalog.OPERATORS:
		for angle: String in ["front","side","three-quarter"]:
			view.clear_round()
			var a := actor(identity)
			observe(view,a,1.0)
			var visual: Node3D=view.actors[2]
			for frame in 60: visual.advance(1.0/60)
			camera.position={"front":Vector3(0,1.65,-3.8),"side":Vector3(3.8,1.65,0),"three-quarter":Vector3(2.8,1.65,-2.8)}[angle]
			camera.look_at(Vector3(0,0.95,0))
			for strike in 3:
				var time := 1.0+strike*0.32
				observe(view,a,time)
				client.events.emit([event(strike+1,time)])
				var age := 0.0
				for phase: float in [0.065,0.095,0.19]:
					visual.advance(phase-age)
					age=phase
					check(visual.world_melee.sequence.accepted==strike+1,"gallery accepted-event count")
					label.text="%s · strike %d · %s · %.3f s\nAccepted source-event fixture / actual imported rig"%[identity,strike+1,angle,phase]
					await process_frame
					await RenderingServer.frame_post_draw
					var file := "%s/%s-%s-strike%d-%03d.png"%[output,identity,angle,strike+1,roundi(phase*1000)]
					check(root.get_texture().get_image().save_png(file)==OK,"gallery image write")
					captures+=1
					print(JSON.stringify({"capture":file,"accepted":visual.world_melee.sequence.accepted,"contacts":visual.locomotion.contacts,"grips":visual.grip_error}))
				visual.advance(0.32-age)
	check(captures==243,"all nine identities, three views, three strikes, three phases")
	view.free()
	world.free()
	label.free()
	print("OPERATOR_MELEE_GALLERY ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"captures":captures}))
	quit(0 if failures.is_empty() else 1)
