shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;

void vertex() {
	// Full camera-facing billboard. Preserve authored world scale at all angles.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
	vec4 texel = texture(frame_texture, UV);
	// Five-tap highlight dilation keeps the very sparse 48px source impulses
	// legible when minified. This is bounded shader work, not a glow pass.
	vec2 pixel = 1.0 / vec2(textureSize(frame_texture, 0));
	vec3 highlight = texel.rgb;
	highlight = max(highlight, texture(frame_texture, UV + vec2(pixel.x, 0.0)).rgb);
	highlight = max(highlight, texture(frame_texture, UV - vec2(pixel.x, 0.0)).rgb);
	highlight = max(highlight, texture(frame_texture, UV + vec2(0.0, pixel.y)).rgb);
	highlight = max(highlight, texture(frame_texture, UV - vec2(0.0, pixel.y)).rgb);
	// Baked Moth frames have opaque dark backgrounds (source used additive).
	// Preserve exact injected RGBA; derive presentation coverage in the shader.
	vec3 background = texture(frame_texture, vec2(0.0)).rgb;
	vec3 signal_color = max(highlight - background, vec3(0.0));
	float contrast = max(max(signal_color.r, signal_color.g), signal_color.b);
	float coverage = smoothstep(0.0005, 0.015, contrast);
	float edge = 1.0 - smoothstep(0.76, 1.0, length(UV * 2.0 - 1.0));
	// Exposure of source signal, preserving its color ratios and exact resource.
	ALBEDO = vec3(1.0) - exp(-signal_color * 10.0);
	ALPHA = texel.a * coverage * edge * opacity;
}
