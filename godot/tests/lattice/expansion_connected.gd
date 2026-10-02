extends SceneTree
## Three separate native processes use ordinary transports. Protocol/feedback
## evidence only: this does not stand in for graphical input or layout review.
const Transport = preload("res://lattice/world_transport.gd")
const Feedback = preload("res://lattice/world_feedback.gd")
var client := Transport.new()
var role := "host"
var room := ""
var checks := 0
var failed := false

func check(ok: bool, message: String) -> bool:
	checks += 1
	print("EXPANSION_CHECK ", JSON.stringify({"role":role,"ok":ok,"message":message}))
	if not ok: failed = true
	return ok

func wait_for(condition: Callable, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while not condition.call() and client.error.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check(condition.call(), message + (" " + client.error if not client.error.is_empty() else ""))

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var endpoint := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--endpoint="): endpoint = arg.trim_prefix("--endpoint=")
		elif arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		elif arg.begins_with("--room="): room = arg.trim_prefix("--room=")
	root.add_child(client)
	client.mode = "cocs"
	check(client.connect_server(endpoint, {"tern-archipelago":{"modes":["cocs","cocs-coop"]}}, "tern-archipelago") == OK, "connect queued")
	if not await wait_for(func() -> bool: return client.connection_open(), "socket open"): finish(); return
	check((client.create_room("Feedback host") if role == "host" else client.join_room(room, role)) == OK, "ordinary create/join")
	if not await wait_for(func() -> bool: return not client.room_id.is_empty(), "welcome"): finish(); return
	if role == "host":
		print("EXPANSION_ROOM ", client.room_id)
		if not await wait_for(func() -> bool: return int(client.roster_metadata.get("connected_peers", 0)) >= 2, "two native players joined"): finish(); return
		check(client.send_frame({"type":"host","mapId":"tern-archipelago","config":{"mode":"cocs","botCount":0,"timeLimit":900}}) == OK, "configure ordinary source room")
		await create_timer(0.15).timeout
		check(client.send_frame({"type":"start"}) == OK, "source start request")
	if role == "spectator":
		if not await wait_for(func() -> bool: return client.spectating and client.last_snapshot_seq >= 0, "late join is authoritative spectator"): finish(); return
		check(client.projection.is_empty(), "spectator has no player-private projection")
		check(not client.activate("hold", "front-0").is_empty() and client.actions.is_empty(), "spectator cannot queue native action")
		finish(); return
	if not await wait_for(func() -> bool: return not client.projection.is_empty(), "recipient projection"): finish(); return
	if role == "host": print("EXPANSION_LIVE")
	var target := ""
	for node: Dictionary in client.projection.nodes:
		if node.get("owner") == client.projection.team: target = str(node.id); break
	if not check(not target.is_empty(), "known own objective"): finish(); return
	check(client.activate("hold", target).is_empty(), "ordinary HOLD adapter queues")
	if not await wait_for(func() -> bool: return not client.actions.is_empty() and client.actions[-1].status != "queued", "exact source HOLD response"): finish(); return
	check(client.actions[-1].status != "rejected", "HOLD accepted")
	if role == "host":
		if not await wait_for(func() -> bool: return client.gate().is_empty() and float(client.projection.get("req", 0)) >= 200, "controlled source wallet received"): finish(); return
		check(client.activate("buy", "repair-tool").is_empty(), "repair request uses ordinary REQ adapter")
		if not await wait_for(func() -> bool: return client.actions[-1].status == "rejected", "source no-target response"): finish(); return
		check(client.actions[-1].reason == "no-target" and Feedback.receipt(client.actions, client.revision).text.contains("REFUSED"), "no-target receipt displayed without debit claim")
		if not await wait_for(func() -> bool: return client.gate().is_empty(), "repeat cooldown"): finish(); return
		check(client.activate("buy", "overshield").is_empty(), "ordinary funded BUY request")
		if not await wait_for(func() -> bool: return client.actions[-1].status == "confirmed", "exact source purchase settled"): finish(); return
		check(Feedback.receipt(client.actions, client.revision).text.contains("SETTLED"), "settled source purchase feedback")
		if not await wait_for(func() -> bool: return client.gate().is_empty(), "post-buy cooldown"): finish(); return
		var enemy_hq := "hq-%d" % (1 - int(client.projection.team))
		check(client.activate("hold", enemy_hq).is_empty(), "known enemy HQ request reaches authority")
		if not await wait_for(func() -> bool: return client.actions[-1].status == "rejected", "source rejects illegal HOLD"): finish(); return
		check(Feedback.receipt(client.actions, client.revision).text.contains("HOLD") and Feedback.receipt(client.actions, client.revision).text.contains("REFUSED"), "later HOLD refusal replaces successful BUY")
	if role == "guest": await create_timer(4.0).timeout
	finish()

func finish() -> void:
	print("EXPANSION_NATIVE_RESULT ", JSON.stringify({"role":role,"passed":not failed,"checks":checks,"actor":client.actor_id,"peer":client.peer_id,"actions":client.actions,"req":client.projection.get("req"),"feedback":Feedback.receipt(client.actions, client.revision)}))
	client.disconnect_server()
	quit(1 if failed else 0)
