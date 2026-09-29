extends SceneTree

const Profile = preload("res://ambience/weather_profile.gd")
const VECTORS = "../port/native-audiovisual/weather-vectors.json"
const TOLERANCE := 0.00002

func _initialize() -> void:
	var file := FileAccess.open(ProjectSettings.globalize_path("res://") + VECTORS, FileAccess.READ)
	assert(file != null, "weather vectors must be present beside godot/")
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	assert(data.source == "game/environment.mjs")
	for row: Dictionary in data.mapSeeds:
		assert(Profile.seed_for({"id": row.id}) == int(row.seed), "map seed: " + row.id)
	for row: Dictionary in data.hashes:
		_equal(Profile.hash_unit(int(row.seed), int(row.salt)), row.unit, "hash: %s/%s" % [row.seed, row.salt])
	for row: Dictionary in data.selection:
		_equal(Profile.biome(row.arena), row.biome, "biome: " + row.arena.id)
		_equal(Profile.select(row.arena, row.time, int(row.seed), row.get("reduced", false)), row.kind, "weather: " + row.arena.id)
	for row: Dictionary in data.times:
		_equal(Profile.time_at(row.arena, float(row.elapsed), row.mode), row.expected, "time: " + row.arena.id)
	for row: Dictionary in data.winds:
		_equal(Profile.gust(float(row.time), int(row.seed), float(row.strength)), row.expected, "wind: " + str(row.seed))
	for row: Dictionary in data.lightning:
		_equal(Profile.lightning(int(row.seed), float(row.window), int(row.count), row.kind), row.expected, "lightning: " + row.kind)
	for row: Dictionary in data.precipitation:
		_equal(_precip(row), row.expected, "precipitation: " + row.kind)
	print("WEATHER_ORACLE_OK")
	quit()

func _equal(actual: Variant, expected: Variant, label: String) -> void:
	if expected is Dictionary:
		assert(actual is Dictionary, label + ": expected object")
		assert(actual.size() == expected.size(), label + ": object key count")
		for key: Variant in expected:
			assert(actual.has(key), label + ": missing " + str(key))
			_equal(actual[key], expected[key], label + "." + str(key))
	elif expected is Array:
		assert(actual is Array, label + ": expected array")
		assert(actual.size() == expected.size(), label + ": array length")
		for i in expected.size():
			_equal(actual[i], expected[i], label + "[" + str(i) + "]")
	elif expected is float or expected is int:
		assert(actual is float or actual is int, label + ": expected number")
		assert(is_finite(float(actual)) and absf(float(actual) - float(expected)) <= TOLERANCE, label + ": %s != %s" % [actual, expected])
	else:
		assert(actual == expected, label + ": %s != %s" % [actual, expected])

# Reconstruct the service's spawn fields from its native hash/profile primitives.
# With seed offset zero, the service salt is serial*17+i*131, like JS.
func _precip(row: Dictionary) -> Array:
	var kind: String = row.kind
	if not Profile.KINDS.has(kind): return []
	var profile: Dictionary = Profile.KINDS[kind]
	if int(profile.particles) <= 0: return []
	var result: Array = []
	var radius := maxf(2.0, float(row.radius))
	for i in maxi(1, roundi(float(profile.particles) / 6.0)):
		var salt := int(row.serial) * 17 + i * 131
		var angle := Profile.hash_unit(salt, 1) * TAU
		var distance := sqrt(Profile.hash_unit(salt, 2)) * radius
		var fall: float = profile.fall * (0.85 + Profile.hash_unit(salt, 5) * 0.3)
		result.append({
			"pos": {"x": float(row.origin.x) + cos(angle) * distance, "y": float(row.origin.y) + 4.0 + Profile.hash_unit(salt, 3) * 6.0, "z": float(row.origin.z) + sin(angle) * distance},
			"color": "#" + str(profile.color), "size": profile.size * (0.8 + Profile.hash_unit(salt, 6) * 0.5),
			"life": profile.life * (0.8 + Profile.hash_unit(salt, 4) * 0.4),
			"velocity": {"x": (Profile.hash_unit(salt, 7) - 0.5) * profile.drift, "y": -fall, "z": (Profile.hash_unit(salt, 8) - 0.5) * profile.drift},
			"additive": kind in ["snow", "ash"], "streak": profile.streakRatio,
		})
	return result
