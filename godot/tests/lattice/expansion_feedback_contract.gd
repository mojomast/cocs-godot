extends SceneTree
## Pure source-oracle differential checks. Run only after engine slot grant.
const Feedback = preload("res://lattice/world_feedback.gd")
const Captions = preload("res://lattice/event_caption.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print("LATTICE_EXPANSION ", JSON.stringify({"ok":ok,"message":message}))

func _initialize() -> void:
	var oracle: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lattice/fixtures/expansion_feedback.json"))
	check(oracle is Dictionary, "source vectors loaded")
	if not oracle is Dictionary:
		quit(1)
		return
	for row: Dictionary in oracle.captions:
		check(Captions.text_for(row.event) == row.text, "source caption: " + str(row.event))
	for row: Dictionary in oracle.recovery:
		check(Feedback.recovery(row.reason) == row.text, "source recovery: " + row.reason)
	for row: Dictionary in oracle.progress:
		var model := Feedback.objective(row.node, {"x":0,"z":0})
		check(model.progress.contains("%d%%" % int(row.percent)), "source progress " + row.node.id)
		check(model.range == "5 m planar · radius 10 m", "published radius and planar distance")
	check(Feedback.objective({}, {}).text == "CAPTURE UNKNOWN · RANGE UNKNOWN", "missing state remains unknown")
	check(Feedback.objective({"progress":[NAN, 0],"x":0,"z":0}, {"x":INF,"z":0}).text == "CAPTURE UNKNOWN · RANGE UNKNOWN", "nonfinite remains unknown")
	check(Captions.text_for({"type":"unrecognized","targets":[1]}).is_empty(), "no invented unknown event caption")
	check(not Captions.text_for({"type":"cocs-role-spot","targets":[991,992]}).contains("991"), "only source count, no target identities")
	check(not Captions.text_for({"type":"cocs-command","action":"set-route","value":"front\nsecret"}).contains("\n"), "plain bounded source label")
	var actions: Array = [{"roundRev":1,"cardId":"buy","kind":"buy","target":"overshield","status":"confirmed"}]
	actions.append({"roundRev":1,"cardId":"hold","kind":"hold","target":"front-0","status":"queued"})
	check(Feedback.receipt(actions, 1).text.contains("NOT ACCEPTED"), "latest HOLD replaces old BUY receipt")
	actions[1].status = "pending (server accepted)"
	check(Feedback.receipt(actions, 1).text.contains("AWAIT SETTLEMENT"), "acceptance is not settlement")
	actions[1].status = "rejected"
	actions[1].reason = "wrong-team"
	check(Feedback.receipt(actions, 1).text.contains("REFUSED · WRONG-TEAM"), "source failure is visible")
	actions[1].status = "confirmed"
	check(Feedback.receipt(actions, 1).text.contains("EFFECT NOT PROVEN"), "settled HOLD does not claim capture")
	check(Feedback.receipt(actions, 2).is_empty(), "old round receipts cleared")
	check(Feedback.receipt([], 1).is_empty(), "missing local actions clear receipt")
	print("LATTICE_EXPANSION_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
