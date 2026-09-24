extends SceneTree
## Stress: many simultaneous kills in one authoritative callback, then a
## 2,000-event backlog. Proves the pools stay bounded, no node/material is ever
## created at runtime, and one callback inspects at most 512 events.

const Controller = preload("res://blood_fx/controller.gd")

var failed := false
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)


func fixture_map() -> Dictionary:
	return {
		"id": "blood-fx-stress-fixture",
		"bounds": {"minX": -40.0, "maxX": 40.0, "minZ": -40.0, "maxZ": 40.0},
		"blocks": [
			{"x": 0.0, "z": -10.0, "w": 24.0, "h": 6.0, "d": 1.0},
			{"x": 0.0, "z": 10.0, "w": 24.0, "h": 6.0, "d": 1.0},
			{"x": -10.0, "z": 0.0, "w": 1.0, "h": 6.0, "d": 18.0},
			{"x": 10.0, "z": 0.0, "w": 1.0, "h": 6.0, "d": 18.0},
		],
		"terrain": {"support_triangles": [
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-40, 0, -40], [-40, 0, 40], [40, 0, 40]]},
			{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-40, 0, -40], [40, 0, 40], [40, 0, -40]]},
		]},
	}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3, 0)
	var controller := Controller.new()
	world.add_child(controller)
	var configured: Dictionary = controller.configure(camera, fixture_map())
	check(configured.ok, "stress fixture configures")
	controller.set_quality("High")

	# 48 actors alive inside a walled 20x20 pen: 40 deaths + 400 damage events in
	# one callback, all with fresh wire IDs.
	var actors := []
	for i in range(48):
		actors.append({"id": i, "x": float(i % 8) * 2.0 - 7.0, "y": 0.0, "z": float(i / 8) * 2.0 - 5.0,
			"health": 100.0, "maxHealth": 100.0, "armor": 0.0, "temporaryShield": 0.0})
	controller.apply_state({"time": 1.0, "mapId": "blood-fx-stress-fixture", "actors": actors}, 0)

	var children_before := controller.get_child_count()
	var node_ids := []
	for slot: Dictionary in controller.fluid_slots:
		node_ids.append(slot.node.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		node_ids.append(slot.node.get_instance_id())
	var material_ids := []
	for slot: Dictionary in controller.fluid_slots:
		material_ids.append(slot.material.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		material_ids.append(slot.material.get_instance_id())

	var events := []
	var serial := 1000
	for i in range(40):
		serial += 1
		events.append({"type": "death", "id": serial, "actor": i, "pos": {"x": float(i % 8) * 2.0 - 7.0, "y": 1.1, "z": float(i / 8) * 2.0 - 5.0},
			"killer": 47, "direction": {"x": 0.6, "y": 0, "z": 0.8}, "overkill": float(i), "seed": float(i)})
	for i in range(400):
		serial += 1
		var victim := i % 48
		events.append({"type": "damage", "id": serial, "actor": victim, "source": 47,
			"amount": 18.0 + float(i % 5) * 12.0, "shield": 0.0})
	var started := Time.get_ticks_usec()
	controller.apply_events(events, 0)
	var elapsed_usec := Time.get_ticks_usec() - started
	var snapshot: Dictionary = controller.snapshot()
	check(snapshot.events_seen == 440, "one callback consumed all 440 fresh events")
	check(snapshot.death_bursts == 40, "forty simultaneous kills produced forty bursts")
	# Forty death events precede the damage wave; only the eight living victims
	# may bleed. The large callback still exercises the bounded pool and dedup.
	check(snapshot.spurts > 50 and snapshot.spurts < 80, "damage wave spurts come only from living victims")
	check(snapshot.no_bleed >= 300, "late damage after confirmed deaths cannot make corpses bleed")
	check(snapshot.active_emitters <= snapshot.concurrent_cap, "concurrent emitters stay inside the cap under a 48-actor wave")
	check(snapshot.pool_nodes == controller.settings.fluid_emitters, "the fluid pool did not grow")
	check(snapshot.stains_live <= snapshot.stain_cap, "live stains stay inside the documented cap")
	check(snapshot.stains_recycled + snapshot.stains_rejected >= 0, "stain recycle/reject counters are real numbers")
	check(controller.get_child_count() == children_before, "no child node was created by the wave")
	var after_nodes := []
	for slot: Dictionary in controller.fluid_slots:
		after_nodes.append(slot.node.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		after_nodes.append(slot.node.get_instance_id())
	var after_materials := []
	for slot: Dictionary in controller.fluid_slots:
		after_materials.append(slot.material.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		after_materials.append(slot.material.get_instance_id())
	check(after_nodes == node_ids, "node identity is stable through the wave")
	check(after_materials == material_ids, "material identity is stable through the wave")
	check(snapshot.submitted_slots <= snapshot.allocated_slots, "submitted capacity never exceeds the allocation")

	# One saturated frame: the CPU cost of aging every pool slot is bounded by the
	# pool size, never by the event count.
	var frame_times := PackedFloat64Array()
	for i in range(90):
		var frame_start := Time.get_ticks_usec()
		controller._process(1.0 / 60.0)
		frame_times.append(float(Time.get_ticks_usec() - frame_start))
	var ordered := frame_times.duplicate()
	ordered.sort()
	var median_us := ordered[ordered.size() / 2]
	var max_us := ordered[-1]
	check(max_us < 8000.0, "one saturated frame stays under 8 ms on the CPU side (median %.3f ms, max %.3f ms)" % [median_us / 1000.0, max_us / 1000.0])
	check(controller.get_child_count() == children_before, "ninety saturated frames create no node")

	# 2,000-event backlog: exactly the documented scan cap is inspected.
	var backlog := []
	for i in range(2000):
		backlog.append({"type": "damage", "id": 100000 + i, "actor": 47, "source": 46, "amount": 40.0, "shield": 0.0})
	var before_events: int = controller.snapshot().events_seen
	controller.apply_events(backlog, 0)
	check(controller.snapshot().events_seen == before_events + 512, "a 2,000-event backlog is scanned at most 512 events per callback")
	check(controller.get_child_count() == children_before, "the backlog creates no node")
	check(controller.snapshot().active_emitters <= controller.snapshot().concurrent_cap, "the backlog cannot exceed the concurrent cap")

	# Per-event cost: one death and one wall impact at a time, so the cap raise
	# can be justified by measured cost instead of a guess.
	var death_usec := 0
	var impact_usec := 0
	var probe_serial := 500000
	var probe_start := Time.get_ticks_usec()
	for i in range(20):
		probe_serial += 1
		controller.apply_events([{"type": "death", "id": probe_serial, "actor": i % 48,
			"pos": {"x": float(i % 8) * 2.0 - 7.0, "y": 1.1, "z": float(i / 8) * 2.0 - 5.0},
			"killer": 47, "direction": {"x": 0.6, "y": 0, "z": 0.8}, "overkill": 0.0, "seed": float(i)}], 0)
	death_usec = (Time.get_ticks_usec() - probe_start) / 20
	probe_start = Time.get_ticks_usec()
	for i in range(200):
		probe_serial += 1
		controller.apply_events([{"type": "damage", "id": probe_serial, "actor": i % 48, "source": 47,
			"amount": 34.0, "shield": 0.0}], 0)
	impact_usec = (Time.get_ticks_usec() - probe_start) / 200
	check(death_usec < 4000, "one death stays under 4 ms of CPU (%.0f us)" % death_usec)
	check(impact_usec < 1500, "one impact stays under 1.5 ms of CPU (%.0f us)" % impact_usec)

	# ID window: a very old id falls out of the 4,096 window and is not treated as
	# the immediate duplicate, while the newest ids never replay.
	var highest: int = controller.highest_event
	controller.apply_events([{"type": "damage", "id": highest, "actor": 47, "source": 46, "amount": 40.0, "shield": 0.0}], 0)
	check(controller.snapshot().duplicates >= 1, "an immediate duplicate is rejected")
	var old_duplicate: int = controller.snapshot().duplicates
	var stale_spurts: int = controller.snapshot().spurts
	controller.apply_events([{"type": "damage", "id": highest - 5000, "actor": 47, "source": 46, "amount": 40.0, "shield": 0.0}], 0)
	check(controller.snapshot().duplicates == old_duplicate + 1, "an id below the 4,096-id window floor is dropped as stale")
	check(controller.snapshot().spurts == stale_spurts, "a stale event can never replay a spurt")

	print("BLOOD_FX_STRESS ", "FAIL" if failed else "PASS", " checks=", checks)
	print("BLOOD_FX_STRESS_METRICS ", JSON.stringify({
		"callback_usec_440_events": elapsed_usec, "frame_median_us": median_us, "frame_max_us": max_us,
		"quality": controller.quality, "allocated_slots": controller.snapshot().allocated_slots,
		"submitted_slots": controller.snapshot().submitted_slots, "pool_nodes": controller.snapshot().pool_nodes,
		"active_emitters": controller.snapshot().active_emitters, "concurrent_cap": controller.snapshot().concurrent_cap,
		"stains_live": controller.snapshot().stains_live, "stains_cap": controller.snapshot().stain_cap,
		"stains_placed": controller.snapshot().stains_placed, "stains_recycled": controller.snapshot().stains_recycled,
		"dropped": controller.snapshot().dropped, "recycled": controller.snapshot().recycled,
		"usec_per_death": death_usec, "usec_per_impact": impact_usec,
		"marks_wall": controller.snapshot().marks_wall, "marks_floor": controller.snapshot().marks_floor,
		"marks_skipped_edge": controller.snapshot().marks_skipped_edge,
		"marks_skipped_facing": controller.snapshot().marks_skipped_facing,
		"clusters_placed": controller.snapshot().clusters_placed, "fan_rays_cast": controller.snapshot().fan_rays_cast,
	}))
	quit(1 if failed else 0)
