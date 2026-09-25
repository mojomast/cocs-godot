extends SceneTree
## Boundary fixture, not live-authority evidence. Only the queue is substituted.
const Demo = preload("res://lattice/world_demo.gd")
const Commands = preload("res://lattice/world_commands.gd")
class QueueProbe extends "res://lattice/world_transport.gd":
	var frames: Array[Dictionary] = []
	func connection_open() -> bool: return true
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame.duplicate(true))
		return OK

var demo: Node
var panel: Control
var client: Node
var checks := 0
var failures := 0
var seq := 0
var revision := 0
var actor := {"id":0,"team":0,"x":-100,"y":2,"z":4,"yaw":1,"pitch":0,"health":100,"eyeHeight":1.45}
var state := {"mapId":"asterion-relay"}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	print("WORLD_COMMANDS_CONTRACT ", message, " ", ok)

func wire(frame: Dictionary) -> void:
	if not client.decode_text(JSON.stringify(frame)): failures += 1; push_error("Fixture wire rejected")

func snapshot() -> void:
	seq += 1
	wire({"type":"snapshot","seq":seq,"state":state})
	panel.world_refresh()

func fresh() -> void:
	demo.application_focused = true
	demo.world_wait_release = false
	client.mode = "cocs"
	wire({"type":"welcome","v":3,"roomId":"fixture","peerId":1})
	wire({"type":"lobby","players":[{"peerId":1,"actorId":0}]})
	revision += 1
	wire({"type":"start","mapId":demo.current_id,"config":{"mode":client.mode},"roundRevision":revision})
	actor.health = 100
	state.actors = [actor]
	state.cocs = {"roundRevision":revision,"nodes":[{"id":"front-0","x":-52,"z":-8,"owner":null}],"flux":{"0":60},"fluxSpent":{"0":0},"roleBoard":{"0":{"allow":["fighter"],"threads":{"used":0,"cap":4},"spawned":0}}}
	panel.show()
	snapshot()
	panel.world_select(0)
	panel.confirm_spend.button_pressed = true
	check(panel.selected == "front-0" and panel.confirm_spend.button_pressed and not panel.spend_button.disabled, "fresh fixture can explicitly select and authorize")

func cleared(message: String) -> void:
	panel.world_refresh()
	check(panel.selected.is_empty() and not panel.confirm_spend.button_pressed and panel.hold_button.disabled and panel.spend_button.disabled, message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	demo = Demo.new()
	demo.client.free()
	demo.client = QueueProbe.new()
	client = demo.client
	demo.current_id = "asterion-relay"
	demo.selected_mode = "cocs"
	client.allowlist = {demo.current_id:{"modes":["cocs","cocs-coop"]}}
	client.requested_map = demo.current_id
	client.lobby.connect(demo.on_lobby)
	client.started.connect(demo.on_started)
	client.snapshot.connect(demo.on_snapshot)
	client.results.connect(demo.on_results)
	demo.lattice_hud.heights["front-0"] = 0.0
	panel = Commands.new()
	demo.world_commands = panel
	root.add_child(panel)
	panel.set_process(false)
	panel.world_bind(demo)
	fresh()
	check(client.actions.is_empty() and client.frames.is_empty(), "selection and consent never enqueue automatically")
	panel.world_purchase()
	panel.world_purchase()
	check(client.actions.size() == 1 and client.frames.size() == 1 and not panel.confirm_spend.button_pressed, "one explicit purchase consumes consent before signal reentry")
	check(client.projection.spent == 0 and client.projection.flux == 60 and client.projection.roles.spawned == 0 and client.actions[0].status == "queued", "queued request never optimistically spends or spawns")
	fresh()
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	cleared("focus loss clears selection and authorization immediately")
	var neutral: Dictionary = client.frames.back().input
	check(neutral.x == 0 and neutral.z == 0 and not neutral.fire and not neutral.interact and not neutral.mobility and not neutral.has("weapon"), "focus loss queues neutral through same input adapter")
	demo._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	panel.world_refresh()
	check(panel.selected.is_empty() and not panel.confirm_spend.button_pressed and not demo.can_capture_pointer(), "focus return does not restore consent or recapture")
	fresh()
	demo.snapshot_watch.advance(2)
	cleared("stale world pose clears and disables")
	fresh()
	actor.health = 0
	snapshot()
	cleared("authoritative death clears and disables")
	fresh()
	wire({"type":"lobby","players":[{"peerId":1,"actorId":1}]})
	cleared("actor reassignment clears old selection and authorization")
	check(client.actions.is_empty() and client.projection.is_empty(), "identity change clears recipient pending actions")
	fresh()
	state.erase("cocs")
	snapshot()
	cleared("missing recipient projection clears and disables")
	fresh()
	wire({"type":"results","state":state})
	cleared("results clear and disable")
	fresh()
	client.disconnect_server()
	cleared("disconnect clears and disables")
	fresh()
	demo.world_close_commands()
	panel.world_hold()
	panel.world_purchase()
	check(panel.selected.is_empty() and not panel.confirm_spend.button_pressed and client.actions.is_empty(), "hidden panel cannot issue actions and close drops consent")
	# Co-op UI authorization is keyed to the transport's recipient lease.
	fresh()
	client.mode = "cocs-coop"
	state.cocs.coop = true
	state.cocs.command = {"executor":0,"leaseUntil":500,"slices":[{"id":0,"allowance":60}],"threads":{"used":0,"cap":4}}
	state.cocs.director = {"phase":"intermission","wave":1,"intermission":{"open":true,"sinks":[{"id":"REINFORCE","cost":50,"available":true,"enabled":true,"affordable":true}]}}
	snapshot()
	check(panel.confirm_spend.text.contains("50") and not panel.confirm_spend.disabled, "co-op price and permission come from existing adapter")
	panel.confirm_spend.button_pressed = true
	state.cocs.command.leaseUntil = 600
	snapshot()
	check(not panel.confirm_spend.button_pressed and panel.spend_button.disabled, "lease change invalidates old purchase consent")
	panel.confirm_spend.button_pressed = true
	panel.world_purchase()
	check(client.frames.back().action == "reinforce" and client.actions.size() == 1 and not panel.confirm_spend.button_pressed, "co-op purchase routes through existing activate once")
	for node: Node in [panel,demo.client,demo.camera,demo.sun,demo.environment,demo.label,demo.selector,demo.world_label,demo.combat_label,demo.pickups,demo.presentation,demo.combat,demo.lattice_hud]: node.free()
	demo.free()
	print("WORLD_COMMANDS_CONTRACT checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
