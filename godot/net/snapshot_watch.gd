class_name PortSnapshotWatch
extends RefCounted

# Diagnostic receive-age guard. No prediction, ping estimate or reconnect.
const STALE_AFTER := 1.0
var age := 0.0
var received := false
func reset() -> void:
	age = 0.0
	received = false
func observe() -> void:
	age = 0.0
	received = true
func advance(delta: float) -> void:
	if is_finite(delta) and delta > 0:
		age = minf(age + delta, 3600.0)
func stale() -> bool:
	return not received or age >= STALE_AFTER
func message() -> String:
	if not received: return "Waiting for authoritative snapshot"
	if stale(): return "Snapshots stalled · controls neutral · %.1fs since update" % age
	return ""
