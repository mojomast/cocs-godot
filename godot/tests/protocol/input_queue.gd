extends SceneTree
const Network = preload("res://net/client.gd")
class QueueProbe extends Network:
	var response: Error = OK
	var attempts: Array = []
	func send_frame(frame: Dictionary) -> Error:
		attempts.append(frame.duplicate(true))
		return response
var checks := 0
func check(ok: bool) -> void:
	checks += 1
	if not ok:
		push_error("Input queue assertion " + str(checks))
		quit(1)
		assert(ok)
func _initialize() -> void:
	var disconnected := Network.new()
	check(disconnected.send_input({}) == ERR_CONNECTION_ERROR)
	check(disconnected.input_seq == 0)
	disconnected.free()
	var probe := QueueProbe.new()
	check(probe.send_input({"fire":true}) == OK and probe.input_seq == 1)
	probe.response = ERR_OUT_OF_MEMORY
	for i: int in range(40):
		check(probe.send_input({}) == ERR_OUT_OF_MEMORY and probe.input_seq == 1)
	probe.response = OK
	check(probe.send_input({"fire":false}) == OK and probe.input_seq == 2)
	check(probe.attempts.back().seq == 2 and probe.attempts.back().input.fire == false)
	probe.reset_round()
	check(probe.send_input({}) == OK and probe.input_seq == 1)
	probe.free()
	print("PORT_INPUT_QUEUE_OK checks=", checks, " synthetic_queue_errors=true disconnected_peer=real")
	quit(0)
