extends SceneTree
# Read-only geometry regression on the actual disconnected scene. No gameplay,
# transport injection, state changes, direct UI handlers, or authority required.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var session: Node = load("res://world/session.tscn").instantiate()
	root.add_child(session)
	await create_timer(0.3).timeout
	var hud: Node = session.get_node("GameHUD")
	var leave: Rect2 = session.lobby_menu.leave_button.get_global_rect()
	var score: Rect2 = hud.score_label.get_global_rect()
	var overlaps := leave.intersects(score)
	print("LOBBY_HUD_GEOMETRY ",JSON.stringify({"viewport":[root.size.x,root.size.y],"disconnected_hud_visible":hud.root.visible,"leave_rect":str(leave),"score_rect":str(score),"intersects":overlaps,"leave_visible_now":session.lobby_menu.leave_button.visible}))
	session.free()
	quit(1 if overlaps else 0)
