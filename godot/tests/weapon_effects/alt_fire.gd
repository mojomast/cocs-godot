extends SceneTree
## Alt-fire presentation contract: each projectile alt mode owns a distinct
## pooled body, its own exhaust character and its own arming behaviour, and the
## effects controller answers each alt explosion with its own pooled burst.
## Presentation only: nothing here reads or writes aim, ammo, damage or any
## authoritative position.
const Projectiles = preload("res://world/projectiles.gd")
const FX = preload("res://weapon_effects/controller.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func alt(id: int, kind: String, pos: Vector3, dir: Vector3, extra: Dictionary = {}) -> Dictionary:
	var row := {"id":id, "owner":0, "weapon":Projectiles.ALT_WEAPONS[kind], "alt":true, "altId":kind,
		"pos":{"x":pos.x,"y":pos.y,"z":pos.z}, "dir":{"x":dir.x,"y":dir.y,"z":dir.z}}
	row.merge(extra, true)
	return row

func rocket(id: int, pos: Vector3, dir: Vector3, weapon: int = 1) -> Dictionary:
	return {"id":id,"owner":0,"weapon":weapon,"pos":{"x":pos.x,"y":pos.y,"z":pos.z},"dir":{"x":dir.x,"y":dir.y,"z":dir.z}}

func surface_material(mesh: Mesh, index: int) -> StandardMaterial3D:
	var material := mesh.surface_get_material(index)
	return material as StandardMaterial3D

func emissive_surfaces(mesh: Mesh) -> int:
	var count := 0
	for index: int in mesh.get_surface_count():
		var material := surface_material(mesh, index)
		if material != null and material.emission_enabled: count += 1
	return count

func first_colors(mesh: Mesh) -> Array:
	var colors: Array = []
	for index: int in mesh.get_surface_count():
		var material := surface_material(mesh, index)
		colors.append(material.albedo_color if material != null else Color.BLACK)
	return colors

func ribbon(node: MeshInstance3D) -> MeshInstance3D:
	return node.get_child(0) as MeshInstance3D

func trail_alphas(node: MeshInstance3D) -> Array:
	var values: Array = []
	var mesh: ImmediateMesh = ribbon(node).mesh
	if mesh.get_surface_count() == 0: return values
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for color: Color in colors:
		if not values.has(snappedf(color.a, 0.001)): values.append(snappedf(color.a, 0.001))
	return values

func trail_width(node: MeshInstance3D) -> float:
	var mesh: ImmediateMesh = ribbon(node).mesh
	if mesh.get_surface_count() == 0: return 0.0
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var maximum := 0.0
	# Each span submits two triangles; the first one holds the head width pair.
	for index: int in range(0, vertices.size(), 6):
		maximum = maxf(maximum, vertices[index + 1].distance_to(vertices[index + 2]))
	return maximum

func run() -> void:
	# --- 1. Distinct pooled bodies per alt mode -----------------------------
	var world := Node3D.new()
	root.add_child(world)
	var projectiles := Projectiles.new()
	world.add_child(projectiles)
	projectiles.set_process(false)
	projectiles.configure_occlusion(func(_from: Vector3, _to: Vector3) -> bool: return false)
	var rows: Array = [
		alt(11, "cluster", Vector3(-3,2,-6), Vector3.FORWARD, {"bomblets":3}),
		alt(12, "mortar", Vector3(-1,2,-6), Vector3.FORWARD, {"gravity":0.45}),
		alt(13, "mine", Vector3(1,2,-6), Vector3.FORWARD, {"mine":true,"arm":0.2,"life":7}),
		alt(14, "bomb", Vector3(3,2,-6), Vector3.FORWARD, {"flak":8}),
	]
	projectiles.apply_state({"time":0.0,"rockets":rows})
	var meshes := {
		"cluster":projectiles.alt_meshes["cluster"], "mortar":projectiles.alt_meshes["mortar"],
		"mine":projectiles.alt_meshes["mine"], "bomb":projectiles.alt_meshes["bomb"],
	}
	var ids := {"cluster":11, "mortar":12, "mine":13, "bomb":14}
	for kind: String in meshes:
		var node: MeshInstance3D = projectiles.markers[ids[kind]]
		check(node.mesh == meshes[kind], "alt %s marker presents its own body mesh" % kind)
		check(node.get_meta("alt") == kind, "alt %s identity recorded on the marker" % kind)
	check(meshes.cluster != meshes.mortar and meshes.cluster != meshes.mine and meshes.cluster != meshes.bomb
		and meshes.mortar != meshes.mine and meshes.mortar != meshes.bomb and meshes.mine != meshes.bomb,
		"four alt bodies are four distinct shared meshes")
	for kind: String in meshes:
		check(meshes[kind] != projectiles.rocket_mesh and meshes[kind] != projectiles.generic_mesh,
			"alt %s body is not the primary rocket or generic sphere" % kind)
	check(projectiles.alt_meshes.cluster.get_surface_count() >= 6, "cluster shell is a segmented drum")
	check(projectiles.alt_meshes.mortar.get_surface_count() >= 8, "mortar round has a core, shell, collar, four fins and exhaust")
	check(projectiles.alt_meshes.mine.get_surface_count() >= 4, "mine has a disc, hub and sensor prongs")
	check(projectiles.alt_meshes.bomb.get_surface_count() >= 6, "flak canister has a body, cap, vents, slit and rear ring")
	check(emissive_surfaces(projectiles.alt_meshes.cluster) >= 2, "cluster carries emissive accent rings")
	check(emissive_surfaces(projectiles.alt_meshes.mortar) >= 5, "mortar carries emissive fins and exhaust")
	check(emissive_surfaces(projectiles.alt_meshes.bomb) >= 2, "flak bomb carries emissive vent and rear ring")
	check(projectiles.mine_eye_mesh.material is StandardMaterial3D and (projectiles.mine_eye_mesh.material as StandardMaterial3D).emission_enabled,
		"mine sensor eye is its own emissive mesh")
	# Source weapon base colours: 1 orange, 4 blue, 5 red-orange, 7 yellow.
	check(surface_material(meshes.cluster, 0).albedo_color == Projectiles.WEAPON_COLORS[1], "cluster body carries rocket orange")
	check(surface_material(meshes.mortar, 0).albedo_color == Projectiles.WEAPON_COLORS[4], "mortar body carries plasma blue")
	check(surface_material(meshes.mine, 0).albedo_color == Projectiles.WEAPON_COLORS[5], "mine disc carries grenade red-orange")
	check(surface_material(meshes.bomb, 0).albedo_color == Projectiles.WEAPON_COLORS[7], "flak canister carries flak yellow")
	var palette := {}
	for kind: String in meshes:
		for color: Color in first_colors(meshes[kind]): palette[color.to_html(false)] = true
	check(palette.size() >= 12, "alt bodies span a wide distinct palette (%d colours)" % palette.size())
	var cluster_box: AABB = meshes.cluster.get_aabb()
	var mortar_box: AABB = meshes.mortar.get_aabb()
	var mine_box: AABB = meshes.mine.get_aabb()
	var bomb_box: AABB = meshes.bomb.get_aabb()
	check(mine_box.size.y < 0.30 and minf(cluster_box.size.x, cluster_box.size.z) > 0.15,
		"mine reads flat and low, the drum reads round")
	check(cluster_box != mortar_box and cluster_box != mine_box and cluster_box != bomb_box
		and mortar_box != mine_box and mortar_box != bomb_box and mine_box != bomb_box,
		"four silhouette boxes are distinct")
	check(mine_box.position.y + mine_box.size.y * 0.5 <= 0.06, "mine body sits low on its origin")

	# --- 2. Kind detection mirrors the source precedence --------------------
	check(Projectiles.alt_kind(alt(0,"cluster",Vector3.ZERO,Vector3.FORWARD)) == "cluster", "altId cluster detected")
	check(Projectiles.alt_kind({"mine":true,"alt":true,"altId":"mine"}) == "mine", "mine flag detected")
	check(Projectiles.alt_kind({"bomblets":3,"alt":true,"altId":"cluster"}) == "cluster", "bomblets detected")
	check(Projectiles.alt_kind({"flak":8,"alt":true,"altId":"bomb"}) == "bomb", "flak detected")
	check(Projectiles.alt_kind({"alt":true,"weapon":4}) == "mortar", "alt weapon fallback resolves the mortar")
	check(Projectiles.alt_kind(rocket(0, Vector3.ZERO, Vector3.FORWARD, 1)) == "", "primary rocket stays generic")
	check(Projectiles.alt_kind(rocket(0, Vector3.ZERO, Vector3.FORWARD, 5)) == "", "thrown grenade stays generic")
	check(Projectiles.alt_kind({"alt":false,"weapon":4}) == "", "missing alt identity and fields stay generic")
	check(Projectiles.alt_kind({"alt":false,"altId":"cluster"}) == "cluster", "a known altId wins even without the flag (source parity)")
	check(Projectiles.alt_kind({"alt":true,"altId":"slug"}) == "", "hitscan alt modes never get a projectile body")

	# --- 3. Orientation and the mine's low stance + arming blink ------------
	check(absf((projectiles.markers[13] as MeshInstance3D).basis.y.dot(Vector3.UP)) > 0.999,
		"mine keeps the flat low stance regardless of flight direction")
	check((-(projectiles.markers[11] as MeshInstance3D).basis.z).is_equal_approx(Vector3.FORWARD), "cluster shell points along flight")
	var mine: MeshInstance3D = projectiles.markers[13]
	check(mine.get_child_count() == 2 and mine.get_node_or_null("Blink") is MeshInstance3D,
		"mine owns one extra pooled arming eye child")
	var rocket_node: MeshInstance3D = projectiles.markers[11]
	check(rocket_node.get_child_count() == 1, "non-mine markers keep the single exhaust child")
	projectiles._process(0.1)
	var blink: MeshInstance3D = mine.get_node_or_null("Blink")
	check(not blink.visible, "mine eye is dark while the fuse burns")
	check(not bool(projectiles.flight[13].armed), "mine is not armed before its source arm time")
	projectiles._process(0.15)
	check(bool(projectiles.flight[13].armed), "mine arms exactly when the source arm field elapses")
	var eye_phases := {}
	for step: int in 7:
		projectiles.clock += 1.0 / 7.0
		projectiles._process(0.0)
		eye_phases[blink.visible] = true
	check(eye_phases.size() == 2, "armed mine eye blinks at the source 7 Hz cadence")

	# --- 4. One ribbon per projectile, distinct characters, no reallocation --
	projectiles.clear_round()
	for step: int in 20:
		var time := float(step) * 0.05
		var moved: Array = []
		for row: Dictionary in rows:
			var copy: Dictionary = row.duplicate(true)
			var pos: Vector3 = Projectiles.point(copy.pos)
			copy.pos = {"x":pos.x,"y":pos.y,"z":pos.z - float(step) * 0.7}
			moved.append(copy)
		projectiles.apply_state({"time":time,"rockets":moved})
		projectiles._process(0.05)
	var live: Dictionary = {}
	for kind: String in ids:
		var node: MeshInstance3D = projectiles.markers[ids[kind]]
		check(not projectiles.flight[ids[kind]].trail.is_empty(), "alt %s grows its exhaust ribbon in flight" % kind)
		check(ribbon(node).visible, "alt %s ribbon is visible while in flight" % kind)
		check(node.get_child_count() == (2 if kind == "mine" else 1), "alt %s stays at one ribbon (mine adds the eye)" % kind)
		live[kind] = node
	var tints := {}
	for kind: String in ids:
		var mesh: ImmediateMesh = ribbon(live[kind]).mesh
		var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		tints[colors[colors.size() - 1].to_html(false)] = true
	check(tints.size() == 4, "four alt exhaust colours are distinct (%d)" % tints.size())
	check(trail_width(live.mortar) > trail_width(live.cluster) * 1.5 and trail_width(live.bomb) > trail_width(live.cluster) * 1.5,
		"smoke plumes read wider than the cluster spark trail")
	check(trail_width(live.mine) < trail_width(live.mortar), "mine pulse stays tighter than the mortar plume")
	var pulse: Array = []
	for phase: float in [0.0, 0.35, 0.7]:
		projectiles.clock += phase
		projectiles._process(0.0)
		pulse.append(trail_alphas(live.mine))
	check(pulse[0] != pulse[1] or pulse[1] != pulse[2], "mine ribbon pulses before/while arming")
	var before_ids: Array = []
	for id: int in ids.values(): before_ids.append(projectiles.markers[id].get_instance_id())
	projectiles.apply_state({"time":1.5,"rockets":rows})
	projectiles._process(0.05)
	for index: int in ids.values().size():
		check(projectiles.markers[ids.values()[index]].get_instance_id() == before_ids[index],
			"authoritative samples reuse the pooled marker and its one body mesh")

	# --- 5. Saturation stays bounded with mixed alt types -------------------
	projectiles.clear_round()
	var many: Array = []
	for id: int in range(600):
		var kind: String = Projectiles.ALT_KINDS[id % Projectiles.ALT_KINDS.size()]
		many.append(alt(1000 + id, kind, Vector3.ZERO, Vector3.FORWARD))
	projectiles.apply_state({"time":2.0,"rockets":many})
	check(projectiles.markers.size() == Projectiles.MAX_PROJECTILES, "alt bodies share the bounded marker pool")
	check(projectiles.get_child_count() == Projectiles.MAX_PROJECTILES, "no extra scene nodes under alt saturation")

	# --- 6. Alt explosion bursts are pooled, distinct and quality-bounded ---
	var fx := FX.new()
	world.add_child(fx)
	fx.set_process(false)
	fx.set_quality(2)
	var visual_kinds := {"cluster":13, "mortar":14, "mine":15, "bomb":16}
	var serial := 0
	for kind: String in ["cluster", "mortar", "mine", "bomb"]:
		serial += 1
		fx.reset()
		var count_before: int = fx.slots.size()
		fx.consume([{"id":serial,"time":1.0,"type":"explosion","weapon":Projectiles.ALT_WEAPONS[kind],"alt":true,"altId":kind,"pos":{"x":1,"y":0,"z":1}}], 0, [])
		check(fx.blasts == 1, "alt %s explosion answered by the pooled blast path" % kind)
		check(fx.slots.size() <= FX.CAP, "alt %s burst stays inside the flash pool cap" % kind)
		var card: Dictionary = fx.slots[count_before]
		check(int(card.kind) == int(visual_kinds[kind]), "alt %s uses its own shader card kind" % kind)
		check(card.material.get_shader_parameter("tint") is Color, "alt %s burst carries a tint" % kind)
		check(slot_position(card.node).distance_to(Vector3(1, 0, 1)) < 0.02, "alt %s burst sits on the authoritative position" % kind)
		if kind == "bomb":
			var shards := 0
			for slot: Dictionary in fx.slots:
				if int(slot.kind) == 12: shards += 1
			check(shards == FX.MAX_BLAST_SHARDS, "flak burst sprays the full fragment fan at Extreme")
		if kind == "cluster":
			check(fx.slots.size() - count_before == 2, "cluster shell splits with a pop and a ring")
		if kind == "mortar":
			check(fx.slots.size() - count_before == 3, "mortar burst adds a dome, dust and a smoke column")
		if kind == "mine":
			check(fx.slots.size() - count_before == 3, "mine burst keeps the sharp core and two shock rings")
	# Cluster bomblet events stagger their small pops deterministically.
	fx.reset()
	fx.consume([{"id":1,"time":2.0,"type":"explosion","weapon":1,"alt":true,"altId":"cluster","bomblet":0,"pos":{"x":0,"y":0,"z":0}}], 0, [])
	fx.consume([{"id":2,"time":2.0,"type":"explosion","weapon":1,"alt":true,"altId":"cluster","bomblet":1,"pos":{"x":1,"y":0,"z":0}}], 0, [])
	fx.consume([{"id":3,"time":2.0,"type":"explosion","weapon":1,"alt":true,"altId":"cluster","bomblet":2,"pos":{"x":0,"y":0,"z":1}}], 0, [])
	check(fx.blasts == 3 and fx.slots.size() == 3, "three bomblet events make three small bursts")
	check(not fx.slots[1].node.visible and not fx.slots[2].node.visible, "later bomblet pops start hidden on their stagger")
	fx.advance(0.06)
	check(fx.slots[1].node.visible and not fx.slots[2].node.visible, "bomblet pops stagger in on their own index")
	# Replays, primary explosions and quality 0 never invent an alt burst.
	var after: int = fx.blasts
	fx.consume([{"id":3,"time":2.0,"type":"explosion","weapon":1,"alt":true,"altId":"cluster","bomblet":2,"pos":{"x":0,"y":0,"z":1}}], 0, [])
	check(fx.blasts == after, "alt blast events are deduplicated by identity")
	fx.consume([{"id":9,"time":3.0,"type":"explosion","weapon":1,"pos":{"x":0,"y":0,"z":0}}], 0, [])
	check(fx.blasts == after, "primary explosions keep their existing presentation")
	fx.set_quality(0)
	fx.consume([{"id":10,"time":4.0,"type":"explosion","weapon":4,"alt":true,"altId":"mortar","pos":{"x":0,"y":0,"z":0}}], 0, [])
	check(fx.blasts == after, "quality 0 suppresses alt bursts")
	fx.set_quality(1)
	fx.reset()
	fx.consume([{"id":11,"time":5.0,"type":"explosion","weapon":7,"alt":true,"altId":"bomb","pos":{"x":0,"y":0,"z":0}}], 0, [])
	var shards := 0
	for slot: Dictionary in fx.slots:
		if int(slot.kind) == 12: shards += 1
	check(shards == 4, "High quality spends half the fragment fan")
	check(fx.flashes == 0 and fx.tracer_count == 0 and fx.impacts == 0 and fx.rejected == 0,
		"alt bursts never write the flash/tracer/impact/rejected counters")
	# Stress: repeated alt explosions stay inside the pooled node budgets.
	for index: int in 200:
		fx.consume([{"id":1000+index,"time":10.0+float(index)*0.01,"type":"explosion","weapon":7,"alt":true,"altId":"bomb","pos":{"x":0,"y":0,"z":0}}], 0, [])
	check(fx.slots.size() <= FX.CAP and fx.lines.size() <= FX.LINE_CAP, "repeated alt bursts stay bounded")
	check(fx.flashes == 0, "stress never fabricates muzzle flashes")

	# --- 7. Reset and teardown free every pooled node -----------------------
	fx.reset()
	check(fx.blasts == 0 and fx.blast_shards == 0 and fx.slots.is_empty(), "controller reset clears alt blast counters and pool")
	projectiles.clear_round()
	check(projectiles.markers.is_empty() and projectiles.flight.is_empty(), "round reset frees the alt bodies")
	fx.free()
	projectiles.free()
	world.free()
	print("WEAPON_EFFECTS_ALT_FIRE ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func slot_position(node: Node3D) -> Vector3:
	return node.global_position
