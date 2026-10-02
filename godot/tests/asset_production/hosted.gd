extends "res://tests/new_maps/gravemill_foundry/journey.gd"
## Two actual production native transports; input dictionaries use send_input.
## The parent fixture handles presentation/captures, never actor pose writes.
var shutdown_pending := false

func _process(delta: float) -> void:
	# Results put the inherited driver in phase 4, so quit must be read here,
	# outside its phase-3-only input sampling. Also works during failed startup.
	if shutdown_pending: return
	if not controls_path.is_empty() and FileAccess.file_exists(controls_path):
		var command: Variant = JSON.parse_string(FileAccess.get_file_as_string(controls_path))
		if command is Dictionary and command.get("quit", false):
			shutdown_pending = true
			shutdown_fixture.call_deferred()
			return
	super._process(delta)

func shutdown_fixture() -> void:
	# Drain an in-flight viewport capture before releasing its scene resources.
	while capture_busy:
		await get_tree().process_frame
	client.disconnect_server()
	print("CANDIDATE_TEARDOWN_READY ", JSON.stringify({"role":role,"phase":phase,"hash":expected_hash}))
	get_tree().quit(0)

func _init() -> void:
	catalog = preload("res://tests/asset_production/candidate_catalog.gd").new()

func on_lobby(frame: Dictionary) -> void:
	if phase == 10:
		phase = 11
		return
	if phase == 1:
		client.send_frame({"type":"host","mapId":current_id,"config":{"mode":selected_mode,"botCount":0,"timeLimit":900,"fragLimit":3 if selected_mode in ["deathmatch","teamdeathmatch"] else 1,"startingWeapon":2,"unlimitedAmmo":true}})
		phase = 2
		return
	if phase == 2 and frame.get("players",[]).size() < 2: return
	# Bypass foundry's configuration only, retain ordinary lobby/start lifecycle.
	if phase == 2 and join_room_id.is_empty():
		client.send_frame({"type":"start"})
		phase = 20

func on_results(frame: Dictionary) -> void:
	print("CANDIDATE_RESULTS ",JSON.stringify({"role":role,"hash":expected_hash,"mode":selected_mode,"sent":sent,"ack":client.last_ack,"state":frame.state}))
	super.on_results(frame)
