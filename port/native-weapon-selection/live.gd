extends SceneTree

# Real shipped scene. Only physical-key, mouse-button and relative-look input
# are stimulated; snapshots, camera, controls and authority are never assigned.
var session: Node
var route_file: String
var output: String
var route: Array = []
var waypoint: int = 0
var moving: bool = false
var stage: int = 0
var deadline: int
var last_weapon: int = -1

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--route="): route_file = arg.trim_prefix("--route=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	call_deferred("run")

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if code != KEY_W: print("WEAPON_LIVE key=", code, " pressed=", down)

func button(code: int, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.position = Vector2(800, 500)
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func move(down: bool) -> void:
	if moving == down: return
	moving = down
	key(KEY_W, down)

func observe(frame: Dictionary) -> void:
	var actor: Dictionary = session.presentation.local_actor
	if actor.is_empty(): return
	if int(actor.weapon) != last_weapon:
		last_weapon = int(actor.weapon)
		print("WEAPON_AUTH ", JSON.stringify({"seq":frame.seq,"ack":session.client.last_ack,"stage":stage,"weapon":actor.weapon,"ammo":actor.ammo,"health":actor.health,"actor_id":actor.id,"position":[actor.x,actor.y,actor.z],"focused":root.has_focus(),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED}))

func wait_weapon(index: int) -> bool:
	var until: int = Time.get_ticks_msec() + 1800
	while Time.get_ticks_msec() < until:
		await process_frame
		if session.presentation.local_actor.get("weapon") == index: return true
	push_error("Authority did not confirm weapon " + str(index))
	quit(2)
	return false

func run() -> void:
	deadline = Time.get_ticks_msec() + 60000
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.snapshot.connect(observe)
	while not session.received_pose or not FileAccess.file_exists(route_file):
		await process_frame
		if Time.get_ticks_msec() > deadline:
			quit(2)
			return
	route = JSON.parse_string(FileAccess.get_file_as_string(route_file))
	button(MOUSE_BUTTON_LEFT, true)
	button(MOUSE_BUTTON_LEFT, false)
	stage = 1
	while session.presentation.local_actor.ammo[1] == 0:
		if Time.get_ticks_msec() > deadline or not session.weapon_controls_active():
			push_error("Approach timed out or controls lost")
			quit(2)
			return
		var actor: Dictionary = session.presentation.local_actor
		var pos := Vector2(float(actor.x), float(actor.z))
		var target := Vector2(float(route[waypoint][0]), float(route[waypoint][1]))
		if pos.distance_to(target) < 0.65 and waypoint < route.size() - 1:
			waypoint += 1
			target = Vector2(float(route[waypoint][0]), float(route[waypoint][1]))
		var desired := atan2(-(target.x - pos.x), -(target.y - pos.y))
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-wrapf(desired - session.yaw, -PI, PI) / 0.003, session.pitch / 0.003)
		Input.parse_input_event(event)
		move(pos.distance_to(target) > 0.35)
		await create_timer(0.1).timeout
	move(false)
	if not await wait_weapon(1): return
	await create_timer(0.15).timeout
	stage = 2
	key(KEY_1, true)
	if not await wait_weapon(0): return
	key(KEY_1, false)
	stage = 3
	key(KEY_2, true)
	if not await wait_weapon(1): return
	key(KEY_2, false)
	stage = 4
	button(MOUSE_BUTTON_WHEEL_UP, true)
	button(MOUSE_BUTTON_WHEEL_UP, false) # Wheel releases are not held keys.
	if not await wait_weapon(0): return
	stage = 5
	button(MOUSE_BUTTON_WHEEL_DOWN, true)
	button(MOUSE_BUTTON_WHEEL_DOWN, false)
	if not await wait_weapon(1): return
	stage = 6
	# Real release/capture boundary: an uncaptured 1 press must not switch,
	# including after recapture while that same physical key is still held.
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	key(KEY_1, true)
	await create_timer(0.2).timeout
	button(MOUSE_BUTTON_LEFT, true)
	button(MOUSE_BUTTON_LEFT, false)
	await create_timer(0.2).timeout
	if session.presentation.local_actor.weapon != 1:
		push_error("Released-pointer selection leaked across recapture")
		quit(2)
		return
	key(KEY_1, false)
	stage = 7
	key(KEY_1, true)
	if not await wait_weapon(0): return
	key(KEY_1, false)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var saved: Error = root.get_texture().get_image().save_png(output)
	print("PORT_WEAPON_LIVE_OK ", JSON.stringify({"stages":stage,"screenshot":saved == OK,"smoke":session.smoke,"actor_id":session.client.actor_id,"ack":session.client.last_ack,"weapon":session.presentation.local_actor.weapon,"rocket_ammo":session.presentation.local_actor.ammo[1]}))
	session.client.disconnect_server()
	quit(0 if saved == OK else 2)
