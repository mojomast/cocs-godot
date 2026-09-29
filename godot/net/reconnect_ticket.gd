extends RefCounted
## Ephemeral source room token. Never persist, print, or expose through UI.
const WINDOW_MS := 18000 # Source defaults to 20 seconds of disconnected grace.
var token := ""
var endpoint := ""
var map_id := ""
var room_id := ""
var actor_id := -1
var spectator := false
var host := false
var expires_at := 0

func clear() -> void:
	token = ""
	endpoint = ""
	map_id = ""
	room_id = ""
	actor_id = -1
	spectator = false
	host = false
	expires_at = 0

func remember(value: String, url: String, map: String, room: String, actor: int, readonly: bool, hosted: bool) -> void:
	clear()
	if value.is_empty() or url.is_empty() or room.is_empty(): return
	token = value
	endpoint = url
	map_id = map
	room_id = room
	actor_id = actor
	spectator = readonly
	host = hosted

func dropped() -> bool:
	if token.is_empty(): return false
	expires_at = Time.get_ticks_msec() + WINDOW_MS
	return true

func available(url: String, map: String, room: String) -> bool:
	return not token.is_empty() and expires_at > Time.get_ticks_msec() and endpoint == url and map_id == map and room_id == room
