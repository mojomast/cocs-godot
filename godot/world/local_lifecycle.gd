class_name PortLocalLifecycle
extends RefCounted

# Snapshot-owned state only: never predict respawn or count down locally.
var status: String = "waiting"
var respawn_remaining: float = 0.0
var reseed_look: bool = false
var death_transitions: int = 0
var respawn_transitions: int = 0

func clear() -> void:
	status = "waiting"
	respawn_remaining = 0.0
	reseed_look = false
	death_transitions = 0
	respawn_transitions = 0

func apply(actor: Dictionary, over: bool) -> void:
	var previous: String = status
	respawn_remaining = maxf(0.0, float(actor.get("dead", 0)))
	status = "results" if over else ("waiting" if actor.is_empty() else ("dead" if respawn_remaining > 0 else "alive"))
	reseed_look = status == "alive" and previous != "alive"
	if status == "dead" and previous == "alive": death_transitions += 1
	if status == "alive" and previous == "dead": respawn_transitions += 1

func can_control() -> bool:
	return status == "alive"

func label() -> String:
	match status:
		"dead": return "DEAD · server respawn in %.1fs" % respawn_remaining
		"results": return "RESULTS"
		"alive": return "LIVE"
	return "Waiting for local actor"
