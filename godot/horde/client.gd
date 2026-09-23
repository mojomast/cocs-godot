extends "res://net/client.gd"
## Additive local-only input metadata; public protocol/client stay unchanged.
signal input_reset(reason: String)
var input_epoch := 0
var received_input := 0
var input_status := {}
## Local Horde upgrade intent. The authority stays the only source of truth for
## which choices exist and which one applied: these fields only bound what this
## client may ask for, and what it is still waiting on. `pending_*` is set when
## an intent is actually queued; planning alone never claims a send.
const UPGRADE_FRAME := "horde-upgrade"
const APPLIED_FRAME := "horde-upgrade-applied"
const REJECTED_FRAME := "horde-upgrade-rejected"
const CHOICE_LIMIT := 64
var offer_pending := false
var offer_ids: Array = []
var offer_wave := 0
var offer_count := 0
var offer_selected := ""
var pending_choice := ""
var pending_wave := 0
var pending_count := 0
var confirmed_choice := ""
var confirmed_count := 0
var rejected_reason := ""
var upgrade_sent := 0

static func wire_int(value: Variant, fallback: int = 0) -> int:
	if value is int: return value
	if value is float and is_finite(value) and floorf(value) == value: return int(value)
	return fallback

## Same contract as the adapter's choice guard: bounded, printable, untrimmed.
static func valid_choice(value: Variant) -> bool:
	if not value is String: return false
	var choice: String = value
	if choice.length() < 1 or choice.length() > CHOICE_LIMIT: return false
	for index in choice.length():
		var code := choice.unicode_at(index)
		if code < 32 or code == 127: return false
	return true

func reset_upgrade_state() -> void:
	offer_pending = false
	offer_ids = []
	offer_wave = 0
	offer_count = 0
	offer_selected = ""
	pending_choice = ""
	pending_wave = 0
	pending_count = 0
	confirmed_choice = ""
	confirmed_count = 0
	rejected_reason = ""
	upgrade_sent = 0

func disconnect_server() -> void:
	input_epoch = 0
	received_input = 0
	input_status.clear()
	reset_upgrade_state()
	super.disconnect_server()

## Projection of the live offer, as published by the authority snapshot. The
## offer closing without our choice, or a different wave replacing it, resolves
## the single-flight guard exactly once so a retry is explicit.
func observe_offer(view: Dictionary) -> void:
	var ids: Array = []
	var raw_ids: Variant = view.get("ids")
	if raw_ids is Array:
		for value: Variant in raw_ids:
			if valid_choice(value) and not ids.has(value): ids.append(value)
	offer_ids = ids
	offer_pending = view.get("pending") == true and not ids.is_empty()
	offer_wave = maxi(0, wire_int(view.get("wave"), 0))
	offer_count = maxi(0, wire_int(view.get("count"), 0))
	offer_selected = str(view.get("selected")) if view.get("selected") is String else ""
	if pending_choice == "": return
	if offer_count > pending_count and (offer_selected.is_empty() or offer_selected == pending_choice):
		confirmed_choice = pending_choice
		confirmed_count = offer_count
		pending_choice = ""
		pending_wave = 0
		pending_count = 0
		rejected_reason = ""
	elif not offer_pending or offer_wave != pending_wave:
		pending_choice = ""
		pending_wave = 0
		pending_count = 0
		rejected_reason = "offer-closed"

## Pure decision for one choice. Planning mutates nothing; `send_upgrade_intent`
## is the only path that claims a send and takes the single-flight guard.
func upgrade_intent(choice: String, wave: int) -> Dictionary:
	if not valid_choice(choice): return {"ok":false, "reason":"malformed-choice", "frame":{}}
	if input_epoch < 1: return {"ok":false, "reason":"no-round", "frame":{}}
	if not offer_pending: return {"ok":false, "reason":"no-pending-offer", "frame":{}}
	if not offer_ids.has(choice): return {"ok":false, "reason":"unauthorized-choice", "frame":{}}
	if wave != offer_wave: return {"ok":false, "reason":"stale-offer", "frame":{}}
	if pending_choice != "":
		return {"ok":false, "reason":"duplicate-choice" if pending_choice == choice else "selection-pending", "frame":{}}
	return {"ok":true, "reason":"", "frame":{"type":UPGRADE_FRAME, "inputEpoch":input_epoch,
		"choice":choice, "wave":offer_wave, "applied":offer_count}}

func send_upgrade_intent(choice: String, wave: int) -> Dictionary:
	var intent := upgrade_intent(choice, wave)
	if not intent.ok: return intent
	var result: Error = send_frame(intent.frame)
	if result != OK: return {"ok":false, "reason":"transport", "frame":intent.frame}
	upgrade_sent += 1
	pending_choice = choice
	pending_wave = int(intent.frame.wave)
	pending_count = int(intent.frame.applied)
	rejected_reason = ""
	return intent

## Answers are additive local frames: an answer for another round is tolerated,
## then ignored. Only the authority can confirm or refuse an intent.
func decode_upgrade_answer(frame: Dictionary) -> bool:
	if not wire_integer(frame.get("inputEpoch")) or int(frame.inputEpoch) < 1:
		return fail("Missing local Horde upgrade epoch")
	if int(frame.inputEpoch) != input_epoch: return true
	if frame.get("type") == APPLIED_FRAME:
		var choice: Variant = frame.get("choice")
		if not valid_choice(choice) or not wire_integer(frame.get("wave")) or not wire_integer(frame.get("count")):
			return fail("Malformed Horde upgrade answer")
		confirmed_choice = choice
		confirmed_count = int(frame.count)
		pending_choice = ""
		pending_wave = 0
		pending_count = 0
		rejected_reason = ""
		return true
	var reason: Variant = frame.get("reason")
	if not reason is String or reason.is_empty() or reason.length() > CHOICE_LIMIT or "\n" in reason:
		return fail("Malformed Horde upgrade rejection")
	var named: Variant = frame.get("choice")
	if pending_choice != "" and (not named is String or named == pending_choice):
		pending_choice = ""
		pending_wave = 0
		pending_count = 0
		rejected_reason = reason
	return true

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var frame: Variant = JSON.parse_string(text)
	if frame is Dictionary:
		if frame.get("type") in [APPLIED_FRAME, REJECTED_FRAME]:
			return decode_upgrade_answer(frame)
		if frame.get("type") in ["start", "snapshot", "results", "horde-input-reset"]:
			if not wire_integer(frame.get("inputEpoch")) or frame.inputEpoch < 1:
				return fail("Missing local Horde input epoch")
			var changed: bool = int(frame.inputEpoch) != input_epoch
			input_epoch = int(frame.inputEpoch)
			if frame.get("type") == "start":
				received_input = 0
				input_status.clear()
			elif changed:
				input_reset.emit(str(frame.get("reason", "authority boundary")))
		if frame.get("hordeInput") is Dictionary:
			input_status = frame.hordeInput.duplicate(true)
			received_input = int(input_status.get("receivedSeq", 0))
	return super.decode_text(text)

func send_controls(controls: Dictionary, cancel: bool = false) -> Error:
	if input_epoch < 1: return ERR_UNCONFIGURED
	var next_seq := input_seq + 1
	var result := send_frame({"type":"input", "seq":next_seq, "inputEpoch":input_epoch,
		"cancel":cancel, "input":{} if cancel else controls})
	if result == OK: input_seq = next_seq
	return result

func send_input(controls: Dictionary) -> Error:
	return send_controls(controls)
