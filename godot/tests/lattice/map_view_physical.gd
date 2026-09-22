extends "res://tests/lattice/physical.gd"
## Reuses input/capture helpers only; executes the actual command-line board scene.
func switch_view(to_map: bool) -> void:
	await click(board.view_choice)
	# Mouse-opened PopupMenu starts with no keyboard-highlighted row.
	await key(KEY_DOWN)
	if to_map: await key(KEY_DOWN)
	await key(KEY_ENTER)
	await process_frame
	check(board.map_view.visible == to_map and board.nodes.visible != to_map, "physical view choice map=%s" % to_map)

func run() -> void:
	await process_frame
	board = current_scene
	if not check(board != null and board.scene_file_path == "res://lattice/board.tscn", "actual board.tscn loaded by engine"):
		quit(1); return
	await process_frame
	check(not board.smoke and board.view_choice.selected == 0, "default list; built-in smoke off")
	await click(board.connect_button)
	if not await wait_for(func() -> bool: return board.phase == "active" and board.client.gate().is_empty(), "Connect reaches real recipient projection"):
		quit(1); return
	observed("connected")
	await switch_view(true)
	var owners_match := true
	for marker: Dictionary in board.map_view.markers:
		if marker.get("owner") != null:
			owners_match = owners_match and board.map_view.owner_symbol(marker) == str(int(marker.owner))
	check(owners_match, "real wire ownership retains team symbols")
	var target: String = "front-%d" % int(board.client.projection.team)
	var index := -1
	for i: int in range(board.map_view.markers.size()):
		if board.map_view.markers[i].id == target: index = i
	if not check(index >= 0, "own public frontier is positioned"):
		quit(1); return
	await click_at(board.map_view.global_position + board.map_view.marker_position(index), "public marker " + target)
	check(board.selected == target and board.nodes.is_selected(board.node_ids.find(target)), "physical marker click synchronizes ItemList")
	check(root.gui_get_focus_owner() == board.map_view, "map click receives native keyboard focus")
	await key(KEY_UP)
	check(board.selected != target, "map Up browses objective")
	await key(KEY_DOWN)
	check(board.selected == target, "map Down restores own frontier")
	check(board.client.actions.is_empty(), "map mouse/keyboard selection sends no orders or purchases")
	await switch_view(false)
	check(board.nodes.is_selected(board.node_ids.find(target)), "List retains map-selected target")
	await switch_view(true)
	if not check(board.selected == target, "view toggles preserve selection"):
		quit(1); return
	if not await wait_for(func() -> bool: return not board.hold_button.disabled, "explicit HOLD enabled"):
		quit(1); return
	await click(board.hold_button)
	await click(board.hold_button)
	check(board.client.actions.size() == 1, "rapid HOLD clicks remain deduplicated")
	if not await wait_for(func() -> bool: return board.client.actions.size() == 1 and board.client.actions[0].status == "pending (server accepted)", "HOLD accepted running by real source"):
		quit(1); return
	observed("map-hold-accepted")
	await create_timer(0.8).timeout
	check(root.get_visible_rect().encloses(board.history.get_global_rect()), "map receipt fully visible without scroll")
	check(root.get_visible_rect().encloses(board.map_view.get_global_rect()), "map fits viewport")
	check(root.get_visible_rect().encloses(board.resources.get_global_rect()) and root.get_visible_rect().encloses(board.hold_button.get_global_rect()), "resources and explicit action visible")
	await capture("map-receipts")
	var disconnect: Button
	for button: Node in board.find_children("*", "Button", true, false):
		if button.text == "Disconnect": disconnect = button
	await click(disconnect)
	check(board.phase == "idle" and board.client.projection.is_empty() and board.client.actions.is_empty() and board.selected.is_empty(), "physical disconnect clears state and selection")
	check(board.map_view.markers.is_empty() and board.map_view.selected.is_empty(), "disconnect removes positioned map targets")
	await click_at(board.map_view.global_position + Vector2(88, 90), "empty disconnected map")
	await key(KEY_DOWN)
	await click(board.hold_button)
	check(board.client.actions.is_empty() and board.selected.is_empty(), "empty map keyboard/click cannot select or submit")
	await capture("map-disconnected")
	record("result", {"checks":checks, "failures":failures, "input":"Input.parse_input_event mouse and physical-key events; not OS input"})
	quit(1 if failures else 0)
