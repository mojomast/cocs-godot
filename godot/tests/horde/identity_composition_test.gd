extends SceneTree
## Offline identity-composition gate.
##
## Loads the actual identity Horde composition with no authority attached and
## asserts its seams: the reviewed identity loader, the allowlist, the single
## shared sun/environment, the passive Horde strip, the shared combat-focus
## contract, and that the source-map composition still refuses identity maps.
## This is a composition test, not gameplay acceptance.
const Product = preload("res://native_arenas/identity_horde_demo.tscn")
const SourceProduct = preload("res://horde/demo.tscn")
const Controls = preload("res://horde/controls.gd")
const Model = preload("res://horde/model.gd")
var count := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	var product := Product.instantiate()
	root.add_child(product)
	await process_frame
	await process_frame
	check(product.scene_file_path == "res://native_arenas/identity_horde_demo.tscn", "identity scene path")
	check(product.get_script().resource_path == "res://native_arenas/identity_horde_demo.gd", "identity scene script")
	check(product.current_id == "nacre-engine", "identity loader selected Nacre Engine")
	check(product.selected_mode == "horde", "identity composition mode")
	check(product.has_node("GameHUD") and product.has_node("Scoreboard"), "shared HUD/scoreboard composition")
	check(product.has_method("environment_census"), "environment census seam")
	var census: Dictionary = product.environment_census()
	check(census.get("suns", -1) == 1, "exactly one sun for the identity map")
	check(census.get("environments", -1) == 1, "exactly one WorldEnvironment for the identity map")
	check(is_instance_valid(product.world) and product.world.has_node("StaticPickupMarkers"), "hidden pickup marker hook")
	check(product.world.has_node("HordeCacheGuides"), "Nacre Horde wayfinding is built into the real world")
	check(product.cache_signs.size() == 5 and product.world.get_node("HordeCacheGuides").get_child_count() == 5,
		"all five source-recipe weapon caches have a readable world marker")
	check(product.cache_signs[9].text.contains("WAVE 7") and product.cache_signs[11].text.contains("WAVE 9"),
		"heavy weapons advertise their later-wave milestones")
	check(product.horde_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Horde strip is passive")
	check(product.map_supports_horde("nacre-engine"), "Nacre Engine supports Horde")
	check(not product.map_supports_horde("lacuna-court"), "identity Deathmatch map not accepted by Horde")
	check(not product.map_supports_horde("meridian-exchange"), "source map not accepted by the identity loader")
	check(not product.load_selected_map("lacuna-court"), "identity loader refuses a non-allowlisted identity map")
	check(not product.load_selected_map("../../etc/passwd"), "identity loader refuses a path-like id")
	check(product.client.has_method("send_controls"), "identity composition uses the Horde input-epoch client")

	var source_product := SourceProduct.instantiate()
	root.add_child(source_product)
	await process_frame
	await process_frame
	check(not source_product.map_supports_horde("nacre-engine"), "source composition still refuses identity maps")
	check(source_product.map_supports_horde("meridian-exchange"), "source composition keeps its three Horde maps")

	var controls := Controls.new()
	check(controls.focused == true, "shared combat focus contract defaults on")
	controls.focus(false)
	check(controls.focused == false, "focus transition recorded")

	var model := Model.new()
	model.apply({"singleplayer":{"kind":"horde","wave":2,"waveTarget":4,"lives":2,"score":100,
		"enemiesAlive":1,"enemiesTotal":3,"phase":"wave","winner":null}})
	check("WAVE 2 / 4" in model.text and "LIVES 2" in model.text, "Horde projection from snapshot only")
	model.clear()
	check(model.state.is_empty(), "round cleanup")

	for node: Node in [product, source_product]:
		root.remove_child(node)
		node.free()
	print("HORDE_IDENTITY_COMPOSITION checks=", count, " failures=", failures)
	quit(0 if failures == 0 else 1)
