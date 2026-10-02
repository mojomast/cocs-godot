extends "res://multiplayer_worlds/sports_demo.gd"
## Test-only lobby barrier. Production sports auto-starts; hold its ordinary
## start path until two real native player seats have reached the source roster.
func on_lobby(frame: Dictionary) -> void:
	if join_room_id.is_empty() and configured and not start_sent:
		var humans := 0
		for player: Dictionary in frame.get("players", []):
			if player.get("connected") == true and player.get("spectate") != true: humans += 1
		if humans < 2: return
	super.on_lobby(frame)
