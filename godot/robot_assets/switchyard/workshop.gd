extends Node3D
## Six shallow service fixtures mounted on existing Emberline metal cover faces.
## No collision nodes, new cover, source geometry or navigation modifications.
const DIRECTORY := "res://robot_assets/switchyard/generated/"
const SITES := {
	"fight-1-cover--1":"relay_console", "fight-1-cover-1":"battery_rack",
	"fight-1-screen--1":"repair_dock", "fight-1-screen-1":"blast_shutter_frame",
	"fight-2-cover--1":"cargo_stack", "fight-2-cover-1":"cable_junction"
}
var installed: Array[Dictionary] = []

func build(host: Node3D) -> void:
	for child: Node in get_children(): child.free()
	installed.clear()
	if host.get_arena_id() != "emberline-ascent": return
	for block: Dictionary in host.recipe.arena.blocks:
		var id := str(block.get("id", ""))
		if not SITES.has(id): continue
		var path := DIRECTORY + str(SITES[id]) + ".glb"
		if not ResourceLoader.exists(path): continue
		var packed := load(path) as PackedScene
		if packed == null: continue
		var prop := packed.instantiate() as Node3D
		var meshes := prop.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() != 1 or not prop.find_children("*", "CollisionObject3D", true, false).is_empty():
			prop.free()
			continue
		var mesh: MeshInstance3D = meshes[0]
		var bounds: AABB = mesh.transform * mesh.mesh.get_aabb()
		var front := float(block.z) - float(block.d) * 0.5
		var floor_y: float = host.height_at(float(block.x), front - 0.2)
		var top := float(block.get("baseY", 0)) + float(block.h)
		var room := top - floor_y - 0.12
		if not is_finite(floor_y) or room < 0.6:
			prop.free()
			continue
		# Existing box remains visibly behind all open frame/dock spaces. These
		# are wall-mounted service fixtures, not a newly blocked doorway or crate.
		var factor := minf(1.0, minf((float(block.w)-0.25)/bounds.size.x, room/bounds.size.y))
		prop.scale = Vector3(factor, factor, 0.10/bounds.size.z)
		prop.position = Vector3(float(block.x), floor_y+0.06-bounds.position.y*factor, front-0.015-bounds.end.z*prop.scale.z)
		prop.name = str(SITES[id])
		add_child(prop)
		prop.set_meta("source_block", id)
		installed.append({"asset":str(SITES[id]), "sourceBlock":id, "position":[prop.position.x,prop.position.y,prop.position.z], "scale":[prop.scale.x,prop.scale.y,prop.scale.z], "projectionMetres":0.115})
