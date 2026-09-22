extends RefCounted
## Presentation of existing control gates and recipient state; never authorization.

static func control_state(session: Node) -> Dictionary:
	if session.phase == -1:
		return state("stopped", "RELEASED · SESSION STOPPED", "Relaunch to reconnect.")
	if session.phase == 4:
		return state("results", "RELEASED · RESULTS", "Enter: request another round.")
	if session.phase != 3:
		return state("waiting", "RELEASED · WAITING", "Waiting for authoritative round start…")
	if not session.application_focused or (session.is_inside_tree() and not session.get_window().has_focus()):
		return state("unfocused", "RELEASED · UNFOCUSED", "Return to this window, release controls, then fresh click.")
	if not session.received_pose or session.client.projection.is_empty() or session.client.projection_actor != session.client.actor_id:
		return state("unavailable", "RELEASED · ACTOR / STATE UNAVAILABLE", "Waiting for your authoritative actor and objective state.")
	if session.snapshot_watch.stale():
		return state("stale", "RELEASED · STATE STALE", "Wait for fresh state, release controls, then fresh click.")
	if not session.presentation.lifecycle.can_control():
		return state("dead", "RELEASED · " + session.presentation.lifecycle.label(), "Wait for server respawn, release controls, then fresh click.")
	if is_instance_valid(session.world_commands) and session.world_commands.visible:
		return state("commands", "RELEASED · TACTICAL COMMANDS", "Close [C / Esc], release controls, then fresh click.")
	if session.can_capture_pointer() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return state("engaged", "ENGAGED · LIVE", "WASD move · mouse look/fire · Esc release · C commands\nShift sprint · Space jump · R reload · E interact · F mobility")
	return state("released", "RELEASED · LIVE", "Release keys and mouse buttons, then fresh click to engage/fire.\nC: tactical commands · Match continues while released.")

static func state(id: String, title: String, hint: String) -> Dictionary:
	return {"id":id, "title":title, "hint":hint}

static func bearing(actor: Dictionary, node: Dictionary, yaw: float) -> String:
	var delta := Vector2(float(node.x) - float(actor.x), float(node.z) - float(actor.z))
	if delta.length() < 1.0: return "Nearby"
	# Infantry camera looks along -Z. Use its horizontal right/forward vectors.
	var angle := atan2(delta.dot(Vector2(cos(yaw), -sin(yaw))), delta.dot(Vector2(-sin(yaw), -cos(yaw))))
	if absf(angle) < PI / 6.0: return "Ahead"
	if absf(angle) > PI * 5.0 / 6.0: return "Behind"
	return "Right" if angle > 0 else "Left"
