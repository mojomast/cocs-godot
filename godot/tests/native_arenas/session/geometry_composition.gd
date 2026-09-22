extends SceneTree
## Actual geometry integration only; no transport/gameplay acceptance claim.
const Demo = preload("res://native_arenas/demo.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func count_type(node: Node, type: String) -> int:
	var count := 1 if node.is_class(type) else 0
	for child: Node in node.get_children(): count += count_type(child, type)
	return count

func run() -> void:
	var d := Demo.new()
	root.add_child(d)
	if d.phase == -1:
		push_error(d.startup_error)
		quit(1)
		return
	for id: String in d.ids:
		if not d.load_map(id):
			push_error(d.catalog.error)
			failures += 1
			continue
		await process_frame
		var cameras := count_type(d.world, "Camera3D")
		var environments := count_type(d.world, "WorldEnvironment")
		var lights := count_type(d.world, "DirectionalLight3D")
		var ok := cameras == 0 and environments == 1 and lights == 1 and d.camera.position == Vector3.ZERO and d.pickups.markers.is_empty()
		if not ok: failures += 1
		print("NATIVE_DM_GEOMETRY_COMPOSITION ", JSON.stringify({"map":id,"ok":ok,"mapCameras":cameras,
			"environments":environments,"suns":lights,"meshes":count_type(d.world,"MeshInstance3D"),
			"cameraUnassignedUntilSnapshot":d.camera.position == Vector3.ZERO,"evidence":"actual-geometry-only"}))
	d.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
