extends SceneTree
## Actual Combined Arms graphics adapter, actual imported rig, public source frames.
const Graphics = preload("res://combined_arms/graphics.gd")
const Client = preload("res://net/client.gd")
const Presentation = preload("res://world/presentation.gd")
const Controls = preload("res://combined_arms/controls.gd")
const Wire = preload("res://world/projectiles.gd")
const Origin = preload("res://weapon_effects/origin.gd")
var failures: Array[String] = []
var checks := 0

class View extends Node3D:
	var camera := Camera3D.new()
	func _ready() -> void: add_child(camera)

class Context extends Node3D:
	var world := View.new()
	var net := Client.new()
	var actors := Presentation.new()
	var controls := Controls.new()
	var map_id := "sunscar-convoy"
	var phase := "active"
	var state := {}
	var actor := {}
	var vehicle := {}
	func eligible() -> bool: return phase == "active"
	func aim_requested() -> bool: return false
	func _ready() -> void:
		add_child(world)
		add_child(actors)
		add_child(net)
		net.set_process(false)
		net.actor_id = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_integration/source.json"))
	var context := Context.new()
	root.add_child(context)
	var graphics := Graphics.new()
	context.add_child(graphics)
	graphics.attach_to(context)
	var feedback: Node = graphics.feedback
	feedback.set_process(false)
	feedback.audio_feedback.set_muted(true)
	graphics.rig.set_process(false)
	context.state = source.frames[0].state.duplicate(true)
	context.state.mapId = context.map_id
	context.actor = context.state.actors[0]
	context.world.camera.position = Wire.point(source.frames[0].camera)
	graphics.rig.apply_actor(context.actor,true)
	for i in 20: graphics.rig.advance(1.0/60)
	graphics.public_active = true
	graphics.apply_state()
	check(feedback.effect_camera == context.world.camera and feedback.effect_session == context and feedback.effect_local_id == 0, "graphics parent resolves real session.world.camera and net identity")
	check(feedback.attached_rig == graphics.rig and feedback.occlusion.map_id == "sunscar-convoy", "actual Combined Arms rig and semantic geometry attached")
	check(feedback.world_particles.budget == 32768 and feedback.world_particles.snapshot().collision_shapes > 0, "Combined Arms particles configured from source collisions")
	check(feedback.shields.actor_visuals == context.actors.actors, "Combined Arms shield actor visuals bound")
	var before: Vector3 = graphics.rig.anchors.Muzzle0.global_position
	graphics.apply_events(source.frames[0].events)
	check(feedback.weapon_effects.flashes == 0 and graphics.rig.recoil_count == 1, "actual adapter applies recoil and queues FX")
	# Deliberately omit another rig process: source events arrive after rig's
	# process in the production Combined Arms child order.
	feedback.flush_effects()
	check(before.distance_to(graphics.rig.anchors.Muzzle0.global_position) > 0.00001, "late events refresh animated anchor before FX consumption")
	check(feedback.weapon_effects.flashes == 1 and graphics.rig.recoil_count == 1, "late refresh does not double recoil or flash")
	for line: Dictionary in feedback.weapon_effects.lines:
		var mapped := Origin.map_tip(context.world.camera,graphics.rig.weapon_camera,line.tip)
		check(context.world.camera.unproject_position(line.start).distance_to(mapped.pixel) < 0.001, "Combined Arms animated muzzle and tracer identical projection")
	context.actor.vehicleId = 12
	graphics.rig.apply_actor(context.actor,true)
	var hidden_event: Dictionary = source.frames[0].events.back().duplicate(true)
	hidden_event.id = 500
	hidden_event.time = 20.0
	graphics.apply_events([hidden_event])
	feedback.flush_effects()
	check(not graphics.rig.showing and feedback.weapon_effects.flashes == 1, "mounted owner emits no infantry muzzle")
	context.actor.vehicleId = null
	graphics.rig.apply_actor(context.actor,true)
	graphics.apply_events([hidden_event])
	feedback.flush_effects()
	check(feedback.weapon_effects.flashes == 1, "dismount cannot replay mounted event")
	graphics.reset()
	check(feedback.world_particles.snapshot().active_emitters == 0 and feedback.shields.debug_state().materials == 0 and feedback.weapon_effects.lines.is_empty(), "actual adapter reset drains every controller")
	feedback.flush_effects()
	check(not feedback.effects_active, "no resumption without fresh public frame")
	context.free()
	print("COMBAT_COMBINED_INTEGRATION ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
