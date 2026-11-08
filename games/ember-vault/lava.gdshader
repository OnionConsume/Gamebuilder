// SPDX-License-Identifier: GPL-3.0-only
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 p = UV * 85.0;
	float vein = abs(sin(p.x * 2.0 + sin(p.y * 2.0 + TIME * 0.15)) + sin(p.y * 2.2 + cos(p.x * 1.7)));
	float cracks = 1.0 - smoothstep(0.035, 0.18, vein);
	vec3 crust = vec3(0.025, 0.012, 0.02);
	vec3 fire = vec3(0.85, 0.12, 0.012);
	ALBEDO = mix(crust, fire, cracks);
	EMISSION = mix(crust * 0.25, fire * 0.8, cracks);
}
