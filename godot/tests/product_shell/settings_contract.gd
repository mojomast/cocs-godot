extends SceneTree
## Run with: Godot --headless --path godot --script res://tests/product_shell/settings_contract.gd
## Every disk operation uses an injected fixture path, never the real user store.
const Store = preload("res://ui/local_settings.gd")
const SportsControls = preload("res://sports/controls.gd")
const CombinedControls = preload("res://combined_arms/controls.gd")
const MouseMotion = preload("res://ui/mouse_motion.gd")
const Session = preload("res://world/session.gd")
const Lattice = preload("res://lattice/world_demo.gd")
const ArmsRace = preload("res://arms_race/demo.gd")
var failed := 0
var checks := 0

class FixtureScene extends Node:
	var controls: RefCounted
	func _init(instance: RefCounted) -> void:
		controls = instance

class AdapterScene extends Node:
	var adapter: Node
	func _init(instance: Node) -> void:
		adapter = instance
	func release_pointer() -> void:
		adapter.call("release_pointer")

func key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func button(code: int, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	return event

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "fixture can be written")
		return
	file.store_string(text)
	file.close()

func free_detached_adapter(adapter: Node) -> void:
	# These fixtures deliberately never enter the tree: _ready normally adopts
	# constructor-created cameras, UI and transport nodes. Adopt their nested
	# detached Node fields before free(), so their RIDs have a real owner here.
	adopt_detached_nodes(adapter)
	adapter.free()

func adopt_detached_nodes(owner: Node) -> void:
	for property: Dictionary in owner.get_property_list():
		if property.type != TYPE_OBJECT: continue
		var child: Variant = owner.get(property.name)
		if child is Node and child != owner and child.get_parent() == null:
			adopt_detached_nodes(child)
			owner.add_child(child)

func run() -> void:
	var path := "user://settings_contract_%d/nested/local.json" % OS.get_process_id()
	var clean: Dictionary = Store.normalize({"master_volume": 8, "mute": true,
		"window_mode": "fullscreen", "mouse_sensitivity": 175, "ui_scale": 125, "wallet": 1000})
	check(clean.size() == Store.DEFAULTS.size() and not clean.has("wallet")
		and clean.master_volume == 8 and clean.mute and clean.ui_scale == 125
		and clean.music_enabled and not clean.announcer_enabled,
		"only device settings survive normalization, including new opt-in audio preferences")
	clean = Store.normalize({"master_volume": -300, "mouse_sensitivity": 9999,
		"ui_scale": NAN, "mute": "true", "window_mode": "malicious"})
	check(clean.master_volume == 0 and clean.mouse_sensitivity == 250 and clean.ui_scale == 100
		and not clean.mute and clean.window_mode == "windowed", "invalid and out-of-range fields recover independently")
	check(Store.explicit_display_flag(PackedStringArray(["--fullscreen"]))
		and Store.explicit_display_flag(PackedStringArray(["-f"]))
		and Store.explicit_display_flag(PackedStringArray(["-w"]))
		and Store.explicit_display_flag(PackedStringArray(["--windowed"]))
		and not Store.explicit_display_flag(PackedStringArray(["--smoke"]))
		and not Store.explicit_display_flag(PackedStringArray(["--fullscreen"]), PackedStringArray(["--fullscreen"]))
		and Store.explicit_display_flag(PackedStringArray(["-w", "--fullscreen"]), PackedStringArray(["--fullscreen"])),
		"explicit engine display switches are recognized without treating user args as display flags")
	var previous_scale := root.content_scale_factor
	var previous_stretch := root.content_scale_mode
	var previous_base := root.content_scale_size
	var first := Store.new()
	root.add_child(first)
	first.load_at(path)
	check(first.values == Store.DEFAULTS, "absent file uses defaults")
	check(not first.set_value("wallet", 3, false) and not first.set_value("mute", "yes", false),
		"invalid mutation cannot enter the store")
	check(first.set_value("master_volume", 35) and first.set_value("mute", true)
		and first.set_value("mouse_sensitivity", 150) and first.set_value("ui_scale", 125),
		"settings save atomically into a nested injected directory")
	check(absf(first.sensitivity() - 1.5) < 0.001, "control gain reads current settings")
	var hardware := InputEventMouseMotion.new()
	hardware.relative = Vector2(24, -12)
	hardware.screen_relative = Vector2(24, -12)
	var baseline_yaw := -MouseMotion.raw_delta(hardware).x * 0.003
	for percent in [75, 100, 150]:
		var scale := float(percent) / 100.0
		var transform := Transform2D(Vector2(scale, 0), Vector2(0, scale), Vector2.ZERO)
		var scaled := hardware.xformed_by(transform) as InputEventMouseMotion
		check(scaled != null and scaled.relative.is_equal_approx(hardware.relative * scale)
			and scaled.screen_relative == hardware.screen_relative,
			"content transform scales relative but preserves hardware motion at UI scale %d" % percent)
		if scaled != null:
			check(absf(-MouseMotion.raw_delta(scaled).x * 0.003 - baseline_yaw) < 0.000001,
				"UI scale %d preserves yaw at fixed sensitivity" % percent)
	var synthetic := InputEventMouseMotion.new()
	synthetic.relative = Vector2(-20, 8)
	check(MouseMotion.raw_delta(synthetic) == synthetic.relative,
		"relative-only synthetic aiming events retain their delta")
	for sensitivity in [75, 150]:
		first.set_value("mouse_sensitivity", sensitivity, false)
		check(absf(-MouseMotion.raw_delta(hardware).x * 0.003 * first.sensitivity()
			- baseline_yaw * float(sensitivity) / 100.0) < 0.000001,
			"sensitivity %d changes the existing session look gain" % sensitivity)
	check(absf(root.content_scale_factor - 1.25) < 0.001
		and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_size == Vector2i.ZERO,
		"UI scale changes the actual root canvas stretch live, including explicit HUD font overrides")
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		check(AudioServer.is_bus_mute(master) and absf(AudioServer.get_bus_volume_linear(master) - 0.35) < 0.001,
			"audio settings reach the Master bus")
	first.open_panel(true)
	check(first.overlay_open() and not first.rows.leave.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
		"Home settings opens without a Leave Match action")
	first.close_panel()
	check(not first.overlay_open(), "Back closes settings without recapture")
	first.open_panel()
	check(first.rows.leave.visible, "route settings offers explicit process leave")
	first.close_panel()
	var sports := SportsControls.new()
	sports.accept(key(KEY_ENTER, true), true)
	sports.accept(key(KEY_W, true), true)
	var fixture := FixtureScene.new(sports)
	root.add_child(fixture)
	current_scene = fixture
	first.open_panel()
	check(not sports.engaged and sports.packet(0.0, true).x == 0.0
		and sports.packet(0.0, true).z == 0.0, "opening overlay drains held sports movement")
	first.close_panel()
	check(not sports.engaged and sports.packet(0.0, true).z == 0.0,
		"closing overlay cannot auto-resume held sports W")
	current_scene = null
	root.remove_child(fixture)
	fixture.free()
	var combined := CombinedControls.new()
	combined.accept(key(KEY_ENTER, true), true)
	combined.accept(key(KEY_W, true), true)
	combined.accept(button(MOUSE_BUTTON_RIGHT, true), true)
	check(combined.engaged and combined.ads, "fixture starts with active combined-vehicle controls")
	fixture = FixtureScene.new(combined)
	root.add_child(fixture)
	current_scene = fixture
	first.open_panel()
	first.close_panel()
	combined.accept(key(KEY_W, true), true)
	combined.accept(button(MOUSE_BUTTON_RIGHT, true), true)
	var neutral: Dictionary = combined.command(0.0, 0.0, true, false)
	check(not combined.engaged and neutral.x == 0.0 and neutral.z == 0.0 and not neutral.ads,
		"combined controls block held W/ADS until fresh release and explicit engagement")
	combined.accept(key(KEY_W, false), false)
	combined.accept(button(MOUSE_BUTTON_RIGHT, false), false)
	combined.accept(key(KEY_ENTER, false), false)
	combined.accept(key(KEY_ENTER, true), true)
	check(combined.engaged and not combined.ads, "fresh Enter re-engages without inheriting ADS")
	combined.accept(key(KEY_W, true), true)
	check(combined.command(0.0, 0.0, true, false).z < -0.5,
		"movement only resumes after fresh key press following explicit engagement")
	current_scene = null
	root.remove_child(fixture)
	fixture.free()
	check_overlay_release_paths(root.get_node("LocalSettings"))
	root.remove_child(first)
	first.free()
	for i in 3:
		var again := Store.new()
		root.add_child(again)
		again.load_at(path)
		check(again.values.master_volume == 35 and again.values.mute and again.values.mouse_sensitivity == 150,
			"stored values survive lifetime %d" % i)
		root.remove_child(again)
		again.free()
	for bad: String in ["{broken", " ".repeat(Store.MAX_BYTES + 1),
		JSON.stringify({"version": 2, "settings": {"mute": true}}),
		JSON.stringify({"version": 1, "settings": []})]:
		write(path, bad)
		var recovered := Store.new()
		root.add_child(recovered)
		recovered.load_at(path)
		check(recovered.values == Store.DEFAULTS, "corrupt/oversized/version/shape recovers")
		root.remove_child(recovered)
		recovered.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir().get_base_dir()))
	# Restore process-global audio and defaults for any subsequent test in this process.
	var reset := Store.new()
	root.add_child(reset)
	reset.apply()
	root.remove_child(reset)
	reset.free()
	root.content_scale_factor = previous_scale
	root.content_scale_mode = previous_stretch
	root.content_scale_size = previous_base
	print("SETTINGS_CONTRACT checks=", checks, " failures=", failed)
	quit(1 if failed else 0)

func check_overlay_release_paths(settings: Variant) -> void:
	var ammo := [20, 20, 20, 20, 20, 20, 20, 20, 20, 20]
	for adapter: Variant in [Session.new(), Lattice.new()]:
		var scene := AdapterScene.new(adapter)
		root.add_child(scene)
		current_scene = scene
		adapter.combat_actions.record(key(KEY_W, true), true)
		adapter.combat_actions.record(button(MOUSE_BUTTON_LEFT, true), true)
		adapter.weapon_selection.handle_event(key(KEY_1, true), true, {"ammo":ammo, "weapon":1})
		settings.open_panel()
		check(adapter.combat_actions.down.has("k%d" % KEY_W) and adapter.weapon_selection.held.has(KEY_1),
			"%s retains physical downs at the settings boundary" % adapter.get_script().resource_path)
		adapter._input(key(KEY_W, true))
		adapter._input(button(MOUSE_BUTTON_LEFT, true))
		adapter._input(key(KEY_1, true))
		check(adapter.combat_actions.held.is_empty() and adapter.weapon_selection.pending == -1,
			"settings blocks new presses and queued actions")
		for released: InputEvent in [key(KEY_W, false), button(MOUSE_BUTTON_LEFT, false), key(KEY_1, false)]:
			adapter._input(released)
		check(not adapter.combat_actions.down.has("k%d" % KEY_W)
			and not adapter.combat_actions.down.has("m1") and not adapter.weapon_selection.held.has(KEY_1),
			"%s observes W/fire/number releases through its overlay input" % adapter.get_script().resource_path)
		settings.close_panel()
		adapter.combat_actions.record(key(KEY_W, true), true)
		adapter.combat_actions.record(button(MOUSE_BUTTON_LEFT, true), true)
		adapter.weapon_selection.handle_event(key(KEY_1, true), true, {"ammo":ammo, "weapon":2})
		check(adapter.combat_actions.key(KEY_W) and adapter.combat_actions.sample(0, 0, true).fire
			and adapter.weapon_selection.pending == 0,
			"released controls can act on a fresh press after Back")
		adapter.release_pointer()
		settings.open_panel()
		settings.close_panel()
		adapter.combat_actions.record(key(KEY_W, true), true)
		adapter.weapon_selection.handle_event(key(KEY_1, true), true, {"ammo":ammo, "weapon":2})
		check(not adapter.combat_actions.key(KEY_W) and adapter.weapon_selection.pending == -1,
			"held controls without an observed release stay blocked")
		current_scene = null
		root.remove_child(scene)
		scene.free()
		free_detached_adapter(adapter)
	var arms := ArmsRace.new()
	var scene := AdapterScene.new(arms)
	root.add_child(scene)
	current_scene = scene
	arms.fresh.observe(key(KEY_W, true))
	arms.fresh.observe(button(MOUSE_BUTTON_LEFT, true))
	arms.combat_actions.record(button(MOUSE_BUTTON_LEFT, true), true)
	settings.open_panel()
	check(not arms.fresh.capture_allowed(), "Arms Race blocks capture while pre-overlay controls remain held")
	arms._input(key(KEY_W, true))
	arms._input(key(KEY_W, false))
	arms._input(button(MOUSE_BUTTON_LEFT, false))
	check(arms.fresh.capture_allowed() and not arms.combat_actions.down.has("m1"),
		"Arms Race observes releases while Settings is open")
	settings.close_panel()
	arms._input(button(MOUSE_BUTTON_LEFT, true))
	check(arms.fresh.capture_allowed(), "Arms Race permits a fresh capture press after Back")
	arms.release_pointer()
	check(not arms.fresh.capture_allowed(), "Arms Race still blocks a held click across a boundary")
	current_scene = null
	root.remove_child(scene)
	scene.free()
	free_detached_adapter(arms)
