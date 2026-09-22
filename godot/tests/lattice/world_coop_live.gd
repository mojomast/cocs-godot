extends "res://tests/lattice/world_commands_live.gd"
## Actual world panel; read recipient state, act only through engine UI events.

func observed(event: String) -> void:
	var p: Dictionary = demo.client.projection
	record(event, {"round":demo.client.revision, "spent":p.get("spent"),
		"req":p.get("req"), "recruitment":p.get("recruitment"),
		"command":p.get("command"), "consent":panel.confirm_spend.button_pressed,
		"gate":panel.economy_help.text, "actions":demo.client.actions.duplicate(true)})

func abort(message: String) -> void:
	observed(message)
	await capture(message)
	record("result", {"checks":checks,"failures":failures})
	quit(1)

func run() -> void:
	await process_frame
	demo = current_scene
	panel = demo.world_commands
	if not await wait_for(func() -> bool: return demo.can_capture_pointer(), "ordinary world host ready", 15):
		await abort("host-timeout"); return
	check(demo.scene_file_path == "res://lattice/world_demo.tscn" and panel.client == demo.client and demo.client.mode == "cocs-coop", "actual co-op world and shared movement socket")
	await click(Vector2(900, 600))
	await key(KEY_W, true)
	await mouse(Vector2(900, 600), true)
	await create_timer(0.15).timeout
	await toggle()
	record("opened")
	check(panel.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not demo.can_capture_pointer(), "C releases pointer with W/fire held")
	await create_timer(0.6).timeout
	var position: Vector3 = demo.camera.position
	record("overlay-settled")
	await create_timer(0.4).timeout
	check(demo.camera.position.distance_to(position) < 0.1, "overlay stops authoritative motion with W/fire held")
	await key(KEY_W, false)
	await mouse(Vector2(900, 600), false)
	var index: int = panel.node_ids.find("front-%d" % int(demo.client.projection.team))
	if not check(index >= 0, "own frontier listed"):
		await abort("frontier-missing"); return
	await click(panel.nodes.global_position + panel.nodes.get_item_rect(index).get_center())
	check(panel.selected == panel.node_ids[index] and demo.client.actions.is_empty(), "selection submits nothing")
	await button(panel.hold_button)
	await button(panel.hold_button)
	# Source bots can replace the HOLD before the first receipt snapshot. A
	# done/replaced card is also accepted; it is not an objective capture claim.
	if not await wait_for(func() -> bool: return demo.client.actions.size() == 1 and demo.client.actions[0].status in ["pending (server accepted)", "confirmed"], "one HOLD accepted by source (running or already settled)", 5):
		await abort("hold-failed"); return
	observed("hold-receipt")
	check(panel.confirm_spend.disabled and panel.spend_button.disabled, "initial deployment recruitment closed")
	await capture("waiting-window")
	if not await wait_for(func() -> bool: return not panel.confirm_spend.disabled, "natural intermission permits recruitment", 155):
		await abort("window-timeout"); return
	observed("window-open")
	check(not panel.confirm_spend.button_pressed and panel.spend_button.disabled and panel.confirm_spend.text.contains("50") and panel.spend_button.text == "Purchase co-op REINFORCE", "natural window needs explicit 50-FLUX consent")
	await button(panel.spend_button)
	check(demo.client.actions.size() == 1, "purchase without consent sends nothing")
	await button(panel.confirm_spend)
	if not check(panel.confirm_spend.button_pressed and not panel.spend_button.disabled, "engine click authorizes expiring lease"):
		await abort("lease-consent-failed"); return
	var old_lease: float = demo.client.projection.command.leaseUntil
	observed("old-consent")
	await capture("authorized-old-lease")
	if not await wait_for(func() -> bool: return demo.client.projection.get("command", {}).get("leaseUntil", old_lease) != old_lease, "source lease expires naturally", 13):
		await abort("lease-timeout"); return
	observed("lease-rotated")
	check(not panel.confirm_spend.button_pressed and panel.spend_button.disabled, "natural epoch change drops old consent")
	await button(panel.spend_button)
	await create_timer(0.3).timeout
	check(demo.client.actions.size() == 1, "old consent cannot purchase after natural lease expiration")
	observed("old-consent-blocked")
	await capture("expired-consent")
	if not check(not panel.confirm_spend.disabled, "same natural window still permits new consent"):
		await abort("window-lost"); return
	observed("before-purchase")
	var spent: float = demo.client.projection.spent
	var spawned: int = demo.client.projection.recruitment.spawned
	await button(panel.confirm_spend)
	check(panel.confirm_spend.button_pressed, "new deliberate consent for current lease")
	observed("fresh-consent")
	await key(KEY_TAB, true)
	await key(KEY_TAB, false)
	if not check(root.gui_get_focus_owner() == panel.spend_button, "Tab focuses REINFORCE"):
		await abort("focus-failed"); return
	await key(KEY_ENTER, true)
	await key(KEY_ENTER, false)
	await button(panel.spend_button)
	await button(panel.spend_button)
	check(demo.client.actions.size() == 2 and not panel.confirm_spend.button_pressed, "Enter and repeated clicks consume one consent")
	if not await wait_for(func() -> bool: return demo.client.actions.size() == 2 and demo.client.actions[1].status == "confirmed", "matching source done receipt", 8):
		await abort("purchase-failed"); return
	check(is_equal_approx(float(demo.client.projection.spent) - spent, 50.0) and int(demo.client.projection.recruitment.spawned) == spawned + 1, "recipient cumulative spent +50 and spawned +1")
	observed("purchase-receipt")
	await capture("purchase-receipt")
	check(panel.panel.get_global_rect().end.x <= root.size.x and panel.panel.get_global_rect().end.y <= root.size.y, "panel fits viewport")
	await key(KEY_W, true)
	record("closing")
	await toggle()
	await mouse(Vector2(900, 600), true)
	check(not panel.visible and panel.selected.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "close drops selection and held W blocks recapture")
	await key(KEY_W, false)
	await process_frame
	check(not demo.can_capture_pointer(), "held mouse still blocks recapture")
	await mouse(Vector2(900, 600), false)
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "releasing controls alone does not resume")
	record("resume-click")
	await click(Vector2(900, 600))
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "fresh click recaptures")
	var previous: Vector3 = demo.camera.position
	record("movement-start")
	await key(KEY_D, true)
	await create_timer(0.5).timeout
	await key(KEY_D, false)
	check(demo.camera.position.distance_to(previous) > 0.5, "same actor moves after fresh click")
	record("movement-end")
	await toggle()
	record("reopened")
	check(not panel.confirm_spend.button_pressed and panel.spend_button.disabled, "reopening restores no stale consent")
	await button(panel.spend_button)
	await create_timer(0.8).timeout
	check(demo.client.actions.size() == 2, "reopened repeated purchase cannot duplicate")
	observed("final-receipt")
	await capture("reopened")
	demo.client.disconnect_server()
	await process_frame
	check(demo.client.actions.is_empty() and not panel.confirm_spend.button_pressed and not demo.can_capture_pointer(), "disconnect clears controls and consent")
	record("result", {"checks":checks,"failures":failures,"input":"engine key/mouse events; not OS/human input"})
	quit(0 if failures == 0 else 1)
