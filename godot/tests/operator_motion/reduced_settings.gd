extends "res://tests/operator_motion/melee_contracts.gd"
const Settings = preload("res://ui/settings_access.gd")

func run() -> void:
	var settings := Settings.service()
	check(settings != null,"ordinary LocalSettings singleton exists")
	if settings == null: quit(1); return
	var old: bool = settings.values.reduced_motion
	var view := Presentation.new()
	root.add_child(view)
	view.set_process(false)
	var a := actor("chatgpt")
	a.vz=-3.0
	for reduced: bool in [false,true,false]:
		settings.set_value("reduced_motion",reduced,false)
		for frame in 60:
			a.z-=0.05
			var state := {"time":float(frame)/60,"actors":[a]}
			var before := state.duplicate(true)
			view.apply_state(state,1)
			var visual: Node3D=view.actors[2]
			visual.automatic_animation=false
			visual.advance(1.0/60)
			check(state==before and not a.has("reduced"),"settings decoration leaves authority untouched")
			check(visual.snapshot.reduced==reduced,"real settings toggle reaches public operator pipeline")
		var visual: Node3D=view.actors[2]
		check(visual.locomotion.distance_phase>0.01,"reduced motion retains essential travel gait")
		check(visual.nodes.footL.global_position.is_finite(),"toggle retains finite ankle")
		if reduced:
			check(visual.rig.joints.hips.rotation.length()<0.0001,"reduced setting silences secondary hip weight shift")
	settings.set_value("reduced_motion",old,false)
	view.free()
	print("OPERATOR_REDUCED_SETTINGS ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
