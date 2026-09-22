extends SceneTree

const Scenery = preload("res://moth_scenery/scenery.gd")
const Atmosphere = preload("res://graphics_atmosphere/atmosphere.gd")
const Library = preload("res://moth/library.gd")
const DetailControl = preload("res://moth_scenery/detail_control.gd")
const REVIEW_MAPS := ["meridian-exchange", "ember-crucible", "asterion-relay"]

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0]
	var viewer = load("res://world/viewer.gd").new()
	root.add_child(viewer)
	viewer.set_process(false)
	var detail_control := DetailControl.new()
	viewer.selector.get_parent().add_child(detail_control)
	var atmosphere := Atmosphere.new()
	var manifest: Array = []
	for id: String in viewer.ids:
		if not viewer.load_map(id):
			quit(1)
			return
		var map: Dictionary = viewer.catalog.resolve_map(id)
		atmosphere.configure(map, viewer.environment, viewer.sun, Library.sky(Atmosphere.sky_name(map)))
		atmosphere.decorate(viewer.world)
		var scenery = Scenery.create(map, viewer.world)
		detail_control.bind_scenery(scenery)
		scenery.set_clock_for_capture(12.0)
		var views := ["street", "service"] if id in REVIEW_MAPS else ["overview"]
		for view: String in views:
			viewer.camera.fov = 72
			viewer.camera.position = Vector3(65, 35, 68) if map.bounds.maxX < 100 else Vector3(110, 52, 102)
			var target := Vector3(0, 2.5, 0)
			if view == "street":
				match id:
					"meridian-exchange":
						viewer.camera.position = Vector3(9, viewer.support_height(map, 9, 21) + 1.8, 21)
						target = Vector3(-10, 2.5, -14)
					"ember-crucible":
						viewer.camera.position = Vector3(-21, viewer.support_height(map, -21, 22) + 1.8, 22)
						target = Vector3(1, 3.0, -4)
					"asterion-relay":
						viewer.camera.position = Vector3(-25, viewer.support_height(map, -25, 8) + 1.8, 8)
						target = Vector3(2, 3.0, -9)
			elif view == "service":
				match id:
					"meridian-exchange":
						viewer.camera.position = Vector3(5, viewer.support_height(map, 5, -6) + 1.8, -6)
						target = Vector3(-1.0, 2.2, -15)
					"ember-crucible":
						viewer.camera.position = Vector3(-17, viewer.support_height(map, -17, 19) + 1.8, 19)
						target = Vector3(-10, 2.7, 11)
					"asterion-relay":
						viewer.camera.position = Vector3(-62, viewer.support_height(map, -62, -63) + 1.8, -63)
						target = Vector3(-58, 1.5, -68)
			viewer.camera.look_at(target)
			# Captures are actual first-person eye height, no aerial close-up trick.
			if view != "overview":
				for b: Dictionary in map.blocks:
					if absf(viewer.camera.position.x - b.x) < b.w / 2 and absf(viewer.camera.position.z - b.z) < b.d / 2 and viewer.camera.position.y < b.h:
						push_error("Capture camera inside solid: " + id + " " + view)
						quit(1)
						return
			var phases := ["before", "after"] if id in REVIEW_MAPS else ["after"]
			for phase: String in phases:
				scenery.visible = phase == "after"
				# Identical overlay in both phases preserves pixel-difference evidence.
				viewer.label.text = "%s · %s\nMoth scenery / fixed source camera / FOV 72 / eye 1.8 m" % [map.name, view]
				for frame in range(5):
					await process_frame
					await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				var name: String = id + "-" + view + "-" + phase + ".png"
				if image.save_png(output.path_join(name)) != OK:
					quit(1)
					return
				manifest.append({"map": id, "view": view, "phase": phase, "file": name, "width": image.get_width(), "height": image.get_height(), "position": [viewer.camera.position.x, viewer.camera.position.y, viewer.camera.position.z], "target": [target.x, target.y, target.z], "fov": viewer.camera.fov, "eye_height": 1.8 if view != "overview" else null, "geometry_sha256": scenery.geometry_hash(), "stats": scenery.stats()})
				print("MOTH_SCENERY_CAPTURE ", name, " ", image.get_size())
				if phase == "after" and view == "service":
					# Measure the original linear LUT and shader-only motion on the
					# actual world view, rather than a separate material gallery.
					for batch: MultiMeshInstance3D in scenery.get_children():
						if batch.material_override.shader == Scenery.PanelShader:
							batch.material_override.set_shader_parameter("lut_strength", 0.0)
					await _save_probe(output.path_join(id + "-service-no-lut.png"))
					for batch: MultiMeshInstance3D in scenery.get_children():
						if batch.material_override.shader == Scenery.PanelShader:
							batch.material_override.set_shader_parameter("lut_strength", 0.10)
					scenery.set_clock_for_capture(25.0)
					await _save_probe(output.path_join(id + "-service-clock25.png"))
					scenery.set_clock_for_capture(12.0)
	var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	atmosphere.clear(viewer.environment)
	viewer.free()
	atmosphere = null
	await process_frame
	print("MOTH_SCENERY_GRAPHICAL_SMOKE maps=9 captures=", manifest.size())
	quit(0)

func _save_probe(path: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Scenery probe save failed: " + path)
		quit(1)
