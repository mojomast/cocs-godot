extends SceneTree
## Bounded deterministic six-second frame sequence through production actors.
const Robot = preload("res://campaign/robot_visual.gd")
const Operator = preload("res://source_operators/operator_visual.gd")
const Puppy = preload("res://campaign/puppy_visual.gd")
const Gesture = preload("res://campaign/story_gesture.gd")
var before := false
var output := ""
var robots: Array[Node3D] = []
var operator: Node3D
var puppy: Node3D
var friendly: Node3D
var gesture: RefCounted

func _initialize() -> void:
	call_deferred("run")

func label(parent: Node3D, text: String, at: Vector3) -> void:
	var node := Label3D.new(); node.text=text; node.position=at; node.font_size=32; node.pixel_size=0.008; node.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(node)

func run() -> void:
	output=OS.get_environment("ACTOR_ANIMATION_CAPTURE")
	before=OS.get_environment("ACTOR_ANIMATION_BEFORE")=="1"
	if output.is_empty(): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,800)
	var world := Node3D.new(); root.add_child(world)
	var environment := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("1b2637"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("c9dcef"); env.ambient_light_energy=0.7
	environment.environment=env; world.add_child(environment)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-30,0); light.light_energy=1.4; world.add_child(light)
	var floor := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size=Vector2(30,30); floor.mesh=plane
	var mat := StandardMaterial3D.new(); mat.albedo_color=Color("344456"); mat.roughness=1; floor.material_override=mat; world.add_child(floor)
	var camera := Camera3D.new(); world.add_child(camera); camera.position=Vector3(8,7,-15); camera.look_at(Vector3(0,0.9,0)); camera.fov=48; camera.current=true
	var cast_focus := OS.get_environment("ACTOR_ANIMATION_FOCUS")=="cast"
	if cast_focus:
		camera.position=Vector3(0,2.7,-6); camera.look_at(Vector3(0,1.0,3)); camera.fov=58
	for i in 6:
		var robot: Node3D = load("res://tests/animation_pass/reference_robot.gd").new() if before else Robot.new()
		robot.automatic_animation=false; robot.automatic_lod=false; world.add_child(robot)
		robot.position=Vector3((i%3-1)*4.0,0.9,-float(i/3)*4.0)
		robot.configure({"id":1,"npcModel":Robot.IDS[i],"health":100,"grounded":true})
		robots.append(robot)
		if cast_focus: robot.hide()
		else: label(world,Robot.IDS[i],robot.position+Vector3(0,1.5,0))
	operator=load("res://tests/animation_pass/reference_operator.gd").new() if before else Operator.new()
	operator.automatic_animation=false; world.add_child(operator); operator.position=Vector3(-4,0.9,4)
	operator.configure({"id":1,"character":"claude","health":100,"weapon":0})
	label(world,"Operator: move / aim / reload",Vector3(-4,2.7,4))
	friendly=Operator.new(); friendly.automatic_animation=false; world.add_child(friendly); friendly.position=Vector3(0,0.9,4)
	friendly.apply_actor({"id":2,"character":"chatgpt","health":100}); friendly.nodes.weapon.hide()
	gesture=load("res://tests/animation_pass/reference_gesture.gd").new() if before else Gesture.new(); gesture.select("wave")
	label(world,"Mara: wave / work",Vector3(0,2.7,4))
	puppy=load("res://tests/animation_pass/reference_puppy.gd").new() if before else Puppy.new()
	world.add_child(puppy); puppy.set_process(false); puppy.position=Vector3(4,0,4)
	label(world,"Patch: walk / sit / pet",Vector3(4,1.4,4))
	var title := Label.new(); title.text="BEFORE — source actor presentation" if before else "AFTER — contact gait / restrained physics"; title.position=Vector2(20,15); title.add_theme_font_size_override("font_size",24); root.add_child(title)
	for frame in 180:
		var time := float(frame)/30
		var moving := time>=0.6 and time<2.6
		var windup := time>=3.2 and time<4.3
		for i in 6:
			var robot: Node3D = robots[i]
			var sideways := time>1.8
			var state := {"id":1,"npcModel":Robot.IDS[i],"health":100,"vx":1.5 if moving and sideways else 0.0,"vz":-1.5 if moving and not sideways else 0.0,"grounded":true,"campaignAttackWindup":0.5 if windup else 0.0,"campaignExposed":0.5 if time>4.7 else 0.0,"pitch":0.15,"shots":1 if time>=4.3 else 0}
			robot.apply_actor(state); robot.advance(1.0/30)
			if cast_focus: robot.hide()
			robot.position.x=(i%3-1)*4.0 + (clampf(time-1.8,0,0.8)*1.5 if sideways else 0)
			robot.position.z=-float(i/3)*4.0-clampf(time-0.6,0,1.2)*1.5
		var state := {"id":1,"character":"claude","health":100,"weapon":0,"grounded":not(time>2.6 and time<3.0),"vy":-3.0,"vx":1.4 if moving and time>1.8 else 0.0,"vz":-1.4 if moving and time<=1.8 else 0.0,"ads":time>3.0,"reloading":time>=4.0 and time<5.4,"reloadDuration":1.4,"reloadTimer":maxf(0,5.4-time),"bodyYaw":0.0,"yaw":0.3 if time>2.6 else 0.0,"pitch":0.08}
		operator.apply_actor(state)
		operator.position.x=-4+clampf(time-1.8,0,0.8)*1.4
		operator.position.z=4-clampf(time-0.6,0,1.2)*1.4
		if frame==100: operator.kick()
		operator.advance(1.0/30)
		if frame==95: gesture.select("work")
		gesture.advance(1.0/30); gesture.apply_to(friendly)
		puppy.set_pose("walk" if moving else ("sit" if time>2.6 else "idle"))
		puppy.position.z=4-clampf(time-0.6,0,2.0)*0.9
		if frame==135: puppy.pet()
		if before: puppy._process(1.0/30)
		else: puppy.advance(1.0/30)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/frame-%03d.png"%frame)
	print("ACTOR_CAPTURE_OK frames=180 simulated_fps=30 duration=6 before=",before)
	quit()
