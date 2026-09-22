extends RefCounted

# Display identities in game/data.mjs order; no weapon rules or selection authority.
const NAMES := ["Pulse Rifle", "Rocket Launcher", "Rail Lance", "Scattergun", "Plasma Driver", "Grenade Launcher", "Shock Beam", "Flak Cannon", "Marksman Rifle", "Submachine Gun"]

static func display_name(index: int) -> String:
	return NAMES[index] if index >= 0 and index < NAMES.size() else "Weapon unknown"

static func ammo_text(value: Variant) -> String:
	# The wire serializer represents unlimited ammunition with this exact string.
	if value is String and value == "∞": return "∞"
	if (value is int or value is float) and is_finite(float(value)) and float(value) >= 0:
		return str(int(minf(float(value), 1000000)))
	return "—"
