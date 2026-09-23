extends SceneTree
const View = preload("res://lattice/map_view.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func link_state(view: Control, a: String, b: String) -> String:
	for link: Dictionary in view.links:
		if (link.a == a and link.b == b) or (link.a == b and link.b == a): return link.state
	return ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(924, 184)
	var public_nodes := [{"id":"west", "x":-104, "z":0, "owner":0, "live":true, "secret":"not copied"},
		{"id":"east", "x":104, "z":0, "owner":1}, {"id":"north", "x":8, "z":-32, "owner":null, "contested":true},
		{"id":"south", "x":-8, "z":32}, {"id":"missing"}, {"id":"nan", "x":NAN, "z":0},
		{"id":"infinite", "x":0, "z":INF}, {"id":"string", "x":"1", "z":0}, {"id":"west", "x":2,"z":2}]
	view.set_nodes(public_nodes, "west", "asterion-relay")
	check(view.markers.size() == 4 and view.missing == 4, "missing/nonfinite coordinates excluded; duplicate IDs deterministic")
	check(not view.markers[0].has("secret"), "marker model retains only authorized display fields")
	check(view.owner_symbol(view.markers[0]) == "0" and view.owner_symbol(view.markers[1]) == "1", "team identity is non-color text")
	check(view.owner_symbol({"owner":0.0}) == "0" and view.owner_symbol({"owner":1.0}) == "1", "wire JSON floating-point team IDs preserve owner symbols")
	check(view.owner_symbol({"owner":"0"}) == "?" and view.owner_symbol({"owner":2}) == "?", "malformed/unknown owner is not coerced into a team")
	check(view.owner_symbol(view.markers[2]) == "N" and view.owner_symbol(view.markers[3]) == "?", "neutral and unknown are distinct")
	check(view.markers[2].contested == true and view.markers[0].live == true, "live/contested status retained")
	for i: int in range(4):
		check(view.hit_test(view.marker_position(i)) == view.markers[i].id, "marker center hit resolves public identity %d" % i)
	check(view.hit_test(Vector2.ZERO).is_empty(), "background click has no target")
	check(view.marker_position(0).x < view.marker_position(1).x and view.marker_position(2).y < view.marker_position(3).y, "source X/Z orientation preserved")
	view.set_nodes([{"id":"a","x":0,"z":0},{"id":"b","x":0,"z":0}], "", "")
	var center := view.marker_position(0)
	check(center.is_finite() and center == view.marker_position(1), "coincident and zero-span fit remains finite with true positions")
	check(view.hit_test(center) == "a" and view.hit_test(center, "a") == "b" and view.hit_test(center, "b") == "a", "repeated hit cycles co-located nodes deterministically")
	view.set_nodes([], "", "")
	check(view.markers.is_empty() and view.hit_test(center).is_empty(), "empty projection removes hit targets")
	view.queue_free()
	var board: Control = load("res://lattice/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	check(board.view_choice.selected == 0 and board.nodes.visible and not board.map_view.visible, "default list preserved")
	board.client.revision = 1
	board.client.projection = {"map":"asterion-relay", "nodes":public_nodes.slice(0, 4)}
	board.refresh()
	board.map_view.choose("north")
	check(board.selected == "north" and board.nodes.is_selected(2), "map selection synchronizes list")
	check(board.client.actions.is_empty(), "map selection submits no action")
	board.client.projection.nodes.remove_at(2)
	board.refresh()
	check(board.selected.is_empty() and board.map_view.selected.is_empty() and board.nodes.get_selected_items().is_empty(), "removed selection clears both views")
	board.map_view.choose("west")
	board.client.revision = 2
	board.refresh()
	check(board.selected.is_empty() and board.map_view.selected.is_empty(), "round changes clear selection even if IDs repeat")
	board.map_view.choose("west")
	board.client.projection.map = "monsoon-foundry"
	board.refresh()
	check(board.selected.is_empty(), "map changes clear selection")
	board.map_view.choose("west")
	board.disconnect_session()
	check(board.selected.is_empty() and board.map_view.markers.is_empty() and board.map_view.hit_test(center).is_empty(), "disconnect removes all map targets")
	# Authored link layer: only this recipient's visible markers and authored
	# links are drawn, and only from the team-visible cut list.
	var wire: Array = []
	for seed: Dictionary in [
			{"id":"hq-0", "archetype":"hq", "label":"WEST / FLIGHT CONTROL", "x":-104, "z":0, "owner":0},
			{"id":"hq-1", "archetype":"hq", "label":"EAST / FLIGHT CONTROL", "x":104, "z":0, "owner":1},
			{"id":"front-0", "archetype":"front", "label":"WEST / ARCHIVE GATE", "x":-52, "z":-8, "owner":0},
			{"id":"front-1", "archetype":"front", "label":"EAST / ARCHIVE GATE", "x":52, "z":8},
			{"id":"econ-n", "archetype":"economy", "label":"NORTH / SOLAR EXCHANGE", "x":8, "z":-32},
			{"id":"econ-s", "archetype":"economy", "label":"SOUTH / DEEP ARRAY", "x":-8, "z":32},
			{"id":"relay-0", "archetype":"relay", "label":"ASTERION / OCULUS", "x":0, "z":0, "owner":0}]:
		var node: Dictionary = seed.duplicate()
		node.live = node.archetype != "hq"
		node.contested = false
		node.progress = [0, 0]
		wire.append(node)
	board.client.revision = 3
	board.client.projection = {"map":"asterion-relay", "team":0, "nodes":wire, "cuts":["front-0"]}
	board.refresh()
	check(board.topology.nodes.size() == 7 and board.topology.edges.size() == 10, "board loads the authored topology of its own map")
	check(board.map_view.links.size() == 10, "every authored link between visible markers is drawn")
	check(board.map_view.counts.owned == 3 and board.map_view.counts.linked == 1 and board.map_view.counts.cut == 2, "link summary counts own supply exactly")
	check(link_state(board.map_view, "hq-0", "front-0") == "severed" and link_state(board.map_view, "relay-0", "front-1") == "front", "a team-visible cut severs own links only")
	check(board.selection.text.contains("NEXT") and board.selection.text.contains("EAST / ARCHIVE GATE") and board.selection.text.contains("no linked route home"), "guidance names the next public target and its missing route home under the current cut")
	board.map_view.choose("relay-0")
	check(board.selection.text.contains("HOLD") and board.selection.text.contains("Server decides"), "a cut-off owned selection still reads as a legal HOLD, server final")
	board.client.projection.nodes.remove_at(6)
	board.refresh()
	check(board.map_view.links.size() == 6 and link_state(board.map_view, "relay-0", "front-1").is_empty(), "links through a node the recipient cannot see are never drawn")
	board.client.projection.map = "unknown-map-xyz"
	board.refresh()
	check(board.map_view.links.is_empty() and board.selection.text.contains("Authored links unavailable"), "an unauthored map says so instead of inventing links")
	board.disconnect_session()
	check(board.map_view.links.is_empty() and board.map_view.counts.linked == 0, "disconnect clears the drawn link layer")
	board.queue_free()
	await process_frame
	print("LATTICE_MAP_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
