extends "res://tests/arms_race/fixtures.gd"
## Count delivered release-safe checks and exercise every fresh-action binding.
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func board_checks(board: Node) -> void:
	for code: int in Fresh.KEYS:
		var gate := Fresh.new()
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		gate.observe(event)
		gate.boundary()
		check(not gate.capture_allowed(), "Fresh-action gate blocks held key %d" % code)
		event.pressed = false
		gate.observe(event)
		check(gate.capture_allowed(), "Fresh-action gate clears released key %d" % code)
	var p := Progress.new()
	p.apply_state({"actors":[{"id":0,"ladder":0,"weapon":0,"frags":999}]}, 0)
	check(p.rung == 0 and "Pulse Rifle" in p.current, "Large frag total never fabricates ladder")
	p.apply_state({"actors":[{"id":0,"ladder":10,"weapon":9,"frags":10}],"over":true,"winner":0}, 0)
	check("Ladder completed" in p.next and "LADDER FINISH" in p.outcome, "Explicit completion uses final source weapon")
	p.clear()
	check(p.rung == -1 and p.weapon == -1 and p.outcome.is_empty(), "Clear removes completed round progress")
	super.board_checks(board)
	print("ARMS_INDEPENDENT_FIXTURES ", JSON.stringify({"checks":checks,"failures":failures,"release_safe":true}))
