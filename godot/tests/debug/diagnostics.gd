extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var overlay: Node = root.get_node_or_null("Diagnostics")
	var passed := overlay != null
	if passed:
		var panel: PanelContainer = overlay.get_node_or_null("DiagnosticsOverlay")
		var label: Label = panel.get_node_or_null("DiagnosticsReadout") if panel != null else null
		passed = panel != null and label != null and panel.visible
		if passed:
			passed = label.text.contains("FPS") and label.text.contains("Actors") and label.text.contains("F11")
			var key := InputEventKey.new()
			key.keycode = KEY_F11
			key.pressed = true
			overlay._input(key)
			passed = passed and not panel.visible
			overlay._input(key)
			passed = passed and panel.visible
	if passed: print("MODE_DIAGNOSTICS_OK checks=4")
	else: push_error("Menu-armed diagnostics did not expose a toggleable in-game overlay")
	quit(0 if passed else 1)
