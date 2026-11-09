shader_type spatial;
// Enemy telegraphs: red-orange ground decals drawn above player effects.
// shape 0 = circle, 1 = sector (facing local +Z), 2 = line. progress fills 0 -> 1 until the hit.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform int shape = 0;
uniform float progress = 0.0;
uniform float half_arc = 0.9;
uniform vec4 color : source_color = vec4(1.0, 0.32, 0.08, 0.75);
uniform float emphasis = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float inside = 0.0;
	float rim = 0.0;
	float fill = 0.0;
	if (shape == 0) {
		float r = length(p);
		inside = step(r, 1.0);
		rim = inside * smoothstep(0.86, 0.97, r);
		fill = inside * step(r, progress);
	} else if (shape == 1) {
		float r = length(p);
		float a = abs(atan(p.x, p.y));
		inside = step(r, 1.0) * step(a, half_arc);
		rim = inside * max(smoothstep(0.86, 0.97, r), smoothstep(half_arc - 0.06, half_arc, a));
		fill = inside * step(r, progress);
	} else {
		inside = step(abs(p.x), 1.0) * step(abs(p.y), 1.0);
		rim = inside * smoothstep(0.75, 0.98, abs(p.x));
		fill = inside * step((p.y + 1.0) * 0.5, progress);
	}
	float a = inside * 0.16 + fill * 0.32 + rim * 0.7;
	a *= 1.0 + emphasis * 0.6;
	ALBEDO = color.rgb * (1.0 + emphasis * 0.5);
	ALPHA = clamp(a * color.a, 0.0, 1.0);
}
