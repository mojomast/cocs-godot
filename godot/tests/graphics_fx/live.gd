extends SceneTree

# Private staging integration around unchanged shipped Horde composition.
# Only ordinary native Input events control play. No source/snapshot writes.
const FX = preload("res://graphics_fx/moth_world.gd")
const Fixtures = preload("res://tests/graphics_fx/fixture_library.gd")
var session: Node
var fx: Node3D
var rows: Array = []
var latest_actors: Array = []
var snapshots := 0
var saved := false
var output: String

func _initialize() -> void:
	output = OS.get_environment("MOTH_VFX_EVIDENCE")
	call_deferred("run")

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(600,400)
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func consume(items: Array) -> void:
	if session.phase != 3: return
	for event: Dictionary in items:
		var before: int = fx.spawned
		fx.consume([event],session.client.actor_id,latest_actors)
		if fx.spawned > before:
			var positions: Array = []
			for slot: Dictionary in fx.slots:
				if slot.event_id == event.id:
					var pos: Vector3 = slot.node.position
					positions.append([pos.x,pos.y,pos.z])
			rows.append({"id":event.id,"sourceId":event.get("sourceId"),"type":event.type,"event":event,"spawned":fx.spawned-before,"positions":positions})
	var total: int = fx.spawned
	fx.consume(items,session.client.actor_id,latest_actors)
	if fx.spawned != total:
		push_error("live retained replay spawned twice")
		quit(2)

func run() -> void:
	session = load("res://horde/demo.gd").new()
	root.add_child(session)
	fx = FX.new()
	session.add_child(fx)
	fx.configure_resources(Fixtures.resources())
	session.client.started.connect(func(_frame: Dictionary) -> void: fx.reset(); latest_actors.clear())
	session.client.snapshot.connect(func(frame: Dictionary) -> void: latest_actors = frame.state.get("actors",[]); snapshots += 1)
	session.client.events.connect(consume)
	var deadline := Time.get_ticks_msec() + 45000
	while not session.received_pose:
		await process_frame
		if Time.get_ticks_msec() > deadline:
			push_error("Live Horde start deadline")
			quit(2)
			return
	button(true)
	button(false)
	var start := Time.get_ticks_msec()
	var last_grenade := -5000
	while Time.get_ticks_msec() - start < 22000:
		await process_frame
		var age := Time.get_ticks_msec() - start
		if session.can_capture_pointer() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			button(false)
			button(true)
		button(true)
		# Throw ordinary source grenades. Ground blasts provide reliable real events
		# without mutating equipment, actors, health, damage, clock or protocol.
		if age - last_grenade > 5000:
			key(KEY_G,true)
			last_grenade = age
		elif age - last_grenade > 150: key(KEY_G,false)
		if not saved:
			for slot: Dictionary in fx.slots:
				if slot.remaining <= 0 or slot.key != "effect-explosion": continue
				if session.camera.is_position_behind(slot.node.position): continue
				var pixel: Vector2 = session.camera.unproject_position(slot.node.position)
				if not Rect2(Vector2(100,150),root.size - Vector2i(200,220)).has_point(pixel): continue
				await RenderingServer.frame_post_draw
				saved = root.get_texture().get_image().save_png(output.path_join("live-horde.png")) == OK
				break
	button(false)
	key(KEY_G,false)
	var ok: bool = rows.size() > 0 and snapshots > 100 and session.client.last_ack > 100
	var report := {"normal_rate":true,"state_injection":false,"private_staging_integration":true,"fixture_textures":true,
		"map":session.current_id,"snapshots":snapshots,"ack":session.client.last_ack,"wall_ms":Time.get_ticks_msec()-start,
		"spawned":fx.spawned,"overflow":fx.overflow,"saved":saved,"events":rows,"ok":ok}
	var file := FileAccess.open(output.path_join("live-client.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	print("MOTH_VFX_LIVE ",JSON.stringify(report))
	session.client.disconnect_server()
	fx.reset()
	await create_timer(0.5).timeout
	quit(0 if ok else 2)
