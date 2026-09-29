extends SceneTree
## Pure projection + service behaviour for the read-only source HISTORY lane.
## 'Recent server matches' is server-wide; the reader never guesses a personal
## association from a player name and never turns a missing stat into a zero.
const HistoryModel = preload("res://career/history_model.gd")
const Client = preload("res://net/client.gd")
var failed := false

class Probe extends Client:
	var sent: Array[Dictionary] = []
	func career_wire_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame)
		return OK

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("career history: " + label)

func matches() -> Array:
	return [{"roomId":"room-a","mapId":"crosswire","mode":"deathmatch","endedBy":"time","duration":60.4,"leader":"A",
		"players":[{"name":"A","character":"chatgpt","harness":"openclaw","frags":3,"deaths":1},
			{"name":"B","frags":0,"deaths":2,"scoreStats":{"captures":2,"assists":0}}]}]

func run() -> void:
	var service := root.get_node("Career")
	var client := Probe.new()
	root.add_child(client)
	client.room_id = "room-a"
	client.career_seated = true
	# --- strict numeric policy ----------------------------------------------
	check(HistoryModel.count(-0.5) == null and HistoryModel.count(1.5) == null, "fractional/negative counts unknown")
	check(HistoryModel.count(-3) == null, "negative penalty count stays unknown, not zero")
	check(HistoryModel.count(9007199254740992.0) == null, "overflow count unknown")
	check(HistoryModel.decimal(12.5) == 12.5, "decimal duration preserved")
	# --- pure projection -----------------------------------------------------
	check(HistoryModel.project("nope").is_empty(), "malformed top-level is invalid, not empty")
	check(HistoryModel.project(null).is_empty(), "missing list is invalid")
	var projected: Dictionary = HistoryModel.project([{"mapId":"m","mode":"dm"}, {"bad":1}, null, 42])
	check(projected.get("records").size() == 1 and projected.get("invalid") == 3 and projected.get("total") == 4, "malformed records counted and skipped")
	var record: Dictionary = HistoryModel.project_record({"mapId":"m","mode":"dm","duration":12.5,"leader":"Top","players":[{"name":"A","frags":3,"scoreStats":{"objectiveTime":12.5,"damage":42.75,"captures":2}},{"name":"B","frags":-0.5}]})
	check(record.get("duration") == 12.5, "decimal duration kept without flooring")
	check(record.get("players")[0].get("frags") == 3, "known player frags kept")
	check(absf(float(record.get("players")[0].get("score_stats").get("objectiveTime")) - 12.5) < 0.0001, "objective time keeps precision")
	check(absf(float(record.get("players")[0].get("score_stats").get("damage")) - 42.75) < 0.0001, "damage keeps precision")
	check(record.get("players")[0].get("score_stats").get("captures") == 2, "objective count kept")
	check(not record.get("players")[1].has("frags"), "fractional/negative player frags omitted, never zero")
	check(not record.get("players")[1].has("deaths"), "missing player deaths omitted")
	check(HistoryModel.project_record({"unrelated":true}).is_empty(), "empty record omitted")
	# --- Home has no authority ----------------------------------------------
	check(service.history_status == "offline", "Home starts offline")
	service.request_history()
	check(service.history_status == "offline" and client.sent.is_empty(), "no request without a seated source")
	# --- admitted seat requests, loading then reply --------------------------
	service.receive(client, {"type":"welcome","profile":{"id":"player-one","level":1,"unlocks":{},"gear":{},"attachments":{}}})
	service.select_category("history")
	check(service.history_status == "loading" and service.history_pending and client.sent.size() == 1 and client.sent[0].get("type") == "history", "history requested on an admitted seat")
	service.request_history(true)
	check(client.sent.size() == 1, "force cannot stack a second outstanding request")
	service.receive(client, {"type":"history","matches":matches()})
	check(service.history_status == "ready" and not service.history_pending and service.history_records.size() == 1, "reply becomes ready")
	check(service.history_records[0].get("map") == "crosswire", "source record facts projected")
	check(service.history_records[0].get("players")[1].get("frags") == 0, "a known zero is preserved")
	check(absf(float(service.history_records[0].get("duration")) - 60.4) < 0.0001, "ready duration keeps precision")
	# --- mixed invalid entries keep the valid record ------------------------
	service.request_history(true)
	check(service.history_pending, "next request is outstanding")
	service.receive(client, {"type":"history","matches":[{"mapId":"m","mode":"dm"}, "bad", 42]})
	check(service.history_status == "ready" and service.history_records.size() == 1 and service.history_invalid == 2, "malformed entries counted, valid record kept")
	# --- all-invalid and malformed top-level keep the last known list -------
	service.request_history(true)
	service.receive(client, {"type":"history","matches":[{"bad":1}, "bad"]})
	check(service.history_status == "error" and service.history_records.size() == 1, "all-invalid reply reported as error, not empty")
	service.request_history(true)
	service.receive(client, {"type":"history","matches":"nope"})
	check(service.history_status == "error" and service.history_records.size() == 1, "malformed reply reported, last known kept")
	service.request_history(true)
	service.receive(client, {"type":"history-error","message":"unsupported"})
	check(service.history_status == "error" and service.history_notice == "unsupported" and service.history_records.size() == 1, "history-error is non-fatal and keeps facts")
	# --- a genuinely empty reply is its own status --------------------------
	service.request_history(true)
	service.receive(client, {"type":"history","matches":[]})
	check(service.history_status == "empty" and service.history_records.is_empty(), "empty reply distinct from error")
	# --- refresh button round trip ------------------------------------------
	var rows := service.details.find_child("CatalogRows", true, false) as VBoxContainer
	var refresh_button := rows.find_child("HistoryRefresh", true, false) as Button
	check(refresh_button != null and not refresh_button.disabled, "refresh action available on an admitted source")
	var before := client.sent.size()
	if refresh_button != null: refresh_button.pressed.emit()
	check(client.sent.size() == before + 1 and service.history_status == "loading" and service.history_pending, "refresh re-requests the source")
	service.receive(client, {"type":"history","matches":matches()})
	check(service.history_status == "ready" and service.history_records.size() == 1, "second reply accepted")
	# --- timeout, then a delayed reply is only an observation ---------------
	service.request_history(true)
	check(service.history_status == "loading", "request in flight")
	service.history_requested_at = Time.get_ticks_msec() - 9000
	service._process(0.0)
	check(service.history_status == "timeout" and not service.history_pending and service.history_records.size() == 1, "timeout is unknown, last known kept, slot released")
	service.receive(client, {"type":"history","matches":matches()})
	check(service.history_status == "timeout" and service.history_notice.contains("Delayed"), "delayed reply is not fresh readiness")
	check(service.history_records.size() == 1, "delayed observation still updates the snapshot")
	# --- no cross-client history --------------------------------------------
	var foreign := Probe.new()
	root.add_child(foreign)
	foreign.room_id = "room-b"
	foreign.career_seated = true
	service.receive(foreign, {"type":"history","matches":[]})
	check(service.history_records.size() == 1 and service.history_status == "timeout", "foreign client history ignored")
	# --- no credential keys ------------------------------------------------
	check(not JSON.stringify(service.history_records).contains("ownerToken") and not JSON.stringify(service.history_records).contains("progressToken"), "no credential keys in history records")
	# --- disconnect clears the endpoint ------------------------------------
	service.clear_connection(client)
	check(service.history_status == "offline" and service.history_records.is_empty() and not service.history_pending, "disconnect clears history")
	client.queue_free()
	foreign.queue_free()
	print("CAREER_HISTORY_OK")
	quit(1 if failed else 0)
