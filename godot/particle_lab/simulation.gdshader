shader_type particles;
render_mode disable_force, disable_velocity;

#include "res://particle_lab/trajectories.gdshaderinc"

void start() {
	CUSTOM = seed_for(INDEX);
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = field_target(CUSTOM, field_clock);
	VELOCITY = vec3(0.0);
	COLOR = vec4(field_color(CUSTOM), 1.0);
	ACTIVE = true;
}

void process() {
	// Stateful GPU spring/advection. TRANSFORM and VELOCITY persist in the
	// transform-feedback buffers on Compatibility (compute on RD renderers).
	// Exact critically-damped step remains finite at genuinely slow frame rates.
	vec3 target = field_target(CUSTOM, field_clock);
	float omega = 5.0 + CUSTOM.w * 3.0;
	vec3 displacement = TRANSFORM[3].xyz - target;
	vec3 c = VELOCITY + omega * displacement;
	float decay = exp(-omega * DELTA);
	TRANSFORM[3].xyz = target + (displacement + c * DELTA) * decay;
	VELOCITY = (VELOCITY - omega * c * DELTA) * decay;
	ACTIVE = true;
}
