extends Node3D
## Rendered positive/negative control: exhaust aimed at a solid wall must not
## emerge on its camera-facing side; an equivalent front-side source must draw.
const Manager = preload("res://combat_particles/manager.gd")
var manager := Manager.new()
var camera := Camera3D.new()
var frame := 0
var baseline: Image
var behind: Image
var output := ""
var finishing := false
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	get_window().size = Vector2i(320, 240)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Engine.max_fps = 60
	add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 3, 0))
	camera.current = true
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(12, 8, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.05, 0.07, 0.1)
	wall.mesh = mesh
	wall.material_override = material
	wall.position = Vector3(0, 4, 0)
	add_child(wall)
	add_child(manager)
	manager.ambient_enabled = false
	manager.configure(camera, {"id": "occlusion-control", "bounds": AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20)), "blocks": [{"x": 0, "z": 0, "w": 12, "h": 8, "d": 1}]})
	manager.set_quality("High")

func _process(_delta: float) -> void:
	if finishing: return
	frame += 1
	if frame == 8:
		await RenderingServer.frame_post_draw
		baseline = get_viewport().get_texture().get_image()
	if frame > 8:
		var z := -1.7 if frame < 140 else 3.0
		manager.apply_state({"rockets": [{"id": 1, "owner": 7, "weapon": 1, "pos": {"x": 0, "y": 3, "z": z}, "dir": {"x": 0, "y": 0, "z": -1}}]}, 7)
	if frame == 138:
		await RenderingServer.frame_post_draw
		behind = get_viewport().get_texture().get_image()
		manager.reset()
	if frame == 210:
		finishing = true
		await RenderingServer.frame_post_draw
		var front := get_viewport().get_texture().get_image()
		var hidden_changed := difference(baseline, behind)
		var front_changed := difference(baseline, front)
		var record := {"behind_wall_changed_pixels": hidden_changed, "front_control_changed_pixels": front_changed,
			"renderer": RenderingServer.get_video_adapter_name(), "wall_collision_cells": manager.occupancy.solid_cells,
			"viewport": [front.get_width(), front.get_height()], "frames": frame}
		var ok := hidden_changed == 0 and front_changed > 20
		print("COMBAT_PARTICLES_OCCLUSION ", "PASS " if ok else "FAIL ", JSON.stringify(record))
		if not output.is_empty():
			behind.save_png(output + "-behind.png")
			front.save_png(output + "-front.png")
			var file := FileAccess.open(output + ".json", FileAccess.WRITE)
			file.store_string(JSON.stringify(record, "\t") + "\n")
		get_tree().quit(0 if ok else 1)

func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in range(20, 220):
		for x in range(40, 280):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02: changed += 1
	return changed
