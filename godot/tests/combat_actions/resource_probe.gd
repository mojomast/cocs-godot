extends RefCounted
## Fixture-only read-only ownership probe. Retains weak references and scalar
## receipts, never texture/material owners. No RID freeing or cache flushing.
const LIMIT := 2048
var textures: Dictionary = {}

func snapshot(label: String, roots: Dictionary) -> void:
	var seen := {}
	var work: Array = []
	for key: String in roots: work.append([roots[key], key])
	while not work.is_empty() and seen.size() < LIMIT:
		var item: Array = work.pop_back()
		var value: Variant = item[0]
		var owner: String = item[1]
		if not value is Object or not is_instance_valid(value): continue
		var id: int = value.get_instance_id()
		if seen.has(id): continue
		seen[id] = true
		if value is Sky:
			print("CONTROLS_SKY_OWNER ",JSON.stringify({"stage":label,"owner":owner,"path":value.resource_path,"id":id,"rid":value.get_rid().get_id(),"size":value.radiance_size}))
		if value is Texture2D:
			if not textures.has(id): textures[id] = {"ref":weakref(value),"first":label,"owner":owner}
			continue
		if value is Node:
			for child: Node in value.get_children(): work.append([child,owner + "/" + str(child.name)])
		if value is Script:
			for key: String in value.get_script_constant_map():
				append_value(work,value.get_script_constant_map()[key],owner + "::" + key)
			var base: Script = value.get_base_script()
			if base != null: work.append([base,owner + "::base"])
		else:
			var script: Variant = value.get_script()
			if script is Script: work.append([script,owner + "::script"])
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE):
				append_value(work,value.get(property.name),owner + "." + str(property.name))
	var rows: Array = []
	for id: int in textures:
		var entry: Dictionary = textures[id]
		var texture: Texture2D = entry.ref.get_ref()
		var row := {"object_id":id,"first":entry.first,"owner":entry.owner,"alive":texture != null}
		if texture != null:
			var rid := texture.get_rid()
			row.merge({"class":texture.get_class(),"path":texture.resource_path,
				"width":texture.get_width(),"height":texture.get_height(),"rid":rid.get_id(),
				"native_handle":RenderingServer.texture_get_native_handle(rid) if rid.is_valid() else 0})
		rows.append(row)
	print("CONTROLS_RESOURCE_PROBE ",JSON.stringify({"stage":label,"visited":seen.size(),
		"truncated":not work.is_empty(),"textures":rows,
		"objects":Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}))

func append_value(work: Array, value: Variant, owner: String) -> void:
	if value is Object: work.append([value,owner])
	elif value is Array:
		for i in mini(value.size(), LIMIT):
			if value[i] is Object: work.append([value[i],owner + "[" + str(i) + "]"])
	elif value is Dictionary:
		for key: Variant in value:
			if value[key] is Object: work.append([value[key],owner + "[" + str(key) + "]"])
