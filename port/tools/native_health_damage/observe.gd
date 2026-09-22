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
var evidence := ""
var pending_hud: Dictionary = {}
var rendered_seq := -1
var damage_event_id := -1
var rendered_damage_id := -1
var overlay_draw_frame := -1
var overlay_draw_hurt := 0.0
var images: Dictionary = {}
var hud_sample_at := -1.0

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
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	call_deferred("begin")

func begin() -> void:
	session = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	session.combat.overlay.draw.connect(func():
		overlay_draw_frame = Engine.get_process_frames()
		overlay_draw_hurt = session.combat.overlay.hurt_strength)
	RenderingServer.frame_post_draw.connect(observe_rendered_hud)
	session.client.started.connect(func(frame: Dictionary):
		# Must immediately follow runtime round_start in synchronous signal order.
		print("HEALTH_CORRELATE " + JSON.stringify({"event":"start","mapId":frame.mapId,"roundRevision":frame.roundRevision,"actor_id":session.client.actor_id}))
		started_at = elapsed)
	session.client.snapshot.connect(observe)
	session.client.events.connect(func(items: Array):
		var selected: Array = []
		for item: Dictionary in items:
			selected.append(projection(item,EVENT_KEYS))
			if item.get("type") == "damage" and item.get("actor") == session.client.actor_id and float(item.get("amount",0)) > 0:
				damage_event_id = int(item.id)
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
	# No HUD read here: its deferred binding puts its snapshot callback after ours.
	# Multiple snapshots in one render interval supersede this pending observation.
	pending_hud = {"seq":int(frame.seq),"native_sequence":session.trace_count-1,"actor":projection(a,ACTOR_KEYS),"time":frame.state.time}
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

func ui_control(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	return {"visible":control.is_visible_in_tree(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"in_viewport":root.get_visible_rect().encloses(rect)}

func observe_rendered_hud() -> void:
	if ended or pending_hud.is_empty(): return
	if rendered_seq == int(pending_hud.seq) and rendered_damage_id == damage_event_id: return
	if elapsed-hud_sample_at < 0.1 and rendered_damage_id == damage_event_id: return
	hud_sample_at = elapsed
	rendered_seq = int(pending_hud.seq)
	rendered_damage_id = damage_event_id
	var hud: CanvasLayer = session.get_node("GameHUD")
	var overlay: Control = session.combat.overlay
	var data := pending_hud.duplicate(true)
	data.merge({"schema":1,"mode":"compact-default","render_frame":Engine.get_process_frames(),"post_draw":true,"root_visible":hud.root.is_visible_in_tree(),"layer_visible":hud.visible,"vitals_visible":hud.vitals.is_visible_in_tree(),"legacy_label_visible":session.label.is_visible_in_tree(),"legacy_combat_visible":session.combat_label.is_visible_in_tree(),"health_label":ui_control(hud.health_label),"armor_label":ui_control(hud.armor_label),"health_bar":ui_control(hud.health_bar),"armor_bar":ui_control(hud.armor_bar),"overlay":ui_control(overlay),"overlay_draw_frame":overlay_draw_frame,"overlay_draw_hurt":overlay_draw_hurt,"hurt_strength":overlay.hurt_strength,"hurt_remaining":session.combat.hurt_remaining,"hurts":session.combat.hurts,"damage_event_id":damage_event_id})
	data.health_label["text"] = hud.health_label.text
	data.armor_label["text"] = hud.armor_label.text
	for name: String in ["health_bar","armor_bar"]:
		data[name]["value"] = hud.get(name).value
		data[name]["max"] = hud.get(name).max_value
		data[name]["step"] = hud.get(name).step
	var image_name := ""
	if damage_event_id < 0: image_name = "baseline"
	elif overlay.hurt_strength > 0 and overlay_draw_frame == Engine.get_process_frames(): image_name = "hurt"
	elif collected: image_name = "collected"
	if not image_name.is_empty() and not images.has(image_name) and not evidence.is_empty():
		images[image_name] = true
		data["image"] = image_name + ".png"
		data["image_result"] = root.get_texture().get_image().save_png(evidence.path_join(data.image))
	record("hud_render",data)

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
