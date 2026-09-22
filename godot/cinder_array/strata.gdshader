shader_type spatial;
render_mode cull_disabled;

uniform sampler2D rock_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 basalt : source_color = vec4(0.16, 0.18, 0.22, 1.0);
uniform vec4 iron : source_color = vec4(0.27, 0.18, 0.155, 1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_position;
	vec3 weights = pow(abs(world_normal), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 texel = texture(rock_map, p.zy * 0.16).rgb * weights.x;
	texel += texture(rock_map, p.xz * 0.16).rgb * weights.y;
	texel += texture(rock_map, p.xy * 0.16).rgb * weights.z;
	float grey = dot(texel, vec3(0.2126, 0.7152, 0.0722));
	float band_height = p.y + sin(p.x * 0.052) * 2.6 + sin(p.z * 0.077) * 1.8;
	float layers = sin(band_height * 1.65) * 0.055 + sin(band_height * 5.9) * 0.025;
	float iron_band = smoothstep(0.82, 0.96, sin(band_height * 0.38));
	vec3 base = mix(basalt.rgb, iron.rgb, iron_band * 0.58);
	ALBEDO = base * (0.76 + grey * 1.2 + layers);
	ROUGHNESS = 0.94;
	SPECULAR = 0.16;
}
