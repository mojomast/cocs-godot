extends SceneTree
const Stage = preload("res://tests/new_maps/parallax_glyph/AC01/staged.gd")
func _initialize() -> void:
	call_deferred("run")
	create_timer(150).timeout.connect(func() -> void: quit(2))
func run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var world := Stage.make_world(holder,"parallax-observatory",true)
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var rows: Array = []
	for z: float in [-37.0,-34.0,-31.0]:
		for x: float in [44.0,48.0]:
			var origin := Vector3(x,13.5,z)
			var end := origin + Vector3(4.0 if x == 44.0 else -4.0,0,0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end))
			assert(hit.is_empty(), "Fresh 4m aperture obstruction")
			rows.append({"origin":[origin.x,origin.y,origin.z],"end":[end.x,end.y,end.z],"clear":true})
		var origin := Vector3(46,12.1,z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3(0,-.2,0)))
		assert(not hit.is_empty() and abs(hit.position.y-12.0)<.0001, "Fresh aperture grade differs")
		rows.append({"origin":[origin.x,origin.y,origin.z],"gradeY":hit.position.y})
	var path := Stage.directory("parallax-observatory")+"targeted-rays.json"
	assert(not FileAccess.file_exists(path))
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"selectedArt":world.get_meta("selected_art"),"scope":"six 4m aperture and three grade rays on actual WorldMap authority colliders; not the historical 13587 capsule suite or visual-mesh collision proof","rays":rows},"  ")+"\n")
	holder.free()
	quit()
