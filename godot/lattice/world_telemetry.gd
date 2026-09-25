extends RefCounted
## Bounded observational trace, never a gameplay authority or a private room view.
const MAX_RECORDS := 128
var records: Array[Dictionary] = []
var visits := 0
var captures := 0
var attributed_captures := 0
var unavailable_attribution := 0
var open_visit := false
var epoch := ""
const MAX_EVENTS := 32
var recent_events: Array[Dictionary] = []
var completed_rounds: Array[Dictionary] = []
var event_revision: Variant = null

func clear() -> void:
	records.clear()
	visits = 0
	captures = 0
	attributed_captures = 0
	unavailable_attribution = 0
	open_visit = false
	epoch = ""
	recent_events.clear()
	event_revision = null

func add(kind: String, evidence: String, projection: Dictionary, fields: Dictionary = {}) -> void:
	var item := {"schema":1, "kind":kind, "evidence_class":evidence,
		"round":projection.get("context", {}).get("revision"), "actor":projection.get("context", {}).get("actor"),
		"source_sequence":projection.get("source_sequence"), "source_time":projection.get("source_time"),
		"fields":fields.duplicate(true)}
	if records.size() >= MAX_RECORDS: records.pop_front()
	records.append(item)

func observe(projection: Dictionary) -> void:
	if projection.is_empty(): return
	var next_epoch := "%s/%s" % [projection.get("context", {}).get("revision"), projection.get("context", {}).get("actor")]
	if next_epoch != epoch:
		clear()
		epoch = next_epoch
	add("snapshot", "recipient-wire", projection, {"mode":projection.get("mode")})

## Call on authoritative results; retain summaries until begin_round().
func finish_round() -> void:
	var result := summary()
	if completed_rounds.size() >= 32: completed_rounds.pop_front()
	completed_rounds.append(result)

## Call only on an authoritative start for the new revision.
func begin_round() -> void:
	clear()

func panel(opened: bool, projection: Dictionary) -> void:
	if opened == open_visit: return
	open_visit = opened
	if opened: visits += 1
	add("command-panel-open" if opened else "command-panel-close", "native-ui", projection)

func events(items: Array, projection: Dictionary) -> void:
	var revision: Variant = projection.get("context", {}).get("revision")
	if event_revision != revision:
		recent_events.clear()
		event_revision = revision
	for raw: Variant in items:
		if not raw is Dictionary: continue
		var event: Dictionary = raw
		var kind: String = str(event.get("type", event.get("kind", "")))
		if kind not in ["cocs-capture", "cocs-order-complete"]: continue
		# The source event has no round field. Its arrival in this event batch is
		# scoped to the current recipient revision; explicit conflicting metadata
		# is rejected, never used to manufacture a match.
		if event.has("round") and event.get("round") != revision: continue
		if recent_events.size() >= MAX_EVENTS: recent_events.pop_front()
		var observed := event.duplicate(true)
		observed["_arrival_revision"] = revision
		recent_events.append(observed)
		if kind != "cocs-capture": continue
		captures += 1
		var participants: Variant = event.get("participants")
		var actor: Variant = projection.get("context", {}).get("actor")
		var attributed: bool = participants is Array and actor != null and actor in participants
		if attributed: attributed_captures += 1
		if not participants is Array: unavailable_attribution += 1
		# Participation identifies an actor, never a particular command card.
		add("capture", "recipient-event", projection, {"event_id":event.get("id"), "event_tick":event.get("tick"), "source_sequence":event.get("sequence", projection.get("source_sequence")), "node":event.get("node"), "team":event.get("team"), "local_participant":attributed if participants is Array else null, "effect":"observed nearby/unattributed"})

func observe_events(items: Array, projection: Dictionary) -> void:
	events(items, projection)

## Exact metadata gate for a UI correlation. Capture proximity/participation is
## deliberately insufficient; source must name the card and matching context.
func order_matches(event: Dictionary, action: Dictionary, projection: Dictionary, actor_id: Variant) -> bool:
	if str(event.get("type", event.get("kind", ""))) != "cocs-order-complete": return false
	if not event.has("cardId") or event.get("cardId") == null or event.get("cardId") != action.get("cardId"): return false
	var context: Dictionary = projection.get("context", {})
	if event.get("_arrival_revision") != context.get("revision") or action.get("roundRev") != context.get("revision"): return false
	# The simulation emits its actor id as peerId; the room's transport peer id is different.
	if not event.has("peerId") or actor_id == null or str(event.get("peerId")) != str(actor_id): return false
	return true

func effect_for_action(action: Dictionary, projection: Dictionary, actor_id: Variant) -> bool:
	for event: Dictionary in recent_events:
		if order_matches(event, action, projection, actor_id): return true
	return false

func observe_projection(projection: Dictionary) -> void:
	observe(projection)
	# Authoritative spend/spawn deltas are positive evidence, but not card causality.
	add("projection-economy", "recipient-wire", projection, {"flux_spent":projection.get("spent"), "fighters":projection.get("fighters"), "reinforcements":projection.get("reinforcements")})

func summary() -> Dictionary:
	return {"schema":1,"persistence":"in-memory bounded; no JSONL", "evidence_class":"recipient-and-native-observation", "visits":visits,
		"captures":captures,"attributed_captures":attributed_captures,
		"attribution_unavailable":unavailable_attribution,"records_retained":records.size(), "records":records.duplicate(true)}
