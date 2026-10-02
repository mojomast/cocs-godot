extends CanvasLayer
## Mount only on an admitted live session. Records received client signals, never Match.
const Bridge = preload("res://replay/bridge.gd")
const Access = preload("res://ui/settings_access.gd")
var bridge: Node
var recipient: Node
var last_state: Dictionary = {}
var event_batch: Array = []
var recording := false
var opening := false
var has_capture := false
var role := ""
var revision := -1
var row := HFlowContainer.new()
var status := Label.new()
var record_button := Button.new()
var save_button := Button.new()
var discard_button := Button.new()
var badge := Label.new()

func _ready() -> void:
	name = "ReplayCapture"
	layer = 12
	var session := get_parent()
	if not ("client" in session): queue_free(); return
	recipient = session.get("client")
	if not is_instance_valid(recipient): queue_free(); return
	add_child(row)
	add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(-190, 12)
	badge.text = "● REC · local replay"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.modulate = Color(1.0, 0.35, 0.3)
	badge.hide()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.position = Vector2(16, -100)
	row.size = Vector2(550, 84)
	for button: Button in [record_button, save_button, discard_button]: row.add_child(button)
	row.add_child(status)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 280
	record_button.text = "Record replay"
	save_button.text = "Save clip"
	discard_button.text = "Discard recording"
	record_button.pressed.connect(begin)
	save_button.pressed.connect(save)
	discard_button.pressed.connect(discard)
	recipient.snapshot.connect(observe)
	recipient.started.connect(observe)
	recipient.results.connect(observe)
	recipient.events.connect(events)
	if recipient.has_signal("transport_dropped"): recipient.transport_dropped.connect(interrupted)
	status.text = "Replay: Meridian combat only"

func _process(_delta: float) -> void:
	row.visible = not Access.overlay_open() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	badge.visible = recording and not Access.overlay_open()
	var admitted := last_state.get("mapId") == "meridian-exchange" and last_state.get("config", {}).get("mode") in ["deathmatch", "teamdeathmatch", "instagib", "rockets"]
	record_button.disabled = recording or opening or has_capture or not admitted
	save_button.disabled = not has_capture or opening
	discard_button.disabled = not has_capture or opening
	row.size.x = minf(550, get_viewport().get_visible_rect().size.x - 32)

func current_role() -> String:
	return "spectator" if recipient.get("spectating") == true else "seated"

func begin() -> void:
	if last_state.is_empty() or has_capture or opening: return
	if is_instance_valid(bridge) and bridge.stopped:
		bridge.free()
		bridge = null
	if not is_instance_valid(bridge):
		bridge = Bridge.new()
		bridge.reply.connect(received)
		bridge.failed.connect(interrupted)
		add_child(bridge)
	role = current_role()
	opening = true
	if not bridge.send({"op":"record", "mapId":last_state.mapId, "mode":last_state.config.mode, "role":role}): opening = false

func observe(frame: Dictionary) -> void:
	var state: Variant = frame.get("state")
	if not state is Dictionary: return
	var next_revision := int(frame.get("roundRevision", recipient.get("resumed_revision")))
	if recording and (current_role() != role or (revision >= 0 and next_revision >= 0 and revision != next_revision) or float(state.get("time", 0)) < float(last_state.get("time", 0))):
		interrupted("Round/seat changed. Save this clip, then record again.")
	revision = next_revision
	last_state = state.duplicate(true)
	if not recording: return
	if not bridge.send({"op":"frame", "state":last_state, "events":event_batch, "role":role}): recording = false
	event_batch = []
	if state.get("over") == true:
		recording = false
		status.text = "Round ended · Save clip"

func events(items: Array) -> void:
	if not recording: return
	if event_batch.size() + items.size() > 512:
		interrupted("Event queue limit reached. Save the delivered prefix.")
		return
	event_batch.append_array(items.duplicate(true))

func save() -> void:
	if not has_capture or opening: return
	if recording and not event_batch.is_empty():
		bridge.send({"op":"frame", "state":last_state, "events":event_batch, "role":role})
	recording = false
	event_batch = []
	if bridge.send({"op":"save"}): status.text = "Saving replay…"
	else: status.text = "Runtime unavailable; unsaved clip cannot be saved. Discard to reset."

func discard() -> void:
	if not has_capture: return
	recording = false
	event_batch = []
	if not bridge.send({"op":"discard"}):
		has_capture = false
		status.text = "Unsaved recording discarded; saved clips preserved"

func received(op: String, value: Dictionary) -> void:
	if op == "record":
		opening = false
		has_capture = true
		if current_role() != role:
			interrupted("Seat changed while starting recording. Discard and record again.")
			return
		recording = true
		event_batch = []
		bridge.send({"op":"frame", "state":last_state, "events":[], "role":role})
		status.text = "REC · delivered %s stream" % role
	elif op in ["frame", "frames"] and recording: status.text = "REC · %.1fs · %d frames" % [value.duration, value.frames]
	elif op == "save":
		has_capture = false
		status.text = "Saved · Home → Replays"
	elif op == "discard":
		has_capture = false
		status.text = "Recording discarded"

func interrupted(message: String) -> void:
	recording = false
	opening = false
	event_batch = []
	status.text = message
