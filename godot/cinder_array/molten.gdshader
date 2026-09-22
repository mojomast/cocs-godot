shader_type spatial;
render_mode unshaded, cull_disabled;

// Opaque, moving crust islands. No screen sampling, glow, or transparent lake pass.
uniform sampler2D flow_map : filter_linear, repeat_enable;
uniform sampler2D dust_map : filter_linear, repeat_enable;
uniform vec4 crust : source_color = vec4(0.105, 0.063, 0.074, 1.0);
uniform vec4 ember : source_color = vec4(0.91, 0.19, 0.035, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.76, 0.31, 1.0);
uniform float flow_speed = 0.055;
uniform float plate_scale = 0.38;
varying vec3 world_position;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (world_position.xz + vec2(0.0, -world_position.y * 0.65)) * plate_scale;
	vec2 drift = vec2(0.38, -1.0) * TIME * flow_speed;
	vec2 curl = texture(flow_map, p * 0.046 + drift * 0.055).rg - vec2(0.5);
	p += drift + curl * 1.25;
	p += vec2(sin(p.y * 1.35 + p.x * 0.7), sin(p.x * 1.5 - p.y * 0.4)) * 0.32;
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = hash2(cell + offset);
			vec2 r = offset + 0.06 + seed * 0.88 - local;
			float d = dot(r, r);
			second = min(second, max(nearest, d));
			nearest = min(nearest, d);
		}
	}
	float dust = texture(dust_map, p * 0.21 - drift * 0.12).r;
	float edge = second - nearest;
	float cracks = 1.0 - smoothstep(0.03, 0.13 + dust * 0.12, edge);
	float pools = smoothstep(0.53, 0.74, dust);
	cracks = max(cracks, pools);
	float core = 1.0 - smoothstep(0.015, 0.065, edge);
	float pulse = 0.78 + 0.22 * sin(world_position.x * 0.12 + world_position.z * 0.16 + TIME * 0.32);
	vec3 rock = crust.rgb * (0.55 + dust * 0.8);
	vec3 liquid = mix(ember.rgb, hot.rgb, max(core, pools * 0.55) * pulse);
	ALBEDO = mix(rock, liquid, cracks * (0.85 + dust * 0.15));
}
