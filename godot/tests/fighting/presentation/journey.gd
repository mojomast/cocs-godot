extends SceneTree
## Native-grant harness: production scene, real InputEvents, no combat writes.
## UI focus is controlled only to make the keyboard journey reproducible.
var shell
var failure := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://fighting/main.tscn")
	shell = scene.instantiate()
	root.add_child(shell)
	await process_frame
	await activate("Start match")
	if not shell.active:
		print("FIGHTING_JOURNEY_BLOCKED ",shell.error_text)
		quit(2)
		return
	await ticks(120)
	key(KEY_C,true)
	await ticks(2)
	check((int(shell.last_inputs[0].held)&64) != 0,"guard input reaches actual core command")
	key(KEY_C,false)
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	await process_frame
	check(shell.paused,"pause through actual Esc event")
	var tick := int(shell.state.tick)
	await ticks(5)
	check(int(shell.state.tick) == tick,"pause freezes simulation")
	await activate("Move list")
	await activate("Back")
	await activate("Fighting Settings & bindings")
	await activate("Back")
	# Real application focus notification, with the same production handler.
	shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check(shell.paused,"focus loss pauses")
	shell.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await activate("Resume")
	# Let the seeded opponent beat an idle human through normal AI commands.
	for i: int in 24000:
		if str(shell.state.phase) == "match_over": break
		await physics_frame
	check(str(shell.state.phase) == "match_over","input-only AI reaches results")
	if failure.is_empty():
		await activate("Rematch")
		check(shell.active and str(shell.state.phase) != "match_over","rematch resets through public UI")
		key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
		await process_frame
		await activate("Character select")
		check(not shell.active,"selection tears down match")
		await activate("Home")
		await process_frame
		check(root.get_node_or_null("OperatorClash") == null,"Home releases fighting scene")
	print("FIGHTING_JOURNEY ",JSON.stringify({"passed":failure.is_empty(),"failure":failure,"throw_tech_native":"separate owner-run two-player journey pending","controller_unplug_native":"owner-run pending"}))
	quit(0 if failure.is_empty() else 1)

func activate(text: String) -> void:
	var button := find_button(root,text)
	if button == null:
		check(false,"missing button: " + text)
		return
	button.grab_focus()
	await process_frame
	key(KEY_ENTER,true); key(KEY_ENTER,false)
	await process_frame
	await process_frame

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child: Node in node.get_children():
		var found := find_button(child,text)
		if found != null: return found
	return null

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func ticks(count: int) -> void:
	for i: int in count: await physics_frame

func check(value: bool, message: String) -> void:
	if not value and failure.is_empty(): failure = message
