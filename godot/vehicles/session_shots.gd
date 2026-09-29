extends Node3D
## One reusable visual owner for source-mounted shots in ordinary world sessions.
## The source event supplies its own muzzle and impact; no local raycast/input FX.
const ShotFX = preload("res://vehicles/shot_fx.gd")
var shot_fx := ShotFX.new()
var bound_client: Node
var allowed: Callable
var active := false

func _init() -> void:
	add_child(shot_fx)

func bind(client: Node, can_show: Callable) -> void:
	allowed = can_show
	if bound_client == client: return
	if is_instance_valid(bound_client) and bound_client.events.is_connected(_on_events):
		bound_client.events.disconnect(_on_events)
	bound_client = client
	if is_instance_valid(bound_client) and not bound_client.events.is_connected(_on_events):
		bound_client.events.connect(_on_events)

func _on_events(items: Array) -> void:
	if active and allowed.is_valid() and allowed.call(): shot_fx.apply_events(items)
	else: set_active(false)

func _process(_delta: float) -> void:
	if active and (not allowed.is_valid() or not allowed.call()): set_active(false)

func set_active(value: bool) -> void:
	if active and not value: shot_fx.clear_round()
	active = value

func clear_round() -> void:
	set_active(false)
	shot_fx.clear_round()

func _exit_tree() -> void:
	if is_instance_valid(bound_client) and bound_client.events.is_connected(_on_events):
		bound_client.events.disconnect(_on_events)
	bound_client = null
