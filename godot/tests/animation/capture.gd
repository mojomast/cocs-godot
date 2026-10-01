extends SceneTree
## Native frame sequence: accepted source-shaped events/observations; no inputs
## or gameplay state writes. --rig= permits the base rig for paired evidence.
var out := ""
var rig_path := "res://first_person/rig.gd"
var captures := 0
var serial := 0
var camera: Camera3D
var rig: Node
var actor := {"id":7,"weapon":0,"health":100,"x":0.0,"y":0.0,"z":0.0,"vx":0.0,"vy":0.0,"vz":0.0,"grounded":true}
var camera_rest := Transform3D.IDENTITY

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--rig="): rig_path = arg.trim_prefix("--rig=")
	call_deferred("run")

func snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	rig.viewport.get_texture().get_image().save_png(out.path_join(name_ + ".png"))
	captures += 1

func advance(seconds: float) -> void:
	for frame: int in int(round(seconds * 60.0)): rig.advance(1.0/60.0)

func fire(id: int) -> void:
	serial += 1
	rig.apply_events([{"id":serial,"time":float(serial),"type":"shot","actor":7,"weapon":id}],7)

func run() -> void:
	if out.is_empty(): push_error("--out= required"); quit(1); return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,800)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera_rest = camera.transform
	rig = load(rig_path).new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	for id: int in 10:
		rig.reset()
		actor.weapon = id
		rig.apply_actor(actor,true)
		advance(0.5)
		await snap("weapon-%d-idle" % id)
		fire(id)
		for frame: int in 12:
			rig.advance(1.0/60.0)
			await snap("weapon-%d-fire-%02d" % [id,frame])
		advance(0.7)
		rig.apply_aim(true)
		advance(1.0)
		await snap("weapon-%d-ads" % id)
		rig.apply_aim(false)
		actor.reloading = true
		actor.reloadDuration = 1.0
		for phase: float in [0.1,0.3,0.6,0.85,0.96]:
			actor.reloadTimer = 1.0 - phase
			rig.apply_actor(actor,true)
			rig.advance(1.0/60.0)
			await snap("weapon-%d-reload-%02d" % [id,int(phase*100)])
		actor.reloading = false
		rig.apply_actor(actor,true)
	actor.weapon = 0
	rig.apply_actor(actor,true)
	advance(0.5)
	actor.vx = 8.0
	rig.apply_actor(actor,true)
	for frame: int in 12:
		rig.advance(1.0/60.0)
		await snap("acceleration-%02d" % frame)
	actor.vx = 0.0
	actor.grounded = false
	actor.vy = -9.0
	rig.apply_actor(actor,true)
	actor.grounded = true
	actor.vy = 0.0
	rig.apply_actor(actor,true)
	for frame: int in 12:
		rig.advance(1.0/60.0)
		await snap("landing-%02d" % frame)
	serial += 1
	rig.apply_events([{"id":serial,"time":float(serial),"type":"melee","actor":7,"hit":null}],7)
	for frame: int in 12:
		rig.advance(1.0/60.0)
		await snap("melee-%02d" % frame)
	var unchanged := camera.transform == camera_rest
	print("PHYSICS_CAPTURE ",JSON.stringify({"frames":captures,"rig":rig_path,"source_camera_unchanged":unchanged,"out":out}))
	rig.free()
	camera.free()
	quit(0 if unchanged else 1)
