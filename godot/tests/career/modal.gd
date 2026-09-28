extends SceneTree
const Menu = preload("res://ui/main_menu.gd")
const SettingsAccess = preload("res://ui/settings_access.gd")
var failed := false

class ControlsProbe extends RefCounted:
	var releases := 0
	func release() -> void: releases += 1

class MotionProbe extends RefCounted:
	var resets := 0
	func reset() -> void: resets += 1

class LiveScene extends Control:
	var controls := ControlsProbe.new()
	var local_motion := MotionProbe.new()
	var pointer_releases := 0
	func release_pointer() -> void: pointer_releases += 1

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("career modal: " + label)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var career := root.get_node("Career")
	var settings := root.get_node("LocalSettings")
	var menu := Menu.new()
	menu.preferences_path = "user://career_modal_fixture.json"
	root.add_child(menu)
	current_scene = menu
	var home_button := menu.career_button as Button
	check(not home_button.disabled and home_button.text.contains("CAREER"), "Home discoverability")
	home_button.pressed.emit()
	check(career.active() and not settings.overlay_open(), "Home opens single Career modal")
	career._input(key(KEY_F9))
	check(career.active(), "combat F9 is never intercepted")
	career._input(key(KEY_ESCAPE))
	check(not career.active() and not menu.quitting, "Esc closes Career without MENU_QUIT")
	settings.open_panel(true, menu.settings_button)
	check(settings.overlay_open() and not career.active(), "Home Settings visible")
	settings.career_button.pressed.emit()
	check(career.active() and not settings.overlay_open(), "Settings to Career has one modal")
	career.close_panel()
	check(settings.overlay_open() and not career.active() and not settings.rows.leave.visible, "Back restores Home Settings, no Leave match")
	settings.close_panel()
	check(menu.settings_button.has_focus(), "Home focus restored")
	current_scene = null
	menu.queue_free()
	var live := LiveScene.new()
	root.add_child(live)
	current_scene = live
	settings.open_panel(false)
	check(live.controls.releases > 0 and live.local_motion.resets > 0, "F12 neutralizes held actions and motion")
	settings.career_button.pressed.emit()
	check(career.active() and SettingsAccess.overlay_open(), "Career blocks sports/combined input through shared gate")
	check(live.controls.releases >= 2 and live.local_motion.resets >= 2, "Career transition neutralizes controls again")
	career._input(key(KEY_ESCAPE))
	check(settings.overlay_open() and not career.active(), "Esc restores live Settings")
	settings.rows.back.pressed.emit()
	check(not SettingsAccess.overlay_open() and live.pointer_releases >= 2, "SettingsBack exits modal with fresh pointer state")
	print("CAREER_MODAL_OK" if not failed else "CAREER_MODAL_FAILED")
	quit(1 if failed else 0)
