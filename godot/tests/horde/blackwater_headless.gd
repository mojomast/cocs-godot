extends Node
## Bounded, automated NATIVE input fixture. This is not human balance/playtime.
## InputEventKey/MouseButton/Motion -> HordeControls.sample -> HordeClient
## FIFO -> the unchanged source Match and BlackwaterDirector. Reads only
## authority snapshots and scene receipts; never sets actor, wave or mission.
@onready var session: Node = $NativeHorde
const STATIONS := ["north-feeder", "south-feeder", "switch-pump", "relief-valve"]
const LOOK_GAIN := 0.002
var held: Dictionary = {}
var firing := false
var goal := "chain"
var started_usec := 0
var last_position_log := 0
var last_wave := -1
var last_revision := -1
var last_serial := -1
var last_progress := -1
var last_phase := -1
var last_warden_phase := 0
var last_voice_count := 0
var warden_id := -1
var boss_tell := false
var boss_voice := false
var restored := {}
var gate_events: Array[String] = []
var stage_events: Array[String] = []
var reward_events: Array[String] = []
var objective_receipts := {}
var pending_pulse := -1.0
var route_key := ""
var route: Array[Vector2] = []
var route_index := 0
var done := false

func _ready() -> void:
	started_usec = Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--goal="): goal = arg.trim_prefix("--goal=")
	if goal not in ["chain", "boss"]:
		finish(false,"unknown bounded fixture goal")
		return
	session.client.events.connect(observe_events)
	print("BLACKWATER_FIXTURE ",JSON.stringify({"goal":goal,"scene":session.scene_file_path,
		"client_script":session.get_script().resource_path,"headless":OS.has_environment("BLACKWATER_HEADLESS_FIXTURE"),
		"controls_path":"InputEvent -> HordeControls.sample -> HordeClient.send_controls"}))

func key(code: int, down: bool) -> void:
	if held.get(code,false) == down: return
	held[code] = down
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func mouse(down: bool) -> void:
	if firing == down: return
	firing = down
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	Input.parse_input_event(e)

func neutral() -> void:
	for code: int in held.keys(): key(code,false)
	mouse(false)

func pulse_interact() -> void:
	key(KEY_E,true)
	key(KEY_E,false)
	print("BLACKWATER_INPUT_INTERACT ",JSON.stringify({"epoch":session.horde_client.input_epoch,
		"last_ack":session.client.last_ack,"source_time":session.latest.get("time")}))

func aim_at(target: Dictionary, player: Dictionary) -> void:
	var delta := Vector3(float(target.x)-float(player.x),float(target.get("y",player.y))+0.9-session.camera.position.y,
		float(target.z)-float(player.z))
	var yaw := atan2(-delta.x,-delta.z)
	var pitch := atan2(delta.y,Vector2(delta.x,delta.z).length())
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-wrapf(yaw-session.yaw,-PI,PI)/LOOK_GAIN,-(pitch-session.pitch)/LOOK_GAIN)
	Input.parse_input_event(motion)

func move_towards(target: Vector2, player: Dictionary, enemy: Dictionary = {}) -> float:
	var current := Vector2(float(player.x),float(player.z))
	var direction := (target-current).normalized()
	if not enemy.is_empty(): aim_at(enemy,player)
	else: aim_at({"x":target.x,"y":player.y,"z":target.y},player)
	# World motion independent of look: ordinary simultaneous WASD keys, even
	# while aiming a robot across the route. No direct wire/world-axis injection.
	var forward := -sin(session.yaw)*direction.x-cos(session.yaw)*direction.y
	var right := cos(session.yaw)*direction.x-sin(session.yaw)*direction.y
	var moving := current.distance_to(target)>2.3
	key(KEY_W,moving and forward>0.35)
	key(KEY_S,moving and forward< -0.35)
	key(KEY_D,moving and right>0.35)
	key(KEY_A,moving and right< -0.35)
	key(KEY_SHIFT,moving)
	return current.distance_to(target)

func set_route(id: String, waypoints: Array[Vector2]) -> void:
	if route_key == id: return
	route_key = id
	route = waypoints
	route_index = 0
	print("BLACKWATER_INPUT_ROUTE ",JSON.stringify({"id":id,"points":route.map(func(p: Vector2)->Array: return [p.x,p.y])}))

func follow_route(player: Dictionary, enemy: Dictionary = {}) -> bool:
	if route.is_empty(): return false
	var pos := Vector2(float(player.x),float(player.z))
	while route_index < route.size()-1 and pos.distance_to(route[route_index])<4:
		route_index += 1
	return move_towards(route[route_index],player,enemy)<4 and route_index==route.size()-1

func station_route(id: String) -> Array[Vector2]:
	match id:
		"north-feeder": return [Vector2(-170,0),Vector2(-170,-40),Vector2(-170,78)]
		"south-feeder": return [Vector2(-170,0),Vector2(-170,-40),Vector2(-82,-40),Vector2(-82,-78)]
		"switch-pump": return [Vector2(-82,-40),Vector2(0,-40),Vector2(0,78)]
		"relief-valve": return [Vector2(0,-40),Vector2(170,-40),Vector2(170,-82)]
	return []

func nearest_enemy(player: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for actor: Dictionary in session.latest.get("actors",[]):
		if actor.get("isNpc") != true or float(actor.get("health",0))<=0: continue
		var distance := Vector2(float(actor.x)-float(player.x),float(actor.z)-float(player.z)).length()
		if distance<best:
			best = distance
			result = actor
	return result

func observe_events(events: Array) -> void:
	for value: Variant in events:
		if not value is Dictionary: continue
		var e: Dictionary = value
		var kind := str(e.get("type",""))
		if kind in ["horde-transit-begin","horde-gate-open","horde-gate-closed","horde-transit-fallback","horde-stage-entered"]:
			gate_events.append(kind)
			if kind == "horde-stage-entered": stage_events.append(str(e.get("stageId","")))
			print("BLACKWATER_SOURCE_GATE_EVENT ",JSON.stringify(e))
		if kind in ["blackwater-station-armed","blackwater-station-restored","horde-resupply"]:
			if kind == "blackwater-station-restored": restored[str(e.get("station",""))] = true
			if kind == "horde-resupply": reward_events.append(kind)
			print("BLACKWATER_SOURCE_REWARD_EVENT ",JSON.stringify(e))
		if kind in ["horde-warden-arrived","boss-phase","enemy-telegraph","boss-slam"] and (kind != "enemy-telegraph" or e.get("kind") == "boss"):
			if kind == "enemy-telegraph" and e.get("kind") == "boss": boss_tell = true
			print("BLACKWATER_SOURCE_BOSS_EVENT ",JSON.stringify(e))

func observe_state(player: Dictionary, state: Dictionary, mission: Dictionary) -> void:
	var wave := int(state.get("wave",0))
	if wave != last_wave:
		last_wave = wave
		print("BLACKWATER_NATIVE_WAVE ",JSON.stringify({"wave":wave,"phase":state.get("phase"),
			"source_time":session.latest.get("time"),"lives":state.get("lives"),"enemies":state.get("enemiesAlive")}))
	var stage: Dictionary = state.get("stage",{})
	var revision := int(stage.get("geometryRevision",-1))
	if revision != last_revision and revision>=0 and is_instance_valid(session.builder):
		last_revision = revision
		var bodies: Array = session.builder.gate_bodies
		print("BLACKWATER_NATIVE_GATES ",JSON.stringify({"revision":revision,"mask":stage.get("gateMask"),
			"stage":stage.get("stageId"),"bodies":bodies.map(func(b: StaticBody3D)->Dictionary:
				return {"visible":b.visible,"collision_layer":b.collision_layer}),"source_time":session.latest.get("time")}))
	var serial := int(mission.get("serial",-1))
	if serial != last_serial:
		last_serial = serial
		print("BLACKWATER_NATIVE_STATIONS ",JSON.stringify({"serial":serial,"completed":mission.get("completed"),
			"active":mission.get("active"),"hud":session.horde_label.text,"source_time":session.latest.get("time")}))
	for s: Dictionary in mission.get("stations",[]):
		if s.get("id") != mission.get("active"): continue
		var progress := int(float(s.get("progress",0)))
		if progress != last_progress:
			last_progress = progress
			var sign: Label3D = session.builder.station_signs.get(str(s.id))
			objective_receipts[str(s.id)] = sign != null and sign.visible and "WORKING" in session.horde_label.text and "DEFEND" in sign.text
			print("BLACKWATER_NATIVE_PROGRESS ",JSON.stringify({"station":s.id,"progress":s.get("progress"),
				"required":s.get("required"),"hud":session.horde_label.text,"sign":sign.text if sign != null else "missing",
				"source_time":session.latest.get("time")}))
	for actor: Dictionary in session.latest.get("actors",[]):
		if actor.get("npcModel") != "warden" or float(actor.get("health",0))<=0: continue
		warden_id = int(actor.id)
		var phase := int(actor.get("bossPhase",0))
		if phase>last_warden_phase:
			last_warden_phase = phase
			print("BLACKWATER_NATIVE_WARDEN ",JSON.stringify({"id":warden_id,"health":actor.health,
				"phase":phase,"windup":actor.get("bossStompWindup"),"hud_phase":state.get("bossPhase"),
				"source_time":session.latest.get("time")}))
	if session.robot_voices.played>last_voice_count:
		last_voice_count = session.robot_voices.played
		for index: int in session.robot_voices.players.size():
			var voice: AudioStreamPlayer3D = session.robot_voices.players[index]
			if session.robot_voices.owners[index] == warden_id and voice.stream != null:
				boss_voice = true
				print("BLACKWATER_NATIVE_WARDEN_VOICE ",JSON.stringify({"owner":warden_id,
					"asset":voice.stream.resource_path,"played":last_voice_count,"source_time":session.latest.get("time")}))
	var now := Time.get_ticks_usec()
	if now-last_position_log>5000000:
		last_position_log = now
		print("BLACKWATER_NATIVE_INPUT ",JSON.stringify({"position":[player.get("x"),player.get("y"),player.get("z")],
			"health":player.get("health"),"wave":wave,"source_time":session.latest.get("time"),
			"route":route_key,"ack":session.client.last_ack,"epoch":session.horde_client.input_epoch,
			"fifo":session.horde_client.input_status,"native_controls":session.controls.sample(session.yaw,session.pitch)}))

func chain_complete(state: Dictionary, mission: Dictionary) -> bool:
	return mission.get("completed",[]).size()==4 and last_revision>=2 \
		and state.get("stage",{}).get("stageId")=="C" and "B" in stage_events and "C" in stage_events \
		and restored.size()==4 and reward_events.size()>=2 \
		and objective_receipts.get("north-feeder",false) and objective_receipts.get("south-feeder",false) \
		and objective_receipts.get("switch-pump",false) and objective_receipts.get("relief-valve",false)

func _process(_delta: float) -> void:
	if done: return
	var elapsed := float(Time.get_ticks_usec()-started_usec)/1000000.0
	if elapsed>(620.0 if goal == "chain" else 760.0):
		finish(false,"normal-clock bounded wall time expired")
		return
	if session.phase == -1:
		finish(false,"client transport/error: "+session.label.text)
		return
	if session.phase == 4:
		finish(false,"source results before objective/boss receipts: "+str(session.horde.state.get("phase")))
		return
	if session.phase != 3 or not session.received_pose: return
	var player: Dictionary = session.presentation.local_actor
	var state: Dictionary = session.horde.state
	var mission: Dictionary = session.latest.get("blackwater",{})
	if player.is_empty() or state.is_empty() or mission.is_empty(): return
	observe_state(player,state,mission)
	if chain_complete(state,mission):
		if last_phase != 1:
			last_phase = 1
			print("BLACKWATER_CHAIN_DONE ",JSON.stringify({"wave":state.get("wave"),"stage":state.get("stage"),
				"serial":mission.get("serial"),"reward_events":reward_events.size(),"source_time":session.latest.get("time")}))
		if goal == "chain":
			finish(true,"four source-earned stations, two source arrivals and native HUD/physical-gate receipts")
			return
	if goal == "boss" and last_phase == 1 and int(state.get("wave",0))>=10 and last_warden_phase>=3 and boss_tell and boss_voice:
		finish(true,"bounded normal-wave Warden role, three source phases, ground tell and native voice")
		return
	if float(player.get("health",0))<=0:
		neutral()
		return
	if not session.weapon_controls_active():
		neutral()
		return
	var enemy := nearest_enemy(player)
	var stage: Dictionary = state.get("stage",{})
	var transit: Variant = stage.get("transit")
	if transit is Dictionary:
		var to := str(transit.get("to",""))
		if to=="B": set_route("transit-B",[Vector2(-170,-40),Vector2(-82,-40),Vector2(0,-40),Vector2(0,0)])
		elif to=="C": set_route("transit-C",[Vector2(0,-40),Vector2(170,-40),Vector2(170,0)])
		follow_route(player)
		mouse(false)
		return
	var station: Dictionary = {}
	for id: String in STATIONS:
		if id in mission.get("completed",[]): continue
		for s: Dictionary in mission.get("stations",[]):
			if str(s.get("id"))==id and s.get("available")==true:
				station=s
				break
		if not station.is_empty(): break
	var fight := int(state.get("enemiesAlive",0))>0 and (station.is_empty() or str(station.get("id")) not in ["north-feeder","south-feeder"])
	if not station.is_empty() and not fight:
		var id := str(station.id)
		set_route(id,station_route(id))
		var at_station := Vector2(float(player.x),float(player.z)).distance_to(Vector2(float(station.x),float(station.z)))<4.2
		if at_station:
			neutral()
			if float(mission.get("tick",0))>=pending_pulse and str(mission.get("active",""))!=id:
				pulse_interact()
				pending_pulse = float(mission.get("tick",0))+45
			if not enemy.is_empty():
				aim_at(enemy,player)
				mouse(true)
		else:
			follow_route(player,enemy if not enemy.is_empty() and Vector2(float(enemy.x)-float(player.x),float(enemy.z)-float(player.z)).length()<30 else {})
			mouse(not enemy.is_empty() and Vector2(float(enemy.x)-float(player.x),float(enemy.z)-float(player.z)).length()<30)
		return
	if not enemy.is_empty():
		var distance := Vector2(float(enemy.x)-float(player.x),float(enemy.z)-float(player.z)).length()
		move_towards(Vector2(float(enemy.x),float(enemy.z)),player,enemy)
		mouse(true)
		key(KEY_R,player.get("ammo",[]) is Array and int(player.get("weapon",0))<player.get("ammo",[]).size() and player.get("ammo",[])[int(player.get("weapon",0))]==0)
		if distance<14: key(KEY_SHIFT,false)
	else:
		neutral()

func finish(ok: bool, message: String) -> void:
	if done: return
	done = true
	neutral()
	print("BLACKWATER_HEADLESS_DONE ",JSON.stringify({"ok":ok,"message":message,"goal":goal,
		"wave":session.horde.state.get("wave"),"stage":session.horde.state.get("stage"),
		"completed":session.latest.get("blackwater",{}).get("completed",[]),
		"stage_events":stage_events,"gate_events":gate_events,"rewards":reward_events.size(),
		"warden_phase":last_warden_phase,"warden_tell":boss_tell,"warden_voice":boss_voice,
		"wall_seconds":float(Time.get_ticks_usec()-started_usec)/1000000.0}))
	get_tree().quit(0 if ok else 1)
