extends SceneTree
# Shipped scene, no subclassing or runtime/control-state writes.
# Synchronous observer association from native_death_respawn 1d5a3dd;
# route-following Input.parse_input_event pattern adapted from
# native_pickup_acceptance/observe.gd at 5e8e02e (no archives used).
const ACTOR_KEYS := ["id","x","y","z","yaw","pitch","eyeHeight","health","maxHealth","armor","dead","temporaryShield","juggernautShield","protection","active","braceTimer","braceMitigation","cocsArrival","damageMultiplier","gearDamage","gearSpread","character","harness","verbState","powerups","npcShield","weapon","shots"]
const PICKUP_KEYS := ["id","kind","x","y","z","wait"]
const EVENT_KEYS := ["id","time","type","actor","source","amount","shield","shieldBreak","kind","killer","weapon","hit","falloff"]
var session: Node
var elapsed := 0.0
var started_at := -1.0
var last_seq := -1
var stage := "damage_wait"
var steering := 0.0
var sample_elapsed := 0.0
var route_file := ""
var route: Array = []
var generation := 0
var waypoint := 0
var held := false
var clicked := false
var collected := false
var finish_at := -1.0
var ended := false

func projection(value: Dictionary, keys: Array) -> Dictionary:
	var result: Dictionary = {}
	for k: String in keys: result[k] = value.get(k)
	return result

func record(event: String, data: Dictionary = {}) -> void:
	data["event"] = event
	data["elapsed"] = elapsed
	data["trace_next"] = session.trace_count
	print("HEALTH_OBSERVE " + JSON.stringify(data))

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--route="): route_file = arg.trim_prefix("--route=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.client.started.connect(func(frame: Dictionary):
		# Must immediately follow runtime round_start in synchronous signal order.
		print("HEALTH_CORRELATE " + JSON.stringify({"event":"start","mapId":frame.mapId,"roundRevision":frame.roundRevision,"actor_id":session.client.actor_id}))
		started_at = elapsed)
	session.client.snapshot.connect(observe)
	session.client.events.connect(func(items: Array):
		var selected: Array = []
		for item: Dictionary in items: selected.append(projection(item,EVENT_KEYS))
		record("events",{"items":selected,"hurts":session.combat.hurts,"hurt_remaining":session.combat.hurt_remaining,"combat_text":session.combat.text(),"ui_text":session.combat_label.text}))

func key(down: bool) -> void:
	if held == down: return
	held = down
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.physical_keycode = KEY_W
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	record("physical_key",{"key":"W","pressed":down,"engine_held":Input.is_physical_key_pressed(KEY_W)})

func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(800,500)
	event.global_position = event.position
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point_at(target: Vector2) -> void:
	var a: Dictionary = session.presentation.local_actor
	var desired := atan2(-(target.x-float(a.x)),-(target.y-float(a.z)))
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(-wrapf(desired-float(session.yaw),-PI,PI)/0.003,float(session.pitch)/0.003)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	record("mouse_motion",{"relative":[event.relative.x,event.relative.y],"target":[target.x,target.y]})

func observe(frame: Dictionary) -> void:
	last_seq = int(frame.seq)
	var a: Dictionary = session.presentation.local_actor
	var target: Dictionary = {}
	for p: Dictionary in frame.state.pickups:
		if p.kind == "health" and p.x == -6 and p.z == 22: target = p
	var marker: Node3D = session.pickups.markers.get(int(target.get("id",-1)))
	# First print stays immediately adjacent to the runtime snapshot record.
	print("HEALTH_CORRELATE " + JSON.stringify({"event":"snapshot","seq":frame.seq,"time":frame.state.time,"over":frame.state.over,"actor_id":session.client.actor_id,"ack":session.client.last_ack,"actor":projection(a,ACTOR_KEYS),"pickup":projection(target,PICKUP_KEYS),"marker_visible":marker.visible if marker else null,"marker_instance":marker.get_instance_id() if marker else null,"marker_position":[marker.position.x,marker.position.y,marker.position.z] if marker else null,"hud":session.presentation.hud_text,"label":session.label.text,"stage":stage}))
	if a.is_empty() or target.is_empty():
		record("blocker",{"reason":"local actor or authored health pickup missing"})
		stop(2)
		return
	if float(a.health) <= 0 or float(a.dead) > 0:
		record("blocker",{"reason":"nonlethal scenario became lethal"})
		stop(2)
		return
	if generation >= 1 and not collected and float(target.wait) > 0:
		key(false)
		collected = true
		if stage == "approach": stage = "collected"
		record("collected_boundary",{"seq":frame.seq,"time":frame.state.time,"pickup_id":target.id})
	if stage == "waiting_return" and float(target.wait) <= 0:
		stage = "returned"
		finish_at = elapsed+0.75
		record("return_boundary",{"seq":frame.seq,"time":frame.state.time,"pickup_id":target.id})

func stop(code: int) -> void:
	if ended: return
	ended = true
	key(false)
	mouse(false)
	record("harness_end",{"stage":stage,"reason":"return_window" if stage == "returned" else "bounded_inconclusive","completionProven":false})
	quit(code)

func _process(delta: float) -> bool:
	elapsed += delta
	steering += delta
	sample_elapsed += delta
	if not is_instance_valid(session) or ended: return false
	if sample_elapsed >= 0.1:
		sample_elapsed = 0.0
		record("frame",{"phase":session.phase,"seq":last_seq,"actor_id":session.client.actor_id,"starts":session.round_starts,"pose":session.received_pose,"stage":stage,"held_w":Input.is_physical_key_pressed(KEY_W),"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"focused":root.has_focus(),"hurts":session.combat.hurts,"hurt_remaining":session.combat.hurt_remaining,"combat_text":session.combat.text(),"ui_text":session.combat_label.text,"hud":session.presentation.hud_text,"label":session.label.text})
	if (started_at >= 0 and elapsed-started_at > 105.0) or session.phase in [-1,4] or (finish_at >= 0 and elapsed >= finish_at):
		stop(0 if stage == "returned" else 2)
		return false
	if not session.received_pose: return false
	if not clicked and session.can_capture_pointer():
		mouse(true)
		mouse(false)
		clicked = true
		record("capture_click",{"captured":Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,"focused":root.has_focus()})
	if steering < 0.1: return false
	steering = 0.0
	if FileAccess.file_exists(route_file):
		var command: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_file))
		if int(command.generation) > generation:
			generation = int(command.generation)
			route = command.points
			waypoint = 0
			stage = str(command.stage)
			record("route",command)
	var a: Dictionary = session.presentation.local_actor
	var pos := Vector2(float(a.x),float(a.z))
	if stage in ["approach","leave"] and not route.is_empty():
		var target := Vector2(float(route[waypoint][0]),float(route[waypoint][1]))
		if pos.distance_to(target) < 0.65 and waypoint < route.size()-1:
			waypoint += 1
			target = Vector2(float(route[waypoint][0]),float(route[waypoint][1]))
		point_at(target)
		key(pos.distance_to(target) > 0.35)
		if stage == "leave" and waypoint == route.size()-1 and pos.distance_to(target) < 0.5:
			key(false)
			stage = "waiting_return"
			point_at(Vector2(-6,22))
			record("left_radius",{"position":[a.x,a.y,a.z],"seq":last_seq})
	return false
