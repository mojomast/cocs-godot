shader_type particles;
render_mode disable_force, disable_velocity;

uniform sampler2D occupancy : filter_nearest, repeat_disable;
uniform vec3 bounds_min;
uniform vec3 bounds_size;
uniform vec3 source_position;
uniform vec3 previous_position;
uniform vec3 source_direction = vec3(0.0, 0.0, -1.0);
uniform vec3 field_extent = vec3(8.0, 5.0, 8.0);
uniform vec4 tint = vec4(1.0, 0.5, 0.12, 1.0);
uniform int profile = 0; // 0 blast debris/dust/shock, 1 rocket, 2 plasma, 3 cinder, 4 ice, 5 reactor
uniform float event_seed = 1.0;
uniform float emitter_age = 0.0;
uniform bool source_alive = true;
uniform float density_gain = 1.0;

float hash(float x) { return fract(sin(x * 127.1 + event_seed * 19.19) * 43758.5453); }
bool blocked(vec3 p) {
	vec3 q = (p - bounds_min) / bounds_size;
	if (any(lessThan(q, vec3(0.0))) || any(greaterThanEqual(q, vec3(1.0)))) { return true; }
	vec3 v = floor(q * vec3(96.0, 48.0, 96.0));
	vec2 uv = (vec2(mod(v.z, 12.0) * 96.0 + v.x, floor(v.z / 12.0) * 48.0 + v.y) + 0.5) / vec2(1152.0, 384.0);
	return texture(occupancy, uv).r > 0.5;
}
void spawn_particle(float index, float cycle, inout mat4 trans, inout vec3 velocity, inout vec4 custom, inout vec4 color) {
	float n = index + cycle * 1709.0;
	vec3 r = vec3(hash(n + 1.0), hash(n + 2.0), hash(n + 3.0));
	vec3 dir = normalize(r * 2.0 - 1.0 + vec3(0.001));
	custom = vec4(0.0, 0.7 + hash(n + 4.0) * 2.2, hash(n + 5.0), cycle);
	trans = mat4(1.0);
	vec3 p = source_position;
	if (profile == 0) {
		// Separate ground shock flecks, ballistic fragments, and slow impact dust.
		if (custom.z < 0.25) { dir.y *= 0.1; }
		p += dir * (0.15 + r.x * 0.8);
		velocity = dir * (3.0 + r.y * 13.0);
		velocity.y += 3.0;
		if (custom.z > 0.72) { velocity *= 0.25; }
	} else if (profile < 3) {
		p = mix(previous_position, source_position, r.y) + dir * 0.18;
		velocity = -source_direction * (2.0 + r.x * 3.0) + dir * 0.9;
		custom.y = 0.4 + r.z * 1.1;
	} else {
		p += (r * 2.0 - 1.0) * field_extent;
		velocity = vec3(0.45, -0.9, 0.15);
		if (profile != 4) { velocity.y = 0.4 + r.x; }
		custom.y = 3.0 + r.z * 5.0;
	}
	trans[3].xyz = p;
	color = tint;
	if (profile == 0 && custom.z > 0.72) { color.rgb = mix(tint.rgb, vec3(0.22, 0.20, 0.18), 0.8); }
	// Keep the allocated slot active, but suppress solid-born particles. No
	// teleport across a wall to 'find' air. Continuous fields recycle in place.
	if (blocked(p) || (profile < 3 && blocked(source_position))) {
		// A source embedded in a conservative solid voxel cannot prove which
		// side is air. Keep the slot hidden for this life instead of leaking
		// an offset spawn through the opposite side of a thin wall.
		color.a = 0.0;
		velocity = vec3(0.0);
		custom.y = -custom.y;
	}
}
void start() {
	spawn_particle(float(INDEX), 0.0, TRANSFORM, VELOCITY, CUSTOM, COLOR);
	if (profile > 0) { CUSTOM.x = abs(CUSTOM.y) * hash(float(INDEX) + 71.0); }
	ACTIVE = true;
}
void process() {
	// No shader TIME: pausing speed_scale truly freezes both transport and age.
	float dt = min(DELTA, 0.05);
	CUSTOM.x += dt;
	if (CUSTOM.x >= abs(CUSTOM.y)) {
		if (profile > 0 && source_alive) { spawn_particle(float(INDEX), CUSTOM.w + 1.0, TRANSFORM, VELOCITY, CUSTOM, COLOR); }
		else { COLOR.a = 0.0; }
	}
	if (profile == 0) { VELOCITY.y -= (CUSTOM.z > 0.72 ? -0.5 : 9.0) * dt; }
	if (profile >= 3) { VELOCITY.x += sin(CUSTOM.x + CUSTOM.z * 6.28) * dt * 0.4; }
	VELOCITY *= exp(-dt * (profile == 0 ? 0.4 : 0.8));
	vec3 p = TRANSFORM[3].xyz;
	vec3 displacement = VELOCITY * dt;
	float cell_min = min(bounds_size.x / 96.0, min(bounds_size.y / 48.0, bounds_size.z / 96.0));
	displacement *= min(1.0, cell_min * 0.4 / max(length(displacement), 0.001));
	// Axis swept steps are shorter than a voxel: no tunneling at slow render rates.
	for (int axis = 0; axis < 3; axis++) {
		vec3 q = p;
		q[axis] += displacement[axis];
		if (blocked(q)) { VELOCITY[axis] *= -0.28; }
		else { p = q; }
	}
	TRANSFORM[3].xyz = p;
	float fade = max(0.0, 1.0 - CUSTOM.x / abs(CUSTOM.y));
	COLOR.a = (blocked(p) || CUSTOM.y < 0.0 ? 0.0 : fade * fade) * density_gain;
	ACTIVE = true;
}
