extends SceneTree
## Pending native font/container check. No connection or authority is constructed.
const Hud = preload("res://combined_arms/hud.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	print("VEHICLE_HUD ", "PASS " if value else "FAIL ", message)
	if not value: failures += 1

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 12: await process_frame

func run() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for profile: Dictionary in [{"size":Vector2i(760,520),"scale":1.5},{"size":Vector2i(1280,800),"scale":1.0}]:
		root.size = profile.size
		root.content_scale_factor = profile.scale
		hud.update({"health":100,"team":0,"vehicleSeat":"driver"},{"kind":"titan","driver":0,"gunner":null,"passengers":[null],"health":650,"maxHealth":650,"heat":0},{},true,"active",0,"")
		hud.objective({"objectives":{"kind":"domination","zones":[{},{},{}]},"teamScores":{"0":1.083,"1":0.0},"config":{"fragLimit":900}},true)
		await settle()
		var view := root.get_visible_rect().size
		check(hud.top_rows.get_combined_minimum_size().y <= hud.top_scroll.size.y+1,"status/objective fits " + str(profile))
		check(hud.bottom_rows.get_combined_minimum_size().y <= hud.bottom_scroll.size.y+1,"all driver instructions fit " + str(profile))
		check(not hud.scroll_hint.visible,"normal instructions need no scrolling " + str(profile))
		check(hud.bottom_scroll.get_rect().end.y <= view.y-Hud.FOOTER_SAFE+1,"F12 safe area " + str(profile))
		check(hud.top_scroll.get_rect().end.y+Hud.HUD_GAP <= hud.bottom_scroll.position.y+1,"no region overlap " + str(profile))
		check(is_equal_approx(root.content_scale_factor,profile.scale),"accessibility scale retained")
		# Stress wrapped localization/remapping without shrinking accessibility text.
		hud.help.text += "\n" + "Extended remapped control instructions ".repeat(100)
		await settle()
		check(hud.scroll_hint.visible,"overflow navigation remains outside scrolling content")
		check(hud.scroll_hint.get_rect().end.y <= view.y-Hud.FOOTER_SAFE+1,"overflow hint stays above F12")
		hud.bottom_scroll.grab_focus()
		var event := InputEventKey.new()
		event.keycode = KEY_END
		event.pressed = true
		hud.bottom_scroll.gui_input.emit(event)
		await settle()
		check(hud.bottom_scroll.scroll_vertical > 0,"shared End navigation reaches lower actions")
		event.keycode = KEY_HOME
		hud.bottom_scroll.gui_input.emit(event)
		await settle()
		check(hud.bottom_scroll.scroll_vertical == 0,"shared Home navigation restores critical controls")
		hud.bottom_scroll.release_focus()
	hud.queue_free()
	await process_frame
	quit(1 if failures else 0)
