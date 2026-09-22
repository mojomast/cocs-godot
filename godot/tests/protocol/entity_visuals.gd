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
	var actor: Dictionary = {"id": 7, "x": 2.0, "y": 3.0, "z": 4.0, "health": 100, "dead": 0, "character": "claude", "team": 0}
	var other: Dictionary = actor.duplicate(true)
	other.id = 8
	other.team = 1.0
	view.apply_state({"actors": [actor, other]}, -1)
	var node: Node3D = view.actors[7]
	var instance: int = node.get_instance_id()
	var helmet: int = node.get_node("Helmet").get_instance_id()
	check(node.armor.albedo_color != view.actors[8].armor.albedo_color, "team armor distinguishes actors")
	check(node.identity.albedo_color == view.actors[8].identity.albedo_color, "character identity survives team assignment")
	check(node.team_marks[0].visible and not node.team_marks[1].visible and view.actors[8].team_marks[1].visible, "team stripes distinguish without color")
	var bounds := AABB()
	var first: bool = true
	for part: Node in node.get_children():
		check(not part is CollisionObject3D, "visual has no collision authority")
		if part is MeshInstance3D:
			var box: AABB = part.transform * part.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	check(is_equal_approx(bounds.position.y, -0.9) and is_equal_approx(bounds.end.y, 0.9), "1.8m body retains centered feet/head bounds")
	check(bounds.size.x <= 0.701, "body retains 0.7m width")
	for yaw: float in [0.0, PI / 2, PI, -PI / 2]:
		actor.bodyYaw = yaw
		view.apply_state({"actors": [actor, other]}, -1)
		check(node.position.is_equal_approx(Vector3(2, 3.9, 4)), "cardinal orientation does not move anchor")
		var forward := Vector3(-sin(yaw), 0, -cos(yaw))
		check((node.get_node("Muzzle").global_position - node.global_position).dot(forward) > 0.5, "weapon points along authority yaw")
	actor.character = "kimi"
	actor.team = 1.0
	actor.health = 0
	view.apply_state({"actors": [other, actor]}, -1)
	check(not node.visible and node.get_instance_id() == instance, "zero-health timer-zero hides stable actor")
	check(node.get_node("Helmet").get_instance_id() == helmet, "identity updates do not rebuild geometry")
	check(node.armor.albedo_color == view.actors[8].armor.albedo_color and node.team_marks[1].visible, "wire float team IDs retain team identity")
	check(node.identity.albedo_color != view.actors[8].identity.albedo_color, "character updates are material-isolated")
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
