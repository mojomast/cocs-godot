shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 ground : source_color;
uniform vec4 horizon : source_color;
uniform float fade_begin = 100.0;
uniform float fade_end = 450.0;
// Bounded ground grain from the material language's derived data bucket
// (R = AO, G = roughness, B = detail). One sampler, one texture, faded out
// before the sky blend so the far plane stays clean.
uniform sampler2D grain_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_grain = false;
uniform float grain_scale = 0.35;
uniform float grain_strength = 0.16;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Match the sky at the finite plane's distant edge without fogging the arena.
	float distance_to_camera = length(world_position.xz - CAMERA_POSITION_WORLD.xz);
	float fade = smoothstep(fade_begin, fade_end, distance_to_camera);
	vec3 base = mix(ground.rgb, horizon.rgb, fade);
	if (has_grain) {
		vec3 data = texture(grain_map, world_position.xz * grain_scale).rgb;
		// Creases darken, ridges brighten by at most grain_strength.
		float grain = clamp((data.b - 0.5) * 1.6 + (data.r - 0.5) * 0.9, -1.0, 1.0);
		base *= 1.0 + grain * grain_strength * (1.0 - fade);
	}
	ALBEDO = base;
}
