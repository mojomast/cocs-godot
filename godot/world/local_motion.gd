class_name PortLocalMotion
extends RefCounted

# Camera-only visual translation. Authoritative eye positions and gameplay inputs
# remain owned by the caller; this helper only returns a rendered position.
const EXTRAPOLATION_LIMIT: float = 0.05
const CORRECTION_SECONDS: float = 0.075
const TELEPORT_DISTANCE: float = 3.0
const MAX_VELOCITY: float = 40.0
const MAX_VELOCITY_INTERVAL: float = 0.2

var _has_snapshot: bool = false
var _eye: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _correction: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _source_time: float = NAN
var _alive: bool = false

func reset() -> void:
	_has_snapshot = false
	_eye = Vector3.ZERO
	_velocity = Vector3.ZERO
	_correction = Vector3.ZERO
	_time = 0.0
	_source_time = NAN
	_alive = false

func ready() -> bool:
	return _has_snapshot

func ingest(eye: Vector3, alive: bool, now: float, source_time: float = NAN) -> void:
	if not eye.is_finite() or not is_finite(now):
		return
	if _has_snapshot and now <= _time:
		return
	if not _has_snapshot or alive != _alive or eye.distance_to(_eye) > TELEPORT_DISTANCE:
		_anchor(eye, alive, now, source_time)
		return
	# Arrival time measures render latency, not the simulation interval. Several
	# source ticks can be drained in one render frame after a short stall; dividing
	# their position deltas by microseconds of receive time produces an artificial
	# 40 m/s camera surge and then a visible correction. Horde supplies the source
	# clock; other sessions retain their existing receive-clock policy.
	var interval: float = now - _time
	if is_finite(source_time) and is_finite(_source_time):
		# Duplicate/non-advancing source times must not fall back to a tiny
		# receive interval and manufacture visual speed from a delayed packet.
		interval = source_time - _source_time
	var previous_visual: Vector3 = sample(now)
	var velocity: Vector3 = Vector3.ZERO
	if alive and interval >= 0.0001 and interval <= MAX_VELOCITY_INTERVAL:
		velocity = (eye - _eye) / interval
		velocity = velocity.limit_length(MAX_VELOCITY)
	_eye = eye
	_time = now
	_source_time = source_time
	_velocity = velocity
	# The newly received pose starts exactly where the prior visual path ended.
	# This offset decays as the camera catches up to the authoritative eye.
	_correction = previous_visual - eye if alive else Vector3.ZERO

func sample(now: float) -> Vector3:
	if not _has_snapshot:
		return Vector3.ZERO
	if not is_finite(now):
		return _eye
	if not _alive:
		return _eye
	var elapsed: float = maxf(now - _time, 0.0)
	return _eye + _velocity * minf(elapsed, EXTRAPOLATION_LIMIT) + _correction * exp(-elapsed / CORRECTION_SECONDS)

func _anchor(eye: Vector3, alive: bool, now: float, source_time: float) -> void:
	_has_snapshot = true
	_eye = eye
	_alive = alive
	_time = now
	_source_time = source_time
	_velocity = Vector3.ZERO
	_correction = Vector3.ZERO
