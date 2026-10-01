extends SceneTree
## Matched captures: same camera, actor, lighting and source poses with only
## Art.enabled toggled. Images are saved outside the repository via EVIDENCE.
const Rig = preload("res://first_person/rig.gd")
const Art = preload("res://first_person/art_adapter.gd")
const Visual = preload("res://source_operators/operator_visual.gd")
var directory := ""
var camera: Camera3D
var rig: Node

func _initialize() -> void:
	directory = OS.get_environment("EVIDENCE")
	call_deferred("run")

func wait_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func image(file: String) -> void:
	await wait_frame()
	await wait_frame()
	root.get_texture().get_image().save_png(directory.path_join(file))

func run() -> void:
	if directory.is_empty(): push_error("EVIDENCE required"); quit(1); return
	root.size = Vector2i(1280,800)
	camera = Camera3D.new(); camera.fov = 75.0
	root.add_child(camera); camera.make_current()
	var bg := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("263540")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7cddd"); env.ambient_light_energy = 0.8
	bg.environment = env; root.add_child(bg)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-28,-40,0)
	light.light_energy = 2.0; root.add_child(light)
	for baseline: bool in [true,false]:
		Art.enabled = not baseline
		var label := "before" if baseline else "after"
		rig = Rig.new(); root.add_child(rig); rig.attach_to(camera)
		for id: int in range(10):
			camera.fov = 75.0
			var actor := {"id":7,"weapon":id,"health":100,"character":"claude","team":2,
				"reloadDuration":1.8,"reloadTimer":.9}
			rig.apply_actor(actor,true)
			for i: int in 12: rig.advance(.05)
			await image("%s-w%02d-normal.png" % [label,id])
			rig.apply_aim(true)
			for i: int in 20: rig.advance(.05)
			camera.fov = float(rig.get_aim_state(75.0).fov)
			await image("%s-w%02d-ads.png" % [label,id])
			rig.apply_aim(false)
			rig.apply_actor({},false)
			camera.fov = 75.0
			# A side close-up of the actual third-person operator's held weapon.
			var actor_visual := Visual.new()
			root.add_child(actor_visual)
			actor_visual.position = Vector3(0,0,-1.8)
			actor_visual.apply_actor({"id":id+20,"weapon":id,"health":100,"character":"claude","team":2})
			var muzzle: Node3D = actor_visual.world_weapon.find_child("Muzzle",true,false)
			var grip: Node3D = actor_visual.world_weapon.find_child("WeaponGripRight",true,false)
			var target: Vector3 = (muzzle.global_position + grip.global_position)*.5
			camera.position=target+Vector3(1.25,.28,-.7)
			camera.look_at(target)
			await image("%s-w%02d-world.png" % [label,id])
			actor_visual.free()
			camera.transform = Transform3D.IDENTITY
		rig.free()
	Art.enabled = true
	# Sequence frames: source-shaped shot, recovery, authoritative mid-reload
	# and next-weapon switch. Actual animated native rig, deterministic time step.
	rig = Rig.new(); root.add_child(rig); rig.attach_to(camera)
	var actor := {"id":7,"weapon":3,"health":100,"reloadDuration":1.8,"reloadTimer":.9}
	rig.apply_actor(actor,true)
	for i: int in 10: rig.advance(.05)
	rig.apply_events([{"id":1,"time":1.0,"type":"shot","actor":7,"weapon":3}],7)
	for frame: int in range(24):
		if frame == 8: actor.reloading=true
		if frame >= 8 and frame < 17: actor.reloadTimer = 1.8 * (17-frame)/9.0
		if frame == 17:
			actor.reloading=false
			actor.weapon=4
		rig.apply_actor(actor,true)
		rig.advance(1.0/30.0)
		await image("sequence-%02d.png" % frame)
	quit()
