class_name PortPresentation
extends Node3D

# Diagnostic actors only. Node simulation remains authoritative; no extrapolation.
var actors: Dictionary = {}
var local_actor: Dictionary = {}
var hud_text: String = "Waiting for authoritative snapshot"
var applied: int = 0

func clear_round() -> void:
	for node: Node3D in actors.values():
		remove_child(node)
		node.free()
	actors.clear()
	local_actor = {}
	hud_text = "Waiting for authoritative snapshot"
	applied = 0

func apply_state(state: Dictionary, local_id: int) -> void:
	var present: Dictionary = {}
	local_actor = {}
	for actor: Dictionary in state.get("actors", []):
		var id: int = int(actor.id)
		present[id] = true
		if not actors.has(id):
			var node := MeshInstance3D.new()
			node.name = "Actor_%d" % id
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.35
			mesh.height = 1.8
			node.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.95, 0.35, 0.2)
			node.material_override = mat
			add_child(node)
			actors[id] = node
		var visual: Node3D = actors[id]
		visual.position = Vector3(actor.x, actor.y + 0.9, actor.z)
		visual.rotation.y = float(actor.get("bodyYaw", actor.get("yaw", 0)))
		visual.visible = id != local_id and float(actor.get("dead", 0)) <= 0
		if id == local_id: local_actor = actor.duplicate(true)
	for id: int in actors.keys():
		if not present.has(id):
			var node: Node3D = actors[id]
			remove_child(node)
			node.free()
			actors.erase(id)
	if local_actor.is_empty():
		hud_text = "Local actor absent — waiting"
	else:
		var a: Dictionary = local_actor
		var weapon: int = int(a.get("weapon", 0))
		var ammo: Array = a.get("ammo", [])
		var rounds: String = str(ammo[weapon]) if weapon >= 0 and weapon < ammo.size() else "?"
		hud_text = "%s | HP %s | Armor %s | Weapon %d | Ammo %s\nFrags %s · Deaths %s | %s" % [state.get("mapName", state.get("mapId", "")), a.get("health", 0), a.get("armor", 0), weapon, rounds, a.get("frags", 0), a.get("deaths", 0), "RESULTS" if state.get("over", false) else ("DEAD — server respawn pending" if float(a.get("dead", 0)) > 0 else "LIVE")]
	applied += 1

func eye_position() -> Vector3:
	return Vector3(local_actor.get("x", 0), float(local_actor.get("y", 0)) + float(local_actor.get("eyeHeight", 1.45)), local_actor.get("z", 0))
