extends SceneTree
## Rendered review of the real first-person rig in hip fire and on a confirmed
## source melee event. Isolated viewport, no gameplay state writes.
const Rig = preload("res://first_person/rig.gd")
var out := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	call_deferred("run")

func run() -> void:
	if out.is_empty():
		push_error("--out= directory required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 800)
	var camera := Camera3D.new()
	camera.fov = 75
	root.add_child(camera)
	camera.current = true
	var rig := Rig.new()
	root.add_child(rig)
	rig.attach_to(camera)
	rig.set_process(false)
	rig.apply_actor({"id":7,"health":100,"dead":0,"weapon":0,"grounded":true}, true)
	for frame: int in 20: rig.advance(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	var hip: Image = rig.viewport.get_texture().get_image()
	hip.save_png(out.path_join("hip.png"))
	rig.apply_events([{"id":47,"time":1.0,"actor":7,"hit":null,"type":"melee"}],7)
	for frame: int in 5: rig.advance(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	var kicked: Image = rig.viewport.get_texture().get_image()
	kicked.save_png(out.path_join("kick.png"))
	var changed := 0
	for x: int in range(390, 890, 5):
		for y: int in range(370, 790, 5):
			var before := hip.get_pixel(x, y)
			var after := kicked.get_pixel(x, y)
			if absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b) + absf(before.a - after.a) > 0.15: changed += 1
	var angle := rad_to_deg((-rig.get_muzzle_world_transform().basis.z).angle_to(
		(camera.project_position(Vector2(root.size) * 0.5, 35.0) - rig.get_muzzle_world_transform().origin).normalized()))
	print("HIP_KICK_CAPTURE ", JSON.stringify({"foot_visible":rig.kick_leg.visible,"different_pixels":changed,
		"hip_barrel_to_crosshair_degrees":angle,"animation_seconds":rig.KICK_SECONDS,
		"hip":out.path_join("hip.png"),"kick":out.path_join("kick.png")}))
	quit(0 if rig.kick_leg.visible and changed > 200 and angle < 8.0 else 1)
