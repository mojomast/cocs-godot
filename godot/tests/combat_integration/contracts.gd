extends SceneTree
const Feedback = preload("res://world/combat_feedback.gd")
const Rig = preload("res://first_person/rig.gd")
const Origin = preload("res://weapon_effects/origin.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
const Projectiles = preload("res://world/projectiles.gd")
const Client = preload("res://net/client.gd")
var checks := 0
var failures: Array[String] = []
var maximum_error := 0.0

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

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/combat_integration/source.json"))
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
	var catalog := Occlusion.Catalog.new()
	check(catalog.open(), "locked catalog opens")
	for batch: Dictionary in source.rays:
		var query := Occlusion.new()
		check(query.configure(context.camera,catalog.resolve_map(batch.id)), "semantic geometry config " + batch.id)
		for row: Dictionary in batch.cases:
			check(query.segment_blocked(Projectiles.point(row.from),Projectiles.point(row.to)) == row.blocked, "source rayWorld parity %s %.3f/%.3f" % [batch.id,row.distance,row.length])
	for frame: Dictionary in source.frames:
		feedback.clear_round()
		context.camera.position = Projectiles.point(frame.camera)
		var actor: Dictionary = frame.state.actors[0]
		context.rig.apply_actor(actor,true)
		context.rig.apply_aim(true)
		for i in 45: context.rig.advance(1.0/60)
		feedback.apply_state(frame.state)
		var before := JSON.stringify(frame)
		feedback.apply_events(frame.events,0)
		check(feedback.weapon_effects.flashes == 0, "FX queued until real rig refresh")
		context.rig.apply_events(frame.events,0)
		context.rig.advance(1.0/60)
		feedback.flush_effects()
		check(context.rig.external_muzzle_fx and not context.rig.flash.visible, "fallback muzzle disabled")
		check(feedback.weapon_effects.flashes == context.rig.get_muzzle_count(), "actual source volley flashes all real barrels weapon %d" % actor.weapon)
		check(feedback.tracers.is_empty() and feedback.blasts.is_empty() and feedback.moth_effects.slots.is_empty(), "no duplicate legacy combat FX")
		for line: Dictionary in feedback.weapon_effects.lines:
			var matching := false
			for event: Dictionary in frame.events:
				if event.get("type") == "shot" and line.end == Projectiles.point(event.to): matching = true
			check(matching, "identical authority endpoint")
			var mapped := Origin.map_tip(context.camera, context.rig.weapon_camera, line.tip)
			var error: float = context.camera.unproject_position(line.start).distance_to(mapped.pixel)
			maximum_error = maxf(maximum_error,error)
			check(error < 0.001, "animated ADS muzzle projection subpixel")
		for event: Dictionary in frame.events:
			if event.type != "launch": continue
			var id := Projectiles.launch_projectile_id(event)
			check(feedback.projectiles.markers.has(id) and feedback.projectiles.launch_origins.has(id), "sourceId launch association exact")
			if feedback.projectiles.launch_origins.has(id):
				check(feedback.projectiles.markers[id].position == feedback.projectiles.launch_origins[id].muzzle, "new launch starts at animated muzzle")
			feedback.projectiles._process(0.13)
			check(feedback.projectiles.markers[id].position == feedback.projectiles.authoritative[id].pos and feedback.projectiles.launch_origins.is_empty(), "short convergence expires to exact authority")
		check(JSON.stringify(frame) == before, "controllers never mutate direct native public frames")
		var shots: int = feedback.shots
		var flashes: int = feedback.weapon_effects.flashes
		feedback.apply_events(frame.events,0)
		feedback.flush_effects()
		check(feedback.shots == shots and feedback.weapon_effects.flashes == flashes, "shared boundary deduplicates public IDs")
	var block: Dictionary = catalog.resolve_map("meridian-exchange").blocks[0]
	var crossing := {"id":850,"type":"shot","actor":1,"weapon":0,"time":source.frames.back().state.time,
		"from":{"x":block.x-block.w/2.0-0.1,"y":block.h/2.0,"z":block.z},
		"to":{"x":block.x+block.w/2.0+0.1,"y":block.h/2.0,"z":block.z}}
	var previous_tracers: int = feedback.weapon_effects.tracer_count
	feedback.apply_events([crossing],0)
	feedback.flush_effects()
	check(feedback.weapon_effects.tracer_count == previous_tracers, "whole authority-to-endpoint segment checked, including remote shots")
	var near: Dictionary = source.nearWall
	feedback.clear_round()
	context.camera.position = Projectiles.point(near.camera)
	context.rig.apply_actor(near.state.actors[0],true)
	context.rig.advance(0.05)
	feedback.apply_state(near.state)
	feedback.apply_events(near.events,0)
	context.rig.apply_events(near.events,0)
	context.rig.advance(0.016)
	feedback.flush_effects()
	check(feedback.weapon_effects.flashes == 0 and feedback.weapon_effects.lines.is_empty() and feedback.hits == 0, "semantic near wall suppresses protruding muzzle and false hits")
	# All three owners + lifecycle, using an actual source frame and explicit
	# integration-only explosion/damage fixtures (not claims of live gameplay).
	var frame: Dictionary = source.frames[0]
	feedback.clear_round()
	context.camera.position = Projectiles.point(frame.camera)
	context.rig.apply_actor(frame.state.actors[0],true)
	context.rig.advance(0.05)
	feedback.apply_state(frame.state)
	feedback.apply_events([{"id":900,"type":"explosion","pos":{"x":0,"y":25,"z":-2}}, {"id":901,"type":"damage","actor":1,"source":0,"amount":12}],0)
	feedback.flush_effects()
	check(feedback.world_particles.snapshot().burst_emitters == 1 and feedback.shields.debug_state().visible_shells == 1 and feedback.hits == 1, "particles shields and local actual-damage HUD integrated")
	var identities: Array = []
	for slot: Dictionary in feedback.world_particles.slots: identities.append([slot.node.get_instance_id(),slot.material.get_instance_id()])
	for quality in [0,1,2,1]:
		feedback.quality_controls.select_quality(quality)
		var expected: int = [8192,32768,1000000][quality]
		check(feedback.world_particles.snapshot().allocated_slots == expected, "shared quality total allocation %d" % expected)
		for i in 32: check(identities[i] == [feedback.world_particles.slots[i].node.get_instance_id(),feedback.world_particles.slots[i].material.get_instance_id()], "quality preserves resource identity")
	feedback._update_metrics()
	check(feedback.quality_controls.metrics.allocated_slots == 32768, "F10 reports measured allocated node amounts")
	feedback._process(0.016)
	feedback._process(0.016)
	check(feedback.shields.debug_state().visible_shells == 1, "ordinary process does not clear shields every frame")
	context.application_focused = false
	feedback.flush_effects()
	feedback.apply_events([{"id":902,"type":"explosion","pos":{"x":0,"y":25,"z":-2}}],0)
	check(feedback.world_particles.snapshot().active_emitters == 0 and feedback.shields.debug_state().visible_shells == 0, "focus loss drains all systems")
	context.application_focused = true
	feedback.apply_state(frame.state)
	feedback.apply_events([{"id":902,"type":"explosion","pos":{"x":0,"y":25,"z":-2}}],0)
	feedback.flush_effects()
	check(feedback.world_particles.snapshot().burst_emitters == 0, "focus recovery cannot replay consumed event")
	while Time.get_ticks_usec()-feedback.last_state_usec <= 850000: await process_frame
	feedback.flush_effects()
	check(not feedback.effects_active and feedback.world_particles.snapshot().active_emitters == 0, "stale snapshots drain age=%d active=%s emitters=%d" % [Time.get_ticks_usec()-feedback.last_state_usec,feedback.effects_active,feedback.world_particles.snapshot().active_emitters])
	feedback.apply_state(frame.state)
	paused = true
	feedback.flush_effects()
	check(not feedback.effects_active, "SceneTree pause drains")
	paused = false
	context.client.actor_id = 1
	feedback.apply_state(frame.state)
	check(feedback.effect_local_id == 1 and feedback.projectiles.launch_origins.is_empty(), "identity change resets projectile ownership")
	for flag in ["spectating", "vehicleId"]:
		var actor: Dictionary = frame.state.actors[0].duplicate(true)
		actor[flag] = true if flag == "spectating" else 22
		context.rig.apply_actor(actor,true)
		check(not context.rig.showing, "production rig hides for " + flag)
	feedback.apply_state({"over":true})
	check(feedback.pending_events.is_empty() and feedback.world_particles.snapshot().active_emitters == 0 and feedback.shields.debug_state().materials == 0, "results reset every owner")
	# Exact native collider provenance; unrelated physics/decor must be excluded.
	var map := Node3D.new()
	context.add_child(map)
	var body := StaticBody3D.new()
	map.add_child(body)
	body.position = Vector3(0,25,0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(6,6,0.2)
	body.add_child(shape)
	await physics_frame
	await physics_frame
	var query := Occlusion.new()
	check(query.configure(context.camera,{"id":"native-fixture","collision_root":map}), "built native physics root accepted")
	check(query.segment_blocked(Vector3(0,25,1),Vector3(0,25,-1)), "native physics near wall blocks")
	check(not query.segment_blocked(Vector3(10,25,1),Vector3(10,25,-1)), "native physics open control")
	check(not query.segment_blocked(Vector3(0,25,1),Vector3(0,25,0.1)), "native exact wall endpoint allowed")
	var projectiles := Projectiles.new()
	context.add_child(projectiles)
	projectiles.configure_occlusion(query.segment_blocked)
	projectiles.apply_state({"rockets":[{"id":77,"owner":0,"weapon":1,"pos":{"x":0,"y":25,"z":-1},"dir":{"x":0,"y":0,"z":-1}}]})
	projectiles.cache_launch({"id":9,"sourceId":78,"time":1,"type":"launch","actor":0,"weapon":1,"pos":{"x":0,"y":25,"z":-1}}, {"position":Vector3(0,25,1)},0)
	check(projectiles.launch_origins.is_empty() and projectiles.markers[77].position == Vector3(0,25,-1), "native wall prevents visual projectile convergence through cover")
	projectiles.cache_launch({"id":10,"time":1,"type":"launch","alt":true,"projectile":77,"actor":0,"weapon":4,"pos":{"x":0,"y":25,"z":-1}}, {"position":Vector3(0,25,-0.8)},0)
	check(projectiles.launch_origins.is_empty(), "explicit ID still requires matching projectile weapon")
	check(Projectiles.launch_projectile_id({"id":78,"type":"launch","alt":true,"weapon":1}) == -1, "missing alt projectile identity never guessed")
	projectiles.free()
	# Real authored roots, not a whole-scene scan or decorative meshes.
	for id: String in ["aurora-basin", "cinder-array", "prism-foundry"]:
		var builder: Node3D = load("res://native_arenas/maps/%s.gd" % id).new()
		context.world.add_child(builder)
		builder.build()
		context.current_id = id
		var native_state: Dictionary = frame.state.duplicate(true)
		native_state.mapId = id
		feedback.apply_state(native_state)
		await physics_frame
		check(feedback.occlusion.collision_root == builder and feedback.occlusion.ready, "actual native root selected " + id)
		check(feedback.world_particles.snapshot().collision_shapes > 20 and feedback.world_particles.budget == 131072, "native built collision occupancy and High allocation " + id)
		var found := false
		for candidate: Node in builder.find_children("*", "CollisionShape3D", true, false):
			if candidate.disabled or not candidate.shape is BoxShape3D: continue
			var half: float = candidate.shape.size.z*0.5
			var from: Vector3 = candidate.global_transform * Vector3(0,0,half+0.1)
			var to: Vector3 = candidate.global_transform * Vector3(0,0,-half-0.1)
			check(feedback.occlusion.segment_blocked(from,to), "authored native collider blocks cosmetic segment " + id)
			found = true
			break
		check(found, "native map has tested actual box collider " + id)
		builder.free()
	context.free()
	print("COMBAT_INTEGRATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"max_projection_error_px":maximum_error}))
	quit(0 if failures.is_empty() else 1)
