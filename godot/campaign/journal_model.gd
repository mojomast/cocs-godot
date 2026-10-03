extends RefCounted
## Read-only Relay Journal derivation. Every value here comes from a public
## campaign snapshot or from an event this client actually observed. Nothing is
## simulated, predicted or advanced locally, and no authority message is sent.
##
## Retention is keyed by chapter (scene). Optional workshops and story beats are
## remembered once the authority reports them complete, so a death/retry that
## carries the chapter forward keeps its recovered list. A restart is detected
## the honest way: the authority regresses a previously completed workshop or
## story beat to incomplete, which clears only that chapter's observed record.
const Catalog = preload("res://campaign/catalog.gd")

class Record extends RefCounted:
	var workshops: Dictionary = {}   # workshop id -> observed choice ("" for link/align)
	var story: Dictionary = {}       # chapter-prefixed story beat id -> true
	var pets := 0
	var cleared := false             # authority reported level/campaign complete
	var max_step := 0

var records: Dictionary = {}         # chapter id -> Record
var latest: Dictionary = {}          # last accepted campaign state
var chapter := ""
var accepted: bool = false

func reset() -> void:
	records.clear()
	latest.clear()
	chapter = ""
	accepted = false

func _blank() -> Record:
	return Record.new()

func _record(map_id: String) -> Record:
	var value: Variant = records.get(map_id)
	if value is Record: return value
	var created := _blank()
	records[map_id] = created
	return created

func cleared(map_id: String) -> bool:
	return _record(map_id).cleared

func observe(state: Variant) -> void:
	if not state is Dictionary: return
	if state.get("id") != "quiet-relay": return
	var map_id := str(state.get("mapId", ""))
	if not Catalog.MAP_IDS.has(map_id): return
	chapter = map_id
	latest = state
	accepted = true
	var record := _record(map_id)
	var restarted := false

	var beats: Array = state.get("interludes", {}).get("beats", []) if state.get("interludes") is Dictionary else []
	var story: Dictionary = state.get("story", {}) if state.get("story") is Dictionary else {}
	var completed_story: Array = story.get("completed", []) if story.get("completed") is Array else []

	# Restart is an authoritative regression, never a local guess.
	for beat: Variant in beats:
		if not beat is Dictionary: continue
		var id := str(beat.get("id", ""))
		if id.is_empty(): continue
		if beat.get("completed", false) == true: continue
		if record.workshops.has(id): restarted = true
	if not restarted and not record.story.is_empty():
		var current := {}
		for entry: Variant in completed_story: current[str(entry)] = true
		for id: String in record.story:
			if not current.has(id): restarted = true; break
	if restarted:
		record = _blank()
		records[map_id] = record

	# Record only what the authority currently reports. Completed stays completed
	# until an observed regression above clears the chapter.
	for beat: Variant in beats:
		if not beat is Dictionary: continue
		var id := str(beat.get("id", ""))
		if id.is_empty() or beat.get("completed", false) != true: continue
		record.workshops[id] = str(beat.get("choice", "")) if beat.get("choice") != null else ""
	for entry: Variant in completed_story:
		record.story[str(entry)] = true
	record.pets = maxi(record.pets, int(story.get("pets", 0)) if _whole(story.get("pets")) else 0)
	record.max_step = maxi(record.max_step, int(state.get("stepIndex", 0)) if _whole(state.get("stepIndex")) else 0)
	var phase := str(state.get("phase", ""))
	if phase in ["level-complete", "campaign-complete"]: record.cleared = true

# JSON integers can arrive as floats; accept only whole, finite values.
static func _whole(value: Variant) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) == floorf(float(value))

func objective() -> Dictionary:
	return {
		"title": str(latest.get("title", "")),
		"objective": str(latest.get("objective", "")),
		"detail": str(latest.get("detail", "")),
		"step": int(latest.get("stepIndex", 0)) if _whole(latest.get("stepIndex")) else 0,
		"step_count": int(latest.get("stepCount", 0)) if _whole(latest.get("stepCount")) else 0,
		"enemies": int(latest.get("enemiesRemaining", 0)) if _whole(latest.get("enemiesRemaining")) else 0,
		"hold": float(latest.get("holdProgress", 0.0)) if latest.get("holdProgress") is float or _whole(latest.get("holdProgress")) else 0.0,
		"kills": int(latest.get("kills", 0)) if _whole(latest.get("kills")) else 0,
		"elapsed": int(latest.get("elapsed", 0)) if _whole(latest.get("elapsed")) else 0,
		"total": int(latest.get("totalElapsed", 0)) if _whole(latest.get("totalElapsed")) else 0,
		"phase": str(latest.get("phase", "")),
		"next": str(latest.get("nextMapId", "")),
	}

func route() -> Array:
	var out: Array = []
	for index: int in Catalog.MAP_IDS.size():
		var id: String = Catalog.MAP_IDS[index]
		var status := "locked"
		if id == chapter: status = "current"
		elif _record(id).cleared: status = "cleared"
		out.append({"id": id, "title": Catalog.TITLES[index], "index": index, "status": status})
	return out

func workshops() -> Array:
	var out: Array = []
	var beats: Array = latest.get("interludes", {}).get("beats", []) if latest.get("interludes") is Dictionary else []
	var record := _record(chapter)
	for beat: Variant in beats:
		if not beat is Dictionary: continue
		var id := str(beat.get("id", ""))
		var completed: bool = beat.get("completed", false) == true or record.workshops.has(id)
		var choice: Variant = beat.get("choice")
		if choice == null and record.workshops.has(id) and not str(record.workshops[id]).is_empty():
			choice = record.workshops[id]
		out.append({
			"id": id,
			"title": str(beat.get("title", "")),
			"family": str(beat.get("family", "")),
			"theme": str(beat.get("theme", "")),
			"actions": beat.get("actions", []) if beat.get("actions") is Array else [],
			"hint": str(beat.get("hint", "")),
			"result": str(beat.get("result", "")),
			"stage": int(beat.get("stage", 0)) if _whole(beat.get("stage")) else 0,
			"completed": completed,
			"choice": choice,
		})
	return out

func crew() -> Dictionary:
	var story: Dictionary = latest.get("story", {}) if latest.get("story") is Dictionary else {}
	var entities: Array = []
	for entry: Variant in story.get("entities", []) if story.get("entities") is Array else []:
		if not entry is Dictionary or entry.get("active", false) != true: continue
		entities.append({"name": str(entry.get("name", "")), "kind": str(entry.get("kind", "")), "pose": str(entry.get("pose", ""))})
	var record := _record(chapter)
	var caption: Variant = story.get("caption")
	return {"entities": entities, "beats": record.story.size(), "pets": record.pets,
		"caption": caption if caption is Dictionary else {}}
