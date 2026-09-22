extends "res://net/client.gd"
## Optional local DM input epochs. All game state is ordinary protocol v3.
signal input_reset(reason: String)
var input_epoch := 0
var input_status: Dictionary = {}

func disconnect_server() -> void:
	input_epoch = 0
	input_status.clear()
	super.disconnect_server()

func create_room(player_name: String = "Godot") -> Error:
	return send_frame({"type":"create", "name":"Native arena Deathmatch", "playerName":player_name,
		"v":3, "delta":0, "nativeArenaInput":1})

func decode_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > MAX_FRAME_BYTES: return fail("Oversized frame")
	var frame: Variant = JSON.parse_string(text)
	if frame is Dictionary:
		if frame.get("type") in ["start", "snapshot", "results", "native-arena-input-reset"]:
			if not wire_integer(frame.get("inputEpoch")) or frame.inputEpoch < 1:
				return fail("Missing native arena input epoch")
			var next_epoch := int(frame.inputEpoch)
			if next_epoch < input_epoch: return fail("Native arena input epoch regressed")
			var changed := next_epoch != input_epoch
			input_epoch = next_epoch
			if frame.get("type") == "start":
				input_status.clear()
			elif changed:
				input_reset.emit(str(frame.get("reason", "authority boundary")))
		if frame.has("nativeArenaInput") and frame.get("type") in ["snapshot", "results"]:
			if not frame.nativeArenaInput is Dictionary: return fail("Malformed native input status")
			for key: String in ["receivedSeq", "appliedSeq", "cancelledThrough", "queueDepth"]:
				if not wire_integer(frame.nativeArenaInput.get(key)): return fail("Malformed native input status")
			input_status = frame.nativeArenaInput.duplicate(true)
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
