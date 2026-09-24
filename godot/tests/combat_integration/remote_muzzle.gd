extends SceneTree

const Feedback = preload("res://world/combat_feedback.gd")
const OperatorVisual = preload("res://source_operators/operator_visual.gd")

class LocalSession extends Node:
	var presentation := preload("res://world/presentation.gd").new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var session := LocalSession.new()
	var camera := Camera3D.new()
	root.add_child(camera)
	var feedback := Feedback.new()
	root.add_child(feedback)
	feedback.configure_effects(camera, session)
	var visual := OperatorVisual.new()
	var weapon := Node3D.new()
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	weapon.add_child(muzzle)
	visual.add_child(weapon)
	visual.world_weapon = weapon
	visual.weapon_type = 4
	visual.visible = true
	session.presentation.actors[27] = visual
	var provider: Callable = feedback.weapon_effects.remote_muzzle_provider
	var passed: bool = provider.is_valid() and provider.call(27, 4) == muzzle
	passed = passed and provider.call(27, 3) == null
	passed = passed and provider.call(28, 4) == null
	visual.visible = false
	passed = passed and provider.call(27, 4) == null
	visual.visible = true
	visual.world_weapon = null
	passed = passed and provider.call(27, 4) == null
	feedback.free()
	visual.free()
	session.presentation.free()
	session.free()
	camera.free()
	if passed: print("COMBAT_REMOTE_MUZZLE_OK checks=5")
	else: push_error("Remote weapon effects did not use the visible matching exported barrel")
	quit(0 if passed else 1)
