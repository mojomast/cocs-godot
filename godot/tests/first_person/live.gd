extends SceneTree
## Private integration probe. Only engine key/mouse input; authority remains the stock server.
const Binding = preload("res://first_person/session_binding.gd")
var session: Node
var binding: Node
var directory := ""
var age := 0.0
var active_age := 0.0
var held: Dictionary = {}
var mouse_down := false
var grid := AStarGrid2D.new()
var target := Vector2.ZERO
var path: PackedVector2Array
var acquired := -1
var origin := Vector3.ZERO
var started := false
var moved := 0.0
var switches: Dictionary = {}
var captures: Dictionary = {}
var busy := false
var switch_age := 0.0
var reload_seen := false
var first_recoil := 0
var samples := 0
var frame_times: Array[float] = []
var right_down := false
var ads_seen := false
var aim_release_seen := false
var max_aim := 0.0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-out="): directory = arg.trim_prefix("--evidence-out=")
	session = load("res://world/session.tscn").instantiate()
	root.add_child.call_deferred(session)
	call_deferred("bind")

func bind() -> void:
	if "first_person" in session and is_instance_valid(session.first_person):
		binding = session.first_person
	else:
		binding = Binding.new()
		session.add_child(binding)
	grid.region = Rect2i(-51,-43,103,87)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var map: Dictionary = session.catalog.resolve_map(session.current_id)
	for x: int in range(-51,52):
		for z: int in range(-43,44):
			for b: Dictionary in map.get("blocks",[]):
				if float(b.h) > 0.4 and absf(x-float(b.x)) < float(b.w)/2+0.65 and absf(z-float(b.z)) < float(b.d)/2+0.65:
					grid.set_point_solid(Vector2i(x,z))
					break
	session.client.snapshot.connect(func(_frame: Dictionary) -> void:
		if session.phase != 3: return
		var actor: Dictionary = session.presentation.local_actor
		if actor.is_empty(): return
		samples += 1
		if actor.get("reloading",false): reload_seen = true
		var id: int = int(actor.get("weapon",-1))
		switches[id] = true
		print("FP_LIVE_SNAPSHOT ", JSON.stringify({"time":_frame.state.time,"weapon":id,"rig_weapon":binding.rig.current_weapon,"showing":binding.rig.showing,"health":actor.health,"shots":actor.shots,"recoil_count":binding.rig.recoil_count,"ack":session.client.last_ack,"reloading":actor.get("reloading",false)})))

func key(code: int, down: bool) -> void:
	if held.get(code,false) == down: return
	held[code] = down
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(down: bool) -> void:
	if mouse_down == down: return
	mouse_down = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = root.size / 2
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func position_of(actor: Dictionary) -> Vector3:
	return Vector3(actor.get("x",0),actor.get("y",0),actor.get("z",0))

func aim(down: bool) -> void:
	if right_down == down: return
	right_down = down
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	event.position = root.size / 2
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(tag: String) -> void:
	if busy or captures.has(tag): return
	busy = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("live-"+tag+".png"))
	captures[tag] = true
	busy = false

func finish() -> void:
	key(KEY_W,false)
	mouse(false)
	aim(false)
	frame_times.sort()
	var ok: bool = moved > 2.0 and switches.size() >= 2 and binding.rig.recoil_count > 3 and samples > 30 and ads_seen and aim_release_seen
	var report := {"normal_rate":true,"input":"engine physical-key/mouse events","private_adapter":true,"snapshot_samples":samples,"distance":moved,"source_weapons":switches.keys(),"rig_recoils":binding.rig.recoil_count,"reload_seen":reload_seen,"ads_seen":ads_seen,"aim_release_seen":aim_release_seen,"max_aim_weight":max_aim,"captures":captures.keys(),"frame_p50_ms":frame_times[frame_times.size()/2]*1000 if not frame_times.is_empty() else 0,"pass":ok}
	FileAccess.open(directory.path_join("live-result.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("FP_LIVE_RESULT ",JSON.stringify(report))
	session.client.disconnect_server()
	quit(0 if ok else 1)

func _process(delta: float) -> bool:
	age += delta
	if age > 55:
		finish()
		return false
	if not is_instance_valid(binding) or session.phase != 3 or not session.received_pose: return false
	frame_times.append(delta)
	var actor: Dictionary = session.presentation.local_actor
	if actor.is_empty() or float(actor.health) <= 0:
		key(KEY_W,false)
		mouse(false)
		aim(false)
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		mouse(false)
		mouse(true)
	if not session.weapon_controls_active(): return false
	active_age += delta
	max_aim = maxf(max_aim,binding.rig.aim_weight)
	if binding.rig.get_aim_state().ready: ads_seen = true
	if ads_seen and not right_down and binding.rig.aim_weight < 0.01: aim_release_seen = true
	var pos := position_of(actor)
	if not started:
		started = true
		origin = pos
		var map: Dictionary = session.catalog.resolve_map(session.current_id)
		var nearest := INF
		for pickup: Array in map.pickups:
			if pickup[0] not in ["rocket","rail","scatter","plasma","grenade","shock","flak","smg","marksman"]: continue
			var point := Vector2(pickup[1],pickup[2])
			var route := grid.get_point_path(Vector2i(roundi(pos.x),roundi(pos.z)),Vector2i(point))
			if route.size() > 1 and route.size() < nearest:
				nearest = route.size()
				target = point
				path = route
		print("FP_LIVE_ROUTE ",target," nodes=",path.size())
	moved = maxf(moved,pos.distance_to(origin))
	if active_age < 1.8:
		if active_age > 0.3 and active_age < 0.6: capture("pulse")
		aim(active_age > 0.6 and active_age < 1.6)
		if active_age > 1.3 and binding.rig.get_aim_state().ready: capture("pulse-ads")
		return false
	if acquired < 0:
		aim(false)
		for i: int in range(1,10):
			if session.weapon_selection.available(actor,i): acquired = i; break
	if acquired < 0:
		var here := Vector2(pos.x,pos.z)
		while path.size() > 1 and here.distance_to(path[0]) < 1.1: path.remove_at(0)
		var goal := path[0] if not path.is_empty() else target
		var direction := goal - here
		var desired := atan2(-direction.x,-direction.y)
		var error := wrapf(desired-session.yaw,-PI,PI)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-clampf(error,-0.12,0.12)/0.003,session.pitch/0.003)
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		key(KEY_W, absf(error)<0.6)
		mouse(true)
	else:
		key(KEY_W,false)
		switch_age += delta
		aim(switch_age > 0.7 and switch_age < 2.5 or switch_age > 5.0 and switch_age < 6.0)
		var code: int = KEY_0 if acquired == 9 else KEY_1+acquired
		key(code,switch_age < 0.22)
		if int(actor.weapon) == acquired and switch_age > 0.6: capture("weapon-%d" % acquired)
		if int(actor.weapon) == acquired and binding.rig.get_aim_state().ready: capture("weapon-%d-ads" % acquired)
		mouse(switch_age < 2.5 or switch_age > 5)
		key(KEY_R,switch_age > 3 and switch_age < 3.3)
		if switch_age > 3.5 and reload_seen: capture("reload")
		key(KEY_1,switch_age > 6 and switch_age < 6.22)
		if switch_age > 7:
			capture("switched-back")
		if switch_age > 8 and not busy: finish()
	return false
