shader_type spatial;
// Inverted-hull outline for "ready to detonate" targets.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float width = 0.05;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	float pulse = 0.7 + 0.3 * sin(TIME * 9.0);
	ALBEDO = color.rgb * pulse;
	ALPHA = color.a;
}
