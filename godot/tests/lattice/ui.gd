extends SceneTree
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var board: Control = load("res://lattice/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	check(board.hold_button.disabled, "disconnected HOLD disabled")
	check(board.spend_button.disabled, "disconnected spend disabled")
	check(board.hold_button.focus_mode == Control.FOCUS_ALL, "HOLD keyboard-focusable")
	check(board.confirm_spend.focus_mode == Control.FOCUS_ALL, "purchase authorization keyboard-focusable")
	check(board.nodes.focus_mode == Control.FOCUS_ALL, "target list keyboard-focusable")
	check(board.known(null) == "unknown / hidden", "unknown label is explicit")
	board.selected = "old-node"
	board.confirm_spend.button_pressed = true
	board.client.actions.append({"kind":"fighter", "cardId":"old", "status":"queued", "reason":null})
	board.disconnect_session()
	check(board.selected.is_empty() and not board.confirm_spend.button_pressed, "disconnect clears selection and spend authorization")
	check(board.client.actions.is_empty(), "disconnect clears receipt history")
	board.notice.text = "SYNTHETIC long refusal: " + "reason ".repeat(40)
	board.refresh()
	await process_frame
	check(board.notice.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "long refusal wraps")
	check(board.history.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "long receipt wraps")
	board.queue_free()
	await process_frame
	print("LATTICE_UI_SYNTHETIC %d checks, %d failures (not OS keyboard acceptance)" % [checks, failures])
	quit(1 if failures else 0)
