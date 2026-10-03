extends SceneTree
## Fixed-step native observation fixture. Does not connect to gameplay authority.
## --motion-capture=/absolute/directory saves two actual rendered frames per case.
const Visual = preload("res://source_operators/operator_visual.gd")
const Catalog = preload("res://source_operators/generated/catalog.gd")
var capture_dir := ""

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-capture="): capture_dir = arg.trim_prefix("--motion-capture=")
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(960,640)
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.045,0.055,0.075)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7,0.8,1)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.8
	world.add_child(sun)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500,0.2,500)
	collision.shape = box
	floor.add_child(collision)
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	surface.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16,0.19,0.24)
	surface.material_override = material
	floor.add_child(surface)
	floor.position.y = -0.1
	world.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 48
	world.add_child(camera)
	camera.make_current()
	var hud := Label.new()
	hud.position = Vector2(20,20)
	hud.add_theme_font_size_override("font_size",18)
	root.add_child(hud)
	var visual := Visual.new()
	visual.automatic_animation = false
	world.add_child(visual)
	await physics_frame
	await physics_frame
	for identity: String in Catalog.OPERATORS:
		var position := Vector3(0,0.9,0)
		visual.reset_pose()
		for action: String in ["idle","walk","run","sprint","strafe","reverse","crouch","stop","turn","jump","land","reduced"]:
			for frame in 90:
				var dt := 1.0/60.0
				var velocity := Vector2.ZERO
				match action:
					"walk": velocity = Vector2(0,-1.5)
					"run": velocity = Vector2(0,-4)
					"sprint": velocity = Vector2(0,-8)
					"strafe": velocity = Vector2(3,0)
					"reverse": velocity = Vector2(0,2)
					"crouch": velocity = Vector2(0,-1.5)
					"reduced": velocity = Vector2(0,-3)
					"jump": velocity = Vector2(0,-2)
				position += Vector3(velocity.x,0,velocity.y)*dt
				var airborne := action == "jump" and frame < 89
				var t := float(frame)/89.0
				position.y = 0.9+sin(t*PI)*1.2 if airborne else 0.9
				var yaw := t*PI if action == "turn" else 0.0
				var actor := {"id":2,"character":identity,"health":100,"weapon":0,"x":position.x,"y":position.y-0.9,"z":position.z,"vx":velocity.x,"vz":velocity.y,"vy":cos(t*PI)*PI*1.2/1.5 if airborne else 0.0,"grounded":not airborne,"crouching":action=="crouch","yaw":yaw,"bodyYaw":yaw,"reduced":action=="reduced","moveSpeed":8.0}
				visual.apply_actor(actor)
				visual.position = position
				visual.rotation.y = yaw
				visual.advance(dt)
				camera.position = Vector3(position.x+2.5,2.0,position.z+3.6)
				camera.look_at(Vector3(position.x,1.0,position.z))
				hud.text = "%s · %s · %d/90\nActual travel %.2f m/s · phase %.2f\nL %s / R %s · grip %s" % [identity,action,frame,velocity.length(),visual.locomotion.distance_phase,visual.locomotion.contacts.get("L",{}).get("planted",false),visual.locomotion.contacts.get("R",{}).get("planted",false),visual.grip_error]
				await process_frame
				if not capture_dir.is_empty() and frame in [44,89]:
					await RenderingServer.frame_post_draw
					var file := "%s/%s-%s-%02d.png" % [capture_dir,identity,action,frame]
					var result := root.get_texture().get_image().save_png(file)
					print(JSON.stringify({"capture":file,"result":result,"contacts":visual.locomotion.contacts,"grips":visual.grip_error}))
	quit()
