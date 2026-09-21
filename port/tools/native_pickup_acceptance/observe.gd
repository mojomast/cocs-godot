extends SceneTree
# Instantiates the shipped scene unchanged. All stimulus enters Input.parse_input_event.
var session: Node
var elapsed := 0.0
var steering := 0.0
var route: Array = []
var waypoint := 0
var stage := "starting"
var held := false
var captured := false
var target_id := -1
var evidence := ""
var route_file := ""
var pending_images: Array[String] = []
var before_image := false
var finish_at := -1.0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
		if arg.begins_with("--route="): route_file = arg.trim_prefix("--route=")
	call_deferred("begin")

func record(event: String, data: Dictionary = {}) -> void:
	data["event"] = event
	data["monotonic_usec"] = Time.get_ticks_usec()
	data["elapsed"] = elapsed
	print("PICKUP_OBSERVE " + JSON.stringify(data))

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	record("harness_begin", {"smoke":session.smoke,"map":session.current_id})
	session.client.snapshot.connect(observe)
	session.client.events.connect(func(items: Array): record("events", {"items":items}))

func key(down: bool) -> void:
	if held == down: return
	held = down
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = down
	Input.parse_input_event(event)
	record("physical_key", {"key":"W", "pressed":down})

func point_at(target: Vector2) -> void:
	var actor: Dictionary = session.presentation.local_actor
	var desired := atan2(-(target.x - float(actor.x)), -(target.y - float(actor.z)))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(desired - float(session.yaw), -PI, PI) / 0.003, float(session.pitch) / 0.003)
	Input.parse_input_event(event)
	record("mouse_motion", {"relative":[event.relative.x,event.relative.y],"target":[target.x,target.y]})

func observe(frame: Dictionary) -> void:
	var actor: Dictionary = session.presentation.local_actor
	if actor.is_empty(): return
	var pickup: Dictionary = {}
	for p: Dictionary in frame.state.pickups:
		if p.kind == "rocket" and p.x == -14 and p.z == -19: pickup = p
	if pickup.is_empty():
		record("blocker", {"reason":"target rocket missing"})
		quit(2)
		return
	target_id = int(pickup.id)
	var marker: Node3D = session.pickups.markers.get(target_id)
	var pos := Vector2(float(actor.x),float(actor.z))
	var distance := Vector3(float(actor.x)+14,float(actor.y)-float(pickup.y),float(actor.z)+19).length()
	record("snapshot", {"seq":frame.seq,"time":frame.state.time,"actor_id":session.client.actor_id,"actor":actor,"pickup":pickup,"distance":distance,"marker_visible":marker.visible if marker else null,"marker_instance":marker.get_instance_id() if marker else null,"hud":session.presentation.hud_text,"label":session.label.text,"stage":stage,"ack":session.client.last_ack,"focused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED})
	if stage == "approach" and distance < 4.0 and not before_image:
		before_image = true
		pending_images.append("available")
	if float(pickup.wait) > 0 and stage == "approach":
		key(false)
		stage = "leave"
		pending_images.append("hidden")
		record("collected_boundary", {"seq":frame.seq,"time":frame.state.time,"pickup_id":target_id})
	if stage == "leave" and pos.distance_to(Vector2(-14,-23)) < 0.5:
		key(false)
		stage = "waiting_return"
		point_at(Vector2(-14,-19))
		pending_images.append("left_radius")
	if stage == "waiting_return" and float(pickup.wait) <= 0:
		stage = "returned"
		pending_images.append("returned")
		finish_at = elapsed + 1.0
		record("return_boundary", {"seq":frame.seq,"time":frame.state.time,"pickup_id":target_id})

func save_images() -> void:
	var names := pending_images.duplicate()
	pending_images.clear()
	await RenderingServer.frame_post_draw
	for name: String in names:
		var result := root.get_texture().get_image().save_png(evidence.path_join(name + ".png"))
		record("screenshot", {"name":name,"result":result,"stage":stage})

func _process(delta: float) -> bool:
	elapsed += delta
	if not pending_images.is_empty(): save_images()
	if elapsed > 90.0 or (finish_at > 0 and elapsed >= finish_at):
		key(false)
		record("harness_end", {"stage":stage,"accepted_candidate":stage == "returned","completionProven":false})
		quit(0 if stage == "returned" else 2)
		return false
	if not is_instance_valid(session) or not session.received_pose: return false
	if not captured and session.can_capture_pointer():
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = Vector2(800,500)
		click.pressed = true
		Input.parse_input_event(click)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = click.position
		Input.parse_input_event(release)
		captured = true
		record("capture_click", {"position":[800,500]})
	if stage == "starting" and FileAccess.file_exists(route_file):
		route = JSON.parse_string(FileAccess.get_file_as_string(route_file))
		stage = "approach"
		record("route", {"points":route})
	steering += delta
	if steering < 0.1: return false
	steering = 0.0
	var a: Dictionary = session.presentation.local_actor
	var pos := Vector2(float(a.x),float(a.z))
	if stage == "approach" and not route.is_empty():
		var target := Vector2(float(route[waypoint][0]),float(route[waypoint][1]))
		if pos.distance_to(target) < 0.65 and waypoint < route.size()-1:
			waypoint += 1
			target = Vector2(float(route[waypoint][0]),float(route[waypoint][1]))
		point_at(target)
		key(pos.distance_to(target) > 0.35)
	elif stage == "leave":
		point_at(Vector2(-14,-23))
		key(true)
	return false
