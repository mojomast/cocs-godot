extends SceneTree
## Bounded-pool, dedup, shield-only, damage-scaling, quality, stain-placement and
## lifecycle contracts for res://blood_fx/controller.gd. Headless, no rendering:
## the semantic surface backend answers without a physics world.

const Controller = preload("res://blood_fx/controller.gd")
const SurfaceQuery = preload("res://blood_fx/surface_query.gd")
const Settings = preload("res://blood_fx/settings.gd")

var failed := false
var checks := 0
var lines: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)
	lines.append(("PASS " if value else "FAIL ") + message)


# A ramp plus a wall plus a floor: clearly a labelled fixture, not live gameplay.
func fixture_map() -> Dictionary:
	return {
		"id": "blood-fx-fixture",
		"bounds": {"minX": -20.0, "maxX": 20.0, "minZ": -20.0, "maxZ": 20.0},
		"blocks": [
			{"x": 0.0, "z": -6.0, "w": 10.0, "h": 6.0, "d": 1.0, "kind": "building"},
			{"x": 0.0, "z": 6.0, "w": 4.0, "h": 1.2, "d": 4.0, "kind": "crate"},
		],
		"terrain": {
			"support_triangles": [
				{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-20, 0, -20], [-20, 0, 20], [20, 0, 20]]},
				{"indices": [0, 1, 2], "normal": [0, 1, 0], "vertices": [[-20, 0, -20], [20, 0, 20], [20, 0, -20]]},
				{"indices": [0, 1, 2], "normal": [0, 0.8, -0.6], "vertices": [[-6, 0, 4], [-2, 0, 4], [-2, 3, 8]]},
				{"indices": [0, 1, 2], "normal": [0, 0.8, -0.6], "vertices": [[-6, 0, 4], [-2, 3, 8], [-6, 3, 8]]},
			],
			"wall_triangles": [],
			"surfaces": [],
		},
	}


func void_map() -> Dictionary:
	# No bounds and no surfaces: a valid but not-ready backend. Nothing may be
	# stained, and no fixed plane may be invented.
	return {
		"id": "blood-fx-void-fixture",
		"blocks": [],
		"terrain": {"support_triangles": [], "wall_triangles": [], "surfaces": []},
	}


func actor(id: int, x: float, y: float, z: float, health: float = 100.0, armor: float = 0.0, shield: float = 0.0) -> Dictionary:
	return {"id": id, "x": x, "y": y, "z": z, "health": health, "maxHealth": 100.0, "armor": armor,
		"temporaryShield": shield, "vx": 0.0, "vy": 0.0, "vz": 0.0}


func damage(id: int, victim: int, amount: float, source: int, shield: float = 0.0) -> Dictionary:
	return {"type": "damage", "id": id, "actor": victim, "source": source, "amount": amount, "shield": shield}


func state(actors: Array, time: float = 1.0, map: String = "blood-fx-fixture") -> Dictionary:
	return {"time": time, "mapId": map, "actors": actors}


func node_ids(controller: Node) -> Array:
	var ids := []
	for slot: Dictionary in controller.fluid_slots:
		ids.append(slot.node.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		ids.append(slot.node.get_instance_id())
	return ids


func material_ids(controller: Node) -> Array:
	var ids := []
	for slot: Dictionary in controller.fluid_slots:
		ids.append(slot.material.get_instance_id())
	for slot: Dictionary in controller.stain_slots:
		ids.append(slot.material.get_instance_id())
	return ids


## Ratio of the most recently started emitter for a profile (0 when none live).
func profile_ratio(controller: Node, profile: int) -> float:
	var best := 0.0
	var best_serial := -1
	for slot: Dictionary in controller.fluid_slots:
		if slot.profile == profile and slot.remaining > 0.0 and int(slot.serial) > best_serial:
			best_serial = int(slot.serial)
			best = float(slot.ratio)
	return best


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.6, 0)
	camera.current = true
	var controller := Controller.new()
	world.add_child(controller)
	var configured: Dictionary = controller.configure(camera, fixture_map())
	check(configured.ok and configured.surface_kind == "semantic" and configured.surface_ready, "semantic fixture map configures")
	check(controller.snapshot().allocated_slots == controller.budget and controller.snapshot().active_emitters == 0,
		"the shared pool is allocated at configure and no emitter is live yet")

	# --- surface query ---------------------------------------------------------
	var provider := SurfaceQuery.semantic_provider(fixture_map())
	var ramp: Dictionary = provider.call(Vector3(-4, 5, 6), Vector3(-4, -1, 6))
	check(not ramp.is_empty() and absf(float(ramp.position.y) - 1.5) < 0.02, "downward query lands on the ramp surface")
	check(not ramp.is_empty() and absf(float(ramp.normal.y) - 0.8) < 0.02 and absf(float(ramp.normal.z) + 0.6) < 0.02, "ramp hit returns the real tilted normal")
	var wall: Dictionary = provider.call(Vector3(0, 2, -2), Vector3(0, 2, -80))
	check(not wall.is_empty() and absf(float(wall.normal.z) - 1.0) < 0.001 and absf(float(wall.position.z) + 5.5) < 0.02,
		"block wall hit returns the near-face horizontal normal (got %s at %s)" % [str(wall.get("normal")), str(wall.get("position"))])
	var floor_hit: Dictionary = provider.call(Vector3(10, 4, 10), Vector3(10, -2, 10))
	check(not floor_hit.is_empty() and absf(float(floor_hit.position.y)) < 0.01, "open floor hit lands on y=0 support geometry")
	var void_provider := SurfaceQuery.semantic_provider(void_map())
	var nothing: Dictionary = void_provider.call(Vector3(15, 8, 15), Vector3(15, -8, 15))
	check(nothing.is_empty(), "a surface-free backend reports no surface instead of a fixed plane")
	var short_ray: Dictionary = provider.call(Vector3(15, 8, 15), Vector3(15, 6, 15))
	check(short_ray.is_empty(), "a query shorter than the drop never invents a floor")
	check(SurfaceQuery.physics_provider(Node3D.new()).is_valid(), "physics provider Callable is constructible")

	# --- authoritative state ---------------------------------------------------
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 1.0), 1)
	check(controller.active and not controller.snapshot().suspended, "public state activates the controller")
	check(controller.snapshot().allocated_slots == controller.budget, "quality budget is allocated after activation")

	# Shield-only damage: amount == shield -> no bleed.
	controller.apply_events([damage(10, 1, 40.0, 2, 40.0)], 1)
	check(controller.snapshot().no_bleed == 1 and controller.snapshot().spurts == 0, "shield-only damage never bleeds")
	# Dedup by the wire numeric id.
	controller.apply_events([damage(11, 1, 30.0, 2)], 1)
	var after_first: int = controller.snapshot().spurts
	controller.apply_events([damage(11, 1, 30.0, 2)], 1)
	check(controller.snapshot().spurts == after_first and controller.snapshot().duplicates == 1, "duplicate event id is deduplicated")
	# Unknown victim: never invent an actor.
	controller.apply_events([damage(12, 99, 30.0, 2)], 1)
	check(controller.snapshot().unknown_actors == 1, "damage for an actor outside the public snapshot is rejected")
	# Small hit -> entry mist only; big hit -> arterial pulse.
	controller.apply_events([damage(13, 1, 5.0, 2)], 1)
	check(controller.snapshot().mist_events == 1, "small real damage emits an entry mist")
	controller.apply_events([damage(14, 1, 60.0, 2)], 1)
	check(controller.snapshot().arterial_hits == 1, "large real damage emits a heavier arterial pulse")
	check(controller.snapshot().spurt_emitters <= controller.concurrent_cap, "concurrent emitter cap holds")

	# Damage scaling: the same wound profile submits more capacity for a bigger
	# real hit. Both cases are remote (actor 2), so the local coverage gain does
	# not enter the comparison.
	controller.reset()
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 3.0), 1)
	controller.apply_events([damage(200, 2, 12.0, 1)], 1)
	var small_ratio := profile_ratio(controller, Controller.JET)
	controller.apply_events([damage(201, 2, 44.0, 1)], 1)
	var big_ratio := profile_ratio(controller, Controller.JET)
	check(small_ratio > 0.0 and small_ratio < big_ratio and big_ratio <= 1.0, "damage scaling grows the submitted jet capacity")

	# --- armor-only hit while the health bar did not move ----------------------
	controller.reset()
	controller.apply_state(state([actor(1, 0, 0, 0, 100.0, 60.0), actor(2, 0, 0, -3)], 4.0), 1)
	controller.apply_state(state([actor(1, 0, 0, 0, 100.0, 45.0), actor(2, 0, 0, -3)], 4.1), 1)
	var stains_before_absorb: int = controller.snapshot().stains_placed
	controller.apply_events([damage(20, 1, 30.0, 2)], 1)
	check(controller.snapshot().absorbed_only == 1, "armor-only hit at unchanged health emits no fluid")
	check(controller.snapshot().stains_placed == stains_before_absorb, "an absorbed hit never stains a surface")
	# A real drop bleeds with the observed drop as the upper bound.
	var before: int = controller.snapshot().spurts
	controller.apply_state(state([actor(1, 0, 0, 0, 70.0, 45.0), actor(2, 0, 0, -3)], 4.2), 1)
	controller.apply_events([damage(21, 1, 30.0, 2)], 1)
	check(controller.snapshot().spurts == before + 1, "a real health drop bleeds")
	# A corpse never spurts again from a late damage event.
	controller.apply_state(state([actor(1, 0, 0, 0, 0.0, 0.0), actor(2, 0, 0, -3)], 4.3), 1)
	var corpse_spurts: int = controller.snapshot().spurts
	controller.apply_events([damage(22, 1, 30.0, 2)], 1)
	check(controller.snapshot().spurts == corpse_spurts, "damage on an already dead actor never bleeds")

	# --- death splatter on the ramp (mid-air above tilted geometry) ------------
	controller.apply_state(state([actor(1, 0, 0, 0, 30.0, 0.0), actor(2, 0, 0, -3)], 2.0), 1)
	var stains_before: int = controller.snapshot().stains_placed
	controller.apply_events([{"type": "death", "id": 30, "actor": 1, "pos": {"x": -4, "y": 5, "z": 6},
		"killer": 2, "direction": {"x": 0.6, "y": 0, "z": 0.8}, "overkill": 10.0, "seed": 7}], 1)
	var placed: int = controller.snapshot().stains_placed - stains_before
	check(controller.snapshot().death_bursts == 1, "death emits exactly one dense burst")
	check(placed >= 1, "death in mid-air stains the surface actually below")
	var ramp_stain := {}
	var nearest := 99.0
	var stain_report := []
	for slot: Dictionary in controller.stain_slots:
		if slot.remaining <= 0.0: continue
		var p: Vector3 = slot.node.global_position
		var n: Vector3 = slot.node.global_transform.basis.z
		stain_report.append([p.x, p.y, p.z, n.x, n.y, n.z])
		var d: float = p.distance_to(Vector3(-4, 1.51, 6))
		if d < nearest:
			nearest = d
			ramp_stain = slot
	check(not ramp_stain.is_empty(), "a stain exists on the ramp plane, not on a fixed y=0 plane")
	if not ramp_stain.is_empty():
		var normal: Vector3 = ramp_stain.node.global_transform.basis.z
		check(absf(normal.y - 0.8) < 0.05 and absf(normal.z + 0.6) < 0.05,
			"the ramp stain follows the real surface normal (got %s at %s, all %s)" % [str(normal), str(ramp_stain.node.global_position), str(stain_report)])

	# --- death over a void: no invented floor stain ----------------------------
	controller.reset()
	controller.apply_state(state([actor(3, 15, 8, 15, 50.0, 0.0)], 2.1), 1)
	var before_void: int = controller.snapshot().stains_placed
	controller.apply_events([{"type": "death", "id": 31, "actor": 3, "pos": {"x": 15, "y": 8, "z": 15},
		"killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "overkill": 0.0, "seed": 9}], 1)
	check(controller.snapshot().stains_placed == before_void, "nothing is stained when no surface is under the death point")
	controller.bind_surfaces(void_map())
	check(not controller.surfaces.ready and controller.surfaces.kind == "semantic", "a surface-free map is a valid but not-ready backend")
	var before_bare: int = controller.snapshot().stains_placed
	controller.apply_state(state([actor(4, 2, 1, 2, 50.0, 0.0)], 2.2), 1)
	controller.apply_events([{"type": "death", "id": 32, "actor": 4, "pos": {"x": 2, "y": 1, "z": 2},
		"killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "overkill": 0.0, "seed": 5}], 1)
	check(controller.snapshot().stains_placed == before_bare, "no geometry means no stain and no crash")
	controller.bind_surfaces(fixture_map())
	check(controller.surfaces.ready, "re-binding the fixture surfaces succeeds")

	# --- bounded pools and eviction -------------------------------------------
	# A run of deaths on a floor: every death places a pool plus radial stains,
	# so the documented cap must engage and old stains must be recycled.
	controller.reset()
	controller.set_quality("High")
	var nodes_at_cap: int = controller.stain_slots.size()
	for i in range(48):
		controller.apply_state(state([actor(5, 0, 0, 0, 100.0)], 50.0 + float(i) * 0.1), 1)
		controller.apply_events([{"type": "death", "id": 2000 + i, "actor": 5, "pos": {"x": 0, "y": 1.4, "z": 0},
			"killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "overkill": 0.0, "seed": float(i)}], 1)
	var snapshot: Dictionary = controller.snapshot()
	check(snapshot.stains_live <= snapshot.stain_cap, "live stains never exceed the documented cap")
	check(snapshot.stains_recycled > 0, "oldest-recycled eviction engages past the cap")
	check(controller.stain_slots.size() == controller.settings.stain_pool, "the stain pool never grows")
	check(snapshot.stains_placed >= snapshot.stain_cap, "the eviction run really overflowed the cap")
	check(snapshot.active_emitters <= snapshot.concurrent_cap and snapshot.pool_nodes == controller.settings.fluid_emitters, "the fluid pool never grows and the concurrent cap holds")
	for i in range(400):
		controller.apply_events([damage(100 + i, 5, 55.0, 2)], 1)
	snapshot = controller.snapshot()
	check(snapshot.active_emitters <= snapshot.concurrent_cap, "the concurrent cap holds under damage spam")
	check(snapshot.recycled > 0 or snapshot.dropped > 0, "the pool recycles or drops instead of growing")
	check(controller.stain_slots.size() == nodes_at_cap and snapshot.pool_nodes == controller.settings.fluid_emitters, "no pool node is created by spamming events")
	check(snapshot.submitted_slots <= snapshot.allocated_slots, "submitted capacity never exceeds the allocation")

	# --- quality switching keeps node and material identity --------------------
	var node_ids_before := node_ids(controller)
	var material_ids_before := material_ids(controller)
	for level: String in ["Extreme", "Low", "High", "Extreme"]:
		check(controller.set_quality(level), "quality accepted: " + level)
		check(controller.snapshot().allocated_slots == controller.budget, "allocation matches the quality budget")
	var node_ids_after := node_ids(controller)
	var material_ids_after := material_ids(controller)
	check(node_ids_before == node_ids_after, "quality switching preserves node identity")
	check(material_ids_before == material_ids_after, "quality switching preserves material identity")
	check(not controller.set_quality("Ultra"), "invalid quality is rejected")
	check(controller.quality == "Extreme", "rejected quality leaves the previous level")

	# --- local death coverage cap ---------------------------------------------
	controller.reset()
	controller.set_quality("High")
	controller.apply_state(state([actor(7, 0, 0, 0), actor(2, 0, 0, -3)], 5.0), 7)
	var bursts_before: int = controller.snapshot().death_bursts
	controller.apply_events([{"type": "death", "id": 40, "actor": 7, "pos": {"x": 0, "y": 1, "z": 0},
		"killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "overkill": 0.0, "seed": 3}], 7)
	var local_ratio := 0.0
	for slot: Dictionary in controller.fluid_slots:
		if slot.profile == Controller.BURST and slot.remaining > 0.0: local_ratio = float(slot.ratio)
	check(controller.snapshot().death_bursts == bursts_before + 1, "the local player's own death still splatters")
	check(local_ratio > 0.0 and local_ratio <= controller.settings.local_gain + 0.001,
		"the local death burst is capped by the coverage gain")
	controller.reset()
	controller.apply_state(state([actor(8, 0, 0, 0), actor(2, 0, 0, -3)], 5.1), -1)
	controller.apply_events([{"type": "death", "id": 41, "actor": 8, "pos": {"x": 0, "y": 1, "z": 0},
		"killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "overkill": 0.0, "seed": 3}], -1)
	var remote_ratio := 0.0
	for slot: Dictionary in controller.fluid_slots:
		if slot.profile == Controller.BURST and slot.remaining > 0.0: remote_ratio = float(slot.ratio)
	check(remote_ratio > local_ratio, "a remote death keeps the full burst capacity")

	# --- lifecycle -------------------------------------------------------------
	var children_before := controller.get_child_count()
	controller.reset()
	check(controller.snapshot().stains_live == 0 and controller.snapshot().active_emitters == 0, "round reset clears stains and emitters")
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 6.0), 1)
	controller.apply_events([damage(50, 1, 30.0, 2), {"type": "death", "id": 51, "actor": 1,
		"pos": {"x": 0, "y": 1, "z": 0}, "killer": 2, "direction": {"x": 1, "y": 0, "z": 0}, "seed": 4}], 1)
	check(controller.snapshot().stains_live > 0, "state after reset stains normally")
	controller.paused = true
	var before_clock: float = controller.clock
	controller._process(0.2)
	check(controller.clock == before_clock, "paused controller does not age")
	controller.paused = false
	controller.set_paused(true)
	controller._process(0.2)
	check(controller.clock == before_clock, "set_paused freezes the clock")
	controller.set_paused(false)
	controller.hide()
	controller._process(0.2)
	check(controller.clock == before_clock, "hidden controller freezes")
	controller.show()
	paused = true
	controller._process(0.2)
	check(controller.clock == before_clock, "SceneTree pause freezes an always-processing controller")
	paused = false
	controller._process(NAN)
	controller._process(-1.0)
	check(controller.clock == before_clock, "invalid deltas are rejected")
	controller._process(0.05)
	check(controller.clock > before_clock, "valid delta advances")
	# Focus loss drains and never replays.
	controller._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(controller.snapshot().stains_live == 0 and controller.snapshot().active_emitters == 0, "focus loss drains every visual")
	var stains_drained: int = controller.snapshot().stains_placed
	controller.apply_events([damage(50, 1, 30.0, 2)], 1)
	check(controller.snapshot().stains_placed == stains_drained, "a drained event id cannot replay after focus returns")
	controller._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	controller.apply_events([damage(52, 1, 30.0, 2)], 1)
	check(controller.snapshot().spurts >= 2, "fresh events flow again after focus returns")
	# Stale public state drains.
	controller.last_state_usec = Time.get_ticks_usec() - 5_000_000
	controller._process(0.2)
	check(not controller.active and controller.snapshot().stains_live == 0, "stale public state drains and deactivates")
	# Results drain.
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 7.0), 1)
	controller.apply_events([damage(60, 1, 30.0, 2)], 1)
	controller.apply_state({"over": true, "actors": [], "time": 7.1}, 1)
	check(not controller.active and controller.snapshot().stains_live == 0 and controller.snapshot().active_emitters == 0, "results reset drains every visual")
	# Restart: a backwards public time resets the round.
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 8.0), 1)
	controller.apply_events([damage(70, 1, 30.0, 2)], 1)
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 0.5), 1)
	check(controller.clock == 0.0 and controller.snapshot().stains_live == 0, "a backwards public time resets the round")
	# Map change: pools from the previous geometry never survive.
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 9.0), 1)
	controller.apply_events([damage(80, 1, 30.0, 2)], 1)
	controller.apply_state(state([actor(1, 0, 0, 0), actor(2, 0, 0, -3)], 9.1, "another-map"), 1)
	check(controller.snapshot().map_id == "another-map" and not controller.surfaces.ready, "map change drops the old surface binding")
	check(not controller.surface_error.is_empty(), "map change reports the required re-bind")

	# --- art direction: one documented override point --------------------------
	var blood_color: String = controller.snapshot().fluid_color
	check(controller.apply_variant("synthetic"), "the synthetic-fluid variant is selectable in one call")
	var synthetic: Dictionary = controller.snapshot()
	check(synthetic.variant == "synthetic" and synthetic.fluid_color != blood_color, "the variant switches the fluid colour")
	check(float(controller.settings.fluid_scale) < 1.0, "the variant changes the particle scale")
	var identity_before_variant := material_ids(controller)
	check(controller.apply_variant("blood"), "the default crimson variant is restored in one call")
	check(controller.snapshot().fluid_color == blood_color and material_ids(controller) == identity_before_variant,
		"a variant switch never replaces a node or a material")
	check(not controller.apply_variant("plasma-candy"), "an unknown variant is rejected")
	# A host-assigned settings object is the single documented override point.
	var custom := Settings.new()
	custom.fluid_color = Color(0.08, 0.62, 0.7)
	custom.fluid_scale = 1.35
	custom.stain_opacity = 0.5
	controller.settings = custom
	check(controller.snapshot().fluid_color == custom.fluid_color.to_html(false), "a host-assigned settings block is honoured")
	check(is_equal_approx(float(controller.snapshot().surfaces.mask), 1.0), "surface queries keep their configured collision mask")

	# --- bounded CPU and node growth ------------------------------------------
	check(controller.get_child_count() == children_before, "no nodes are created after configuration")
	var before_events: int = controller.snapshot().events_seen
	var spam := []
	for i in range(2000): spam.append(damage(9000 + i, 1, 12.0, 2))
	controller.apply_events(spam, 1)
	check(controller.snapshot().events_seen == before_events + 512, "one callback inspects at most 512 events")
	check(controller.get_child_count() == children_before, "event spam creates no nodes")

	print("BLOOD_FX_CONTRACTS ", "FAIL" if failed else "PASS", " checks=", checks,
		" failed=", lines.filter(func(line: String) -> bool: return line.begins_with("FAIL")).size())
	for line: String in lines:
		if line.begins_with("FAIL"): print("  ", line)
	print("BLOOD_FX_CONTRACTS_SNAPSHOT ", JSON.stringify(controller.snapshot()))
	quit(1 if failed else 0)
