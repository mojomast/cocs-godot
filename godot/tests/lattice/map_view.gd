extends SceneTree
const View = preload("res://lattice/map_view.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
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
	board.queue_free()
	await process_frame
	print("LATTICE_MAP_SYNTHETIC %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
