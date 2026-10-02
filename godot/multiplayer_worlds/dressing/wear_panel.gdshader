shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Local face-mounted translucent wear. Depth testing remains enabled.
uniform sampler2D baked_tile : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tile : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.22;
uniform float feather : hint_range(0.0, 0.5) = 0.15;
uniform vec2 mask_offset = vec2(0.0);
void fragment() {
	vec3 tile = texture(baked_tile, UV).rgb;
	vec3 mask = texture(wear_mask, UV + mask_offset).rgb;
	vec2 edge = min(UV, 1.0 - UV);
	float edge_alpha = smoothstep(0.0, max(feather, 0.0001), min(edge.x, edge.y));
	ALBEDO = tint.rgb * clamp(tile * 2.0, vec3(0.0), vec3(1.25));
	NORMAL_MAP = texture(normal_tile, UV).rgb;
	NORMAL_MAP_DEPTH = 0.12;
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	ALPHA = dot(mask, vec3(0.2126, 0.7152, 0.0722)) * edge_alpha * opacity;
}
