extends SceneTree
## Integrated fixture for the supplemental Moth world cues routed by
## PortCombatFeedback. Source parity (`game/view.mjs`): the heal accent for
## health/megahealth pickups and mender-heal, and the effect-teleport accent for
## teleport/teleporter ends, are the only Moth beats the integrated pipeline
## lacks. Damage sparks and explosions already belong to weapon_effects,
## particles, blood and player_fx/impacts, so they must never reach this module.
##
## Runs whole once executed. Authored source-only here: no engine, import,
## render, server or live authority was run. Execute under the native grant with:
##   godot --headless --path godot --script res://tests/combat_integration/support_cues.gd
const Feedback = preload("res://world/combat_feedback.gd")
const Rig = preload("res://first_person/rig.gd")
const Client = preload("res://net/client.gd")
const FX = preload("res://graphics_fx/moth_world.gd")
const Fixtures = preload("res://tests/graphics_fx/fixture_library.gd")
var checks := 0
var failures: Array[String] = []

class Context extends Node3D:
	var camera := Camera3D.new()
	var rig: Node
	var client: Node
	var world := Node3D.new()
	var current_id := "meridian-exchange"
	var phase := 3
	var application_focused := true
	func can_capture_pointer() -> bool: return true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func active_keys(fx: Node3D) -> Dictionary:
	var keys := {}
	for slot: Dictionary in fx.slots:
		if slot.remaining > 0: keys[slot.key] = true
	return keys

# Every pooled slot is stopped, unbound and still inside the fixed pool.
func transiently_hidden(fx: Node3D) -> bool:
	if fx.slots.size() > FX.CAP or fx.get_child_count() > FX.CAP: return false
	for slot: Dictionary in fx.slots:
		if slot.remaining > 0 or slot.node.visible or slot.material.get_shader_parameter("frame_texture") != null: return false
	return true

func run() -> void:
	# The static filter is the whole non-overlap contract: heal/teleport only.
	check(FX.support_only({"type":"pickup","kind":"health"}) and FX.support_only({"type":"pickup","kind":"megahealth"}), "health pickups are supplemental cues")
	check(FX.support_only({"type":"mender-heal"}) and FX.support_only({"type":"teleporter"}) and FX.support_only({"type":"teleport"}), "mender heal and both teleport spellings are supplemental cues")
	check(not FX.support_only({"type":"pickup","kind":"armor"}) and not FX.support_only({"type":"explosion"}) and not FX.support_only({"type":"damage"}) and not FX.support_only({"type":"shot"}), "armor, explosions, damage and shots are excluded")

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
	feedback.weapon_effects.set_process(false)
	feedback.world_particles.set_process(false)
	feedback.shields.set_process(false)
	# Deterministic fixture sheets, exactly like tests/graphics_fx/regression.gd;
	# the shipped MothLibrary provider still owns the live baked assets.
	feedback.moth_effects.configure_resources(Fixtures.resources())
	# Source-shaped fixture (actual Match.emit + Horde EventCursor payloads).
	var fixture: Dictionary = Fixtures.events()
	var events: Array = fixture.events
	var actors: Array = []
	for actor: Dictionary in fixture.actors:
		actors.append({"id":actor.id,"team":0,"health":100,"dead":0,"weapon":0,
			"x":actor.x,"y":actor.y,"z":actor.z,"yaw":0,"pitch":0,"vehicleId":null,"vehicleSeat":null})
	var state := {"mapId":"meridian-exchange","time":1.0,"over":false,"actors":actors}
	# Immutability is checked on the ACTUAL event input and the derived state that
	# is really passed, not on the source fixture dictionary.
	var event_input := JSON.stringify(events)
	var state_snapshot := JSON.stringify(state)
	# A preference chosen before resources are injected must not error or reset.
	var probe := FX.new()
	root.add_child(probe)
	probe.set_quality(0)
	probe.configure_resources(Fixtures.resources())
	probe.consume([{"id":1,"type":"pickup","actor":8,"kind":"health"}], 0, actors)
	check(probe.quality == 0 and probe.spawned == 0, "quality 0 set before configuration drops cues without error")
	probe.free()
	feedback.apply_state(state)
	check(feedback.effects_active, "fresh public frame activates integrated effects")
	check(is_instance_valid(feedback.weapon_effects) and is_instance_valid(feedback.moth_effects), "integrated pipeline present")
	check(feedback.moth_effects.quality == 1 and not feedback.moth_effects.reduced_motion, "combat quality propagates; reduced motion off by default")
	check(feedback.audio_feedback._muted, "audio muted explicitly for the whole fixture")

	# Accepted supplemental cues spawn exactly once from authoritative positions.
	feedback.apply_events(events, 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "health pickup, mender heal and both teleport ends spawn once")
	var keys := active_keys(feedback.moth_effects)
	check(keys.has("effect-heal") and keys.has("effect-teleport"), "supplemental heal/teleport cues present")
	check(not keys.has("effect-explosion") and not keys.has("spark-impact"), "no Moth damage spark or explosion duplicate")
	check(feedback.explosions == 1, "accepted explosion is owned by the integrated weapon pipeline")
	var heal_hits := 0
	var tele_hits := 0
	for slot: Dictionary in feedback.moth_effects.slots:
		if slot.remaining <= 0: continue
		if slot.key == "effect-heal":
			if slot.node.position == Vector3(5.4,1.5,0) or slot.node.position == Vector3(5.4,1.5,-8): heal_hits += 1
		elif slot.key == "effect-teleport":
			if slot.node.position == Vector3(1.8,1.5,0) or slot.node.position == Vector3(1.8,1.5,-8): tele_hits += 1
	check(heal_hits == 2, "pickup uses the snapshot actor position and mender uses event xz with snapshot y")
	check(tele_hits == 2, "teleport cues use both authoritative ends")
	check(JSON.stringify(events) == event_input, "actual event input is never mutated")
	check(JSON.stringify(state) == state_snapshot, "actual derived state snapshot is never mutated")

	# Central _fresh_events dedup: a retained replay is consumed, not replayed.
	feedback.apply_events(events, 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "retained public IDs do not replay supplemental cues")
	check(feedback.moth_effects.duplicates == 0, "central dedup rejects before the Moth seen table")

	# Preference toggle WHILE cues are live must hide them immediately, inside the
	# bounded pool, without clearing the accepted-ID history or the spawn counter.
	feedback.quality_controls.select_quality(0)
	check(feedback.moth_effects.quality == 0, "Low quality propagates to the Moth module")
	check(feedback.moth_effects.active_count() == 0, "Low quality immediately clears the live cues")
	check(transiently_hidden(feedback.moth_effects), "cleared slots are hidden, unbound and stay bounded")
	check(feedback.moth_effects.spawned == 4, "transient clear keeps the monotonic spawn count")
	feedback.apply_events([{"id":101,"type":"pickup","actor":8,"kind":"health"},{"id":102,"type":"teleport","actor":7,"from":{"x":1,"y":1,"z":1},"to":{"x":2,"y":1,"z":2}}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4 and feedback.moth_effects.active_count() == 0, "Low quality drops new cues while consuming their IDs")

	# Restoring quality must not resurrect the cleared cue or replay a consumed ID.
	feedback.quality_controls.select_quality(1)
	var history_before: int = feedback.moth_effects.spawned
	feedback.moth_effects.consume([{"id":4,"type":"pickup","actor":8,"kind":"health"}], 0, actors)
	check(feedback.moth_effects.spawned == history_before, "transient clear preserves the Moth accepted-ID history")
	feedback.apply_events([{"id":101,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "quality restore neither resurrects nor replays a dropped cue")
	feedback.apply_events([{"id":103,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 5 and feedback.moth_effects.active_count() == 1, "restored quality cues new events only")

	# Reduced motion hides the live cue at once and drops new ones until restored.
	feedback.moth_effects.set_reduced_motion(true)
	check(feedback.moth_effects.active_count() == 0 and transiently_hidden(feedback.moth_effects), "reduced motion immediately hides the live cue")
	feedback.apply_events([{"id":104,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 5, "reduced motion drops new supplemental cues")
	feedback.moth_effects.set_reduced_motion(false)
	feedback.apply_events([{"id":105,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 6 and feedback.moth_effects.active_count() == 1, "clearing reduced motion cues new events only")
	feedback.apply_events([{"id":104,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 6, "a cue dropped by reduced motion cannot replay after restore")

	# Hard bound and immediate drain.
	var burst: Array = []
	for index: int in range(80):
		burst.append({"id":1000+index,"type":"teleport","actor":7,"from":{"x":index,"y":0,"z":0},"to":{"x":index,"y":0,"z":1}})
	feedback.apply_events(burst, 0)
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() <= FX.CAP and feedback.moth_effects.slots.size() <= FX.CAP and feedback.moth_effects.get_child_count() <= FX.CAP, "supplemental cues stay inside the fixed pool")
	feedback.clear_round()
	check(feedback.moth_effects.active_count() == 0 and feedback.moth_effects.slots.is_empty() and feedback.moth_effects.seen.is_empty() and feedback.moth_effects.get_child_count() == 0, "round clear frees live cues and the ID history")

	# Round reset clears IDs, so a previously consumed ID is legitimately reusable.
	feedback.apply_state(state)
	feedback.apply_events([{"id":4,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 1, "round reset clears the accepted-ID history so IDs can be reused")
	feedback.clear_round()

	# Hidden events are dropped, and a live cue is hidden rather than left flashing.
	feedback.apply_state(state)
	feedback.apply_events([{"id":7001,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() == 1, "live cue visible while focused")
	context.application_focused = false
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() == 0 and transiently_hidden(feedback.moth_effects), "focus loss hides live Moth cues instead of leaving them flashing")
	check(feedback.moth_effects.spawned == 1, "focus loss does not clear the transient spawn counter")
	feedback.apply_events([{"id":7002,"type":"pickup","actor":8,"kind":"health"}], 0)
	context.application_focused = true
	feedback.apply_state(state)
	feedback.apply_events([{"id":7002,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 1 and feedback.moth_effects.active_count() == 0, "a hidden cue is consumed and cannot replay on resume")

	check(JSON.stringify(state) == state_snapshot, "derived state remains unmutated after the full run")
	context.free()
	print("COMBAT_SUPPORT_CUES ", JSON.stringify({"checks":checks,"failures":failures,"executed":true}))
	quit(0 if failures.is_empty() else 1)
