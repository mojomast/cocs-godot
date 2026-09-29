extends RefCounted
## Godot 4.5 queues AudioStreamPlayer.stop() for mixer-thread deletion.
## Releasing the node alone can leave that queue alive at immediate tree exit.

static func release(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player): return
	player.stop()
	player.stream = null

static func drain() -> void:
	# Observe actual driver mix boundaries, rather than a scene timer or a fixed
	# sleep. Two boundaries cover a partially consumed server mix buffer. The
	# lock pairs with the driver so its deletion work has completed on return.
	# Bound the wait in case an output device has stopped servicing callbacks.
	var deadline := Time.get_ticks_usec() + 250000
	var previous := AudioServer.get_time_since_last_mix()
	var boundaries := 0
	while boundaries < 2 and Time.get_ticks_usec() < deadline:
		OS.delay_usec(1000)
		var current := AudioServer.get_time_since_last_mix()
		if current < previous: boundaries += 1
		previous = current
	AudioServer.lock()
	AudioServer.unlock()
