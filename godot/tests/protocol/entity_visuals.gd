extends SceneTree

const Presentation = preload("res://world/presentation.gd")
const Pickups = preload("res://world/pickups.gd")
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		push_error(message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Synthetic authority transitions, not live collection/respawn evidence.
	var view := Presentation.new()
	root.add_child(view)
	# Actual imported source operators: articulated hierarchy with real team armor
	# materials and genuine source team bars. Measured values are asserted, not
	# primitive-node aliases.
	var actor: Dictionary = {"id": 7, "x": 2.0, "y": 3.0, "z": 4.0, "health": 100, "dead": 0, "character": "claude", "team": 0, "weapon": 0, "yaw": 0.0, "bodyYaw": 0.0}
	var other: Dictionary = actor.duplicate(true)
	other.id = 8
	other.team = 1.0
	view.apply_state({"actors": [actor, other]}, -1)
	var node: Node3D = view.actors[7]
	var mate: Node3D = view.actors[8]
	var instance: int = node.get_instance_id()
	check(node.character == "claude" and mate.character == "claude", "authoritative character selects the imported source identity")
	check(is_instance_valid(node.team_material) and node.team_material != mate.team_material, "source team armor material is instance-isolated")
	check(node.team_material.albedo_color != mate.team_material.albedo_color, "team armor distinguishes actors by color")
	var red_bars := 0
	var blue_bars := 0
	for bar: MeshInstance3D in node.team_bars:
		if bar.visible: red_bars += 1
	for bar: MeshInstance3D in mate.team_bars:
		if bar.visible: blue_bars += 1
	check(red_bars == 2 and blue_bars == 4, "genuine source team bars distinguish teams without color")
	check(node.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual actor has no collision authority")
	var feet: Node3D = node.anchor("FeetOrigin")
	var helmet: Node3D = node.anchor("Helmet")
	var muzzle: Node3D = node.anchor("Muzzle")
	check(is_instance_valid(feet) and is_instance_valid(helmet) and is_instance_valid(muzzle), "articulated source anchors resolve")
	check(absf(node.to_local(feet.global_position).y + 0.9) < 0.001, "source feet origin sits 0.9m below the host anchor")
	var head_y: float = node.to_local(helmet.global_position).y
	check(head_y > 0.55 and head_y < 0.95, "source head joint sits inside the body envelope")
	var bounds := AABB()
	var first: bool = true
	for part: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		if not mesh.visible: continue
		var box: AABB = node.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	check(absf(bounds.position.y + 0.9) < 0.02, "source soles sit 0.9m below the host anchor")
	check(bounds.end.y > 0.75 and bounds.end.y < 1.25, "imported body height stays inside the 1.79-2.03m source envelope")
	check(bounds.size.x <= 1.05, "source accessory width stays bounded")
	var grip_cases := 0
	for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
		actor.bodyYaw = yaw
		actor.yaw = yaw
		view.apply_state({"actors": [actor, other]}, -1)
		check(node.position.is_equal_approx(Vector3(2, 3.9, 4)), "cardinal orientation does not move anchor")
		var forward := Vector3(-sin(yaw), 0, -cos(yaw))
		check((node.anchor("Muzzle").global_position - node.global_position).dot(forward) > 0.5, "mounted third-person weapon points along authority yaw")
		node.advance(1.0 / 60.0)
		for side: String in node.grip_error:
			var residual: float = float(node.grip_error[side])
			check(is_finite(residual) and residual < 0.02, "post-pose hand grip reaches the source weapon contact")
			grip_cases += 1
	check(grip_cases >= 8, "both hands solved against the source weapon contacts")
	check(is_instance_valid(node.world_weapon) and node.world_weapon.get_parent() == node.anchor("GunMount"), "exported source weapon mounts on the authored gun mount")
	var first_weapon: int = node.world_weapon.get_instance_id()
	var first_muzzle: Vector3 = node.to_local(node.anchor("Muzzle").global_position)
	actor.weapon = 4
	view.apply_state({"actors": [actor, other]}, -1)
	check(node.weapon_type == 4 and node.world_weapon.get_instance_id() != first_weapon, "authoritative weapon change swaps the third-person model")
	check(node.to_local(node.anchor("Muzzle").global_position).distance_to(first_muzzle) > 0.02, "swapped weapon moves the muzzle anchor")
	actor.character = "kimi"
	actor.team = 1.0
	actor.health = 0
	view.apply_state({"actors": [other, actor]}, -1)
	check(not node.visible and node.get_instance_id() == instance, "zero-health timer-zero hides stable actor root")
	check(node.character == "kimi" and mate.character == "claude", "identity updates rebuild only the changed actor")
	check(is_instance_valid(node.team_material) and node.team_material.albedo_color == mate.team_material.albedo_color, "wire float team IDs retain team identity")
	actor.health = 100
	view.apply_state({"actors": [actor, other]}, 7)
	check(not node.visible, "healthy self remains hidden")
	view.apply_state({"actors": [actor, other]}, -1)
	check(node.visible, "healthy remote returns")
	view.clear_round()
	check(view.actors.is_empty() and view.get_child_count() == 0, "actor round cleanup")
	view.free()
	var pickups := Pickups.new()
	root.add_child(pickups)
	var source: Array = []
	for kind: String in ["health", "armor", "rocket", "rail", "haste"]:
		source.append({"id": source.size(), "kind": kind, "x": 0, "y": 0, "z": 0, "wait": 0})
	pickups.apply_state({"pickups": source})
	var marker: Node3D = pickups.markers[0]
	var marker_id: int = marker.get_instance_id()
	var case_id: int = marker.get_node("Housing").get_instance_id()
	var health_mesh: Mesh = marker.get_node("IdentityIcon").mesh
	var icons := {}
	for pickup: Node in pickups.markers.values():
		icons[pickup.get_node("IdentityIcon").mesh.get_instance_id()] = true
		check(pickup.find_children("*", "Label3D", true, false).is_empty(), "compact pickup art has no obstructing captions")
	check(icons.size() == source.size(), "health, armor, rocket, rail and haste retain distinct icon geometry")
	check(marker.get_node("Housing").visibility_range_end == 45, "pickup geometry has bounded visibility range")
	source[0].wait = 0.01
	pickups.apply_state({"pickups": source})
	await create_timer(0.05).timeout
	check(not marker.visible, "elapsed wait cannot locally return pickup")
	source[0].wait = 0
	source.reverse()
	pickups.apply_state({"pickups": source})
	check(marker.visible and marker.get_instance_id() == marker_id and marker.get_node("Housing").get_instance_id() == case_id and marker.get_node("IdentityIcon").mesh == health_mesh, "snapshot return and reorder preserve root and geometry")
	source[4].kind = "armor"
	pickups.apply_state({"pickups": source})
	check(marker.get_instance_id() == marker_id and marker.get_node("Housing").get_instance_id() == case_id and marker.get_node("IdentityIcon").mesh == pickups.markers[1].get_node("IdentityIcon").mesh and marker.get_node("IdentityIcon").mesh != health_mesh, "authoritative kind changes refresh geometry on the same marker and render nodes")
	pickups.clear_round()
	check(pickups.markers.is_empty() and pickups.get_child_count() == 0, "pickup round cleanup")
	pickups.free()
	print("PORT_ENTITY_VISUALS_OK checks=", checks, " synthetic=true")
	quit(0)
