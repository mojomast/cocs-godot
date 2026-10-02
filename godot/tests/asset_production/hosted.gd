extends "res://tests/new_maps/gravemill_foundry/journey.gd"
## Two actual production native transports; input dictionaries use send_input.
## The parent fixture handles presentation/captures, never actor pose writes.
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
