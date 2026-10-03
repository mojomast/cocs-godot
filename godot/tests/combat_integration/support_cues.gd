extends SceneTree
## Integrated fixture for the supplemental Moth world cues now routed by
## PortCombatFeedback. Source parity (`game/view.mjs`): the heal accent for
## health/megahealth pickups and mender-heal, and the effect-teleport accent for
## teleport/teleporter ends, are the only Moth beats the integrated pipeline
## lacks. Damage sparks and explosions already belong to weapon_effects,
## particles, blood and player_fx/impacts, so they must never reach this module.
##
## Authored source-only. It was NOT executed in this environment: no engine,
## import, render, server or live authority ran. Execute later under the native
## grant with:
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
	var frozen := JSON.stringify(fixture)
	var actors: Array = []
	for actor: Dictionary in fixture.actors:
		actors.append({"id":actor.id,"team":0,"health":100,"dead":0,"weapon":0,
			"x":actor.x,"y":actor.y,"z":actor.z,"yaw":0,"pitch":0,"vehicleId":null,"vehicleSeat":null})
	var state := {"mapId":"meridian-exchange","time":1.0,"over":false,"actors":actors}
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
	check(JSON.stringify(fixture) == frozen, "fixture actors and events are never mutated")

	# Central _fresh_events dedup: a retained replay is consumed, not replayed.
	feedback.apply_events(events, 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "retained public IDs do not replay supplemental cues")
	check(feedback.moth_effects.duplicates == 0, "central dedup rejects before the Moth seen table")

	# Quality and reduced-motion preferences gate the cues.
	feedback.quality_controls.select_quality(0)
	check(feedback.moth_effects.quality == 0, "Low quality propagates to the Moth module")
	feedback.apply_events([{"id":101,"type":"pickup","actor":8,"kind":"health"},{"id":102,"type":"teleport","actor":7,"from":{"x":1,"y":1,"z":1},"to":{"x":2,"y":1,"z":2}}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "Low quality drops new supplemental cues while consuming their IDs")
	feedback.quality_controls.select_quality(1)
	feedback.moth_effects.set_reduced_motion(true)
	feedback.apply_events([{"id":103,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 4, "reduced motion drops new supplemental cues")
	feedback.moth_effects.set_reduced_motion(false)
	feedback.apply_events([{"id":104,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 5, "restoring the preference restores new cues only")
	feedback.apply_events([{"id":101,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 5, "a cue dropped by quality cannot replay after restore")

	# Hard bound and immediate drain.
	var burst: Array = []
	for index: int in range(80):
		burst.append({"id":1000+index,"type":"teleport","actor":7,"from":{"x":index,"y":0,"z":0},"to":{"x":index,"y":0,"z":1}})
	feedback.apply_events(burst, 0)
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() <= FX.CAP and feedback.moth_effects.slots.size() <= FX.CAP and feedback.moth_effects.get_child_count() <= FX.CAP, "supplemental cues stay inside the fixed pool")
	feedback.clear_round()
	check(feedback.moth_effects.active_count() == 0 and feedback.moth_effects.slots.is_empty() and feedback.moth_effects.seen.is_empty() and feedback.moth_effects.get_child_count() == 0, "round clear frees live supplemental cues")

	# Hidden events are dropped, and a live cue is reset rather than left flashing.
	feedback.apply_state(state)
	feedback.apply_events([{"id":7001,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() == 1, "live cue visible while focused")
	context.application_focused = false
	feedback.flush_effects()
	check(feedback.moth_effects.active_count() == 0 and feedback.moth_effects.slots.is_empty(), "focus loss resets live Moth cues instead of leaving them flashing")
	feedback.apply_events([{"id":7002,"type":"pickup","actor":8,"kind":"health"}], 0)
	context.application_focused = true
	feedback.apply_state(state)
	feedback.apply_events([{"id":7002,"type":"pickup","actor":8,"kind":"health"}], 0)
	feedback.flush_effects()
	check(feedback.moth_effects.spawned == 0, "a hidden cue is consumed and cannot replay on resume")

	context.free()
	print("COMBAT_SUPPORT_CUES ", JSON.stringify({"checks":checks,"failures":failures,"authored_not_executed":true}))
	quit(0 if failures.is_empty() else 1)
