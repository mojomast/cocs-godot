extends "res://tests/combined_arms/observe_crew_shared.gd"
## Third independent native source seat. Entry waits for driver's gunner.
func _initialize() -> void:
	role = "passenger"
	super._initialize()
