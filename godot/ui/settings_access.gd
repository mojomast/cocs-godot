extends RefCounted
## SceneTree scripts can preload route modules without an autoload name binding.
## Normal application launches have the real singleton; detached tests retain
## deterministic defaults without constructing or reading a local settings store.
static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return null
	return tree.root.get_node_or_null("LocalSettings")

static func overlay_open() -> bool:
	var settings := service()
	var tree := Engine.get_main_loop() as SceneTree
	var career := tree.root.get_node_or_null("Career") if tree != null and tree.root != null else null
	return (settings != null and settings.overlay_open()) or (career != null and career.active())

static func sensitivity() -> float:
	var settings := service()
	return settings.sensitivity() if settings != null else 1.0

static func open_panel(from_menu: bool = false, previous_focus: Control = null) -> void:
	var settings := service()
	if settings != null and not overlay_open(): settings.open_panel(from_menu, previous_focus)
