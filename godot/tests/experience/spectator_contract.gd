extends SceneTree
const Model = preload("res://experience/spectator_model.gd")
const Feed = preload("res://experience/kill_feed.gd")
const Events = preload("res://experience/spectator_events.gd")
const Info = preload("res://experience/player_info.gd")
const FreeMotion = preload("res://experience/free_camera_math.gd")
var checks := 0
var failures := 0

class Peer extends Node:
	signal snapshot(frame: Dictionary)
	signal events(items: Array)
	signal started(frame: Dictionary)
	signal results(frame: Dictionary)
	signal connection_error(message: String)
	signal lobby(frame: Dictionary)
	var actor_id := 0
	var spectating := false

class Independent extends Node:
	var phase := "active"
	var net := Peer.new()
	var age := 0.0
	func _init() -> void: add_child(net)

class Shared extends Node:
	var phase := 3
	var client := Peer.new()
	func _init() -> void: add_child(client)

class TestInfo extends Info:
	var obstructed := false
	var expired := false
	func blocked() -> bool: return obstructed
	func stale() -> bool: return expired
	func _process(_delta: float) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SPECTATOR_CONTRACT_FAIL " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experience/spectator_fixture.json"))
	var model := Model.new()
	for vector: Dictionary in fixture.motion:
		var result := FreeMotion.integrate(Vector3(vector.pose.x, vector.pose.y, vector.pose.z), Vector3(vector.velocity.x, vector.velocity.y, vector.velocity.z), vector.pose.yaw, vector.pose.pitch, Vector3(vector.input.forward, vector.input.right, vector.input.up), vector.input.boost, vector.dt)
		check(result.position.distance_to(Vector3(vector.expected.pose.x, vector.expected.pose.y, vector.expected.pose.z)) < 0.00001, "source free-camera pose")
		check(result.velocity.distance_to(Vector3(vector.expected.velocity.x, vector.expected.velocity.y, vector.expected.velocity.z)) < 0.00001, "source free-camera velocity")
	for vector: Dictionary in fixture.selection:
		model.target_id = vector.target
		model.snapshot({"actors":vector.actors})
		check(model.target().get("id") == vector.expected, "source target fallback " + JSON.stringify(vector))
		model.target_id = vector.target
		model.cycle(1)
		check(model.target_id == vector.next, "source forward cycle")
		model.target_id = vector.target
		model.cycle(-1)
		check(model.target_id == vector.previous, "source backward cycle")
	for vector: Dictionary in fixture.assist:
		check(Feed.assist_credit(vector.marks, vector.victim, vector.time) == vector.expected, "source five-second assist boundary")
	for vector: Dictionary in fixture.visibility:
		if vector.team == null: check(Events.public_event(vector.event) == vector.expected, "source spectator event visibility " + str(vector.event.type))
	model.snapshot(fixture.publicSnapshot)
	var projected := JSON.stringify(model.actors)
	check(not projected.contains("req") and not projected.contains("cooldown") and not projected.contains("weapon") and not projected.contains("intel"), "target projection contains only public camera/board fields")
	model.snapshot({"actors":[{"id":0,"health":100,"x":1,"y":2,"z":3,"ability":"PRIVATE","req":777,"orders":{"text":"PRIVATE"}}],"cocs":{"intel":"PRIVATE"}})
	check(not JSON.stringify(model.actors).contains("PRIVATE"), "full-context injection cannot become target HUD context")
	var state := {"time":10,"actors":[{"id":0,"name":"Local","health":100},{"id":1,"name":"Victim","health":100}],"feed":[{"killer":"Other","victim":"Victim","time":10,"weapon":1}]}
	var events := [{"id":1,"type":"damage","source":0,"actor":1,"amount":5,"time":9},{"id":2,"type":"death","killer":2,"actor":1,"overkill":55,"time":10}]
	var feed := Feed.new()
	feed.snapshot(state, 0)
	feed.events(events)
	check(feed.text().contains("ASSIST") and feed.text().contains("OVERKILL"), "source-backed same-batch assist and overkill")
	feed.events(events)
	check(feed.metadata.size() == 1, "duplicate numeric wire events cannot re-credit")
	feed.snapshot(state, null)
	feed.events(events)
	check(not feed.text().contains("ASSIST") and feed.marks.is_empty(), "spectator has no personal assist marks")
	feed.clear()
	feed.snapshot(state, 0)
	var strings := events.duplicate(true)
	strings[0].id = "damage-a"
	strings[1].id = "death-b"
	feed.events(strings)
	feed.events(strings)
	check(feed.metadata.size() == 1 and feed.text().contains("ASSIST"), "string event identities accepted and deduplicated")
	feed.snapshot({"time":1,"actors":state.actors,"feed":[]}, 0)
	check(feed.marks.is_empty() and feed.metadata.is_empty() and feed.seen.is_empty(), "backwards source clock clears event epoch")
	for independent: bool in [false, true]:
		var session: Node = Independent.new() if independent else Shared.new()
		var peer: Node = session.net if independent else session.client
		root.add_child(session)
		var info := TestInfo.new()
		root.add_child(info)
		info.bind_session(session)
		peer.snapshot.emit({"state":state})
		peer.events.emit([{"type":"damage","actor":0,"source":1,"amount":20}])
		check(info.combat.hits.size() == 1, "actor receives local recap before handoff")
		peer.spectating = true
		# Deliberately omit lobby: an old queued event must invalidate the seat.
		peer.events.emit(events)
		check(not info.ready_for_events and info.combat.hits.is_empty() and info.gameplay_model.is_empty() and info.public_feed.marks.is_empty(), "event-first seat transition drops old local context")
		peer.snapshot.emit({"state":state})
		peer.events.emit(events)
		check(info.spectator_camera.model.target_id == 0 and info.combat.hits.is_empty() and not info.public_feed.text().contains("ASSIST"), "public target never becomes local actor")
		info.spectator_camera.held[KEY_W] = true
		info.obstructed = true
		info.spectator_camera._process(0.016)
		check(info.spectator_camera.held.is_empty() and info.spectator_camera.model.actors.is_empty(), "modal/focus clears camera input and target projection")
		info.obstructed = false
		peer.snapshot.emit({"state":state})
		info.expired = true
		info.spectator_camera._process(0.016)
		check(info.spectator_camera.model.actors.is_empty(), "stale camera cannot retain target")
		info.expired = false
		peer.spectating = false
		peer.actor_id = 1
		peer.lobby.emit({})
		check(not info.ready_for_events and info.spectator_camera.model.target_id == null, "spectator-to-player handoff awaits new authoritative snapshot")
		peer.snapshot.emit({"state":state})
		peer.results.emit({})
		check(info.public_feed.rows.is_empty() and info.combat.hits.is_empty(), "results clear both contexts")
		peer.started.emit({})
		check(not info.ready_for_events, "restart awaits snapshot")
		info.unbind()
		info.free()
		session.free()
	print("SPECTATOR_CONTRACT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
