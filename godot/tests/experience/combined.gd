extends SceneTree
## Engine-slot test: source-produced operator fixtures + live signal/lifecycle
## adapter checks + collision-free layout. Not a substitute for connected play.
const Info = preload("res://experience/player_info.gd")
const Status = preload("res://player_gameplay/status.gd")
const Ability = preload("res://experience/ability_text.gd")
const Regions = preload("res://experience/hud_regions.gd")
const CampaignHUD = preload("res://campaign/hud.gd")
const StoryWidgets = preload("res://campaign/story_widgets.gd")
var failures := 0
var checks := 0

class Peer extends Node:
	signal snapshot(frame: Dictionary)
	signal events(items: Array)
	signal started(frame: Dictionary)
	signal results(frame: Dictionary)
	signal connection_error(message: String)
	signal lobby(frame: Dictionary)
	var actor_id := 0
	var spectating := false

class Session extends Node:
	var phase: Variant = 3
	var client := Peer.new()
	var story_widgets: Control
	func _init() -> void: add_child(client)

class Independent extends Node:
	var phase := "active"
	var net := Peer.new()
	var age := 0.0
	func _init() -> void: add_child(net)

class Gameplay extends Node:
	signal status_changed(model: Dictionary)
	var model: Dictionary = {}
	var show_compact_status := true
	var panel := Label.new()
	func _init() -> void: add_child(panel)

class TestInfo extends Info:
	var obstructed := false
	func blocked() -> bool: return obstructed
	func stale() -> bool: return false
	func _process(_delta: float) -> void: pass # Explicitly drive frames in this test.

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("EXPERIENCE_COMBINED_FAIL " + label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for phase: Variant in [0, 1, 2, 4, "connecting", "waiting", "results", "3", null, true]:
		check(not Info.phase_live(phase), "reject non-live phase " + str(phase))
	check(Info.phase_live(3) and Info.phase_live("active"), "both audited live phase families")
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/player_gameplay/fixtures.json"))
	var projector := Status.new()
	var operators := {}
	var info := TestInfo.new()
	root.add_child(info)
	var session := Session.new()
	root.add_child(session)
	info.bind_session(session)
	check(info.gameplay == null, "lazy status owner initially absent")
	var gameplay := Gameplay.new()
	gameplay.name = "PlayerGameplay"
	session.add_child(gameplay)
	for row: Dictionary in fixtures.states:
		operators[row.operator] = true
		var actor: Dictionary = row.state.actors[0]
		session.client.actor_id = int(actor.id)
		session.client.snapshot.emit({"state":row.state})
		var model := projector.project(actor, row.state.config)
		gameplay.model = model
		gameplay.status_changed.emit(model)
		check(info.gameplay == gameplay and not gameplay.show_compact_status and not gameplay.panel.visible, "adopt lazily and suppress fallback")
		check(info.gameplay_model == model, str(row.operator) + " preserves entire source model")
		var text := Ability.text(model)
		for expected: String in [model.power.state, model.mobility.name, model.mobility.input, model.mobility.state, model.passive, model.passive_description, model.grenade]:
			check(text.contains(expected), str(row.operator) + " retains " + expected)
		var original := model.duplicate(true)
		info.layout()
		check(model == original, "layout cannot decrement or mutate authoritative timers")
	check(operators.size() == 9, "all nine source-produced operator fixtures")
	var simultaneous := {"power":{"name":"Power", "state":"ACTIVE 2.0s", "active":2.0, "cooldown":9.0}, "mobility":{}, "statuses":[]}
	check(Ability.text(simultaneous).contains("ACTIVE 2.0s · cooldown 9.0s"), "concurrent active/cooldown remains snapshot-exact")
	info.obstructed = true
	gameplay.status_changed.emit(gameplay.model)
	check(info.gameplay_model.is_empty() and info.ability.text.is_empty(), "modal/focus suppression clears status")
	info.obstructed = false
	session.client.spectating = true
	session.client.lobby.emit({})
	check(info.gameplay_model.is_empty() and not info.ready_for_events, "role change clears before next snapshot")
	session.client.spectating = false
	session.client.snapshot.emit({"state":fixtures.states[0].state})
	gameplay.status_changed.emit(gameplay.model)
	session.client.results.emit({})
	check(info.gameplay_model.is_empty() and info.combat.hits.is_empty(), "results clear status and ledger")
	info.unbind()
	check(gameplay.show_compact_status and not gameplay.status_changed.is_connected(info.on_gameplay_status), "unbind restores owner and disconnects")
	var independent := Independent.new()
	root.add_child(independent)
	info.bind_session(independent)
	independent.net.snapshot.emit({"state":fixtures.states[0].state})
	check(info.client == independent.net and info.ready_for_events, "independent net/active route accepted")
	independent.phase = "results"
	independent.net.snapshot.emit({"state":fixtures.states[0].state})
	check(not info.ready_for_events, "independent results cannot repopulate stale readouts")
	info.unbind()
	for view: Vector2 in [Vector2(1280, 800), Vector2(760, 520), Vector2(760, 520) / 1.5]:
		var obstacles: Array[Rect2] = [Rect2(12,12,view.x-24,60), Rect2(12,view.y-70,view.x-24,58), Rect2(view*0.5-Vector2(28,28),Vector2(56,56))]
		var rect := Regions.choose(view, obstacles, Vector2(300, 120))
		check(rect.has_area() and Rect2(Vector2.ZERO, view).encloses(rect), "responsive logical viewport " + str(view))
		for obstacle: Rect2 in obstacles: check(not rect.intersects(obstacle), "no objective/vitals/aim overlap " + str(view))
	var campaign := CampaignHUD.new()
	root.add_child(campaign)
	session.story_widgets = StoryWidgets.new()
	session.add_child(session.story_widgets)
	campaign.bind_session(session)
	campaign.attach_experience(info.ability, info.caption, false)
	info.campaign_hud = campaign
	check(info.ability.get_parent() == campaign.top and info.caption.get_parent() == campaign.comms_stack, "campaign uses existing bounded scroll areas")
	check(session.story_widgets.comms_docked and session.story_widgets.caption.get_parent() == campaign.comms_stack, "story and captions share transcript rows, not screen positions")
	campaign.attach_experience(info.ability, info.caption, true)
	check(info.caption.get_parent() == campaign.top and campaign.top.get_child(0) == info.caption, "top caption preference docks above objective")
	info._undock_campaign()
	check(info.caption.get_parent() == info and info.ability.get_parent() == info.ability_scroll, "route detach retains persistent labels")
	check(not session.story_widgets.comms_docked and session.story_widgets.caption.get_parent() == session.story_widgets, "story docking relinquishes geometry on detach")
	campaign.free()
	independent.free()
	session.free()
	info.free()
	print("EXPERIENCE_COMBINED ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
