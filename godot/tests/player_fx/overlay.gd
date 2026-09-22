extends SceneTree
## Overlay cue plumbing: edge geometry helpers, visibility from player-state
## cues, and preservation of the existing ADS reticle/fade policy.
const Overlay = preload("res://world/combat_overlay.gd")
const Director = preload("res://player_fx/director.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_OVERLAY: " + message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check(Overlay.edge_direction(0.0).distance_to(Vector2.UP) < 0.0001, "ahead maps to the top edge")
	check(Overlay.edge_direction(PI * 0.5).distance_to(Vector2.RIGHT) < 0.0001, "right maps to the right edge")
	check(Overlay.edge_direction(-PI * 0.5).distance_to(Vector2.LEFT) < 0.0001, "left maps to the left edge")
	var half := Vector2(400, 300)
	check(Overlay.frame_point(half, 0.0).distance_to(Vector2(0, -300)) < 0.001, "ahead frame point sits on the top edge")
	check(Overlay.frame_point(half, PI * 0.5).distance_to(Vector2(400, 0)) < 0.001, "right frame point sits on the right edge")
	check(Overlay.frame_point(half, PI).distance_to(Vector2(0, 300)) < 0.001, "behind frame point sits on the bottom edge")
	check(Overlay.frame_point(half, -PI * 0.5).distance_to(Vector2(-400, 0)) < 0.001, "left frame point sits on the left edge")
	check(absf(Overlay.frame_point(half, PI * 0.25).length()) > 280.0, "oblique frame points stay outside the sight picture")
	var center := Vector2(480, 320)
	check((center + Overlay.frame_point(half, 0.0)).distance_to(Vector2(480, 20)) < 0.001, "edge point stays outside the sight picture")

	var overlay: Control = Overlay.new()
	root.add_child(overlay)
	overlay.update_feedback(false, 0.0, 0.0, {})
	check(not overlay.visible, "idle overlay is hidden")
	overlay.update_feedback(false, 0.0, 0.0, {"direction": true, "direction_strength": 1.0})
	check(overlay.visible and overlay.fx_active(), "damage direction shows without aiming")
	overlay.update_feedback(false, 0.0, 0.0, {"low_health": 0.5})
	check(overlay.visible and overlay.fx_active(), "low health shows without aiming")
	overlay.update_feedback(false, 0.0, 0.0, {"break": 1.0, "death": 0.5, "materialize": 0.5})
	check(overlay.fx_active(), "break, death and materialize cues are visible")
	overlay.update_feedback(false, 0.0, 0.0, {})
	check(not overlay.visible and not overlay.fx_active(), "cleared model hides the overlay")

	# ADS policy: the reticle still depends on aiming and the weight threshold,
	# while edge cues stay visible because they live outside the sight picture.
	overlay.update_feedback(true, 0.0, 0.0, {})
	overlay.set_ads_weight(1.0)
	check(overlay.aiming and overlay.ads_weight >= 0.98, "full ADS hides the reticle input")
	overlay.update_feedback(true, 0.0, 0.0, {"direction": true, "direction_strength": 1.0})
	check(overlay.visible, "damage direction is not suppressed by ADS")
	overlay.update_feedback(false, 0.2, 0.35, {})
	check(overlay.hit_strength > 0.0 and overlay.hurt_strength > 0.0, "existing hit/hurt timers are unchanged")

	# Director model keys feed the overlay directly.
	var camera := Camera3D.new()
	root.add_child(camera)
	var director: Node = Director.new()
	root.add_child(director)
	director.configure(camera)
	director.apply_state({"time": 1.0, "actors": [
		{"id": 0, "x": 0, "y": 0, "z": 0, "health": 20, "dead": 0},
		{"id": 1, "x": 5, "y": 0, "z": -5, "health": 100, "dead": 0}]}, 0)
	director.apply_events([{"id": 5, "type": "damage", "actor": 0, "source": 1, "amount": 12, "shieldBreak": true}], 0)
	director.advance(0.016)
	var model: Dictionary = director.model()
	overlay.update_feedback(false, 0.0, 0.0, model)
	check(overlay.fx_active() and overlay.strength("low_health") > 0.0 and overlay.strength("break") > 0.0, "director model drives overlay cues")
	check(absf(float(overlay.fx.get("direction_angle", 0.0)) - PI * 0.25) < 0.001, "director/overlay share the bearing convention")

	director.free()
	overlay.free()
	camera.free()
	if failures.is_empty():
		print("PLAYER_FX_OVERLAY_OK checks=", checks)
	else:
		print("PLAYER_FX_OVERLAY_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
