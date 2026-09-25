extends SceneTree
const Layer = preload("res://lattice_assets/world_layer.gd")
const Instrument = preload("res://lattice_assets/instrument.gd")
const Recipes = preload("res://lattice_assets/recipes.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func mesh_count(node: Node) -> int:
	check(not node is CollisionObject3D and not node is CollisionShape3D and not node is NavigationRegion3D and not node is Light3D,"decorative subtree has physics/nav/light")
	var count := 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children(): count += mesh_count(child)
	return count

func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lattice/fixtures/flagship_assets.json"))
	check(Instrument.recipient_state({}) == "unknown","missing owner must remain unknown")
	check(Instrument.recipient_state({"owner":null}) == "neutral","explicit null means neutral")
	for invalid: Variant in [true,false,"0",2,-1]:
		check(Instrument.recipient_state({"owner":invalid}) == "unknown","invalid owner")
	for kind: String in Recipes.KINDS:
		var names := {}
		var specs := Recipes.parts(kind)
		check(specs.size() <= 24,"bounded mesh instances per recipe")
		for spec: Dictionary in specs:
			check(not names.has(spec.name),"unique recipe names")
			names[spec.name] = true
			for dimension: float in spec.size: check(dimension > 0 and dimension <= 6,"finite dimensions")
	for source: Dictionary in fixture.maps:
		var layer := Layer.new()
		layer.bind_map(source.id,"cocs",source)
		check(layer.objectives.size() == 7 and layer.static_props.size() == 4,"authored sockets only")
		check(mesh_count(layer) == 194,"PvP instance budget")
		for prop: Node3D in layer.objectives.values(): check(not prop.visible,"unreceived node hidden")
		var received: Dictionary = source.nodes[0].duplicate(true)
		received.owner = 0
		received.contested = true
		var projection := {"map":source.id,"mode":"cocs","nodes":[received]}
		layer.apply_projection(projection)
		var hq: Node3D = layer.objectives[received.id]
		check(hq.visible and hq.get_meta("recipient_owner") == "red" and hq.get_meta("recipient_contested"),"received red/contest")
		check(hq.position == Vector3(-104,0,0),"catalog position retained")
		check(hq.owner_marks[0].visible and not hq.owner_marks[1].visible,"red one-bar encoding")
		received.owner = 1
		received.erase("contested")
		layer.apply_projection(projection)
		check(hq.owner_marks[1].visible and not hq.get_meta("recipient_contested"),"blue two bars; absent contest cleared")
		received.owner = null
		layer.apply_projection(projection)
		check(hq.neutral_mark.visible and not hq.owner_marks[0].visible,"neutral glyph")
		received.erase("owner")
		layer.apply_projection(projection)
		check(not hq.neutral_mark.visible and hq.get_meta("recipient_owner") == "unknown","missing owner is not neutral")
		received.x += 1
		layer.apply_projection(projection)
		check(not hq.visible,"mismatched received coordinates refused")
		layer.apply_projection({"map":"wrong","mode":"cocs","nodes":source.nodes})
		check(not hq.visible,"cross-map projection refused")
		layer.bind_map(source.id,"cocs-coop",source)
		check(mesh_count(layer) == 212,"Operations cartridge budget")
		layer.clear_recipient()
		for prop: Node3D in layer.objectives.values(): check(not prop.visible,"clear removes stale indicators")
		layer.free()
	if failures.is_empty(): print("FLAGSHIP_ASSET_CONTRACT: PASS")
	else:
		for message: String in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
