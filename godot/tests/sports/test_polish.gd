extends SceneTree
## Synthetic presentation regressions; authored boxes are read from locked export.
const Chase = preload("res://sports/chase.gd")
const HUD = preload("res://sports/hud.gd")
const Catalog = preload("res://world/catalog.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.open(), "locked catalog opens")
	var map := catalog.resolve_map("aurora-stadium")
	var original := JSON.stringify(map)
	var chase := Chase.new()
	check(chase.configure_map("aurora-stadium", map), "authored map fits cache")
	check(chase.boxes.size() == map.blocks.size(), "every authored box cached")
	var wall_found := false
	for b: Dictionary in map.blocks:
		if b.get("kind") == "soccer-wall" and b.z == -24.6 and b.w == 90.4: wall_found = true
	check(wall_found, "fixture obstruction is the authored south pitch board")
	var v := {"x":0.0,"y":0.0,"z":-21.0,"yaw":0.0,"vx":0,"vz":0}
	var pose := chase.follow(v, 0.016)
	check(pose.eye.z > -23.65 and pose.eye.z < -21, "eye pulled in before padded wall face")
	check(pose.eye.y > 1.2 and pose.eye.y < 3, "obstruction lowers boom along clear segment")
	for bounds: AABB in chase.boxes:
		if bounds.has_point(pose.eye):
			check(false, "eye outside every padded authored box")
	check(chase.last_candidates < chase.boxes.size()/4, "local spatial query avoids full-map scan")
	var wall_eye: Vector3 = pose.eye
	for i in range(120): pose = chase.follow(v, 0.016)
	check(pose.eye.distance_to(wall_eye) < 0.03, "static obstruction is stable over 120 frames")
	v.vz = -6
	check(chase.follow(v, 0.016).eye.distance_to(wall_eye) < 0.03, "reverse cannot flip obstructed rig")
	v.z = -15.0
	pose = chase.follow(v, 0.016)
	var first_recovery: Vector3 = pose.eye
	var desired := Vector3(0, 5, -24)
	check(first_recovery.distance_to(desired) > 0.5, "recovery does not snap to full boom")
	for i in range(120): pose = chase.follow(v, 0.016)
	check(pose.eye.distance_to(desired) < 0.02, "recovery converges to clear boom")
	chase.reset()
	v.z = 0.0
	pose = chase.follow(v, 0.016)
	check(pose.eye.is_equal_approx(Vector3(0, 5, -9)), "unoccluded original +Z eye")
	check(pose.target.is_equal_approx(Vector3(0, 1, 6)), "unoccluded original look-ahead")
	v.yaw = PI - 0.001
	chase.reset()
	var before: Vector3 = chase.follow(v, 0.016).eye
	v.yaw = -PI + 0.001
	check(chase.follow(v, 0.016).eye.distance_to(before) < 0.03, "yaw wrap takes short arc")
	v.x = 20.0
	v.yaw = 0.0
	check(chase.follow(v, 0.016).eye.is_equal_approx(Vector3(20, 5, -9)), "large source reset snaps without old-position lag")
	var cached := chase.boxes.size()
	chase.reset()
	check(not chase.seeded and chase.boxes.size() == cached, "round reset keeps cache but drops pose")
	check(JSON.stringify(map) == original, "camera never mutates semantic map")
	check(chase.configure_map("ion-speedway", catalog.resolve_map("ion-speedway")), "map change replaces cache")
	check(chase.map_id == "ion-speedway" and not chase.seeded, "map change clears camera seed")
	v = {"x":0.0,"y":0.0,"z":-57.0,"yaw":PI,"vx":0,"vz":0}
	pose = chase.follow(v, 0.016)
	check(chase.obstructed and pose.eye.z < -54.95 and pose.eye.z > -57, "Ion launch straight inner rail also clips boom")
	var too_many: Array = []
	too_many.resize(Chase.MAX_BOXES + 1)
	check(not chase.configure_map("too-large", {"blocks":too_many}) and chase.boxes.is_empty(), "oversize cache rejected explicitly")
	var box := AABB(Vector3(-1, 0, -4), Vector3(2, 3, 1))
	check(is_equal_approx(Chase.entry_fraction(Vector3(0, 1, 0), Vector3(0, 1, -6), box), 0.5), "parallel slab entry")
	check(Chase.entry_fraction(Vector3(2, 1, 0), Vector3(2, 1, -6), box) == 1, "parallel slab miss")
	check(Chase.entry_fraction(Vector3.ZERO, Vector3.ZERO, box) == 1, "zero-length clear segment")
	var view := {"mode":"puma-race", "phase":"active", "age":0.0, "actor_id":4, "eligible":true, "focused":true, "engaged":false, "state":{"race":{"phase":"racing", "laps":3.0, "gates":[{}, {}, {}], "standings":[{"actorId":4, "lap":2.0, "nextGate":0.0}]}}, "vehicle":{"vx":3.0,"vz":4.0}}
	var h := HUD.describe(view)
	check(h.title == "Ion Speedway · Puma Race", "friendly race title")
	check(h.detail == "Lap 2 / 3   ·   Checkpoint 1 / 3", "integer lap and one-based checkpoint")
	check(h.speed == "5.0 m/s", "speed magnitude")
	check(h.status.begins_with("RELEASED") and h.status.contains("Enter"), "released engagement instruction")
	check(h.hints.contains("R:") and not h.hints.contains("F5"), "race-only reset; no early restart")
	view.engaged = true
	check(HUD.describe(view).status.begins_with("ENGAGED"), "engaged feedback")
	view.age = 0.5
	check(HUD.describe(view).status.begins_with("STALLED"), "stale boundary beats old engaged state")
	view.age = 0
	view.state.race.phase = "countdown"
	view.state.race.countdown = 2.1
	h = HUD.describe(view)
	check(h.phase == "Start in · 3" and h.status.begins_with("RELEASED"), "rounded countdown beats engaged flag")
	view.phase = "results"
	check(HUD.describe(view).hints == "F5: start a new round", "restart only in actual results")
	view.phase = "error"
	view.error = "Authoritative snapshots timed out"
	h = HUD.describe(view)
	check(h.status.begins_with("ERROR") and h.hints.contains(view.error) and h.hints.contains("relaunch"), "error recovery instruction")
	view.phase = "active"
	view.mode = "puma-soccer"
	view.state = {"race":{"phase":"playing", "scores":{"0":2.0,"1":1.0}}}
	h = HUD.describe(view)
	check(h.detail == "Red  2     Blue  1", "source team scores labeled and integer")
	check(not h.hints.contains("R:") and not h.hints.contains("reset"), "soccer never advertises reset")
	view.state.race.scores = {}
	check(HUD.describe(view).detail == "Red  —     Blue  —", "partial scores are unknown, not invented zeroes")
	view.state.race.phase = "over"
	check(not HUD.describe(view).hints.contains("F5"), "over snapshot waits for results event")
	view.state = {}
	view.vehicle = {}
	view.eligible = false
	h = HUD.describe(view)
	check(h.speed == "— m/s" and h.status.contains("Waiting"), "partial snapshot safe and ineligible")
	check(HUD.describe({}).phase == "Connecting…", "empty HUD state safe")
	var hud := HUD.new()
	hud.update(view)
	check(hud.text.contains("Aurora Stadium") and not hud.text.contains("{"), "text API remains friendly summary before ready")
	hud.free()
	print("SPORTS_POLISH_SYNTHETIC_CHECKS ", checks, " failures=", failures)
	quit(1 if failures else 0)
