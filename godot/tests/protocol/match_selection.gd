extends SceneTree
const Setup = preload("res://ui/match_setup.gd")
const Catalog = preload("res://world/catalog.gd")
const Session = preload("res://world/session.gd")
const Network = preload("res://net/client.gd")
class Probe extends Network:
	var frames: Array[Dictionary] = []
	func send_frame(frame: Dictionary) -> Error:
		frames.append(frame)
		return OK
var checks := 0
var failures := 0
func check(value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Selection assertion " + str(checks))
func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.open() and catalog.entries.size() == 9)
	var defaults := Setup.parse_args([], catalog.entries)
	check(defaults.map == "meridian-exchange" and defaults.mode == "deathmatch" and not defaults.setup and defaults.error.is_empty())
	for map_id: String in Setup.MAPS:
		for mode: String in Setup.MODES:
			check(Setup.validate(catalog.entries, map_id, mode).is_empty())
	var options := Setup.parse_args(["--map", "ember-crucible", "--mode=instagib", "--setup"], catalog.entries)
	check(options.error.is_empty() and options.map == "ember-crucible" and options.mode == "instagib" and options.setup)
	for args: PackedStringArray in [["--map=unknown"], ["--map="], ["--map"], ["--map", "--setup"], ["--mode"], ["--mode="], ["--mode=bogus"], ["--map=ion-speedway", "--mode=puma-race"], ["--map=aurora-stadium", "--mode=puma-soccer"], ["--map=asterion-relay", "--mode=cocs"], ["--mode=teamdeathmatch"], ["--mode=campaign"], ["--setup", "--session-smoke"], ["--setup", "--join-room=test"], ["--mode=instagib", "--join-room=test"]]:
		check(not Setup.parse_args(args, catalog.entries).error.is_empty())
	check(Setup.parse_args(["--join-room=test"], catalog.entries).error.is_empty())
	check(Setup.parse_args(["--join-room=test", "--map=verdant-reliquary"], catalog.entries).error.is_empty())
	var narrower := catalog.entries.duplicate(true)
	narrower["ember-crucible"].modes = ["deathmatch"]
	check(not Setup.validate(narrower, "ember-crucible", "instagib").is_empty())
	var menu := Setup.new()
	menu.configure(catalog.entries, "verdant-reliquary", "instagib")
	check(menu.map_choice.item_count == 9 and menu.selected_map() == "verdant-reliquary" and menu.selected_mode() == "instagib" and not menu.start.disabled)
	menu.map_choice.select(7) # Ion Speedway retains its actual race identity.
	menu.map_choice.item_selected.emit(7)
	check(menu.selected_map() == "ion-speedway" and menu.selected_mode() == "puma-race" and menu.start.disabled and "pending" in menu.status.text)
	menu.free()
	var session := Session.new()
	session.client.free()
	var probe := Probe.new()
	session.client = probe
	for node: Node in [session.camera,session.label,session.selector,session.client,session.presentation,session.pickups,session.combat,session.combat_label]: session.add_child(node)
	session.phase = -2
	check(session.advance_handshake(200.0) and probe.frames.is_empty())
	session.current_id = "ember-crucible"
	session.selected_mode = "instagib"
	probe.allowlist = catalog.entries
	probe.requested_map = session.current_id
	session.phase = 1
	session.on_lobby({})
	check(session.phase == 2 and probe.frames[-1].mapId == "ember-crucible" and probe.frames[-1].config.mode == "instagib")
	session.on_lobby({"config":{"mode":"instagib"}})
	check(session.phase == 20 and probe.frames[-1].type == "start")
	var count := probe.frames.size()
	session.phase = 2
	session.on_lobby({"config":{"mode":"deathmatch"}})
	check(session.phase == -1 and probe.frames.size() == count)
	session.free()
	print("PORT_MATCH_SELECTION checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
