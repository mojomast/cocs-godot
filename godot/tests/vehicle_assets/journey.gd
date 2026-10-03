extends "res://combined_arms/demo.gd"
## Grant-only production route. The fixture supplies physical input events;
## production controls, native transport and authoritative snapshots do the work.
const Attachments = preload("res://vehicle_assets/attachment.gd")
const WeatherProbe = preload("res://ambience/weather_look.gd")
const MOUTHS := {"puma":[Vector3(-0.82,1.18,0.2),Vector3(0.82,1.18,0.2)],"titan":[Vector3(0,1.5,1.6)],"scout":[Vector3(0,0.9,0.6)]}
const KEY_CODES := {"W":KEY_W,"A":KEY_A,"S":KEY_S,"D":KEY_D,"SHIFT":KEY_SHIFT,"SPACE":KEY_SPACE,"E":KEY_E,"R":KEY_R,"ENTER":KEY_ENTER,"ESCAPE":KEY_ESCAPE}
var command_path := ""
var journey_role := ""
var require_assets := false
var stage_name := "startup"
var command_id := 0
var held: Array[String] = []
var firing := false
var elapsed := 0.0
var reporting := 0.0
var rounds := 0
var shutting_down := false
var failures: Array[String] = []
var asset_meshes: Dictionary = {}
var prior_nodes: Array[WeakRef] = []
var reset_clean := false
var wet := false
var weather_probe := WeatherProbe.new()
var probe_environment := WorldEnvironment.new()
var surface_bases: Array[Dictionary] = []
var vehicle_target := ""
var suppressed_stage := ""
var capture_path := ""
var capture_busy := false
var capture_age := 0.0
var captures := 0
var captured_stages: Dictionary = {}

func verify(value: bool, label: String) -> void:
	if value: return
	if not label in failures:
		failures.append(label)
		push_error("VEHICLE_JOURNEY_FAIL " + label)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle-command="): command_path = arg.trim_prefix("--vehicle-command=")
		if arg.begins_with("--vehicle-role="): journey_role = arg.trim_prefix("--vehicle-role=")
		if arg.begins_with("--vehicle-target="): vehicle_target = arg.trim_prefix("--vehicle-target=")
		if arg.begins_with("--vehicle-capture="): capture_path = arg.trim_prefix("--vehicle-capture=")
		require_assets = require_assets or arg == "--require-assets"
	verify(require_assets, "production journey requires --require-assets; fallback is a separate gate")
	probe_environment.environment = Environment.new()
	# Load the actual nine required GLBs and retain their mesh resource identities.
	for kind: String in MOUTHS:
		asset_meshes[kind] = []
		for lod in 3:
			var path := "res://vehicle_assets/generated/%s-lod%d.glb" % [kind,lod]
			verify(ResourceLoader.exists(path), "required asset " + path)
			if not ResourceLoader.exists(path): continue
			var packed := load(path) as PackedScene
			verify(packed != null, "packed asset " + path)
			if packed == null: continue
			var imported := packed.instantiate()
			var found: Dictionary = {}
			verify(Attachments.meshes(imported, found), "rigid asset " + path)
			var identities: Dictionary = {}
			for joint: String in found: identities[joint] = found[joint].mesh
			asset_meshes[kind].append(identities)
			imported.free()
	if not failures.is_empty():
		get_tree().quit(2)
		return
	super._ready()
	world.sun.shadow_enabled = false
	get_viewport().scaling_3d_scale = 0.5
	if not capture_path.is_empty(): DirAccess.make_dir_recursive_absolute(capture_path)
	var settings := SettingsAccess.service()
	if settings != null: settings.set_value("ui_scale",150 if "--vehicle-compact" in OS.get_cmdline_user_args() else 100,false)
	input_queued.connect(func(seq: int, packet: Dictionary, result: int) -> void:
		print("VEHICLE_INPUT ",JSON.stringify({"role":journey_role,"stage":stage_name,"round":rounds,"seq":seq,"packet":packet,"result":result})))

func on_lobby(frame: Dictionary) -> void:
	if not configured and join_room_id.is_empty() and frame.get("hostId",-1) == net.peer_id:
		configured = true
		roster = frame
		checked(net.send_frame({"type":"host","mapId":map_id,"config":{"mode":"combined-arms","botCount":0,"timeLimit":180,"fragLimit":900,"startingWeapon":0,"unlimitedAmmo":true}}))
		return
	super.on_lobby(frame)

func on_started(frame: Dictionary) -> void:
	weather_probe.clear()
	wet = false
	surface_bases.clear()
	prior_nodes.clear()
	for node: Node3D in fleet.nodes.values() + fleet.secondary.values(): prior_nodes.append(weakref(node))
	super.on_started(frame)
	rounds += 1
	reset_clean = rounds > 1 and fleet.nodes.is_empty() and fleet.secondary.is_empty() and vehicle_bridge.identity.is_empty() and not controls.engaged
	held.clear()
	firing = false
	print("VEHICLE_STARTED ",JSON.stringify({"role":journey_role,"round":rounds,"resetClean":reset_clean}))

func on_events(items: Array) -> void:
	super.on_events(items)
	for event: Dictionary in items:
		if str(event.get("type","")).begins_with("vehicle-") or event.get("type") in ["shot","launch"]:
			print("VEHICLE_EVENT ",JSON.stringify({"role":journey_role,"stage":stage_name,"round":rounds,"event":event}))

func on_snapshot(frame: Dictionary) -> void:
	var previous := identity
	super.on_snapshot(frame)
	# The production lease releases inputs on seat changes. Do not turn a still
	# queued E into an automatic second interaction while the driver observes it.
	if previous != identity and (stage_name.begins_with("enter-") or stage_name.begins_with("exit-")): suppressed_stage = stage_name

func key_event(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_CODES[name]
	event.pressed = pressed
	Input.parse_input_event(event)

func mouse_fire(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)

func release_stimulus() -> void:
	for name: String in held: key_event(name,false)
	held.clear()
	mouse_fire(false)
	firing = false

func channels(material: StandardMaterial3D) -> Array:
	return [material.albedo_texture,material.normal_enabled,material.normal_texture,material.normal_scale,material.roughness,material.metallic,material.roughness_texture,material.roughness_texture_channel,material.metallic_texture,material.metallic_texture_channel]

func toggle_wet(value: bool) -> void:
	if value == wet: return
	if value:
		surface_bases.clear()
		# A labelled presentation probe on LIVE source-owned meshes. This is not
		# claimed as natural map rain or a source weather event.
		var node: Node3D = fleet.vehicle_node(vehicle_target)
		verify(node != null and node.has_meta("authored_vehicle"),"weather target is live authored vehicle")
		if node == null: return
		for binding: Dictionary in node.get_meta("vehicle_accents",[]):
			var mesh: MeshInstance3D = binding.node.get_ref()
			var prior: StandardMaterial3D = mesh.get_active_material(binding.surface)
			surface_bases.append({"node":weakref(mesh),"surface":binding.surface,"prior":prior,"channels":channels(prior)})
		weather_probe.bind(node,probe_environment,null,73)
		weather_probe.apply("rain",1.0,true)
		verify(not weather_probe.capped,"weather probe within material budget")
		for binding: Dictionary in surface_bases:
			var mesh: MeshInstance3D = binding.node.get_ref()
			verify(mesh.get_active_material(binding.surface) != binding.prior,"weather installs independent active clone")
	else:
		weather_probe.clear()
		for binding: Dictionary in surface_bases:
			var mesh: MeshInstance3D = binding.node.get_ref()
			if is_instance_valid(mesh):
				verify(mesh.get_active_material(binding.surface) == binding.prior,"weather restores exact material owner")
				verify(channels(binding.prior) == binding.channels,"weather restores textures and channels while retaining new team tint")
		surface_bases.clear()
	wet = value

func apply_command(command: Dictionary) -> void:
	if command.get("quit",false):
		shutting_down = true
		shutdown_fixture.call_deferred()
		return
	if command.get("id",0) < command_id: return
	command_id = int(command.get("id",0))
	stage_name = str(command.get("stage","unknown"))
	toggle_wet(bool(command.get("wet",false)))
	if phase == "active" and stage_name == suppressed_stage:
		release_stimulus()
		return
	var desired: Array = command.get("keys",[])
	for name: String in desired: verify(KEY_CODES.has(name),"known input key")
	if not failures.is_empty(): return
	if eligible() and not controls.engaged:
		release_stimulus()
		key_event("ENTER",true)
		key_event("ENTER",false)
	if command.has("yaw") and eligible():
		var motion := InputEventMouseMotion.new()
		var gain := 0.003 * SettingsAccess.sensitivity()
		motion.relative = Vector2(-wrapf(float(command.yaw)-yaw,-PI,PI)/gain,(pitch-float(command.get("pitch",0)))/gain)
		Input.parse_input_event(motion)
	for name: String in held:
		if not name in desired: key_event(name,false)
	for name: String in desired:
		if not name in held:
			key_event(name,true)
		elif name in ["W","A","S","D","SHIFT","SPACE"] and controls.engaged and not controls.keys.has(KEY_CODES[name]):
			# A real lease/focus release can arrive between stimulus and snapshot.
			# Recovery uses a fresh physical up/down edge, never edits the gate.
			key_event(name,false)
			key_event(name,true)
	held.assign(desired)
	var next_fire := bool(command.get("fire",false))
	if next_fire != firing: mouse_fire(next_fire)
	firing = next_fire

func fleet_report() -> Array:
	var rows: Array = []
	var ownership: Dictionary = {}
	for v: Dictionary in state.get("vehicles",[]):
		if not MOUTHS.has(v.kind): continue
		var node: Node3D = fleet.vehicle_node(v.id)
		verify(node != null,"source vehicle node exists")
		if node == null: continue
		var targets: Dictionary = {"body":node,"turret":node.turret}
		for i in node.wheels.size(): targets["wheel_%d" % i] = node.wheels[i]
		var lods := 0
		var identities := true
		var isolated := true
		for joint: String in targets:
			var seen: Dictionary = {}
			for child: Node in targets[joint].get_children():
				if not child is MeshInstance3D or not child.visible: continue
				var found := -1
				for lod in asset_meshes[v.kind].size():
					if child.mesh == asset_meshes[v.kind][lod].get(joint): found = lod
				identities = identities and found >= 0 and not seen.has(found)
				seen[found] = true
				lods += 1
				for surface_index in child.mesh.get_surface_count():
					var material: Material = child.get_active_material(surface_index)
					if material == null: continue
					var material_id := material.get_instance_id()
					isolated = isolated and (not ownership.has(material_id) or ownership[material_id] == v.id)
					ownership[material_id] = v.id
			identities = identities and seen.size() == 3
		var source_yaw := Basis(Vector3.UP,float(v.yaw)+float(v.turretYaw))
		var mouth_ok := true
		for mouth: Vector3 in MOUTHS[v.kind]:
			var expected := Vector3(v.x,v.y,v.z)+source_yaw*mouth
			mouth_ok = mouth_ok and (node.turret.global_transform*(mouth-Attachments.PIVOTS[v.kind])).distance_to(expected)<0.0001
		var team := -1
		for a: Dictionary in state.get("actors",[]):
			if a.id == v.driver: team = int(a.team)
		var color := Color("e56859") if team == 0 else (Color("58a7ed") if team == 1 else Color("dfc98d"))
		var owned := true
		var wheel_angles: Array = []
		for wheel: Node3D in node.wheels:
			verify(is_finite(wheel.rotation.x) and is_zero_approx(wheel.rotation.y) and is_zero_approx(wheel.rotation.z),"source-only rolling axis")
			wheel_angles.append(wheel.rotation.x)
		if v.kind == "puma":
			var expected_roll: float = wrapf(node.roll_angle + node.roll_speed * node.roll_age / 0.42,-PI,PI)
			verify(node.roll_age <= 0.100001 and absf(wrapf(node.wheels[0].rotation.x-expected_roll,-PI,PI))<0.0001,"bounded source Puma wheel lead")
		for binding: Dictionary in node.get_meta("vehicle_accents",[]):
			var mesh: MeshInstance3D = binding.node.get_ref()
			var active: StandardMaterial3D = mesh.get_active_material(binding.surface)
			owned = owned and active != null and active.albedo_color.is_equal_approx(color) and binding.base.albedo_color.is_equal_approx(color)
			if active != null:
				var material_id := active.get_instance_id()
				isolated = isolated and (not ownership.has(material_id) or ownership[material_id] == v.id)
				ownership[material_id] = v.id
		verify(node.get_meta("authored_vehicle","") == v.kind and identities,"authored nine-LOD identity for " + str(v.id))
		verify(owned and isolated,"team/weather per-instance ownership for " + str(v.id))
		verify(mouth_ok,"source muzzle transform " + str(v.id))
		rows.append({"id":v.id,"kind":v.kind,"authored":node.get_meta("authored_vehicle",""),"attachments":targets.size(),"lods":lods,"assetIdentity":identities,"muzzleMatch":mouth_ok,"visible":node.visible,"position":[node.position.x,node.position.y,node.position.z],"team":team,"channelsOwned":owned,"materialsIsolated":isolated,"wheelAngles":wheel_angles})
	return rows

func _process(delta: float) -> void:
	if shutting_down: return
	elapsed += delta
	if elapsed > 390: verify(false,"390 second native deadline")
	# Select repair harness through the real create/join protocol before the
	# production route's ordinary connection loop performs its default create.
	if phase == "connecting" and not create_sent and net.peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		create_sent = true
		checked(net.create_room("Vehicle "+journey_role,"chatgpt","codex") if join_room_id.is_empty() else net.join_room(join_room_id,"Vehicle "+journey_role,"chatgpt","codex"))
	if FileAccess.file_exists(command_path):
		var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(command_path))
		if command is Dictionary: apply_command(command)
	if shutting_down: return
	super._process(delta)
	capture_age += delta
	if phase == "active" and not capture_busy and not capture_path.is_empty() and capture_age >= 0.12 and captures < 180:
		if stage_name in ["drive-boost","drive-bend","reverse"] or not captured_stages.has(stage_name):
			capture_age = 0
			captured_stages[stage_name] = true
			capture_frame.call_deferred()
	reporting += delta
	if reporting >= 0.2:
		reporting = 0
		var retired := true
		for reference: WeakRef in prior_nodes: retired = retired and reference.get_ref() == null
		print("VEHICLE_REPORT ",JSON.stringify({"role":journey_role,"stage":stage_name,"command":command_id,"round":rounds,"requireAssets":require_assets,"phase":phase,"peer":net.peer_id,"seq":net.last_snapshot_seq,"ack":net.last_ack,"sourceTime":state.get("time",-1),"actor":actor,"fleet":fleet_report() if phase == "active" else [],"wet":wet,"resetClean":reset_clean,"retired":retired,"failures":failures,"inputState":{"engaged":controls.engaged,"focused":controls.focused,"windowFocus":get_window().has_focus(),"keys":controls.keys,"blocked":controls.blocked,"age":age,"eligible":eligible(),"delta":delta}}))

func capture_frame() -> void:
	if capture_busy: return
	capture_busy = true
	var captured_stage := stage_name
	await RenderingServer.frame_post_draw
	var path := capture_path.path_join("%04d-%s.png" % [captures,captured_stage])
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("VEHICLE_CAPTURE ",JSON.stringify({"file":path,"stage":captured_stage,"sourceTime":state.get("time",-1),"seq":net.last_snapshot_seq,"ticksMs":Time.get_ticks_msec(),"engineFrame":Engine.get_frames_drawn(),"camera":str(world.camera.global_position),"viewport":str(get_viewport().get_visible_rect().size),"result":result}))
	verify(result == OK,"capture write")
	captures += 1
	capture_busy = false

func shutdown_fixture() -> void:
	while capture_busy: await get_tree().process_frame
	release_stimulus()
	toggle_wet(false)
	net.disconnect_server()
	clear_round()
	verify(fleet.nodes.is_empty() and fleet.secondary.is_empty() and vehicle_bridge.identity.is_empty(),"teardown source ownership cleared")
	verify(not controls.engaged and not controls.fire,"teardown input released")
	probe_environment.free()
	asset_meshes.clear()
	print("CANDIDATE_TEARDOWN_READY ",JSON.stringify({"role":journey_role,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 2)
