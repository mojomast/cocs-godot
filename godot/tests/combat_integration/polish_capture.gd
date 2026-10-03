extends SceneTree
## Real integrated production effects from source-shaped event inputs.
## Controlled scene and event timing; not an authority-connected play journey.
const Feedback = preload("res://world/combat_feedback.gd")
const Client = preload("res://net/client.gd")
class Context extends Node3D:
	var camera := Camera3D.new()
	var world := Node3D.new()
	var client := Client.new()
	var current_id := "meridian-exchange"
	var phase := 3
	var application_focused := true
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): output=arg.trim_prefix("--evidence-out=")
	call_deferred("run")

func run() -> void:
	assert(not output.is_empty(),"explicit evidence path")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(960,640)
	var observations: Array = []
	var events := [
		{"id":1,"type":"pickup","kind":"health","actor":2},
		{"id":2,"type":"teleport","actor":2,"from":{"x":-1,"y":1,"z":0},"to":{"x":1,"y":1,"z":0}},
		{"id":3,"type":"explosion","pos":{"x":0,"y":1,"z":0},"radius":2.0}]
	for event: Dictionary in events:
		event.time=1.0
		var context := Context.new()
		root.add_child(context)
		context.add_child(context.world)
		context.add_child(context.camera)
		context.add_child(context.client)
		context.client.set_process(false)
		context.client.actor_id=0
		context.camera.position=Vector3(0,2.4,5)
		context.camera.look_at(Vector3(0,1,0))
		context.camera.make_current()
		var environment := WorldEnvironment.new()
		environment.environment=Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color(0.06,0.07,0.09)
		context.add_child(environment)
		var feedback := Feedback.new()
		context.add_child(feedback)
		feedback.audio_feedback.set_muted(true)
		feedback.set_process(false)
		for node: Node in feedback.find_children("*","Node",true,false): node.set_process(false)
		var state := {"mapId":"meridian-exchange","time":1.0,"over":false,"actors":[{"id":2,"health":100,"weapon":0,"team":0,"x":0.0,"y":0.0,"z":0.0,"yaw":0.0,"pitch":0.0}]}
		feedback.apply_state(state)
		feedback.apply_events([event],0)
		feedback.flush_effects()
		if event.type=="explosion":
			print("POLISH_GENERIC_BLASTS ",feedback.weapon_effects.blasts," rejected=",feedback.weapon_effects.rejected)
		feedback.weapon_effects.advance(0.08)
		var moth: Variant = feedback.get("moth_effects") if "moth_effects" in feedback else null
		if is_instance_valid(moth): moth.advance(0.08)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join(str(event.type)+".png")
		assert(root.get_texture().get_image().save_png(path)==OK,"effect image saved")
		observations.append({"event":event,"image":path,"classification":"integrated production effects; staged public-event payload"})
		context.free()
		await process_frame
	FileAccess.open(output.path_join("effects.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"  "))
	print("POLISH_EFFECT_CAPTURE_OK images=3")
	quit(0)
