extends SceneTree
## Native Horde upgrade-selection tests: source snapshot projection, local
## intent guards, and the visible/hotkey choice controls. Detached Node
## composition, exactly like tests/horde/test.gd: no window, no transport.
##   godot --headless --path godot --script res://tests/horde/upgrade_selection_test.gd
const Model = preload("res://horde/model.gd")
const Client = preload("res://horde/client.gd")
const Demo = preload("res://horde/demo.gd")
var count := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		push_error(message)
		failures += 1

## Detached components are not owned by the scene until _ready; the test frees
## the composition's whole detached field set explicitly.
func drop_composition(d: Node) -> void:
	for node: Node in [d.camera,d.sun,d.environment,d.label,d.selector,d.combat_label,d.pickups,d.presentation,d.combat,d.client,d.horde_label]: node.free()
	d.free()

func offer_state(ids: Array, wave: int = 3, rows: int = -1) -> Dictionary:
	# Real snapshot shape: singlePlayerSnapshot publishes the pending offer as
	# `upgrades` rows (never as the applied id list) plus upgradeWave/count.
	var upgrades: Array = []
	var catalog := [
		{"id":"haste","name":"Haste","description":"Move and fire faster","color":"#72f1b8","duration":6.0},
		{"id":"overcharge","name":"Overcharge","description":"More damage per shot","color":"#ff8f70","duration":5.0},
		{"id":"overshield","name":"Overshield","description":"A slab of temporary armor","color":"#75baff","duration":8.0},
		{"id":"recon","name":"Recon Pulse","description":"Reveals every enemy on the radar","color":"#7fe7ff","duration":10.0},
		{"id":"cloak","name":"Cloak","description":"Bends light around you","color":"#c8b6ff","duration":7.0},
		{"id":"vitality","name":"Vitality Overcharge","description":"+30% maximum health","color":"#ff7ba8","duration":0.0},
	]
	for id: String in ids:
		for row: Dictionary in catalog:
			if row.id == id: upgrades.append(row.duplicate(true))
	return {"singleplayer":{"kind":"horde","phase":"intermission","wave":wave,"waveTarget":10,"waveTimer":4.5,
		"enemiesAlive":0,"enemiesTotal":6,"lives":2,"score":900,"upgradeWave":wave,
		"upgrades":upgrades,"upgradeSelected":null,"upgradeCount":0},"over":false}

func applied_state(id: String, total: int) -> Dictionary:
	var state := offer_state([])
	state.singleplayer["upgrades"] = []
	state.singleplayer["upgradeSelected"] = id
	state.singleplayer["upgradeCount"] = total
	return state

func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = false
	return event

func _initialize() -> void:
	var m := Model.new()
	# ---------------------------------------------------------------------
	# Source offer projection.
	# ---------------------------------------------------------------------
	m.apply(offer_state(["haste","overcharge","overshield"]))
	check(m.offers.size() == 3, "three source rows projected")
	check(m.offer_pending, "offer pending comes from the snapshot, not local state")
	check(m.offer_wave == 3, "offer wave is the source wave")
	check(m.offer_id(1) == "haste" and m.offer_id(3) == "overshield", "hotkey indices follow source order")
	check(m.offer_id(0) == "" and m.offer_id(4) == "", "out-of-range keys resolve to nothing")
	check(m.offer_index("overcharge") == 2, "id lookup follows source order")
	check("Haste" in m.text and "Overshield" in m.text, "offered names are rendered")
	check("1" in m.text and "UPGRADE" in m.text, "offer is rendered with its hotkeys")
	check("unsupported" not in m.text, "selection is no longer reported as unsupported")
	check(m.applied_count == 0 and m.selected_id == "", "no run upgrade before the authority applies one")
	# Malformed rows are dropped, never fabricated into an offer.
	m.apply({"singleplayer":{"kind":"horde","phase":"wave","wave":3,
		"upgrades":["vitality",42,{"name":"No Id"},{"id":""},{"id":"bad\u0001id"},{"id":"x".repeat(65)},
			{"id":"haste","name":"Haste"},{"id":"haste","name":"Duplicate"}],
		"upgradeWave":"nope","upgradeCount":"1"}})
	check(m.offers.size() == 1 and m.offer_id(1) == "haste", "only well-formed unique rows become offers")
	check(m.offer_wave == 0 and m.applied_count == 0, "malformed wave/count are refused, not coerced")
	# A raw mode-state id list is not an offer.
	m.apply({"singleplayer":{"kind":"horde","phase":"wave","wave":4,"upgrades":["vitality","coolant"]}})
	check(m.offers.is_empty() and not m.offer_pending, "applied-id lists never fabricate an offer")
	# Offer replacement, stale and restart boundaries.
	m.apply(offer_state(["haste","overcharge","overshield"]))
	m.apply(applied_state("haste", 1))
	check(m.offers.is_empty() and not m.offer_pending, "selection clears the offer from the snapshot")
	check(m.selected_id == "haste" and m.applied_count == 1, "authoritative confirmation is projected")
	check("haste".to_upper() in m.text.to_upper(), "confirmed run upgrade is visible")
	m.apply(offer_state(["recon","cloak","vitality"]), true)
	check(m.offers.is_empty() and not m.offer_pending, "stale snapshot drops the offer")
	m.apply(offer_state(["recon","cloak","vitality"]))
	m.apply({"singleplayer":{"kind":"campaign","phase":"wave","upgrades":[{"id":"haste"}]}})
	check(m.offers.is_empty(), "campaign snapshots never offer horde upgrades")
	var source := offer_state(["haste","overcharge","overshield"])
	m.apply(source)
	source.singleplayer.upgrades[0].id = "tampered"
	check(m.offer_id(1) == "haste", "projection copies the snapshot")

	# ---------------------------------------------------------------------
	# Local intent guards (pure decisions, no socket).
	# ---------------------------------------------------------------------
	# The first composition instantiation creates engine-side defaults (cached
	# theme/style objects) that outlive it by design, so the ownership baseline
	# is taken after one full create/free cycle: everything a later cycle
	# allocates must be released again, or the run is a leak even when every
	# check passed.
	var warm := Demo.new()
	drop_composition(warm)
	var baseline := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var c := Client.new()
	var offer := {"pending":true,"wave":3,"ids":["haste","overcharge","overshield"],"count":0,"selected":""}
	c.input_epoch = 4
	c.observe_offer(offer)
	var good := c.upgrade_intent("haste", 3)
	check(good.ok and good.reason == "", "source-current choice is accepted locally")
	check(good.frame.type == "horde-upgrade" and good.frame.inputEpoch == 4, "intent carries the round epoch")
	check(good.frame.choice == "haste" and good.frame.wave == 3 and good.frame.applied == 0, "intent carries the offer identity")
	check(not good.frame.has("x") and not good.frame.has("fire") and not good.frame.has("weapon"), "intent is not an input sample")
	check(c.upgrade_intent("haste", 2).reason == "stale-offer", "wave mismatch refused")
	check(c.upgrade_intent("vitality", 3).reason == "unauthorized-choice", "id outside the offer refused")
	check(c.upgrade_intent("", 3).reason == "malformed-choice", "empty choice refused")
	check(c.upgrade_intent("x".repeat(65), 3).reason == "malformed-choice", "oversize choice refused")
	c.observe_offer({"pending":false,"wave":0,"ids":[],"count":0,"selected":""})
	check(c.upgrade_intent("haste", 3).reason == "no-pending-offer", "no offer refused")
	c.observe_offer(offer)
	c.input_epoch = 0
	check(c.upgrade_intent("haste", 3).reason == "no-round", "intent before a round is refused")
	c.input_epoch = 4
	c.pending_choice = "haste"
	c.pending_wave = 3
	check(c.upgrade_intent("haste", 3).reason == "duplicate-choice", "repeat of the in-flight choice refused")
	check(c.upgrade_intent("overcharge", 3).reason == "selection-pending", "second choice while one is in flight refused")
	# Confirmation comes from the authority, never from the local send.
	c.pending_count = 0
	check(c.confirmed_choice == "", "no local confirmation before the authority answers")
	check(c.decode_text('{"type":"horde-upgrade-applied","inputEpoch":3,"choice":"haste","wave":3,"count":1}'), "stale-epoch answer is tolerated")
	check(c.pending_choice == "haste" and c.confirmed_choice == "", "stale-epoch answer cannot confirm")
	check(c.decode_text('{"type":"horde-upgrade-applied","inputEpoch":4,"choice":"haste","wave":3,"count":1}'), "applied answer accepted")
	check(c.pending_choice == "" and c.confirmed_choice == "haste" and c.confirmed_count == 1, "applied answer confirms once")
	var second := c.upgrade_intent("overcharge", 3)
	check(second.ok, "confirmed selection releases the single-flight guard")
	c.pending_choice = "overcharge"
	c.pending_wave = 3
	c.pending_count = 0
	check(c.decode_text('{"type":"horde-upgrade-rejected","inputEpoch":4,"choice":"overcharge","wave":3,"reason":"stale-offer"}'), "rejection accepted")
	check(c.pending_choice == "" and c.rejected_reason == "stale-offer", "rejection is explicit and clears the guard")
	check(c.upgrade_intent("haste", 3).ok, "a refused choice can be retried after the offer is re-read")
	check(c.decode_text('{"type":"horde-upgrade-rejected","inputEpoch":4,"choice":"overshield","wave":3,"reason":"no-pending-offer"}'), "unrelated rejection tolerated")
	check(c.rejected_reason == "stale-offer" and c.upgrade_intent("haste", 3).ok, "unrelated rejection cannot clear another intent")
	check(not c.decode_text('{"type":"horde-upgrade-applied"}'), "answer without an epoch is refused")
	check(c.confirmed_count == 1, "refused answer cannot confirm")
	c.pending_choice = "haste"
	c.observe_offer({"pending":false,"wave":0,"ids":[],"count":1,"selected":"haste"})
	check(c.pending_choice == "" and c.confirmed_choice == "haste", "snapshot confirmation resolves the intent")
	c.pending_choice = "haste"
	c.pending_wave = 5
	c.pending_count = 1
	c.observe_offer({"pending":false,"wave":0,"ids":[],"count":1,"selected":"haste"})
	check(c.pending_choice == "" and c.rejected_reason == "offer-closed", "an offer closed without the choice is reported")
	c.input_epoch = 4
	c.observe_offer(offer)
	check(c.upgrade_intent("haste", 3).ok and c.upgrade_sent == 0, "intent planning never claims a send")
	c.disconnect_server()
	check(c.pending_choice == "" and not c.offer_pending and c.upgrade_intent("haste", 3).reason == "no-round", "disconnect clears upgrade intent state")

	# ---------------------------------------------------------------------
	# Visible choice controls and hotkeys on the real composition.
	# ---------------------------------------------------------------------
	var d := Demo.new()
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	check(d.choice_buttons.size() == 3, "one visible control per offered choice")
	check(d.choice_panel.visible and d.choice_status.visible, "choice controls shown while an offer is live")
	var labelled := 0
	for index in d.choice_buttons.size():
		var button: Button = d.choice_buttons[index]
		if button.visible: labelled += 1
		check(button.mouse_filter == Control.MOUSE_FILTER_STOP, "click on a choice is consumed before unhandled input")
		check(str(index + 1) in button.text, "button carries its hotkey number")
	check(labelled == 3, "every choice is visible and numbered")
	check("Haste" in d.choice_buttons[0].text, "button names the source row")
	# A snapshot that does not change the offer must not rebuild the controls: a
	# rebuild between pointer down and up swallows the click the operator is
	# already making, and every rebuild drops keyboard focus.
	var held: Button = d.choice_buttons[0]
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	check(d.choice_buttons.size() == 3 and d.choice_buttons[0] == held, "an unchanged offer keeps the same button instance")
	check(is_instance_valid(held) and held.get_parent() == d.choice_panel, "the kept button stays mounted on the live panel")
	var bound: Array = held.pressed.get_connections()
	check(bound.size() == 1 and bound[0].callable.get_bound_arguments() == [1], "the kept button still carries the first offer's hotkey")
	held.pressed.emit()
	check(d.choice_status.text != "" and d.horde.offer_pending and d.horde_client.pending_choice == "", "the kept button still reaches the choice path and leaves the offer intact")
	check(d.intercept_offer_key(KEY_2) == 2, "hotkey 2 targets the second offer")
	check(d.intercept_offer_key(KEY_0) == -1, "unbound hotkey is not intercepted")
	var phases := d.phase
	d._input(key_event(KEY_2))
	check(d.controls.weapon == -1, "choice hotkey never switches weapon")
	check(d.controls.keys.is_empty() and d.controls.pulses.is_empty(), "choice hotkey never leaks into held movement or pulses")
	check(d.phase == phases, "a pending offer does not touch the session phase")
	check(d.horde_client.pending_choice == "" and d.horde.offer_pending, "an unqueueable choice leaves the offer intact")
	check(d.choice_status.text != "", "choice feedback is explicit")
	check("unsupported" not in d.choice_status.text, "feedback never claims the feature is unsupported")
	check(d.intercept_offer_key(KEY_1) == 1, "first hotkey targets the first offer")
	d.controls.focused = false
	d.apply_horde(offer_state(["recon","cloak","vitality"]))
	check(d.choice_buttons.size() == 3 and "Recon Pulse" in d.choice_buttons[0].text, "a replaced offer rebuilds the controls")
	d.controls.focused = true
	# The status label is a child of the panel, so a promoted result has to keep
	# the panel open even though the offer that produced it is gone.
	d.apply_horde(applied_state("recon", 1))
	check(d.choice_buttons.is_empty() and d.choice_panel.visible and d.choice_status.visible, "the applied result stays on screen after the offer closes")
	check("RECON" in d.choice_status.text.to_upper() and "1" in d.choice_status.text, "applied upgrade and count are shown")
	check(d.intercept_offer_key(KEY_1) == -1 and d.controls.weapon == -1, "hotkeys are inert without a live offer")
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	d.on_started({})
	check(d.choice_buttons.is_empty() and not d.choice_panel.visible, "restart clears the choice controls")
	check(d.horde_client.pending_choice == "" and d.choice_status.text == "", "restart clears choice feedback")
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	d.on_error("Horde unavailable: test")
	check(d.choice_buttons.is_empty() and not d.choice_panel.visible, "transport error clears the choice controls")
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	d.apply_horde({}, true)
	check(d.choice_buttons.is_empty() and not d.choice_panel.visible, "stale snapshot hides the choice controls")
	var det_label := d.horde_label.text
	d.apply_horde(applied_state("haste", 2))
	check("UPGRADE" not in det_label.to_upper() or not d.horde.offer_pending, "label follows the authoritative offer only")
	# ---------------------------------------------------------------------
	# Authority answers are visible, not just stored on the client.
	# ---------------------------------------------------------------------
	d.apply_horde(offer_state(["haste","overcharge","overshield"]))
	d.horde_client.input_epoch = 4
	d.horde_client.pending_choice = "haste"
	d.horde_client.pending_wave = 3
	d.horde_client.pending_count = 0
	check(d.horde_client.decode_text('{"type":"horde-upgrade-rejected","inputEpoch":4,"choice":"haste","wave":3,"reason":"stale-offer"}'), "the real client decodes the refusal")
	d.observe_choices()
	check("STALE-OFFER" in d.choice_status.text.to_upper(), "a refusal is shown with its authority reason")
	check(d.choice_panel.visible and d.choice_status.visible, "refusal feedback stays visible while the offer is live")
	check("unsupported" not in d.choice_status.text, "refusal feedback never claims the feature is unsupported")
	d.horde_client.pending_choice = "overcharge"
	d.horde_client.pending_wave = 3
	d.horde_client.pending_count = 0
	check(d.horde_client.decode_text('{"type":"horde-upgrade-applied","inputEpoch":4,"choice":"overcharge","wave":3,"count":1}'), "the real client decodes the applied answer")
	d.observe_choices()
	check("ACCEPTED" in d.choice_status.text.to_upper() and "OVERCHARGE" in d.choice_status.text.to_upper(), "the accepted choice is shown with its id")
	d.apply_horde(applied_state("overcharge", 1))
	check(d.choice_buttons.is_empty() and d.choice_panel.visible and "APPLIED OVERCHARGE" in d.choice_status.text.to_upper(), "the snapshot confirmation is shown after the offer closes")
	# Detached components are not owned by the scene until _ready; free explicitly.
	drop_composition(d)
	c.free()
	check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) == baseline, "the client and the composition release every object they created")
	print("HORDE_UPGRADE_TESTS checks=%d failures=%d" % [count, failures])
	quit(1 if failures > 0 else 0)
