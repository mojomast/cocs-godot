extends RefCounted
## Explicit opt-in presentation adapter for existing source-default help strings.
## No scene scanning, per-frame overrides, or gameplay/operator body ownership.
const Access = preload("res://input_bindings/access.gd")
const Model = preload("res://input_bindings/model.gd")
const TOKENS := {"Q":"power","X":"mobility","G":"grenade","F":"melee","E":"interact","R":"reload","Z":"altFire","SPACE":"jump","Space":"jump","SHIFT":"sprint","Shift":"sprint","CTRL":"crouch","Ctrl":"crouch","LMB":"fire","RMB":"ads"}

static func resolve(text: String) -> String:
	var bindings := Access.values()
	var regex := RegEx.new()
	regex.compile("\\b(WASD|W/S|A/D|Q|X|G|F|E|R|Z|SPACE|Space|SHIFT|Shift|CTRL|Ctrl|LMB|RMB)\\b")
	var matches := regex.search_all(text)
	# Replace backwards: replacement labels must not themselves get remapped.
	for index in range(matches.size() - 1, -1, -1):
		var hit: RegExMatch = matches[index]
		var token := hit.get_string()
		var replacement := token
		if token == "WASD":
			if bindings.forward != "KeyW" or bindings.left != "KeyA" or bindings.back != "KeyS" or bindings.right != "KeyD":
				replacement = "/".join([Access.label("forward"), Access.label("left"), Access.label("back"), Access.label("right")])
		elif token in ["W/S", "A/D"]:
			var actions: Array = ["forward", "back"] if token == "W/S" else ["left", "right"]
			replacement = Access.label(actions[0]) + "/" + Access.label(actions[1])
		elif bindings[TOKENS[token]] != Model.DEFAULTS[TOKENS[token]]:
			replacement = Access.label(TOKENS[token])
		text = text.substr(0, hit.get_start()) + replacement + text.substr(hit.get_end())
	return text

static func refresh_label(label: Label) -> void:
	if not is_instance_valid(label): return
	# Some route cards reuse one label for results/story later. A different owner
	# replacing its text ends our ownership until bind() explicitly opts in again.
	if label.text != str(label.get_meta("binding_hint_rendered", label.text)): return
	label.text = resolve(str(label.get_meta("binding_hint", "")))
	label.set_meta("binding_hint_rendered", label.text)

static func bind(label: Label, template: String) -> void:
	label.set_meta("binding_hint", template)
	label.set_meta("binding_hint_rendered", label.text)
	refresh_label(label)
	var service := Access.service()
	if service == null: return
	var callback := refresh_label.bind(label)
	if service.changed.is_connected(callback): return
	service.changed.connect(callback)
	label.tree_exiting.connect(func() -> void:
		if is_instance_valid(service) and service.changed.is_connected(callback): service.changed.disconnect(callback), CONNECT_ONE_SHOT)
