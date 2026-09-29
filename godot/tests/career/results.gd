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

func state(frags: Variant = 3, deaths: Variant = 1) -> Dictionary:
	return {"mapId":"crosswire", "config":{"mode":"deathmatch"}, "overReason":"time", "time":60.4,
		"actors":[{"id":0,"frags":frags,"deaths":deaths},{"id":1,"frags":5,"deaths":0}]}

func award_frame(profile: Dictionary, gained: int = 42) -> Dictionary:
	return {"type":"progression", "profile":profile.duplicate(true), "gained":gained, "baseGained":gained,
		"levelUp":false, "mode":"deathmatch", "actor":{"id":0,"frags":3,"deaths":1}}

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	client.actor_id = 0
	# --- strict numeric policy ----------------------------------------------
	check(ResultsModel.safe_int(1.5) == null, "fractional id is unknown, not floored")
	check(ResultsModel.safe_int(-0.5) == null, "negative fractional id is unknown")
	check(ResultsModel.count(-1) == null and ResultsModel.count(-0.5) == null, "negative count is unknown, not zero")
	check(ResultsModel.count(1.5) == null, "fractional count is unknown, not floored")
	check(ResultsModel.count(0) == 0 and ResultsModel.count(7) == 7, "exact non-negative integers survive")
	check(ResultsModel.count(9007199254740992.0) == null, "overflow past the JS safe integer is unknown")
	check(ResultsModel.safe_int(INF) == null and ResultsModel.safe_int(NAN) == null, "non-finite numbers are unknown")
	check(ResultsModel.decimal(60.4) == 60.4 and ResultsModel.decimal(0) == 0.0, "finite non-negative decimals survive")
	check(ResultsModel.decimal(-0.5) == null and ResultsModel.decimal(INF) == null, "negative/non-finite decimals are unknown")
	check(ResultsModel.unit(1.25) == null and ResultsModel.unit(-0.1) == null, "ratio outside 0..1 is unknown, not clamped")
	check(ResultsModel.unit(0.5) == 0.5, "in-range ratio survives")
	# --- pure projection -----------------------------------------------------
	check(ResultsModel.project(null, 0, "k", false).is_empty(), "non-dictionary state invalid")
	check(ResultsModel.project({"foo":1}, 0, "k", false).is_empty(), "no usable facts invalid")
	var projected := ResultsModel.project(state(), 0, "room-a:3", false)
	check(projected.get("mode") == "deathmatch", "mode from source config")
	check(projected.get("map") == "crosswire", "map from source mapId")
	check(projected.get("ending") == "time", "ending from source overReason")
	check(projected.get("frags") == 3 and projected.get("deaths") == 1, "own actor stats located by exact id")
	check(absf(float(projected.get("time")) - 60.4) < 0.0001, "elapsed keeps decimal precision")
	var other := ResultsModel.project(state(), 5, "k", false)
	check(not other.has("frags") and not other.has("deaths"), "own stats unknown when actor absent")
	var fractional := ResultsModel.project({"mapId":"m","config":{"mode":"dm"},"actors":[{"id":1.5,"frags":9}]}, 1, "k", false)
	check(not fractional.has("frags"), "fractional actor id never matches a real actor")
	var missing := ResultsModel.project({"mapId":"m","config":{"mode":"dm"},"actors":[{"id":0,"deaths":2}]}, 0, "k", false)
	check(not missing.has("frags") and missing.get("deaths") == 2, "unknown frags omitted, never zero")
	var penalty := ResultsModel.project({"mapId":"m","config":{"mode":"dm"},"actors":[{"id":0,"frags":-2}]}, 0, "k", false)
	check(not penalty.has("frags"), "negative frags unknown, never zero")
	# --- award vs equipment --------------------------------------------------
	check(not ResultsModel.is_award({"type":"progression","gear":{},"attachments":{}}), "gear reply is not an award")
	check(not ResultsModel.is_award({"type":"progression","profile":{"id":"x"},"gained":5,"gear":{}}), "any partial gear key rejects the award")
	check(not ResultsModel.is_award({"type":"progression","profile":{"id":"x"},"gained":5,"attachments":"bad"}), "any attachments key rejects the award")
	check(ResultsModel.is_award({"type":"progression","profile":{"id":"x"},"gained":0}), "zero gained is a real award")
	check(not ResultsModel.is_award({"type":"progression","profile":{"id":"x"},"gained":1.5}), "fractional gained is not an award")
	check(ResultsModel.project_award({"type":"progression","gear":{},"attachments":{}}).is_empty(), "no award projection from equipment")
	var award := ResultsModel.project_award({"type":"progression","profile":{"id":"x"},"gained":42,"baseGained":30,"prestigeBonus":2,"achievementXp":10,"levelUp":true,"progress":0.5,"toNext":120,"mode":"deathmatch","unlocked":[{"id":"gear-scope","name":"Precision Scope","level":2},{"bad":true}],"achievements":[{"id":"first-blood","name":"First Blood","xp":100}]})
	check(award.get("gained") == 42 and award.get("levelUp") == true, "award scalars projected")
	check(award.get("unlocked").size() == 1 and award.get("achievements").size() == 1, "malformed reward entries dropped")
	var out_of_range := ResultsModel.project_award({"type":"progression","profile":{"id":"x"},"gained":1,"progress":1.25})
	check(not out_of_range.has("progress"), "out-of-range progress omitted, not clamped")
	# --- service: award arrives before results (authoritative order) ---------
	var raw := {"id":"player-one","level":4,"xp":10,"unlocks":{},"gear":{},"attachments":{}}
	service.receive(client, {"type":"welcome","profile":raw})
	check(service.profile.get("id") == "player-one", "welcome binds the seated profile")
	service.receive(client, {"type":"start","roundRevision":3,"mapId":"crosswire"})
	check(service.round_known and not service.round_key.is_empty(), "known revision makes a round key")
	service.receive(client, award_frame(raw))
	check(service.latest_award.get("gained") == 42, "award recorded before any result")
	service.receive(client, {"type":"results","state":state()})
	check(service.results_status == "complete" and service.result.get("mode") == "deathmatch", "accepted result stored")
	check(service.attributed_award().get("gained") == 42, "same-round same-actor award attributed once")
	# duplicate result: same round key, same witnessed award, no new claim
	service.receive(client, {"type":"results","state":state()})
	check(service.result.get("replayed") == true, "duplicate result flagged replayed")
	check(service.attributed_award().get("gained") == 42, "duplicate keeps one witnessed award")
	# --- missing revision: generic award, never a fabricated pairing ---------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","mapId":"crosswire"})
	check(not service.round_known and service.round_key.is_empty(), "missing revision stays unknown")
	service.receive(client, award_frame(raw, 9))
	check(service.latest_award.get("gained") == 9, "uncorrelated award stays latest")
	service.receive(client, {"type":"results","state":state()})
	check(service.attributed_award().is_empty(), "unknown revision never attributes an award")
	check(service.result.get("reconnect") == true, "result without a revision is read-only reconnect")
	# --- long endpoint: hash correlation is stable ---------------------------
	client.connection_endpoint = "ws://127.0.0.1:4000/" + "segment-".repeat(60) + "much-longer-than-ninety-six-characters"
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":11,"mapId":"crosswire"})
	service.receive(client, award_frame(raw, 21))
	service.receive(client, {"type":"results","state":state()})
	check(service.attributed_award().get("gained") == 21, "a long endpoint still correlates after the hash")
	check(not JSON.stringify(service.result).contains("segment-"), "the raw endpoint is never in the public projection")
	client.connection_endpoint = ""
	# --- possible late award inside the same known round ---------------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":4,"mapId":"crosswire"})
	service.receive(client, {"type":"results","state":state(2, 2)})
	check(service.attributed_award().is_empty(), "no award yet for the active round")
	service.receive(client, award_frame(raw, 7))
	check(service.attributed_award().get("gained") == 7, "late same-round award correlated by round key")
	# --- mixed equipment frame never becomes an accepted award ---------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":5,"gear":{}})
	check(service.latest_award.is_empty(), "malformed mixed award rejected")
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":5,"attachments":"bad"})
	check(service.latest_award.is_empty(), "partial attachments key also rejected")
	# --- reconnect: replayed result claims no award -------------------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, award_frame(raw, 33))
	service.receive(client, {"type":"welcome","profile":raw})
	check(service.latest_award.is_empty(), "welcome clears the previous award")
	service.receive(client, {"type":"start","roundRevision":5,"mapId":"crosswire"})
	service.receive(client, {"type":"results","state":state()})
	check(service.result.get("reconnect", false) != true, "known round result is not a reconnect replay")
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
	service.receive(client, {"type":"progression","profile":{"id":"player-two","xp":1},"gained":99,"baseGained":99,"actor":{"id":0}})
	check(service.latest_award.is_empty() and service.attributed_award().is_empty(), "foreign identity award rejected")
	# --- actor mismatch stays generic ---------------------------------------
	service.receive(client, {"type":"welcome","profile":raw})
	service.receive(client, {"type":"start","roundRevision":12,"mapId":"crosswire"})
	service.receive(client, {"type":"progression","profile":raw.duplicate(true),"gained":5,"actor":{"id":7}})
	check(not service.latest_award.is_empty(), "award from another actor is still a source fact")
	service.receive(client, {"type":"results","state":state()})
	check(service.attributed_award().is_empty(), "another actor's award is never attributed to our result")
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
