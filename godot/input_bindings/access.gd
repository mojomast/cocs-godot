extends RefCounted
const Model = preload("res://input_bindings/model.gd")

static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("InputBindings") if tree != null and tree.root != null else null

static func values() -> Dictionary:
	var current := service()
	return current.values if current != null else Model.DEFAULTS

static func label(action: String) -> String:
	return Model.label(str(values().get(action, "?")))

static func gameplay_codes() -> Array:
	var result: Array = []
	var bindings := values()
	for action: String in Model.LABELS: result.append(bindings[action])
	return result
