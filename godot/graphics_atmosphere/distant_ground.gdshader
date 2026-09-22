shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 ground : source_color;
uniform vec4 horizon : source_color;
uniform float fade_begin = 100.0;
uniform float fade_end = 450.0;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Match the sky at the finite plane's distant edge without fogging the arena.
	float distance_to_camera = length(world_position.xz - CAMERA_POSITION_WORLD.xz);
	ALBEDO = mix(ground.rgb, horizon.rgb, smoothstep(fade_begin, fade_end, distance_to_camera));
}
