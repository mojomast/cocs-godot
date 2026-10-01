extends SceneTree
const Actions = preload("res://world/combat_actions.gd")
class Client:
	extends "res://campaign/client.gd"
	var sent: Array[Dictionary] = []
	var send_error := OK
	func send_frame(frame: Dictionary) -> Error:
		if send_error == OK: sent.append(frame.duplicate(true))
		return send_error

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var client := Client.new()
	client.input_epoch = 1
	var actions := Actions.new()
	# A render sender runs four times faster than an irregular source consumer.
	# Source ACKs, not wall-clock guesses, must bound every admitted burst.
	var fifo: Array[Dictionary] = []
	var consumed := 0
	var busy := 0
	for frame: int in 600:
		if frame % 4 == 0 and not fifo.is_empty():
			var sample: Dictionary = fifo.pop_front()
			consumed += 1
			client.input_status = {"appliedSeq":sample.seq,"cancelledThrough":0}
		var result := client.send_input({"x":1,"fire":true})
		if result == OK: fifo.append(client.sent.back())
		elif result == ERR_BUSY: busy += 1
		else: check(false, "Unexpected send error during a healthy bounded stream")
		check(fifo.size() <= 4, "Delayed source consumption cannot overflow the four-sample window")
	check(consumed > 100 and busy > 300, "Sustained test exercises both source progress and real backpressure")
	check(client.outstanding_inputs.size() == 4, "Window is full before pulse-retention check")
	# The production session only calls queued() after OK; busy must preserve a
	# fresh action and weapon switch, rather than replaying or silently dropping it.
	actions.pulses.melee = true
	var controls := actions.sample(0, 0, true)
	controls.weapon = 2
	var seq := client.input_seq
	check(client.send_input(controls) == ERR_BUSY and client.input_seq == seq, "Backpressure does not allocate a wire sequence")
	check(actions.pulses.has("melee"), "Fresh melee remains pending across backpressure")
	var retired: Dictionary = fifo.pop_front()
	client.input_status.appliedSeq = retired.seq
	check(client.send_input(controls) == OK, "Source ACK admits the pending action")
	actions.queued()
	check(client.sent.back().input.melee and client.sent.back().input.weapon == 2, "Admitted frame retains melee and selected weapon")
	check(not actions.sample(0, 0, true).melee, "Accepted one-shot action is not repeated")
	check(client.send_controls({}, true) == OK, "Release cancellation bypasses a full window")
	check(client.outstanding_inputs.size() == 1 and client.sent.back().cancel, "Cancellation retires queued samples in transport order")
	# A source TTL reset invalidates old in-flight sequences. No longer TTL and
	# no local expiry heuristic is needed to recover admission in the new epoch.
	client.input_epoch = 2
	check(client.send_input({"x":0}) == OK, "Epoch change opens a fresh window")
	check(client.outstanding_inputs.size() == 1 and client.sent.back().inputEpoch == 2, "Old epoch samples do not consume new-epoch credit")
	client.input_status = {"appliedSeq":0,"cancelledThrough":client.input_seq}
	check(client.send_input({"x":0}) == OK and client.outstanding_inputs.size() == 1, "Authoritative cancellation-through releases input credit")
	client.send_error = ERR_CONNECTION_ERROR
	seq = client.input_seq
	check(client.send_input({}) == ERR_CONNECTION_ERROR and client.input_seq == seq, "Real connection errors stay visible and consume no credit")
	client.disconnect_server()
	check(client.outstanding_inputs.is_empty() and client.outstanding_epoch == 0, "Disconnect clears per-connection flow state")
	client.free()
	print("CAMPAIGN_INPUT_FLOW checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
