extends RefCounted

# Source: game/data.mjs WEAPONS order; game/input.mjs hasAmmo/cycleWeapon.
# Ammo is the source's availability/ownership signal; no separate owned bitset.
const NAMES: Array[String] = ["Pulse Rifle", "Rocket Launcher", "Rail Lance", "Scattergun", "Plasma Driver", "Grenade Launcher", "Shock Beam", "Flak Cannon", "Marksman Rifle", "Submachine Gun"]
const REQUEST_SECONDS: float = 0.25
var pending: int = -1
var pending_key: int = 0
var first_sequence: int = -1
var require_ack: bool = false
var remaining: float = 0.0
var held: Dictionary = {}

static func weapon_name(index: int) -> String:
	return NAMES[index] if index >= 0 and index < NAMES.size() else "Unknown weapon"

static func key_index(physical_key: int) -> int:
	if physical_key == KEY_0: return 9
	return physical_key - KEY_1 if physical_key >= KEY_1 and physical_key <= KEY_9 else -1

static func available(actor: Dictionary, index: int) -> bool:
	var ammo: Variant = actor.get("ammo")
	if not ammo is Array or index < 0 or index >= mini(ammo.size(), NAMES.size()): return false
	var value: Variant = ammo[index]
	return value == "∞" if value is String else ((value is int or value is float) and float(value) > 0.0)

func clear() -> void:
	pending = -1
	pending_key = 0
	first_sequence = -1
	require_ack = false
	remaining = 0.0
	# Keep held keys latched across boundaries. Only a release permits a new press.

func request(index: int, key: int, actor: Dictionary) -> void:
	if not available(actor, index): return
	if pending == index: return # Repeat presses cannot extend a request forever.
	var replacing_queued: bool = first_sequence >= 0
	clear()
	if index == actor.get("weapon", -1):
		if not replacing_queued: return
		# The previous command may already be in flight. Send the explicit return
		# rather than mistaking the pre-command snapshot for confirmation.
		require_ack = true
	pending = index
	pending_key = key
	remaining = REQUEST_SECONDS

func handle_event(event: InputEvent, active: bool, actor: Dictionary) -> bool:
	if not active: clear()
	if event is InputEventKey:
		var key: int = event.physical_keycode
		var index := key_index(key)
		if index < 0: return false
		if not event.pressed:
			held.erase(key)
			if pending_key == key: clear()
			return false
		if event.echo or held.has(key): return active
		held[key] = true
		if active: request(index, key, actor)
		return active
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not active: return false
		var start: int = pending if pending >= 0 else int(actor.get("weapon", -1))
		var direction: int = 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		for step in range(1, NAMES.size() + 1):
			var index: int = posmod(start + direction * step, NAMES.size())
			if available(actor, index):
				request(index, 0, actor)
				break
		return true
	return false

func advance(delta: float, active: bool, actor: Dictionary, ack: int) -> void:
	if pending < 0: return
	remaining -= delta
	if not active or remaining <= 0.0 or not available(actor, pending) or (not require_ack and actor.get("weapon", -1) == pending) or (first_sequence >= 0 and ack >= first_sequence):
		clear()

func queued(sequence: int) -> void:
	# Room.input replaces latest input; weapon has no edge latch. Repeat only
	# until an applied ACK (not merely receipt), confirmation, release or timeout.
	if pending >= 0 and first_sequence < 0: first_sequence = sequence
