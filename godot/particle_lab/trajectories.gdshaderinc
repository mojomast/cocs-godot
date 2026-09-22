// Shared, deterministic field targets. No CPU particle position uploads.
uniform int field_preset = 0;
uniform float field_clock = 0.0;
uniform sampler2D flow_field : filter_linear, repeat_enable;
uniform sampler2D material_lut : source_color, filter_linear, repeat_disable;

uint hash_id(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	return (x >> uint(16)) ^ x;
}

vec4 seed_for(uint id) {
	return vec4(float(hash_id(id + uint(11)) & uint(16777215)),
		float(hash_id(id + uint(173)) & uint(16777215)),
		float(hash_id(id + uint(977)) & uint(16777215)),
		float(hash_id(id + uint(7919)) & uint(16777215))) / 16777216.0;
}

vec3 field_target(vec4 s, float t) {
	float tau = 6.28318530718;
	vec3 p;
	if (field_preset == 0) {
		// A rising funnel, with nested, differentially rotating filaments.
		float h = fract(s.z + t * (0.035 + s.w * 0.015));
		float r = 2.0 + h * h * 23.0 + s.y * (2.0 + h * 6.0);
		float a = s.x * tau + h * 11.0 + t * (0.9 + 0.6 * s.y);
		p = vec3(cos(a) * r, h * 40.0 - 20.0, sin(a) * r);
	} else if (field_preset == 1) {
		// Five spiral arms, a warm bulge and a sparse inclined halo.
		float r = 1.2 + pow(s.y, 0.65) * 38.0;
		float a = floor(s.x * 5.0) * tau / 5.0 + r * 0.145;
		a += (fract(s.x * 5.0) - 0.5) * 0.65 + t * (0.12 + 0.2 / (1.0 + r * 0.1));
		float y = (s.z - 0.5) * (1.4 + 13.0 * pow(1.0 - s.y, 3.0));
		if (s.w > 0.93) { a = s.x * tau + t * 0.09; y += (s.z - 0.5) * r * 0.48; }
		p = vec3(cos(a) * r, y, sin(a) * r);
	} else if (field_preset == 2) {
		// Four independently phased, expanding ion shells. Every slot stays active.
		float age = fract(t * 0.115 + floor(s.w * 4.0) * 0.25);
		float r = 1.5 + pow(age, 0.72) * 36.0 + s.y * 1.3;
		float y = s.z * 2.0 - 1.0;
		float a = s.x * tau + age * 1.6;
		float ring = sqrt(max(0.0, 1.0 - y * y));
		p = vec3(cos(a) * ring, y * 0.82, sin(a) * ring) * r;
	} else {
		// Ballistic plasma crown, with a broad fountain and twisted nozzle.
		float age = fract(s.z + t * (0.12 + s.w * 0.025));
		float a = s.x * tau + age * 1.9 + t * 0.25;
		float r = 0.6 + age * (10.0 + s.y * 20.0);
		p = vec3(cos(a) * r, -20.0 + 152.0 * age * (1.0 - age), sin(a) * r);
	}
	// The original Moth flow-field affects motion, not just a label/thumbnail.
	vec2 f = textureLod(flow_field, fract(s.xy + vec2(t * 0.009, s.z)), 0.0).rg;
	p.xz += (f * 2.0 - 1.0) * (0.25 + s.w * 0.75);
	return p;
}

vec3 field_color(vec4 s) {
	vec3 cold = vec3(0.06, 0.60, 1.0);
	vec3 hot = vec3(0.85, 0.13, 0.50);
	float mix_value = s.z;
	if (field_preset == 1) { cold = vec3(0.15, 0.42, 1.0); hot = vec3(1.0, 0.52, 0.16); mix_value = pow(1.0 - s.y, 1.7); }
	if (field_preset == 2) { cold = vec3(1.0, 0.12, 0.04); hot = vec3(1.0, 0.73, 0.15); mix_value = s.w; }
	if (field_preset == 3) { cold = vec3(0.08, 1.0, 0.63); hot = vec3(0.28, 0.26, 1.0); mix_value = s.z; }
	vec3 lut = textureLod(material_lut, vec2(s.y, s.w), 0.0).rgb;
	return mix(cold, hot, mix_value) * (0.65 + lut * 0.7);
}
