extends "res://net/client.gd"
## Additive local-only input metadata; public protocol/client stay unchanged.
signal input_reset(reason: String)
var input_epoch := 0
var received_input := 0
var input_status := {}

func disconnect_server() -> void:
	input_epoch = 0
	received_input = 0
	input_status.clear()
	super.disconnect_server()

func decode_text(text: String) -> bool:
	var frame: Variant = JSON.parse_string(text)
	if frame is Dictionary:
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
