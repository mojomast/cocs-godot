extends SceneTree
const Terrain = preload("res://campaign/terrain.gd")
const Occlusion = preload("res://world/combat_occlusion.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func vector(p: Dictionary) -> Vector3: return Vector3(p.x,p.y,p.z)
func run() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("EDGE_MAP_CASES")))
	var camera := Camera3D.new()
	root.add_child(camera)
	for fixture: Dictionary in fixtures:
		var map := Terrain.new()
		root.add_child(map)
		if not map.build(fixture.id):
			push_error("map build " + fixture.id)
			quit(1)
			return
		var geometry := Occlusion.new()
		geometry.configure(camera,{"id":fixture.id,"collision_root":map})
		await physics_frame
		await physics_frame
		for item: Dictionary in fixture.cases:
			var from := vector(item.from)
			var hit := geometry.contact(from,from+vector(item.direction)*float(item.max))
			var distance: float = from.distance_to(hit.position) if not hit.is_empty() else float(item.max)
			checks += 1
			if float(item.distance) == 0.0:
				# Source block rays starting inside conservative rock report zero;
				# contact deliberately rejects inside normals, visibility must block.
				if not geometry.segment_blocked(from,from+vector(item.direction)*float(item.max)): failures += 1
				continue
			if absf(distance-float(item.distance))>0.002:
				failures += 1
				push_error("facade mismatch %s/%s %.6f vs %.6f %s" % [fixture.id,item.block,distance,item.distance,JSON.stringify(item)])
		print("EDGE_MAP ",fixture.id," native/source queries=",fixture.cases.size()," bodies=",geometry.bodies.size())
		map.free()
	camera.free()
	print("EDGE_MAPS ",checks," checks; failures=",failures)
	quit(0 if failures==0 else 1)
