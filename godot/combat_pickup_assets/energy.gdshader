shader_type spatial;
render_mode depth_draw_opaque, cull_back;
#include "res://shader_lab/moth_common.gdshaderinc"

uniform bool hologram = false;

void fragment() {
	vec3 n = normalize(object_normal);
	vec3 p = object_position * 3.0;
	vec3 flow = tri_field(p + vec3(0.0, -effect_time * 0.13, 0.0), n);
	float scan = band(sin((object_position.y * 10.0 - effect_time * 0.5 + flow.r * 0.12) * 6.283185), 0.22);
	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.0);
	float lut = moth_lut(fresnel);
	if (hologram) {
		// Thin interrupted geometry, never a transparent floor plane or depth bypass.
		float angle = atan(object_position.z, object_position.x);
		if (sin(angle * 6.0 + effect_time * 0.45) < -0.55) discard;
	}
	ALBEDO = mix(moth_body(p, n), accent.rgb, 0.62);
	METALLIC = 0.25;
	ROUGHNESS = 0.4;
	EMISSION = accent.rgb * (0.2 + scan * 0.5 + lut * 0.16 + (hologram ? 0.5 : 0.0));
}
