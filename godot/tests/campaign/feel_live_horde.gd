extends "res://tests/campaign/feel_live.gd"
## Bounded shared-menu integration check. No Horde wave progression claims.
func run() -> void:
	root.size = Vector2i(640, 480)
	root.scaling_3d_scale = .35
	root.grab_focus()
	var scene: PackedScene = load("res://horde/demo.tscn")
	session = scene.instantiate()
	root.add_child(session)
	session.client.snapshot.connect(func(frame: Dictionary) -> void: latest = frame.state)
	if not await wait_for(func() -> bool: return session.phase == 3 and session.received_pose, "Horde real authority starts", 25): finish(); return
	menu = session.solo_cheats
	if not await wait_for(func() -> bool: return menu.available(), "Horde cheat availability"): finish(); return
	# Visible launcher first; F3 resumes below.
	var epoch: int = session.client.input_epoch
	menu.launcher.pressed.emit()
	if not await wait_for(func() -> bool: return menu.overlay.visible and menu.state.get("paused") == true and not menu.pending and session.client.input_epoch > epoch, "Horde launcher pauses"): finish(); return
	var paused: float = latest.time
	await create_timer(.5).timeout
	check(float(latest.time) == paused, "Horde authority clock really paused")
	if not await command(menu.toggles.invulnerable): finish(); return
	check(menu.state.invulnerable, "Horde invulnerability authority confirmed")
	if not await command(menu.actions[0]): finish(); return
	check(actor().ammo.size() == 10, "Horde all-weapon grant snapshot")
	await capture("horde-cheats", Vector2i(760, 520))
	if not await command(menu.actions[2]): finish(); return
	if not await menu_toggle(): finish(); return
	check(not menu.overlay.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Horde F3 resumes and captures")
	if not await wait_for(func() -> bool: return float(latest.time) > paused+.1, "Horde source clock resumes"): finish(); return
	measurements["horde"] = {"map":latest.mapId,"sourceTimeBefore":paused,"sourceTimeAfter":latest.time,"inputEpoch":session.client.input_epoch,"cheats":menu.state}
	finish()
