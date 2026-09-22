extends SceneTree
## Explicit large-allocation lifecycle probe, never run by a normal game/demo.
const Demo = preload("res://particle_lab/demo.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var scene = Demo.instantiate()
	root.add_child(scene)
	scene._orbit = false
	var ids: Dictionary = scene.field.resource_ids()
	var samples: Array[Dictionary] = []
	for cycle in 4:
		samples.append({"cycle": cycle, "objects": 0, "resources": 0, "static_bytes": 0, "render_buffer_bytes": 0})
	for _frame in 12: await RenderingServer.frame_post_draw
	for cycle in 4:
		if cycle > 0:
			for amount in [131072, 524288, 1048576, 32768]:
				check(scene.field.configure(amount, "galaxy", "gpu").ok, "Large reconfiguration succeeds")
				check(scene.field.clock == 0.0, "Large reconfiguration resets clock")
				check(scene.field.resource_ids() == ids, "Large reconfiguration preserves node/material identities")
				for _frame in 6: await RenderingServer.frame_post_draw
				check(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) >= amount * 2, "Full-count native primitive submission during lifecycle probe")
		for _frame in 4: await RenderingServer.frame_post_draw
		samples[cycle].objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		samples[cycle].resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		samples[cycle].static_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC))
		samples[cycle].render_buffer_bytes = int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))
	for i in range(1, samples.size()):
		check(samples[i].render_buffer_bytes <= samples[0].render_buffer_bytes + 65536, "Million-particle buffers are released when returning to 32K")
		check(samples[i].objects <= samples[0].objects + 2 and samples[i].resources <= samples[0].resources + 2, "No accumulating objects/resources after large resize cycle")
		check(samples[i].static_bytes <= samples[0].static_bytes + 1048576, "No >1MiB retained engine static-memory growth after large resize cycle")
	var material_ref: WeakRef = weakref(scene.field.draw_material)
	var mesh_ref: WeakRef = weakref(scene.field.mesh)
	scene.queue_free()
	for _frame in 4: await RenderingServer.frame_post_draw
	check(material_ref.get_ref() == null and mesh_ref.get_ref() == null, "Whole scene teardown releases field resources")
	print("PARTICLE_LAB_STRESS_LIFECYCLE " + JSON.stringify({"ok": failures.is_empty(), "failures": failures, "cycles": samples, "highest_actual_amount": 1048576, "backend": "gpu", "after_teardown_render_buffer_bytes": int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))}))
	quit(0 if failures.is_empty() else 1)
