extends RefCounted
## Official 4.5.2 API: get_collider_shape is Object; *_index is int.
static func capture(body: CharacterBody3D) -> Array:
	var records: Array = []
	for slide_index in body.get_slide_collision_count():
		var hit := body.get_slide_collision(slide_index)
		for contact_index in hit.get_collision_count():
			var object: Object = hit.get_collider_shape(contact_index)
			records.append({"slideIndex":slide_index,"contactIndex":contact_index,
				"colliderRid":hit.get_collider_rid(contact_index),"colliderShapeIndex":hit.get_collider_shape_index(contact_index),
				"shapeObjectDescription":object.get_class() if is_instance_valid(object) else "null",
				"collider":str(hit.get_collider(contact_index).name),"point":hit.get_position(contact_index),
				"normal":hit.get_normal(contact_index),"travel":hit.get_travel(),"remainder":hit.get_remainder()})
	return records
