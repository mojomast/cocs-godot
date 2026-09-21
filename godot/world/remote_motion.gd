class_name PortRemoteMotion
extends RefCounted

# Receive-clock interpolation only: no extrapolation or gameplay authority.
# 100ms is provisional; measure latency/jitter before tuning for deployment.
const DELAY: float = 0.1
const TELEPORT_DISTANCE: float = 8.0
const MAX_SAMPLES: int = 32
var tracks: Dictionary = {}

func clear() -> void:
	tracks.clear()

func ingest(id: int, position: Vector3, yaw: float, alive: bool, now: float) -> void:
	var samples: Array = tracks.get(id, [])
	if not samples.is_empty():
		var previous: Dictionary = samples.back()
		if now <= float(previous.time): return
		if previous.alive != alive or position.distance_to(previous.position) > TELEPORT_DISTANCE:
			samples.clear()
	samples.append({"time": now, "position": position, "yaw": yaw, "alive": alive})
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()
	tracks[id] = samples

func sample(id: int, now: float) -> Dictionary:
	var samples: Array = tracks.get(id, [])
	if samples.is_empty(): return {}
	var target: float = now - DELAY
	while samples.size() > 2 and float(samples[1].time) <= target:
		samples.pop_front()
	if target <= float(samples[0].time): return samples[0]
	for i: int in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		if target <= float(b.time):
			var weight: float = clampf((target - float(a.time)) / (float(b.time) - float(a.time)), 0, 1)
			return {"position": a.position.lerp(b.position, weight), "yaw": lerp_angle(float(a.yaw), float(b.yaw), weight)}
	return samples.back()
