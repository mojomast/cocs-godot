extends "res://tests/lattice/physical.gd"
## Reads recipient/UI state only; all actions use engine mouse/key events.
func observed_economy(event: String) -> void:
	var p: Dictionary = board.client.projection
	record(event, {"map":board.client.requested_map, "actor":board.client.actor_id,
		"peer":board.client.peer_id,"round":board.client.revision,"flux":p.get("flux"),
		"spent":p.get("spent"),"req":p.get("req"),"recruitment":p.get("recruitment"),
		"gate":board.client.action_gate("reinforce"),"actions":board.client.actions.duplicate(true)})

func run() -> void:
	await process_frame
	board = current_scene
	if not check(board != null and board.scene_file_path == "res://lattice/board.tscn", "actual board scene"):
		quit(1); return
	await process_frame
	check(not board.smoke and board.spend_button.disabled, "no smoke activation; purchase disabled initially")
	await click(board.connect_button)
	if not await wait_for(func() -> bool: return board.phase == "active" and board.client.gate().is_empty(), "Connect reaches recipient projection"):
		quit(1); return
	observed_economy("connected")
	await click(board.view_choice)
	await key(KEY_DOWN)
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(board.map_view.visible, "physical Map choice")
	var target := "front-0"
	var index := -1
	for i: int in range(board.map_view.markers.size()):
		if board.map_view.markers[i].id == target: index = i
	if not check(index >= 0, "recipient frontier on map"):
		quit(1); return
	await click_at(board.map_view.global_position + board.map_view.marker_position(index), "front-0 marker")
	await key(KEY_UP)
	check(board.selected != target, "map key changes selection")
	await key(KEY_DOWN)
	check(board.selected == target and board.nodes.is_selected(board.node_ids.find(target)), "map and list share recipient selection")
	await click(board.hold_button)
	await click(board.hold_button)
	if not await wait_for(func() -> bool: return board.client.actions.size() == 1 and board.client.actions[0].status == "pending (server accepted)", "co-op HOLD still accepted exactly once"):
		quit(1); return
	check(board.confirm_spend.disabled and board.spend_button.disabled, "initial deployment is not a spend window")
	await create_timer(0.8).timeout
	await capture("waiting-window")
	# Wait for the actual source wave. No clock overrides, injected funds or sim writes.
	if not await wait_for(func() -> bool: return not board.confirm_spend.disabled, "natural between-wave window authorizes recruitment", 260.0):
		observed_economy("window-timeout")
		await capture("window-timeout")
		quit(1); return
	observed_economy("before-purchase")
	var before: float = float(board.client.projection.spent)
	var spawned: int = int(board.client.projection.recruitment.spawned)
	check(board.spend_button.disabled and not board.confirm_spend.button_pressed, "new window needs fresh explicit consent")
	check(board.spend_button.text == "Co-op REINFORCE" and board.confirm_spend.text.contains("50"), "co-op label and 50 FLUX cost visible")
	await click(board.confirm_spend)
	check(board.confirm_spend.button_pressed and not board.spend_button.disabled, "mouse authorizes one purchase")
	await key(KEY_TAB)
	if not check(root.gui_get_focus_owner() == board.spend_button, "Tab focuses co-op purchase"):
		quit(1); return
	await key(KEY_ENTER)
	await click(board.spend_button)
	await click(board.spend_button)
	check(board.client.actions.size() == 2, "Enter and repeated clicks send exactly one purchase")
	if not await wait_for(func() -> bool: return board.client.actions.size() == 2 and board.client.actions[1].status == "confirmed", "source done receipt confirms recruitment"):
		observed_economy("purchase-failed")
		quit(1); return
	check(is_equal_approx(float(board.client.projection.spent) - before, 50.0), "source cumulative spent increases exactly 50")
	check(int(board.client.projection.recruitment.spawned) == spawned + 1, "source spawned counter increases exactly one")
	check(not board.confirm_spend.button_pressed and board.spend_button.disabled, "consent consumed after purchase")
	await create_timer(0.8).timeout
	check(root.get_visible_rect().encloses(board.history.get_global_rect()), "both receipts inside viewport")
	check(root.get_visible_rect().encloses(board.resources.get_global_rect()) and root.get_visible_rect().encloses(board.spend_button.get_global_rect()), "resources and purchase visible")
	observed_economy("purchase-confirmed")
	await capture("economy-receipts")
	var disconnect: Button
	for button: Node in board.find_children("*", "Button", true, false):
		if button.text == "Disconnect": disconnect = button
	await click(disconnect)
	check(board.client.actions.is_empty() and board.client.projection.is_empty() and board.map_view.markers.is_empty(), "disconnect clears receipts and recipient map")
	await click(board.spend_button)
	check(board.client.actions.is_empty() and not board.confirm_spend.button_pressed, "disconnected click cannot purchase")
	await capture("economy-disconnected")
	record("result", {"checks":checks,"failures":failures,"input":"engine mouse and physical-key events; not OS input"})
	quit(1 if failures else 0)
