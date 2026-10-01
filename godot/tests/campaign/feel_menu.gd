extends SceneTree
const Menu = preload("res://debug/solo_cheats.gd")
class Client extends Node:
	signal snapshot(frame: Dictionary)
	signal results(frame: Dictionary)
	signal started(frame: Dictionary)
	signal connection_error(message: String)
	var input_epoch := 1
	var sent: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error:
		sent.append(frame.duplicate(true))
		return OK
class Presentation extends RefCounted:
	var local_actor := {"health":100}
class Owner extends Node:
	var client := Client.new()
	var presentation := Presentation.new()
	var phase := 3
	var application_focused := false
	var combat_actions := preload("res://world/combat_actions.gd").new()
	func release_pointer() -> void:
		combat_actions.clear()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	var menu := Menu.new()
	root.add_child(menu)
	menu.bind_session(owner)
	menu.observe({"state":{"soloCheats":{"available":true,"paused":false,"revision":0}}})
	menu.toggle_menu()
	assert(owner.client.sent.size() == 1 and menu.pending)
	owner.client.input_epoch = 2
	menu.observe({"state":{"soloCheats":{"available":true,"paused":false,"revision":0}}})
	assert(owner.client.sent.size() == 2 and owner.client.sent.back().inputEpoch == 2 and menu.pending)
	owner.client.input_epoch = 3
	menu.observe({"state":{"soloCheats":{"available":true,"paused":true,"revision":1}}})
	assert(owner.client.sent.size() == 2 and not menu.pending, "own pause epoch cannot create retry loop")
	owner.presentation.local_actor.health = 0
	menu.refresh()
	assert(menu.available() and not menu.resume.disabled)
	assert(menu.actions.all(func(button: Button) -> bool: return button.disabled))
	assert(menu.toggles.flight.disabled)
	menu.toggle_menu()
	assert(owner.client.sent.back().action == "pause" and owner.client.sent.back().enabled == false)
	menu.observe({"state":{"soloCheats":{"available":true,"paused":false,"revision":2}}})
	assert(not menu.overlay.visible and not menu.available())
	owner.client.free();menu.free();owner.free()
	print("CAMPAIGN_FEEL_MENU_OK stale-epoch-retry=true own-ack-no-retry=true dead-resume=true")
	quit()
