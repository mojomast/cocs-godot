extends Node3D
## Local shell. Only core.step advances authority; assets are required, never faked.
const Router = preload("res://fighting/presentation/input_router.gd")
const Camera = preload("res://fighting/presentation/camera.gd")
const Backdrop = preload("res://fighting/stages/backdrop.gd")
const Stages = preload("res://fighting/stages/catalog.gd")
const TrainingBoxes = preload("res://fighting/presentation/training_boxes.gd")
const DEPENDENCIES := ["res://fighting/core/simulation.gd","res://fighting/core/ai.gd","res://fighting/visuals/fighter_visual.gd","res://fighting/effects/director.gd","res://fighting/data/roster.json","res://fighting/data/rules.json"]
var router = Router.new()
var simulation
var ai
var effects
var visuals: Array = []
var roster: Dictionary = {}
var rules: Dictionary = {}
var state: Dictionary = {}
var match_config: Dictionary = {}
var world: Node3D
var camera
var layer := CanvasLayer.new()
var ui := Control.new()
var modal: PanelContainer
var hud: VBoxContainer
var bars: Array = []
var meters: Array = []
var names: Array = []
var cues: Array = []
var timer_label: Label
var phase_label: Label
var input_label: Label
var mode := "ai"
var operators: Array = ["meta","mistral"]
var stage_id := "basalt-reach"
var difficulty := 1
var paused := true
var active := false
var focused := true
var reduced_motion := false
var low_fx := false
var binding_target: Array = []
var dummy := "stand"
var training_speed := 1.0
var training_accumulator := 0.0
var frame_requests := 0
var history: Array = []
var last_inputs: Array = []
var tech_until: Array = [0,0]
var record_inputs: Array = []
var recording := false
var replay_index := -1
var recording_state: Dictionary = {}
var settings_document: Dictionary = {}
var error_text := ""
var box_display := false
var training_boxes
var fx_session_serial := 0
var fx_session_id := ""
var fx_event_floor := 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/data/roster.json"))
	if data is Dictionary: roster = data
	else: error_text = "Roster data unavailable."
	router.load_settings()
	_load_options()
	add_child(layer)
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.joy_connection_changed.connect(_device_changed)
	show_selection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		router.release_all()
		if is_instance_valid(effects): effects.set_paused(true)
		if active: call_deferred("show_pause")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true
		router.release_all()

func _input(event: InputEvent) -> void:
	router.ingest(event)
	if not binding_target.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			binding_target.clear()
			show_settings()
			get_viewport().set_input_as_handled()
			return
		if router.rebind(int(binding_target[0]),str(binding_target[1]),event.physical_keycode):
			router.save_settings()
			binding_target.clear()
			show_settings()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if active:
			if paused: resume_match()
			else: show_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and router.devices.has(event.device):
		if active:
			if paused: resume_match()
			else: show_pause()
		get_viewport().set_input_as_handled()

func _device_changed(device: int, connected: bool) -> void:
	if not connected and router.devices.has(device):
		router.unplug(device)
		if active: show_pause("Controller disconnected. Reconnect or select a device in Settings.")

func _clear_ui() -> void:
	for child: Node in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	modal = null
	hud = null

func _panel(title: String) -> VBoxContainer:
	_clear_ui()
	router.set_modal(true)
	paused = true
	if is_instance_valid(effects): effects.set_paused(true)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.04,0.055,0.96)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	modal.add_theme_stylebox_override("panel",style)
	ui.add_child(modal)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	_text(box,title,24)
	return box

func _text(parent: Node, text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _choice(parent: Node, caption: String, values: Array, selected: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _text(row,caption)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := _button(row,str(values[selected]),func(): callback.call((selected+1)%values.size()))
	button.tooltip_text = "Activate to cycle; keyboard/controller focus supported"

func show_selection() -> void:
	active = false
	_teardown_world()
	var box := _panel("OPERATOR CLASH · local fighting")
	_text(box,"Nine operators · fixed 60 Hz · best of three · native art review pending")
	_choice(box,"Mode",["Versus AI","Local two-player","Training"],["ai","local","training"].find(mode),func(i): mode = ["ai","local","training"][i]; show_selection())
	var ids: Array = []
	var operator_names: Array = []
	for profile: Dictionary in roster.get("operators",[]):
		ids.append(profile.id)
		operator_names.append(profile.name)
	for p: int in 2:
		if ids.is_empty(): continue
		var selected := maxi(0,ids.find(operators[p]))
		operators[p] = ids[selected]
		_choice(box,"Player %d operator" % (p+1),operator_names,selected,func(i): operators[p] = ids[i]; show_selection())
		var profile := _profile(str(operators[p]))
		_text(box,"%s · %d HP · walk %d mm/tick · weight %d%%" % [profile.archetype,profile.stats.hp,profile.stats.walk_speed,profile.stats.weight],14)
	var stage_names: Array = []
	var stage_index := 0
	var available: Array = Stages.available()
	for i: int in available.size():
		stage_names.append(available[i].name)
		if available[i].id == stage_id: stage_index = i
	if not available.is_empty():
		stage_id = available[stage_index].id
		_choice(box,"Stage candidate",stage_names,stage_index,func(i): stage_id = available[i].id; show_selection())
	_choice(box,"AI difficulty",["Easy","Standard","Hard"],difficulty,func(i): difficulty = i; show_selection())
	for p: int in 2:
		device_choice(box,p,show_selection)
	_text(box,"Guard is independent. Back + Grab = back throw. Special + Grab = signature 3. DeepSeek: hold back 36 ticks (0.6s) before Special. Grok: hold down 18 ticks (0.3s) before Mobility.")
	for p: int in 2:
		_text(box,"P%d · L %s / M %s / H %s · Special %s · Mobility %s · Grab %s · Guard %s" % [p+1,router.label(p,"L"),router.label(p,"M"),router.label(p,"H"),router.label(p,"Special"),router.label(p,"Mobility"),router.label(p,"Grab"),router.label(p,"Guard")],14)
	if not error_text.is_empty(): _text(box,error_text)
	_button(box,"Start match",start_match).grab_focus()
	_button(box,"Bindings & fighting Settings",show_settings)
	_button(box,"Home",go_home)

func device_choice(box: Node, p: int, refresh: Callable) -> void:
	var devices: Array = [-1]
	var labels: Array = ["Keyboard %d" % (p+1)]
	for id: int in Input.get_connected_joypads():
		devices.append(id)
		labels.append("Pad %d · %s" % [id,Input.get_joy_name(id)])
	var selected := maxi(0,devices.find(router.devices[p]))
	_choice(box,"Player %d device" % (p+1),labels,selected,func(i):
		if not router.assign(p,devices[i]): error_text = "Each controller belongs to exactly one player."
		else: error_text = ""
		refresh.call())

func start_match() -> void:
	error_text = ""
	for path: String in DEPENDENCIES:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			error_text = "Required production dependency missing: " + path
			show_selection()
			return
	for name: String in ["catalog.json","manifest.json"]:
		var path := "res://fighting/assets/effects/" + name
		if not FileAccess.file_exists(path):
			error_text = "Required production FX asset missing: " + path
			show_selection()
			return
	var fx_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fighting/assets/effects/manifest.json"))
	if not fx_manifest is Dictionary or not fx_manifest.get("files",[]) is Array or fx_manifest.get("files",[]).is_empty():
		error_text = "Production FX manifest is unavailable or invalid."
		show_selection()
		return
	for entry: Dictionary in fx_manifest.files:
		var path := "res://fighting/assets/effects/" + str(entry.get("file",""))
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			error_text = "Required production fighting sound missing: " + path
			show_selection()
			return
	if not Stages.available().any(func(item): return item.id == stage_id):
		error_text = "Selected stage dependency is unavailable."
		show_selection()
		return
	roster = JSON.parse_string(FileAccess.get_file_as_string(DEPENDENCIES[4]))
	rules = JSON.parse_string(FileAccess.get_file_as_string(DEPENDENCIES[5]))
	simulation = load(DEPENDENCIES[0]).new()
	simulation.configure(roster,rules)
	ai = load(DEPENDENCIES[1]).new()
	ai.configure(73117,difficulty)
	match_config = {"operators":operators.duplicate(),"stage_id":stage_id,"seed":73117,"training":mode == "training"}
	simulation.start_match(match_config)
	_teardown_world()
	world = Node3D.new()
	world.name = "MatchPresentation"
	add_child(world)
	var stage := Backdrop.new()
	world.add_child(stage)
	if not stage.build(stage_id):
		error_text = "Stage source/hash/build gate failed: " + stage_id
		show_selection()
		return
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("354951")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b5c6cf")
	env.ambient_light_energy = 0.65
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 0.9
	light.shadow_enabled = false
	world.add_child(light)
	camera = Camera.new()
	camera.current = true
	camera.reduced_motion = reduced_motion
	world.add_child(camera)
	training_boxes = TrainingBoxes.new()
	world.add_child(training_boxes)
	for p: int in 2:
		var visual = load(DEPENDENCIES[2]).new()
		world.add_child(visual)
		if not visual.configure(str(operators[p])):
			error_text = "Production fighter asset unavailable: " + str(operators[p])
			show_selection()
			return
		visuals.append(visual)
	effects = load(DEPENDENCIES[3]).new()
	world.add_child(effects)
	fx_session_serial += 1
	fx_session_id = "match-%d" % fx_session_serial
	effects.configure(_fx_options())
	effects.set_paused(true)
	state = simulation.snapshot()
	fx_event_floor = int(state.tick)
	_present_snapshot_effects()
	history.clear()
	record_inputs.clear()
	recording = false
	replay_index = -1
	tech_until = [0,0]
	training_accumulator = 0.0
	frame_requests = 0
	active = true
	resume_match()

func _teardown_world() -> void:
	if is_instance_valid(effects): effects.reset()
	effects = null
	visuals.clear()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	camera = null
	training_boxes = null

func _physics_process(_delta: float) -> void:
	if not active or not focused: return
	if paused:
		if mode == "training" and frame_requests > 0:
			frame_requests -= 1
			_tick()
			if paused: show_training()
		return
	if mode == "training":
		training_accumulator += training_speed
		if training_accumulator < 1.0: return
		training_accumulator -= 1.0
	_tick()

func _tick() -> void:
	var commands: Array = [router.command(0),router.command(1)]
	if mode == "ai": commands[1] = ai.command(state,1)
	elif mode == "training": commands[1] = _dummy_command()
	if replay_index >= 0:
		if replay_index >= record_inputs.size():
			replay_index = -1
			show_training()
			return
		commands = record_inputs[replay_index].duplicate(true)
		replay_index += 1
	if recording: record_inputs.append(commands.duplicate(true))
	last_inputs = commands.duplicate(true)
	history.append(last_inputs)
	if history.size() > 12: history.pop_front()
	var old_round := int(state.round_index)
	state = simulation.step(commands)
	if int(state.round_index) != old_round:
		effects.reset()
		fx_event_floor = int(state.tick)
		tech_until = [0,0]
		for visual in visuals: visual.reset()
	for event: Dictionary in state.events:
		if int(event.tick) < fx_event_floor: continue
		if str(event.type) in ["throw_start","throw_capture","throw_attempt"] and int(event.target) in [0,1]: tech_until[int(event.target)] = int(event.tick)+10
	_present_snapshot_effects()
	_update_hud()
	if str(state.phase) == "match_over": show_results()

func _dummy_command() -> Dictionary:
	if dummy == "cpu": return ai.command(state,1)
	var tech_press := dummy == "tech" and int(state.tick)%12 == 0
	var mask := 64 if dummy in ["guard","crouch guard"] else 32 if tech_press else 0
	# Tech dummy taps through the same recognizer, never writes a throw result.
	return {"axis_x":0,"axis_y":-1 if dummy in ["crouch","crouch guard"] else 0,"held":mask,"pressed":32 if tech_press else 0}

func _fx_options() -> Dictionary:
	return {"reduced_motion":reduced_motion,"quality":"low" if low_fx else "high","session_id":fx_session_id}

func _present_snapshot_effects(with_events: bool = true) -> void:
	if not is_instance_valid(effects) or state.is_empty(): return
	if with_events:
		var fresh: Array = state.events.filter(func(event): return int(event.tick) >= fx_event_floor)
		effects.consume(fresh,state.fighters)
	# Snapshot presence owns flight, reflection form, clash and despawn removal.
	effects.present_projectiles(state.projectiles,state.fighters)

func _process(delta: float) -> void:
	if not active or state.is_empty() or not is_instance_valid(camera): return
	for p: int in visuals.size():
		visuals[p].present(state.fighters[p],0.0)
		effects.present_fighter(state.fighters[p],visuals[p])
	camera.present(state.fighters,get_viewport().get_visible_rect().size)
	training_boxes.visible = mode == "training" and box_display
	if training_boxes.visible: training_boxes.present(state,roster)
	if not paused and focused: effects.advance(delta)

func resume_match() -> void:
	if not active or not focused: return
	if str(state.get("phase","")) == "match_over":
		show_results()
		return
	for device: int in router.devices:
		if device >= 0 and not Input.get_connected_joypads().has(device):
			show_pause("Assigned controller is disconnected.")
			return
	_clear_ui()
	binding_target.clear()
	router.set_modal(false)
	paused = false
	effects.set_paused(false)
	_build_hud()
	_update_hud()

func _build_hud() -> void:
	var backing := ColorRect.new()
	backing.color = Color(0.02,0.03,0.04,0.86)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	backing.offset_bottom = 155
	ui.add_child(backing)
	hud = VBoxContainer.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 12
	hud.offset_right = -12
	hud.offset_top = 8
	ui.add_child(hud)
	bars.clear(); meters.clear(); names.clear(); cues.clear()
	var row := HBoxContainer.new()
	hud.add_child(row)
	for p: int in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		names.append(_text(column,"",16))
		var health := ProgressBar.new()
		health.custom_minimum_size.y = 18
		health.show_percentage = false
		column.add_child(health)
		bars.append(health)
		var meter := ProgressBar.new()
		meter.max_value = 1000
		meter.custom_minimum_size.y = 8
		meter.show_percentage = false
		column.add_child(meter)
		meters.append(meter)
		cues.append(_text(column,"",14))
	timer_label = _text(hud,"",18)
	phase_label = _text(hud,"",18)
	input_label = Label.new()
	input_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	input_label.offset_top = -70
	input_label.offset_bottom = -6
	input_label.offset_left = 12
	input_label.offset_right = -12
	input_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	input_label.add_theme_font_size_override("font_size",14)
	ui.add_child(input_label)

func _profile(id: String) -> Dictionary:
	for item: Dictionary in roster.get("operators",[]):
		if item.id == id: return item
	return {}

func _update_hud() -> void:
	if hud == null or state.is_empty(): return
	for p: int in 2:
		var fighter: Dictionary = state.fighters[p]
		var profile := _profile(str(fighter.operator_id))
		bars[p].max_value = int(profile.get("stats",{}).get("hp",1000))
		bars[p].value = fighter.hp
		meters[p].value = fighter.meter
		names[p].text = "P%d %s · %d/%d HP · %d wins" % [p+1,profile.get("name",fighter.operator_id),fighter.hp,bars[p].max_value,state.wins[p]]
		var guard := "LOW GUARD" if str(fighter.state) in ["guard_lo","block_lo"] else "GUARD" if "guard" in str(fighter.state) or "block" in str(fighter.state) else ""
		var tech := "GRAB: TECH NOW" if int(fighter.get("throw_tech_frames_left",0)) > 0 or int(state.tick) < tech_until[p] else ""
		var resource: Dictionary = profile.get("resource",{})
		var resource_label := "%s %s" % [resource.get("id",""),str(fighter.resources.get(resource.get("id",""),"—"))]
		cues[p].text = "%s %s · %d hits / %d dmg · %s" % [guard,tech,fighter.combo_hits,fighter.combo_damage,resource_label]
	timer_label.text = "Round %d · %02d" % [int(state.round_index)+1,ceili(float(state.round_ticks_left)/60.0)]
	phase_label.text = str(state.phase).replace("_"," ").to_upper()
	var text := "Esc / Start: pause"
	for p: int in 2:
		if last_inputs.size() == 2: text += "  P%d %s" % [p+1,_command_label(last_inputs[p])]
	if mode == "training": text = "TRAINING %.2fx · dummy %s · frame %d · advantage %s\n%s" % [training_speed,dummy,state.tick,str(state.get("frame_advantage","—")),text]
	input_label.text = text

func _command_label(command: Dictionary) -> String:
	var text := "←" if int(command.axis_x) < 0 else "→" if int(command.axis_x) > 0 else "·"
	text += "↑" if int(command.axis_y) > 0 else "↓" if int(command.axis_y) < 0 else "·"
	for action: String in Router.BITS:
		if (int(command.held) & int(Router.BITS[action])) != 0: text += " " + action + ("*" if (int(command.pressed) & int(Router.BITS[action])) != 0 else "")
	return text

func show_pause(message: String = "") -> void:
	if not active: return
	var box := _panel("Paused")
	if not message.is_empty(): _text(box,message)
	_button(box,"Resume",resume_match).grab_focus()
	_button(box,"Move list",show_moves)
	if mode == "training": _button(box,"Training controls",show_training)
	_button(box,"Fighting Settings & bindings",show_settings)
	_button(box,"Rematch",start_match)
	_button(box,"Character select",show_selection)
	_button(box,"Home",go_home)

func show_moves() -> void:
	var box := _panel("Move list · " + str(operators[0]))
	_text(box,"L / M / H normals: stand, down for crouch, airborne for air. Special = signature 1; Mobility = signature 2; Special + Grab = signature 3. Grab = normal throw / tech; Back+Grab = back throw. Super costs 1000 meter. Facing mirrors motions. DeepSeek holds back 36 ticks even for Simple S1; Grok holds down 18 ticks for S2.")
	for p: int in 2:
		var profile := _profile(str(operators[p]))
		_text(box,"P%d · %s" % [p+1,profile.get("name",operators[p])],20)
		for id: String in profile.get("moves",{}):
			var move: Dictionary = profile.moves[id]
			var command: Dictionary = move.get("input",{})
			_text(box,"%s · %s · %s / %s · %s · %d/%d/%d frames · %d damage" % [id,move.name,command.get("simple",""),command.get("motion",""),move.level,move.startup,move.active,move.recovery,move.damage])
			_text(box,str(move.get("description","")) + " Counterplay: " + str(move.get("counterplay","")),14)
		_text(box,"Proposed learning routes · pending actual core combo verification",18)
		for combo: Dictionary in profile.get("combos",[]): _text(box,"%s (%s): %s — %s" % [combo.name,combo.get("status","proposed"),JSON.stringify(combo.get("route",[])),combo.notes])
	_button(box,"Back",show_pause).grab_focus()

func show_training() -> void:
	if mode != "training": return
	var box := _panel("TRAINING · labelled practice controls")
	var modes := ["stand","crouch","guard","crouch guard","tech","cpu"]
	_choice(box,"Dummy",modes,modes.find(dummy),func(i): dummy = modes[i]; show_training())
	_choice(box,"Training speed",["25%","50%","100%"],[0.25,0.5,1.0].find(training_speed),func(i): training_speed = [0.25,0.5,1.0][i]; show_training())
	_choice(box,"Box display",["Off","Authored attack envelopes"],int(box_display),func(i): box_display = bool(i); show_training())
	_text(box,"Orange: authored active attack envelope. Hurt/push boxes and frame advantage require optional core snapshot fields; unavailable values remain blank.")
	_text(box,"Frame %d · hit/combo/guard information remains visible on resume. Frame advance executes one core step with neutral human input while this modal is open." % int(state.get("tick",0)))
	_button(box,"Advance one frame",func(): frame_requests += 1)
	_button(box,"Reset training match",start_match)
	_button(box,"Stop recording" if recording else "Record inputs from this state",func():
		if recording: recording = false
		else:
			recording_state = simulation.save_state()
			record_inputs.clear()
			recording = true
		resume_match())
	_button(box,"Replay recorded inputs",func():
		if record_inputs.is_empty(): return
		recording = false
		simulation.load_state(recording_state)
		state = simulation.snapshot()
		effects.reset()
		fx_event_floor = int(state.tick)+1
		tech_until = [0,0]
		for visual in visuals: visual.reset()
		_present_snapshot_effects(false)
		replay_index = 0
		resume_match())
	_text(box,"Input history (last 12 ticks): " + JSON.stringify(history),14)
	_button(box,"Back",show_pause).grab_focus()

func show_settings() -> void:
	var box := _panel("Fighting Settings · mode-local")
	_choice(box,"Reduced motion",["Off","On"],int(reduced_motion),func(i): reduced_motion = bool(i); _save_options(); show_settings())
	_choice(box,"FX budget",["High","Low"],int(low_fx),func(i): low_fx = bool(i); _save_options(); show_settings())
	for p: int in 2:
		device_choice(box,p,show_settings)
		_text(box,"Player %d keyboard · activate a binding then press a physical key" % (p+1))
		for action: String in Router.ACTIONS:
			_button(box,"P%d %s: %s" % [p+1,action,router.label(p,action)],func(): binding_target = [p,action]; _text(box,"Press a new key. Reserved/duplicate keys are rejected; Esc returns."))
	_text(box,"Controller: X/Square light, Y/Triangle medium, B/Circle heavy, A/Cross special, R1 mobility, L1 grab, L3 guard, R3 dash, L1+R1 super; D-pad/left stick movement. Special+Grab selects signature 3. Deadzone %.2f." % router.deadzone)
	_choice(box,"Stick deadzone",["0.20","0.28","0.40"],[0.20,0.28,0.40].find(router.deadzone) if router.deadzone in [0.20,0.28,0.40] else 1,func(i): router.deadzone = [0.20,0.28,0.40][i]; router.save_settings(); show_settings())
	_button(box,"Back",show_pause if active else show_selection).grab_focus()

func show_results() -> void:
	var box := _panel("Match complete")
	_text(box,"Draw" if int(state.winner) < 0 else "Player %d wins" % (int(state.winner)+1),24)
	_text(box,"Rounds %d : %d" % [state.wins[0],state.wins[1]])
	_button(box,"Rematch",start_match).grab_focus()
	_button(box,"Character select",show_selection)
	_button(box,"Home",go_home)

func _load_options() -> void:
	if not FileAccess.file_exists("user://fighting/settings.json"): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://fighting/settings.json"))
	if value is Dictionary:
		settings_document = value
		reduced_motion = bool(value.get("reduced_motion",false))
		low_fx = bool(value.get("low_fx",false))

func _save_options() -> void:
	settings_document["reduced_motion"] = reduced_motion
	settings_document["low_fx"] = low_fx
	DirAccess.make_dir_recursive_absolute("user://fighting")
	var file := FileAccess.open("user://fighting/settings.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(settings_document,"\t"))
	if is_instance_valid(camera): camera.reduced_motion = reduced_motion
	if is_instance_valid(effects):
		# Explicit Settings changes rebuild the pool once. Never configure in
		# render/snapshot loops or replay pre-settings contact/audio events.
		effects.configure(_fx_options())
		effects.set_paused(paused or not focused)
		fx_event_floor = int(state.tick)+1
		_present_snapshot_effects(false)

func go_home() -> void:
	active = false
	router.set_modal(true)
	_teardown_world()
	simulation = null
	ai = null
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
