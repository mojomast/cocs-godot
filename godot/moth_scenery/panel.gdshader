shader_type spatial;
render_mode cull_back;

// An opaque plate mounted 32 mm off an existing solid, not a floating HUD.
uniform sampler2D baked_tile : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D circuit_tile : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D housing_tile : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tile : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lut_r : filter_linear, repeat_enable;
uniform sampler2D lut_t : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5, 0.6, 0.6, 1.0);
uniform vec4 light_tint : source_color = vec4(0.7, 0.7, 0.6, 1.0);
uniform bool has_normal = false;
uniform bool has_lut = false;
uniform float lut_strength = 0.10;
uniform float emission_strength = 0.24;
uniform float animation_strength = 1.0;
uniform float clock_override = -1.0;
uniform int style = 0; // 0 service display, 1 circuit, 2 ventilation, 3 light strip, 4 relic inlay
varying float phase;
varying float vertical;

void vertex() {
	phase = INSTANCE_CUSTOM.r;
	vertical = INSTANCE_CUSTOM.g;
}

void fragment() {
	float clock = clock_override >= 0.0 ? clock_override : TIME;
	vec2 edge = min(UV, 1.0 - UV);
	float interior = smoothstep(0.035, 0.055, min(edge.x, edge.y));
	vec3 tile = texture(baked_tile, UV * (style == 2 ? vec2(2.0, 1.0) : vec2(1.0))).rgb;
	float value = dot(tile, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted = mix(vec3(value), tile, style == 4 ? 0.16 : 0.08);
	float housing = dot(texture(housing_tile, UV * vec2(2.0, 1.0)).rgb, vec3(0.3333));
	vec3 body = tint.rgb * (0.19 + housing * 0.24);
	vec3 display = tint.rgb * (0.16 + muted * (style == 2 ? 0.55 : 0.70));
	float luminous = 0.0;
	if (style == 0 || style == 1) {
		// Baked circuitry remains legible; fine printed rails make its scale clear.
		// Blue-channel contrast in the original green/cyan circuit pixels retains
		// their etched paths; luminance alone flattens this unusual baked palette.
		vec3 circuit = texture(circuit_tile, UV).rgb;
		float trace = smoothstep(0.055, 0.24, circuit.b);
		float rail = 1.0 - smoothstep(0.009, 0.020, abs(UV.y - 0.19));
		float rail_breaks = step(0.18, fract(UV.x * 9.0));
		float scan = pow(0.5 + 0.5 * sin(UV.y * 8.0 - clock * 0.65 + phase * 6.283), 8.0);
		luminous = (trace * 0.85 + rail * rail_breaks * 0.18) * (1.0 + scan * 0.09 * animation_strength);
	} else if (style == 3) {
		float across = mix(UV.y, UV.x, vertical);
		float along = mix(UV.x, UV.y, vertical);
		float strip = 1.0 - smoothstep(0.15, 0.25, abs(across - 0.5));
		float divisions = smoothstep(0.02, 0.07, min(fract(along * 12.0), 1.0 - fract(along * 12.0)));
		display = body;
		luminous = strip * (0.72 + 0.14 * value) * (0.45 + 0.55 * divisions);
	} else if (style == 4) {
		luminous = value * 0.18;
	}
	ALBEDO = mix(body, display, interior);
	EMISSION = light_tint.rgb * luminous * interior * emission_strength;
	if (has_lut && style != 2) {
		// These ORIGINAL RGB planes are LINEAR sparse masks, not sRGB colors.
		// Narrow anodized edge only; no shield sheen over the entire world surface.
		float facing = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
		float foil = smoothstep(0.04, 0.06, edge.y) * (1.0 - smoothstep(0.09, 0.12, edge.y));
		vec3 r = texture(lut_r, vec2(mix(UV.x, facing, 0.18), 0.80)).rgb;
		vec3 t = texture(lut_t, vec2(mix(UV.x, facing, 0.18), 0.30)).rgb;
		EMISSION += (r + t) * 0.5 * light_tint.rgb * foil * lut_strength;
	}
	if (has_normal) {
		NORMAL_MAP = texture(normal_tile, UV).rgb;
		NORMAL_MAP_DEPTH = 0.16 * interior;
	}
	ROUGHNESS = style == 2 ? 0.78 : 0.56;
	METALLIC = 0.22;
	SPECULAR = 0.28;
}
