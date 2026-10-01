extends "res://horde_maps/blackwater_demo.gd"
## Test-only desktop-focus seam. Keep the production client, controls.sample,
## HordeClient.send_controls and authority FIFO intact in a headless viewport.
## No synthetic socket, Match mutation, skipped epoch or changed input TTL.

func can_capture_pointer() -> bool:
	if not OS.has_environment("BLACKWATER_HEADLESS_FIXTURE"): return super.can_capture_pointer()
	return not client.spectating and application_focused and phase == 3 and received_pose \
		and not snapshot_watch.stale() and presentation.lifecycle.can_control() \
		and not HordeSettingsAccess.overlay_open() and not social_capturing() \
		and not vehicle_bridge.mounted()

func weapon_controls_active() -> bool:
	if OS.has_environment("BLACKWATER_HEADLESS_FIXTURE"): return can_capture_pointer()
	return super.weapon_controls_active()

func _input(event: InputEvent) -> void:
	super._input(event)
	if OS.has_environment("BLACKWATER_HEADLESS_FIXTURE") and event is InputEventMouseMotion:
		update_look(event.relative)
