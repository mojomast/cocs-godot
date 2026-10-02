extends RefCounted
## Per-consumer physical ledger. Does not inject global Input events, poll held
## state, synthesize packets, or consume raw event accounting in route clients.
const Model = preload("res://input_bindings/model.gd")
const Access = preload("res://input_bindings/access.gd")
var down: Dictionary = {}
var blocked: Dictionary = {}
var override_bindings: Dictionary = {} # Detached native contracts only.

func suppress() -> void:
	blocked.merge(down)

func released_for_capture() -> bool:
	for physical: String in down:
		if physical != "MouseLeft": return false
	return true

func translate(event: InputEvent, active: bool) -> InputEvent:
	if not (event is InputEventKey or event is InputEventMouseButton): return event
	if event is InputEventKey and event.echo: return null
	var physical := Model.physical(event)
	if physical.is_empty(): return event # Shell digits, Escape, wheel, function keys.
	if not event.pressed:
		var previous: String = down.get(physical, "")
		down.erase(physical)
		blocked.erase(physical)
		return Model.virtual_event(previous, false) if not previous.is_empty() else null
	if blocked.has(physical) or down.has(physical): return null
	var bindings := override_bindings if not override_bindings.is_empty() else Access.values()
	var target := ""
	for action: String in Model.LABELS:
		if bindings.get(action, Model.DEFAULTS[action]) == physical:
			target = Model.DEFAULTS[action]
			break
	# The source's fixed second paths remain independently held inputs.
	if physical in ["KeyC", "MouseMiddle"]: target = physical
	if target.is_empty(): return null # An old remapped key is truly unbound.
	down[physical] = target
	if not active: blocked[physical] = target
	# Still deliver inactive presses to the existing consumer's raw-down ledger;
	# its eligibility/capture logic owns the default first-click semantics.
	return Model.virtual_event(target, true)
