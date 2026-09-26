extends SceneTree
## Render-only recipient fixture for the real native REQ panel. Synthetic wire
## data makes the catalogue readable without claiming a live purchase/result.
class StubSession extends Node:
	var client: Node
	func world_command_gate() -> String: return ""

class RecordingTransport extends "res://lattice/world_transport.gd":
	func connection_open() -> bool: return true
	func send_frame(_frame: Dictionary) -> Error: return OK
const Commands = preload("res://lattice/world_commands.gd")

func _initialize() -> void: call_deferred("capture")

func capture() -> void:
	var output := ""
	var width := 1280
	var height := 800
	var item := "sentry"
	var authorize := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): output = arg.trim_prefix("--capture=")
		elif arg.begins_with("--width="): width = int(arg.trim_prefix("--width="))
		elif arg.begins_with("--height="): height = int(arg.trim_prefix("--height="))
		elif arg.begins_with("--item="): item = arg.trim_prefix("--item=")
		elif arg == "--authorize": authorize = true
	if output.is_empty() or width < 760 or height < 520:
		quit(2)
		return
	root.size = Vector2i(width, height)
	var client := RecordingTransport.new()
	client.mode = "cocs"
	client.allowlist = {"asterion-relay":{"modes":["cocs"]}}
	client.requested_map = "asterion-relay"
	for message: Dictionary in [
		{"type":"welcome","v":3,"roomId":"render-fixture","peerId":1},
		{"type":"lobby","players":[{"peerId":1,"actorId":0}]},
		{"type":"start","mapId":"asterion-relay","roundRevision":1,"config":{"mode":"cocs"}},
		{"type":"snapshot","seq":1,"acks":{"0":1},"state":{"mapId":"asterion-relay",
			"actors":[{"id":0,"team":0,"x":0,"y":2,"z":0,"yaw":0,"pitch":0,"health":100}],
			"cocs":{"roundRevision":1,"nodes":[{"id":"front-0","x":0,"z":0,"owner":null}],
				"flux":{"0":80},"fluxSpent":{"0":0},"req":[{"id":0,"req":200}],"traversal":{"depots":[]}}}},
	]:
		if not client.decode_text(JSON.stringify(message)):
			push_error("Synthetic recipient fixture rejected")
			quit(1)
			return
	var session := StubSession.new()
	session.client = client
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var commands := Commands.new()
	layer.add_child(commands)
	commands.set_process(false)
	commands.world_bind(session)
	commands.show()
	commands.tabs.current_tab = 1
	commands.world_refresh()
	var index := -1
	var options: Array = client.req_options()
	for i: int in range(options.size()):
		if options[i].get("id") == item: index = i
	if index < 0:
		push_error("Requested fixture item is not in the source mirror")
		quit(2)
		return
	commands.world_req_select(index)
	if authorize: commands.req_confirm.button_pressed = true
	for _frame: int in range(3): await RenderingServer.frame_post_draw
	var bounds := commands.panel.get_rect()
	if bounds.position.x < 0 or bounds.position.y < 0 or bounds.end.x > width or bounds.end.y > height or commands.req_items.item_count != options.size() or commands.req_name.text != options[index].get("name"):
		push_error("REQ panel or catalog clipped outside the viewport")
		layer.free()
		session.free()
		client.free()
		quit(1)
		return
	var image := root.get_texture().get_image()
	print("REQ_UI_CAPTURE item=", item, " rows=", options.size(), " size=", root.size)
	var result := image.save_png(output)
	layer.free()
	session.free()
	client.free()
	for _frame: int in range(3): await RenderingServer.frame_post_draw
	quit(result)
