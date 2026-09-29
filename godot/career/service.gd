extends CanvasLayer
## Runtime-only view of the active source connection. No profile or credential
## enters local settings, menu preferences, command line or diagnostic output.
##
## RESULTS/HISTORY lane: the reader shows the latest accepted source `results`
## state and the server's recent-match `history` reply. It never computes a
## win/loss, never claims a personal timeline and never persists a snapshot. The
## source remains the only authority; this panel can only display what the
## seated connection was actually sent.
const CareerProfile = preload("res://career/profile.gd")
const Actions = preload("res://career/actions_model.gd")
const ResultsModel = preload("res://career/results_model.gd")
const HistoryModel = preload("res://career/history_model.gd")
const HISTORY_TIMEOUT_MS := 8000
const MAX_SEEN_ROUNDS := 8
var catalog: Dictionary = {}
var connection_owner: WeakRef
var profile: Dictionary = {}
var panel: Control
var details: VBoxContainer
var state_label: Label
var heading: Label
var return_focus: Control
var return_settings := false
var return_settings_menu := false
var category := "gear"
var pending: Dictionary = {}
var action_status := ""
var last_send_ms := -1000
var cooldown_refresh := false
# Results/award tracking. The source carries `roundRevision` on `start`/`lobby`
# but not on `results`, so the service pairs an award with the active round key
# (endpoint:room:revision) and consumes it when the matching accepted result
# arrives. A welcome opens a new connection epoch and clears every per-round
# witness, so a replayed result after reconnect can never reuse an old award.
var round_key := ""
var round_known := false
var connection_epoch := 0
var result: Dictionary = {}
var result_seen: Dictionary = {}
var result_order: Array = []
var round_award: Dictionary = {}
var round_award_key := ""
var latest_award: Dictionary = {}
var latest_award_identity := ""
var results_status := "none" # none | live | complete
# History is a read-only request/response surface. "offline" also covers Home
# (no seated authority). Unknown is never rendered as an empty match list. The
# source has no request id, so only one request may be outstanding; a reply that
# arrives without a pending request is a delayed observation, not fresh data.
var history_status := "offline" # offline | loading | ready | empty | error | timeout
var history_pending := false
var history_records: Array = []
var history_invalid := 0
var history_notice := ""
var history_requested_at := -1

func _ready() -> void:
	layer = 99
	var file := FileAccess.open("res://career/catalog.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if valid_catalog(parsed): catalog = parsed
	build_panel()
	call_deferred("bind_identity_status")

func bind_identity_status() -> void:
	var identity := get_tree().root.get_node_or_null("Identity")
	if identity != null: identity.storage_error.connect(func(_message: String) -> void: refresh())
	refresh()

static func valid_catalog(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("schema") != 1 or not raw.get("items") is Array: return false
	if raw.items.size() < 1 or raw.items.size() > 128: return false
	var ids := {}
	for entry: Variant in raw.items:
		if not entry is Dictionary: return false
		if entry.get("kind") not in ["gear", "attachment", "finish", "crosshair"]: return false
		for field: String in ["id", "unlockId", "name", "description", "slot"]:
			if not entry.get(field) is String or entry[field].length() > (600 if field == "description" else 128): return false
		if entry.id.is_empty() or entry.name.is_empty() or entry.description.is_empty(): return false
		if not entry.get("level") is int and not entry.get("level") is float: return false
		if not is_finite(float(entry.level)) or float(entry.level) != floorf(float(entry.level)) or entry.level < 1 or entry.level > 60: return false
		if not entry.get("modifiers") is Dictionary or not entry.get("spec") is Array or not entry.get("weapons") is Array: return false
		if not entry.get("weaponNames") is Array or entry.weaponNames.size() > 16 or entry.spec.size() > 16 or entry.modifiers.size() > 16: return false
		for value: Variant in entry.spec:
			if not value is String or value.length() > 80: return false
		for value: Variant in entry.weaponNames:
			if not value is String or value.length() > 80: return false
		for value: Variant in entry.modifiers.values():
			if not (value is float or value is int) or not is_finite(float(value)): return false
		var key: String = str(entry.kind) + ":" + str(entry.id)
		if ids.has(key): return false
		ids[key] = true
	return true

func active() -> bool:
	return panel != null and panel.visible

func clear_connection(client: Node) -> void:
	if connection_owner != null and connection_owner.get_ref() == client:
		connection_owner = null
		profile.clear()
		pending.clear()
		last_send_ms = -1000
		cooldown_refresh = false
		action_status = "Disconnected · pending selection unconfirmed."
		reset_result_tracking()
		reset_history()
		refresh()

## A source frame is only ever admitted from the connection that welcome bound.
func owned(client: Node) -> bool:
	return connection_owner != null and connection_owner.get_ref() == client

func receive(client: Node, frame: Dictionary) -> void:
	if not is_instance_valid(client): return
	# A queued reply from a closed room cannot resurrect a disconnected career.
	if not ("room_id" in client) or str(client.room_id).is_empty() or not client.career_seated or not client.career_wire_open(): return
	match str(frame.get("type", "")):
		"welcome": receive_welcome(client, frame)
		"start":
			if owned(client): receive_start(client, frame)
		"results":
			if owned(client): receive_results(client, frame)
		"history":
			if owned(client): receive_history(frame)
		"history-error":
			if owned(client): receive_history_error(frame)
		"progression":
			if owned(client): receive_progression(client, frame)
		_: return
	refresh()

func receive_welcome(client: Node, frame: Dictionary) -> void:
	# Only the seated connection's source welcome owns an identity.
	pending.clear()
	last_send_ms = -1000
	cooldown_refresh = false
	action_status = ""
	connection_owner = weakref(client)
	connection_epoch += 1
	profile = CareerProfile.project(frame.get("profile"))
	reset_result_tracking()
	reset_history()

func receive_start(_client: Node, frame: Dictionary) -> void:
	# The accepted result has no revision of its own. Pair it with the started
	# round only when the source supplied a valid revision: a missing/ malformed
	# revision must never be stringified into a fake key that could later match.
	var revision: Variant = ResultsModel.safe_int(frame.get("roundRevision"))
	round_known = revision != null and int(revision) >= 0
	round_key = (round_source_key() + ":" + str(int(revision))) if round_known else ""
	round_award = {}
	round_award_key = ""
	results_status = "live"

func receive_results(client: Node, frame: Dictionary) -> void:
	var state: Variant = frame.get("state")
	if not state is Dictionary: return
	var reconnect := not round_known
	var key := round_key if round_known else round_source_key() + ":reconnect"
	var replayed := result_seen.has(key)
	if not replayed:
		result_seen[key] = true
		result_order.append(key)
		while result_order.size() > MAX_SEEN_ROUNDS: result_seen.erase(result_order.pop_front())
	var projected: Dictionary = ResultsModel.project(state, current_actor_id(client), key, replayed)
	if projected.is_empty(): return
	if reconnect: projected.reconnect = true
	result = projected
	results_status = "complete"

func receive_progression(client: Node, frame: Dictionary) -> void:
	# Equipment replies and award replies share the `progression` type but have
	# disjoint top-level shapes. Settle a pending write only from equipment and
	# record a reward only from a real award; never confuse the two.
	if not profile.is_empty():
		var next: Dictionary = CareerProfile.project(frame.get("profile"))
		if next.get("id") != profile.get("id"): next = {}
		if not next.is_empty():
			if ResultsModel.is_equipment(frame) and not pending.is_empty():
				var outcome: String = Actions.outcome(pending, frame, next)
				if outcome != "pending":
					action_status = "Source confirmed selection · saved for next match." if outcome == "applied" else "Source adjusted/refused selection · see confirmed equipment below."
					pending.clear()
			profile = next
	if ResultsModel.is_award(frame):
		receive_award(frame, current_actor_id(client))

func receive_award(frame: Dictionary, actor_id: int) -> void:
	var award: Dictionary = ResultsModel.project_award(frame)
	if award.is_empty(): return
	var identity := ""
	var raw_profile: Variant = frame.get("profile")
	if raw_profile is Dictionary: identity = str(raw_profile.get("id", ""))
	var ours := str(profile.get("id", "")) if not profile.is_empty() else ""
	# A foreign identity is never ours. Without a matching known identity we can
	# only show a generic "latest source award": we never pair it with a result.
	if not ours.is_empty() and identity != ours: return
	latest_award = award
	latest_award_identity = identity
	# Pair a reward with the accepted result only for a *known* started revision
	# and the same known source actor. Missing/uncorrelated context stays generic.
	if not round_known or round_key.is_empty(): return
	if ours.is_empty() or identity != ours: return
	var award_actor: Variant = null
	if frame.get("actor") is Dictionary: award_actor = ResultsModel.safe_int(frame.actor.get("id"))
	if actor_id < 0 or award_actor == null or int(award_actor) != actor_id: return
	round_award = award
	round_award_key = round_key

func receive_history(frame: Dictionary) -> void:
	var pending := history_pending
	var projected: Dictionary = HistoryModel.project(frame.get("matches"))
	if projected.is_empty():
		# Malformed envelope: keep every known fact and report the error.
		if pending: history_pending = false
		history_status = "error"
		history_notice = "Malformed source history reply · showing last known."
		return
	var records: Array = projected.records
	var invalid := int(projected.invalid)
	if records.is_empty() and invalid > 0:
		# Every record was malformed: never claim "no history"; keep the last
		# known list and report the error.
		if pending: history_pending = false
		history_status = "error"
		history_notice = "All %d source history records malformed · showing last known." % invalid
		return
	if not pending:
		# The source has no request id: a reply with nothing outstanding is a
		# delayed observation. Update the snapshot but claim no fresh readiness.
		if not records.is_empty():
			history_records = records
			history_invalid = invalid
		history_notice = "Delayed source history received · request outcome unknown."
		return
	history_pending = false
	history_records = records
	history_invalid = invalid
	history_status = "empty" if records.is_empty() else "ready"
	history_notice = "" if invalid <= 0 else "%d malformed record(s) ignored" % invalid

func receive_history_error(frame: Dictionary) -> void:
	if history_pending: history_pending = false
	history_status = "error"
	var message := ResultsModel.text(frame.get("message"), 120)
	history_notice = message if not message.is_empty() else "Source history unavailable."

## A bounded, opaque correlation key. The raw endpoint is never placed in the
## public projection: only its SHA-256 (plus the room) is used internally and
## exposed as the round key, so a long URL can never be clipped into a mismatch.
func round_source_key() -> String:
	var client: Node = connection_owner.get_ref() if connection_owner != null else null
	if not is_instance_valid(client): return "source".sha256_text()
	var endpoint := str(client.get("connection_endpoint")) if "connection_endpoint" in client else ""
	if endpoint.is_empty(): endpoint = "source"
	return (endpoint + "\n" + str(client.get("room_id"))).sha256_text()

func current_actor_id(client: Node) -> int:
	if not is_instance_valid(client) or not ("actor_id" in client): return -1
	var value: Variant = ResultsModel.safe_int(client.get("actor_id"))
	return int(value) if value != null and int(value) >= 0 else -1

func reset_result_tracking() -> void:
	round_key = ""
	round_known = false
	result = {}
	result_seen.clear()
	result_order.clear()
	round_award = {}
	round_award_key = ""
	latest_award = {}
	latest_award_identity = ""
	results_status = "none"

func reset_history() -> void:
	history_status = "offline"
	history_pending = false
	history_records = []
	history_invalid = 0
	history_notice = ""
	history_requested_at = -1

## Attributed award = a confirmed same-round award consumed by the accepted
## result. Missing correlation stays generic, never a false attribution.
func attributed_award() -> Dictionary:
	if result.is_empty() or round_award.is_empty() or round_award_key.is_empty(): return {}
	return round_award if str(result.get("round_key", "")) == round_award_key else {}

func history_connected() -> bool:
	if connection_owner == null: return false
	var client: Node = connection_owner.get_ref()
	return is_instance_valid(client) and client.career_seated and client.career_wire_open() and not str(client.room_id).is_empty()

## Ask the seated source for its recent-match list. Read-only: the request is
## the existing `history` verb and no local store is created. Allowed for a
## spectator seat too (the source reply is server-wide, not personal data).
## The wire has no request id, so only one request may be outstanding: `force`
## cannot bypass a pending request without risking mismatched replies.
func request_history(force: bool = false) -> void:
	if not history_connected():
		history_status = "offline"
		history_pending = false
		refresh()
		return
	if history_pending: return
	if history_status == "loading" and not force: return
	var client: Node = connection_owner.get_ref()
	history_pending = true
	history_status = "loading"
	history_notice = ""
	history_requested_at = Time.get_ticks_msec()
	if client.send_frame({"type":"history"}) != OK:
		history_pending = false
		history_status = "error"
		history_notice = "History request could not be sent."
	refresh()

func open_panel(focus: Control = null, from_settings: bool = false, settings_menu: bool = false) -> void:
	var settings := get_tree().root.get_node_or_null("LocalSettings")
	if active() or (settings != null and settings.overlay_open() and not from_settings): return
	return_focus = focus
	return_settings = from_settings
	return_settings_menu = settings_menu
	if settings != null: settings.release_controls()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.show()
	refresh()
	var back := panel.find_child("CareerBack", true, false) as Button
	back.grab_focus()

func close_panel() -> void:
	if not active(): return
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if return_settings:
		var settings := get_tree().root.get_node_or_null("LocalSettings")
		if settings != null: settings.open_panel(return_settings_menu, return_focus)
	elif is_instance_valid(return_focus): return_focus.grab_focus()
	return_focus = null
	return_settings = false
	return_settings_menu = false

func select_category(id: String) -> void:
	category = id
	if id == "history" and history_status == "offline" and history_connected():
		request_history()
	refresh()

func _process(_delta: float) -> void:
	if connection_owner != null and not is_instance_valid(connection_owner.get_ref()):
		connection_owner = null
		profile.clear()
		pending.clear()
		last_send_ms = -1000
		cooldown_refresh = false
		action_status = "Disconnected · pending selection unconfirmed."
		reset_result_tracking()
		reset_history()
		refresh()
	if history_status == "loading" and history_pending and Time.get_ticks_msec() - history_requested_at > HISTORY_TIMEOUT_MS:
		# No request id: the outcome is unknown. Release the slot so an explicit
		# refresh can retry; a late reply is later treated as an observation.
		history_pending = false
		history_status = "timeout"
		history_notice = "No source history reply · status unknown."
		refresh()
	if cooldown_refresh and Time.get_ticks_msec() - last_send_ms >= 550:
		cooldown_refresh = false
		refresh()
	if not pending.is_empty() and not pending.get("timed_out", false) and Time.get_ticks_msec() - int(pending.get("sent_at", 0)) > Actions.TIMEOUT_MS:
		pending.timed_out = true
		action_status = "No source confirmation · outcome unknown. Reconnect before another selection."
		refresh()

func select_item(item: Dictionary, clear: bool = false) -> void:
	if not pending.is_empty() or profile.is_empty() or connection_owner == null: return
	if Time.get_ticks_msec() - last_send_ms < 550:
		action_status = "Source gear cooldown · wait a moment and select again."
		refresh()
		return
	var client: Node = connection_owner.get_ref()
	if not is_instance_valid(client) or not client.career_wire_open() or not client.career_seated or str(client.room_id).is_empty() or client.spectating: return
	# A complete loadout is sent on every write: omitted gear would clear slots.
	var frame: Dictionary = Actions.request(profile, item, clear)
	if frame.is_empty(): return
	if client.send_frame(frame) != OK:
		action_status = "Selection could not be sent; confirmed equipment unchanged."
	else:
		last_send_ms = Time.get_ticks_msec()
		cooldown_refresh = true
		pending = {"identity":profile.id, "frame":frame, "sent_at":Time.get_ticks_msec()}
		action_status = "Selection sent · awaiting source confirmation (next match)."
	refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if active() and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close_panel()
		get_viewport().set_input_as_handled()

func build_panel() -> void:
	panel = Control.new()
	panel.name = "CareerPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.055, 0.075, 0.98)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	details = VBoxContainer.new()
	details.custom_minimum_size.x = 280
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	scroll.add_child(details)
	heading = Label.new()
	heading.text = "CAREER / ARSENAL"
	heading.add_theme_font_size_override("font_size", 26)
	details.add_child(heading)
	state_label = Label.new()
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := Button.new()
	back.name = "CareerBack"
	back.text = "BACK (Esc)"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close_panel)
	details.add_child(back)
	details.add_child(state_label)
	var tabs := HFlowContainer.new()
	details.add_child(tabs)
	for entry: Dictionary in [{"id":"gear", "label":"GEAR"}, {"id":"attachment", "label":"MODS"}, {"id":"finish", "label":"FINISHES"}, {"id":"crosshair", "label":"RETICLES"}, {"id":"results", "label":"RESULTS"}, {"id":"history", "label":"HISTORY"}]:
		var id: String = entry.id
		var button := Button.new()
		button.name = "Tab_" + id
		button.text = entry.label
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void: select_category(id))
		tabs.add_child(button)
	var list := VBoxContainer.new()
	list.name = "CatalogRows"
	list.add_theme_constant_override("separation", 12)
	details.add_child(list)
	panel.hide()
	refresh()

func add_line(parent: Node, text: String, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func clear_rows(list: Node) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if details == null or state_label == null: return
	var lines: Array = []
	if profile.is_empty():
		lines.append("NO CONNECTED CAREER · Join a room to see your source profile and equip unlocked items.")
	else:
		var parts := []
		for field: String in ["level", "xp", "prestige"]:
			parts.append(field.to_upper() + " " + (str(profile[field]) if profile.has(field) else "UNKNOWN"))
		lines.append("CONNECTED SOURCE CAREER · " + " · ".join(parts))
		lines.append("Equip for next match · Unlocks come from level and source progression.")
		lines.append("MATCHES %s · WINS %s · KILLS %s" % [str(profile.get("matches", "?")), str(profile.get("wins", "?")), str(profile.get("kills", "?"))])
		var modes: Dictionary = profile.get("byMode", {})
		if not modes.is_empty():
			var mode_parts := []
			for mode: String in modes:
				var stats: Dictionary = modes[mode]
				mode_parts.append("%s %s/%s" % [mode, str(stats.get("wins", "?")), str(stats.get("matches", "?"))])
			lines.append("MODE WINS/MATCHES · " + " · ".join(mode_parts))
	if not action_status.is_empty(): lines.append(action_status)
	var identity := get_tree().root.get_node_or_null("Identity")
	if identity != null and not identity.status.is_empty(): lines.append(identity.status)
	if category == "crosshair": lines.append("Reticles are view-only: this server's GEAR wire does not carry a crosshair selection.")
	if category == "finish": lines.append("Finishes are saved to the source profile; native finish rendering is not implemented yet.")
	if category in ["gear", "attachment", "finish", "crosshair"] and catalog.is_empty(): lines.append("Source Arsenal catalog unavailable. Regenerate from the source modules.")
	state_label.text = "\n".join(lines)
	var list := details.find_child("CatalogRows", true, false) as VBoxContainer
	if list == null: return
	clear_rows(list)
	if category == "results":
		render_results(list)
		return
	if category == "history":
		render_history(list)
		return
	for item: Dictionary in catalog.get("items", []):
		if item.kind != category: continue
		var box := VBoxContainer.new()
		list.add_child(box)
		add_line(box, "%s · %s · %s" % [item.name, item.slot if not item.slot.is_empty() else item.kind, CareerProfile.item_state(profile, item)], 19)
		add_line(box, item.description)
		var spec := []
		for key: String in item.modifiers: spec.append(key + " " + str(item.modifiers[key]))
		for part: String in item.spec: spec.append(part)
		if item.kind == "attachment": spec.append("ALL WEAPONS" if item.weapons.is_empty() else "FITS " + ", ".join(item.get("weaponNames", [])))
		if not spec.is_empty(): add_line(box, " · ".join(spec), 14)
		if item.kind != "crosshair":
			var button := Button.new()
			button.name = "Equip_" + str(item.unlockId)
			button.set_meta("catalog_id", item.id)
			button.set_meta("catalog_kind", item.kind)
			var equipped: bool = CareerProfile.item_state(profile, item) == "EQUIPPED"
			button.text = "UNEQUIP · NEXT MATCH" if equipped else "EQUIP · NEXT MATCH"
			button.custom_minimum_size.y = 44
			var client: Node = connection_owner.get_ref() if connection_owner != null else null
			button.disabled = not pending.is_empty() or Time.get_ticks_msec() - last_send_ms < 550 or not is_instance_valid(client) or not client.career_wire_open() or not client.career_seated or client.spectating or not Actions.complete(profile) or not Actions.available(profile, item)
			button.pressed.connect(select_item.bind(item, equipped))
			box.add_child(button)

func render_results(list: Node) -> void:
	if result.is_empty():
		if results_status == "live":
			add_line(list, "Round in progress · no accepted source result yet.", 18)
		else:
			add_line(list, "No accepted source result on this connection.", 18)
		render_latest_award(list)
		return
	var headline := "Round complete"
	if result.get("mode") is String: headline += " · " + str(result.mode)
	if result.get("map") is String: headline += " · " + str(result.map)
	add_line(list, headline, 19)
	var detail := []
	if result.get("ending") is String: detail.append("Ended · " + str(result.ending))
	if result.has("time"): detail.append("Elapsed " + format_seconds(float(result.time)))
	if detail.size() > 0: add_line(list, " · ".join(detail), 14)
	if result.has("frags") or result.has("deaths"):
		add_line(list, "You · %s frags · %s deaths" % [str(result.get("frags", "?")), str(result.get("deaths", "?"))], 16)
	else:
		add_line(list, "You · stats unknown (spectator or actor not in this result)", 14)
	if result.get("reconnect", false):
		add_line(list, "Read-only: result replayed on reconnect · award not delivered on this connection.", 14)
	var award: Dictionary = attributed_award()
	if not award.is_empty():
		render_award(list, "Source award", award)
	elif not latest_award.is_empty():
		render_award(list, "Latest source award (not confirmed for this result)", latest_award)
	else:
		add_line(list, "Source award · unknown (no award received on this connection)", 14)

func render_latest_award(list: Node) -> void:
	if not latest_award.is_empty():
		render_award(list, "Latest source award", latest_award)

func render_award(list: Node, title: String, award: Dictionary) -> void:
	var parts := []
	if award.has("gained"): parts.append("+%d XP" % int(award.gained))
	if award.get("levelUp") == true: parts.append("LEVEL UP")
	if award.get("prestigeUp") == true: parts.append("PRESTIGE UP")
	add_line(list, title + (" · " + " · ".join(parts) if parts.size() > 0 else ""), 16)
	var breakdown := []
	if award.has("baseGained"): breakdown.append("base %d" % int(award.baseGained))
	if award.has("prestigeBonus") and int(award.prestigeBonus) > 0: breakdown.append("prestige +%d" % int(award.prestigeBonus))
	if award.has("achievementXp") and int(award.achievementXp) > 0: breakdown.append("achievements +%d" % int(award.achievementXp))
	if breakdown.size() > 0: add_line(list, " · ".join(breakdown), 14)
	var unlocks: Variant = award.get("unlocked", [])
	if unlocks is Array and unlocks.size() > 0:
		var unlock_list: Array = unlocks
		var names := []
		for item: Dictionary in unlock_list: names.append(str(item.get("name", item.get("id", "unlock"))))
		add_line(list, "Unlocks · " + ", ".join(names), 14)
	var achievements: Variant = award.get("achievements", [])
	if achievements is Array and achievements.size() > 0:
		var achievement_list: Array = achievements
		var names := []
		for item: Dictionary in achievement_list: names.append(str(item.get("name", "achievement")))
		add_line(list, "Achievements · " + ", ".join(names), 14)

func render_history(list: Node) -> void:
	add_line(list, "Recent server matches · source-recorded; not a personal timeline.", 16)
	if history_status == "offline":
		add_line(list, "No connected source · history unavailable offline.", 14)
	elif history_status == "loading":
		add_line(list, "Requesting recent server matches…", 14)
	elif history_status == "empty":
		add_line(list, "No recent server matches recorded yet.", 14)
	elif history_status == "error":
		add_line(list, "Source history error · showing last known.", 14)
	elif history_status == "timeout":
		add_line(list, "No source history reply · status unknown.", 14)
	else:
		add_line(list, "Showing %d of up to 50 source records." % history_records.size(), 14)
	if not history_notice.is_empty(): add_line(list, history_notice, 14)
	var refresh := Button.new()
	refresh.name = "HistoryRefresh"
	refresh.text = "REFRESH"
	refresh.custom_minimum_size.y = 44
	refresh.disabled = history_status == "loading" or not history_connected()
	refresh.pressed.connect(func() -> void: request_history(true))
	list.add_child(refresh)
	for record: Dictionary in history_records:
		var box := VBoxContainer.new()
		list.add_child(box)
		add_line(box, history_headline(record), 19)
		var meta := history_meta(record)
		if not meta.is_empty(): add_line(box, meta, 14)
		var roster := history_roster(record)
		if not roster.is_empty(): add_line(box, roster, 14)

func history_headline(record: Dictionary) -> String:
	var parts := []
	if record.get("map") is String: parts.append(str(record.map))
	if record.get("mode") is String: parts.append(str(record.mode))
	if record.get("ending") is String: parts.append(str(record.ending))
	return " · ".join(parts) if parts.size() > 0 else "Source match"

func format_seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)): return "%ds" % int(roundf(value))
	return "%.1fs" % value

func history_meta(record: Dictionary) -> String:
	var parts := []
	if record.has("duration"): parts.append(format_seconds(float(record.duration)))
	if record.get("leader") is String: parts.append("Source leader " + str(record.leader))
	var players: Variant = record.get("players", [])
	if players is Array and players.size() > 0: parts.append("%d players" % players.size())
	return " · ".join(parts)

func history_roster(record: Dictionary) -> String:
	var players: Variant = record.get("players", [])
	if not players is Array: return ""
	var list: Array = players
	var parts := []
	for player: Dictionary in list:
		if parts.size() >= 8:
			parts.append("+%d more" % (players.size() - parts.size()))
			break
		var stats := []
		if player.has("frags"): stats.append("F%d" % int(player.frags))
		if player.has("deaths"): stats.append("D%d" % int(player.deaths))
		if player.has("goals"): stats.append("G%d" % int(player.goals))
		var label := str(player.get("name", "player"))
		if stats.size() > 0: label += " " + " ".join(stats)
		parts.append(label)
	return " · ".join(parts)
