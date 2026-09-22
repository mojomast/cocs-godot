extends SceneTree
const Demo = preload("res://objectives/demo.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var demo := Demo.new()
	root.add_child(demo)
	demo.set_process(false)
	demo.client.set_process(false)
	await process_frame
	var hud: Node = demo.objective_hud
	var archive: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../port/native-payload-guidance/snapshots.json"))
	for size: Vector2i in [Vector2i(960,640),Vector2i(1280,800)]:
		root.size = size
		await process_frame
		hud.resize()
		await process_frame
		for entry: Dictionary in archive.samples:
			demo.phase = 3
			demo.snapshot_watch.observe()
			demo.objectives.apply_state(entry.state,0)
			hud.apply_state(entry.state,0)
			hud.refresh_status()
			await create_timer(0.15).timeout
			hud.refresh_status()
			check(hud.cart_guidance.visible and hud.cart_guidance.text.contains("Cart "), "cart row visible")
			check(hud.cart_guidance.size.y >= 20, "cart text has nonzero readable height")
			check(hud.cart_guidance.text.contains("Controls released"), "released guidance not push claim")
			check(hud.objective_panel.position.y+hud.objective_panel.size.y <= hud.status_panel.position.y, "dynamic row separates status")
			check(hud.status_panel.position.y+hud.status_panel.size.y < hud.vitals.position.y, "status/vitals separate")
			check(hud.cart_guidance.size.x <= size.x-40, "wrap width bounded")
			check(hud.objective_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "pointer passes through")
			demo.phase = 4
			hud.refresh_status()
			check(not hud.cart_guidance.visible, "results hide approach")
	demo.objectives.apply_state({"config":{"mode":"ctf"}},0)
	demo.phase = 3
	hud.apply_state({},0)
	check(not hud.cart_guidance.visible and demo.objectives.guidance_model.is_empty(), "CTF unchanged")
	demo.objectives.apply_state(archive.samples[0].state,0)
	hud.apply_state(archive.samples[0].state,0)
	demo.snapshot_watch.reset()
	hud.refresh_status()
	check(not hud.cart_guidance.visible and hud.cart_guidance.text.is_empty(), "stale snapshots clear guidance")
	demo.on_error("fixture disconnect")
	hud.on_error("fixture disconnect")
	check(not hud.cart_guidance.visible and hud.cart_guidance.text.is_empty(), "disconnect clears row")
	demo.free()
	print("GUIDANCE_HUD checks=",checks," failures=",failures," synthetic_layout=true")
	quit(1 if failures else 0)
