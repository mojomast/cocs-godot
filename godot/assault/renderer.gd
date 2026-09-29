extends Node3D
## Only the active source sector is marked; inactive sectors cannot imply capture.
var marker: MeshInstance3D
var caption: Label3D

func clear_round() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	marker = null
	caption = null

func apply_sector(sector: Dictionary) -> void:
	if sector.is_empty():
		clear_round()
		return
	if not is_instance_valid(marker):
		marker = MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.height = 0.06
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.65, 0.12, 0.32)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		add_child(marker)
		caption = Label3D.new()
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.font_size = 40
		add_child(caption)
	var cylinder: CylinderMesh = marker.mesh
	cylinder.top_radius = sector.radius
	cylinder.bottom_radius = sector.radius
	marker.position = Vector3(sector.x, float(sector.y)+0.08, sector.z)
	caption.position = Vector3(sector.x, float(sector.y)+2.5, sector.z)
	caption.text = "%s · %.1f%%" % [str(sector.id).to_upper(), float(sector.progress)]
