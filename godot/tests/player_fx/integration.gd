extends SceneTree
## Local-player FX through the real combat composition: public state/events,
## F9 quality budget, F10 metric keys, focus/stale/results drains and the
## legacy-owner no-duplication rule.
const Feedback = preload("res://world/combat_feedback.gd")
const Rig = preload("res://first_person/rig.gd")
const Client = preload("res://net/client.gd")
var checks := 0
var failures: Array[String] = []

class Watch:
	var value := false
	func stale() -> bool: return value

class Context extends Node3D:
	var camera := Camera3D.new()
	var rig: Node
	var client: Node
	var world := Node3D.new()
	var current_id := "meridian-exchange"
	var phase := 3
	var application_focused := true
	var snapshot_watch := Watch.new()
	func can_capture_pointer() -> bool: return true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PLAYER_FX_INTEGRATION: " + message)

func _initialize() -> void: call_deferred("run")

func recorded_shot(id: int) -> Dictionary:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/protocol/captured.json"))
	for record: Dictionary in capture.frames:
		if record.get("direction") != "server": continue
		var frame: Variant = record.get("frame")
		if not frame is Dictionary or frame.get("type") != "events": continue
		for event: Variant in frame.get("items", []):
			if event is Dictionary and event.get("id") == id and event.get("type") == "shot": return event.duplicate(true)
	return {}

func run() -> void:
	var context := Context.new()
	root.add_child(context)
	context.add_child(context.camera)
	context.add_child(context.world)
	context.client = Client.new()
	context.add_child(context.client)
	context.client.set_process(false)
	context.client.actor_id = 0
	context.rig = Rig.new()
	context.add_child(context.rig)
	context.rig.attach_to(context.camera)
	context.rig.set_process(false)
	context.rig.reduced_motion = true
	var feedback := Feedback.new()
	context.add_child(feedback)
	feedback.set_process(false)
	feedback.audio_feedback.set_muted(true)

	var local := {"id": 0, "x": 24, "y": 2.0, "z": -22, "health": 100, "maxHealth": 100, "dead": 0, "protection": 0, "armor": 0}
	var threat := {"id": 1, "x": 29.654, "y": 1.0, "z": -30.069, "health": 100, "dead": 0}
	var state := {"mapId": "meridian-exchange", "time": 1.0, "over": false, "actors": [local, threat]}
	context.camera.position = Vector3(24, 2.0, -22)
	context.camera.look_at(Vector3(29.654, 0.6, -30.069))
	context.rig.apply_actor(local, true)
	context.rig.advance(0.05)
	feedback.apply_state(state)
	check(feedback.effect_local_id == 0 and feedback.occlusion.ready, "composition resolved identity and semantic map")
	check(is_instance_valid(feedback.player_fx) and is_instance_valid(feedback.impacts), "player FX owners created by the composition")

	# Local damage starts the direction cue and the low-health state.
	local.health = 20.0
	feedback.apply_state(state)
	feedback.apply_events([{"id": 10, "type": "damage", "actor": 0, "source": 1, "amount": 12}], 0)
	feedback.flush_effects()
	feedback.advance(0.016)
	check(int(feedback.player_fx.counters.damage) == 1 and feedback.player_fx.damage_remaining > 0.0, "composition routes local damage to the direction cue")
	check(feedback.player_fx.low_health > 0.0, "composition tracks low health from public state")
	check(feedback.player_fx.alive, "local actor alive for cue checks")

	# A recorded server shot on real map geometry draws exactly one impact.
	var recorded: Dictionary = recorded_shot(164)
	check(not recorded.is_empty(), "recorded server shot loaded")
	feedback.apply_events([recorded], 0)
	feedback.flush_effects()
	check(int(feedback.impacts.counters.shown) == 1, "composition draws the confirmed wall impact")

	# The legacy surface-effect owner still handles a surface_hit + normal cue;
	# the new impact path must not duplicate it.
	var legacy: Dictionary = {"id": 11, "type": "shot", "actor": 1, "weapon": 0, "time": 1.5, "hit": false,
		"surface_hit": true, "normal": {"x": 0, "y": 1, "z": 0},
		"from": {"x": 24, "y": 2.0, "z": -22}, "to": {"x": 29.654, "y": 0.6, "z": -30.069}}
	feedback.apply_events([legacy], 0)
	feedback.flush_effects()
	check(int(feedback.impacts.counters.legacy) == 1 and int(feedback.impacts.counters.shown) == 1, "legacy surface cue is never duplicated")
	check(int(feedback.weapon_effects.impacts) == 1, "legacy weapon-effects owner renders the surface cue")

	# F9 quality budget and F10 metrics are honest for the new owners.
	feedback.quality_controls.select_quality(2)
	check(int(feedback.player_fx.quality) == 2 and feedback.impacts.limit() == 20, "Extreme reaches both player FX owners")
	feedback.quality_controls.select_quality(0)
	check(int(feedback.player_fx.quality) == 0 and feedback.impacts.limit() == 6, "F9 Low reaches both player FX owners")
	feedback.player_fx.advance(0.05)
	check(float(feedback.player_fx.model().heartbeat) == 0.0, "F9 Low disables the heartbeat through the composition")
	feedback.quality_controls.select_quality(1)
	feedback._update_metrics()
	for key: String in ["player_fx_low", "player_fx_heartbeat", "player_fx_direction", "player_fx_cues", "impact_pool", "impact_active", "impact_family", "impact_counters"]:
		check(feedback.quality_controls.metrics.has(key), "F10 reports " + key)
	check(int(feedback.quality_controls.metrics.impact_pool) >= 1, "F10 impact pool is the live measured value")
	check(feedback.quality_controls.metrics.player_fx_direction == "actor", "F10 reports the live direction source")

	# Shield break: distinct cue, suppressed under genuine spawn protection.
	feedback.apply_events([{"id": 12, "type": "damage", "actor": 0, "source": 1, "amount": 40, "shieldBreak": true, "shield": 30}], 0)
	feedback.flush_effects()
	check(feedback.player_fx.break_remaining > 0.0 and int(feedback.player_fx.counters.break) == 1, "authoritative shield break cues once")
	local.protection = 2.0
	feedback.apply_state(state)
	feedback.apply_events([{"id": 13, "type": "damage", "actor": 0, "source": 1, "amount": 40, "shieldBreak": true, "shield": 30}], 0)
	feedback.flush_effects()
	check(int(feedback.player_fx.counters.suppressed) == 1, "spawn protection suppresses the break cue")
	check(int(feedback.player_fx.counters.break) == 1, "immunity never adds a break cue")

	# Death then protected respawn.
	local.protection = 0.0
	local.health = 0.0
	local.dead = 1
	feedback.apply_state(state)
	check(feedback.player_fx.death_remaining > 0.0 and int(feedback.player_fx.counters.death) == 1, "composition elimination cue")
	local.health = 100.0
	local.dead = 0
	local.protection = 1.5
	feedback.apply_state(state)
	check(feedback.player_fx.materialize_remaining > 0.0 and int(feedback.player_fx.counters.respawn) == 1, "composition materialize cue matches protection")

	# Focus loss drains every new owner; recovery cannot replay consumed events.
	context.application_focused = false
	feedback.flush_effects()
	check(feedback.player_fx.damage_remaining == 0.0 and feedback.player_fx.low_health == 0.0 and feedback.player_fx.materialize_remaining == 0.0, "focus loss drains player-state cues")
	check(feedback.impacts.snapshot().active == 0, "focus loss drains impacts")
	check(not feedback.overlay.visible, "overlay hidden after drain")
	context.application_focused = true
	feedback.apply_state(state)
	var damage_before: int = feedback.player_fx.counters.damage
	feedback.apply_events([{"id": 10, "type": "damage", "actor": 0, "source": 1, "amount": 12}], 0)
	feedback.flush_effects()
	check(int(feedback.player_fx.counters.damage) == damage_before, "focus recovery cannot replay a consumed event")

	# A stale snapshot window drains the same owners until fresh authority.
	context.snapshot_watch.value = true
	feedback.flush_effects()
	check(feedback.player_fx.damage_remaining == 0.0 and feedback.impacts.snapshot().active == 0, "stale snapshots drain player FX")
	check(not feedback.overlay.visible, "overlay hidden while stale")
	context.snapshot_watch.value = false
	feedback.apply_state(state)
	check(feedback.effects_active, "fresh authority resumes player FX")

	# Results and round restart drain; a reused public ID is accepted once.
	feedback.apply_state({"over": true, "time": 2.0})
	check(feedback.player_fx.local_id == -1 and feedback.player_fx.damage_remaining == 0.0 and feedback.impacts.snapshot().active == 0, "results drain every player FX owner")
	check(int(feedback.player_fx.counters.damage) == 0 and int(feedback.impacts.counters.shown) == 0, "results clear FX counters")
	state.time = 3.0
	feedback.apply_state(state)
	feedback.apply_events([{"id": 10, "type": "damage", "actor": 0, "source": 1, "amount": 12}], 0)
	feedback.flush_effects()
	check(int(feedback.player_fx.counters.damage) == 1, "fresh round accepts a reused public ID once")

	context.free()
	if failures.is_empty():
		print("PLAYER_FX_INTEGRATION_OK checks=", checks)
	else:
		print("PLAYER_FX_INTEGRATION_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
