extends Node3D
## Radius and height come directly from the recipient snapshot, including rotations.
var markers: Dictionary = {}
var rendered: Array[Dictionary] = []

func clear_round() -> void:
	for marker: Node3D in markers.values():
		remove_child(marker)
		marker.queue_free()
	markers.clear()
	rendered.clear()

func apply(projection: Dictionary) -> void:
	if projection.is_empty():
		clear_round()
		return
	var live: Dictionary = {}
	rendered.clear()
	for zone: Dictionary in projection.zones:
		live[zone.id] = true
		var marker: Node3D
		if not markers.has(zone.id):
			marker = Node3D.new()
			var ring := MeshInstance3D.new()
			ring.name = "Radius"
			marker.add_child(ring)
			var caption := Label3D.new()
			caption.name = "Caption"
			caption.position.y = 3.2
			caption.font_size = 40
			caption.pixel_size = 0.012
			caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.add_child(caption)
			add_child(marker)
			markers[zone.id] = marker
		marker = markers[zone.id]
		marker.position = Vector3(zone.x, zone.y, zone.z)
		var ring: MeshInstance3D = marker.get_node("Radius")
		if ring.get_meta("radius", -1) != zone.radius:
			var mesh := TorusMesh.new()
			mesh.inner_radius = maxf(0.01, zone.radius - 0.08)
			mesh.outer_radius = zone.radius + 0.08
			ring.mesh = mesh
			ring.position.y = 0.12
			ring.set_meta("radius", zone.radius)
		var color := Color("ffd166") if zone.contested else (Color("63e3c5") if zone.owner != null and int(zone.owner) == projection.team else (Color("ff826f") if zone.owner != null else Color("d4e2ee")))
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		ring.material_override = material
		var caption: Label3D = marker.get_node("Caption")
		caption.text = "%s · %s · %.0f%%" % [zone.id.to_upper(), "CONTESTED" if zone.contested else preload("res://zone_modes/adapter.gd").allegiance(zone.owner, projection.team), zone.progress]
		caption.modulate = color
		rendered.append(zone.duplicate(true))
	for id: String in markers.keys():
		if not live.has(id):
			remove_child(markers[id])
			markers[id].queue_free()
			markers.erase(id)
