extends SceneTree
const Outcomes = preload("res://lattice/world_outcomes.gd")
const Telemetry = preload("res://lattice/world_telemetry.gd")

func _initialize() -> void:
	var result := {"outcome":{"winner":0.0,"reason":"time"}}
	assert(Outcomes.final_result(result, false).contains("winner team 0"))
	result.outcome.winner = 1.0
	assert(Outcomes.final_result(result, false).contains("winner team 1"))
	result.outcome.winner = 0.5
	assert(Outcomes.final_result(result, false).contains("winner unknown"))
	result.outcome.winner = INF
	assert(Outcomes.final_result(result, false).contains("winner unknown"))
	result.outcome.winner = null
	assert(Outcomes.final_result(result, false).contains("winner draw"))
	result.outcome.erase("winner")
	assert(Outcomes.final_result(result, false).contains("winner unknown"))

	var trace := Telemetry.new()
	var projection := {"context":{"revision":7,"actor":4,"peer":2},"source_sequence":12,"source_time":99}
	trace.observe_events([{"type":"cocs-capture","tick":31,"participants":[4],"node":"n"}], projection)
	assert(trace.captures == 1 and trace.attributed_captures == 1)
	assert(trace.records.back().fields.effect == "observed nearby/unattributed")
	assert(not trace.records.back().fields.has("cardId"), "capture participation is not card attribution")
	var source_order := {"type":"cocs-order-complete","cardId":"card-1","peerId":"4","contributors":[99],"node":"n","team":0,"id":"evt-1","tick":32}
	trace.observe_events([source_order], projection)
	assert(trace.recent_events.size() == 2)
	var action := {"cardId":"card-1","roundRev":7}
	assert(trace.order_matches(trace.recent_events.back(), action, projection, 4))
	assert(not trace.order_matches(trace.recent_events.back(), action, projection, 2), "room peer is not simulation actor")
	var event_with_untrusted_actor: Dictionary = trace.recent_events.back().duplicate(true)
	event_with_untrusted_actor["actor"] = 999
	assert(trace.order_matches(event_with_untrusted_actor, action, projection, 4), "contributors/actor evidence does not gate issuer effect")
	assert(not trace.order_matches(trace.recent_events.back(), {"cardId":"card-2","roundRev":7}, projection, 4))
	assert(not trace.order_matches(trace.recent_events.back(), action, projection, 3), "issuer actor must match")
	assert(not trace.order_matches(trace.recent_events.back(), {"cardId":"card-1","roundRev":6}, projection, 4), "action round must match")
	assert(not trace.order_matches({"type":"cocs-order-complete","peerId":"4","cardId":"card-1","round":7}, action, projection, 4), "invented event round cannot correlate")
	trace.observe_events([{"type":"cocs-order-complete","cardId":"card-1","peerId":"4","round":6}], projection)
	assert(trace.recent_events.size() == 2, "ignore events from a different round")
	for i in range(40): trace.observe_events([{"type":"cocs-capture","tick":i}], projection)
	assert(trace.recent_events.size() == 32, "event correlation buffer remains bounded")
	trace.finish_round()
	assert(trace.completed_rounds.size() == 1 and trace.completed_rounds[0].captures == 41)
	trace.begin_round()
	assert(trace.captures == 0 and trace.completed_rounds.size() == 1 and trace.recent_events.is_empty(), "round boundary clears event correlation")
	print("flagship_l3_evidence_contract: PASS")
	quit()
