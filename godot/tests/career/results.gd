extends SceneTree
## Pure projection + service behaviour for the source RESULTS / award lane.
## Uses genuine source frame shapes (server/room.mjs, server/progression.mjs) and
## a seated probe connection; no fabricated identity or local balance authority.
const ResultsModel = preload("res://career/results_model.gd")
const Client = preload("res://net/client.gd")
var failed := false

class Probe extends Client:
	func career_wire_open() -> bool: return true
	func send_frame(_frame: Dictionary) -> Error: return OK

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("career results: " + label)

func state(frags: int = 3, deaths: int = 1) -> Dictionary:
	return {"mapId":"crosswire", "config":{"mode":"deathmatch"}, "overReason":"time", "time":60.4,
		"actors":[{"id":0,"frags":frags,"deaths":deaths},{"id":1,"frags":5,"deaths":0}]}

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	client.actor_id = 0
	# --- pure projection -----------------------------------------------------
	check(ResultsModel.project(null, 0, "k", false).is_empty(), "non-dictionary state invalid")
	check(ResultsModel.project({"foo":1}, 0, "k", false).is_empty(), "no usable facts invalid")
	check(ResultsModel.number(true) == null and ResultsModel.nonneg(-1) == null, "booleans and negatives are not counts")
	var projected := ResultsModel.project(state(), 0, "room-a:3", false)
	check(projected.get("mode") == "deathmatch", "mode from source config")
	check(projected.get("map") == "crosswire", "map from source mapId")
	check(projected.get("ending") == "time", "ending from source overReason")
	check(projected.get("frags") == 3 and projected.get("deaths") == 1, "own actor stats located by actor id")
	check(projected.get("time") == 60, "elapsed truncated to known integer")
	var other := ResultsModel.project(state(), 5, "k", false)
	check(not other.has("frags") and not other.has("deaths"), "own stats unknown when actor absent")
	var missing := ResultsModel.project({"mapId":"m","config":{"mode":"dm"},"actors":[{"id":0,"deaths":2}]}, 0, "k", false)
	check(not missing.has("frags") and missing.get("deaths") == 2, "unknown frags omitted, never zero")
	# --- award vs equipment --------------------------------------------------
	check(not ResultsModel.is_award({"type":"progression","gear":{},"attachments":{}}), "gear reply is not an award")
	check(not ResultsModel.is_award({"type":"progression","gear":{},"attachments":{},"gained":5}), "equipment shape wins over a stray field")
	check(ResultsModel.is_award({"type":"progression","profile":{"id":"x"},"gained":0}), "zero gained is a real award")
	check(ResultsModel.project_award({"type":"progression","gear":{},"attachments":{}}).is_empty(), "no award projection from equipment")
	var award := ResultsModel.project_award({"type":"progression","profile":{"id":"x"},"gained":42,"baseGained":30,"prestigeBonus":2,"achievementXp":10,"levelUp":true,"progress":0.5,"toNext":120,"mode":"deathmatch","unlocked":[{"id":"gear-scope","name":"Precision Scope","level":2},{"bad":true}],"achievements":[{"id":"first-blood","name":"First Blood","xp":100}]})
	check(award.get("gained") == 42 and award.get("levelUp") == true, "award scalars projected")
	check(award.get("unlocked").size() == 1 and award.get("achievements").size() == 1, "malformed reward entries dropped")
	# --- service: award arrives before results (authoritative order) ---------
	var raw := {"id":"player-one","level":4,"xp":10,"unlocks":{},"gear":{},"attachments":{}}
	service.receive(client, {"type":"welcome","profile":raw})
	check(service.profile.get("id") == "player-one", "welcome binds the seated profile")
	service.receive(client, {"type":"start","roundRevision":3,"mapId":"crosswire"})
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":42,"baseGained":42,"mode":"deathmatch"})
	check(service.latest_award.get("gained") == 42, "award recorded before any result")
	service.receive(client, {"type":"results","state":state()})
	check(service.results_status == "complete" and service.result.get("mode") == "deathmatch", "accepted result stored")
	check(service.attributed_award().get("gained") == 42, "same-round award attributed once")
	# duplicate result: same round key, same witnessed award, no new claim
	service.receive(client, {"type":"results","state":state()})
	check(service.result.get("replayed") == true, "duplicate result flagged replayed")
	check(service.attributed_award().get("gained") == 42, "duplicate keeps one witnessed award")
	# --- possible late award inside the same active round -------------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":4,"mapId":"crosswire"})
	service.receive(client, {"type":"results","state":state(2, 2)})
	check(service.attributed_award().is_empty(), "no award yet for the active round")
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":7,"baseGained":7})
	check(service.attributed_award().get("gained") == 7, "late same-round award correlated by round key")
	# --- reconnect: replayed result claims no award -------------------------
	service.receive(client, {"type":"welcome","profile":raw})
	check(service.latest_award.is_empty(), "welcome clears the previous award")
	service.receive(client, {"type":"results","state":state()})
	check(service.result.get("reconnect") == true, "result without a start is a reconnect replay")
	check(service.attributed_award().is_empty(), "replayed result claims no award")
	# --- spectator: no own stats and no award -------------------------------
	client.actor_id = -1
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":9,"mapId":"crosswire"})
	service.receive(client, {"type":"results","state":state()})
	check(not service.result.has("frags") and not service.result.has("deaths"), "spectator own stats unknown")
	check(service.attributed_award().is_empty(), "spectator claims no award")
	# --- foreign identity award rejected ------------------------------------
	client.actor_id = 0
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"progression","profile":{"id":"player-two","xp":1},"gained":99,"baseGained":99})
	check(service.latest_award.is_empty() and service.attributed_award().is_empty(), "foreign identity award rejected")
	# --- no credential or profile identity serialized -----------------------
	var dump := JSON.stringify({"result":service.result,"award":service.latest_award})
	check(not dump.contains("ownerToken") and not dump.contains("progressToken"), "no credential keys in the projection")
	check(not dump.contains("player-one") and not dump.contains("player-two"), "no profile identity in the projection")
	# --- disconnect clears the endpoints ------------------------------------
	service.clear_connection(client)
	check(service.result.is_empty() and service.results_status == "none", "disconnect clears the accepted result")
	check(service.latest_award.is_empty() and service.attributed_award().is_empty(), "disconnect clears the award")
	client.queue_free()
	print("CAREER_RESULTS_OK")
	quit(1 if failed else 0)
