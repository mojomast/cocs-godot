extends RefCounted
## Offline capture replay preserves the recorded request/response admission.
## Redacted credentials are deliberately absent, not invented valid tokens.

static func request(client: Node, frame: Dictionary) -> void:
	if frame.get("type") not in ["create", "join"]: return
	client.career_welcome_pending = true
	client.joined_room_request = str(frame.get("roomId", "")) if frame.type == "join" else ""
	client.spectator_notice_stage = 1 if frame.type == "join" else 0

static func response(capture: Dictionary, frame: Dictionary) -> Dictionary:
	var projected := frame.duplicate(true)
	if frame.get("type") == "welcome":
		for field: String in ["token", "progressToken"]:
			if "welcome." + field in capture.get("redacted_fields", []) and projected.get(field) == null:
				projected.erase(field)
	return projected
