shader_type spatial;
// Layered photoscan material for primitives without usable UVs. Colour, normal, roughness, AO and
// metal maps are projected on three planes and blended (whiteout normal blend), then weathered:
// large-scale colour drift that hides tiling, cavity darkening, moss on upward faces and in
// crevices, grime at the base, damp streaks down vertical faces and a drowned waterline.
// A luminance-preserving tint keeps hero and enemy colours readable on top of the photo detail.
render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms maps;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D metal_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform bool use_metal_tex = false;
// How many times the map repeats per metre. Static props project in world space so neighbouring
// pieces line up; moving parts project in object space so the texture sticks to them.
uniform float tiles_per_metre = 0.5;
uniform bool world_space = false;
uniform float blend_sharpness : hint_range(1.0, 24.0) = 6.0;

group_uniforms surface;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
// Average luminance of the colour map: tinting divides by it so a tinted surface keeps its brightness.
uniform float albedo_mean : hint_range(0.02, 1.0) = 0.35;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float roughness_scale = 1.0;
uniform float roughness_bias = 0.0;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float normal_depth = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float cavity_darkening : hint_range(0.0, 1.0) = 0.35;

group_uniforms weathering;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.2;
uniform float macro_scale = 0.18;
uniform float grime_height = 0.0;
uniform vec3 grime_color : source_color = vec3(0.07, 0.065, 0.06);
uniform float damp : hint_range(0.0, 1.0) = 0.0;
uniform float moss : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moss_color : source_color = vec3(0.12, 0.16, 0.06);
uniform float waterline = 0.0;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.0;

group_uniforms glow;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
// 0 = even glow; 1 = only the cracks and crevices of the relief glow (runes, embers, magic veins).
uniform float glow_in_cracks : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_obj_pos;
varying vec3 v_obj_normal;
varying vec3 v_world_pos;
varying vec3 v_world_normal;

// Projection planes. X and Z keep images upright on walls (v runs down the world Y axis).
const vec3 AX = vec3(1.0, 0.0, 0.0);
const vec3 UX = vec3(0.0, 0.0, 1.0);
const vec3 VX = vec3(0.0, -1.0, 0.0);
const vec3 AY = vec3(0.0, 1.0, 0.0);
const vec3 UY = vec3(1.0, 0.0, 0.0);
const vec3 VY = vec3(0.0, 0.0, 1.0);
const vec3 AZ = vec3(0.0, 0.0, 1.0);
const vec3 UZ = vec3(1.0, 0.0, 0.0);
const vec3 VZ = vec3(0.0, -1.0, 0.0);


float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amp * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return total;
}

#define TRI(tex, ux, uy, uz, w) (texture(tex, ux) * (w).x + texture(tex, uy) * (w).y + texture(tex, uz) * (w).z)

// One plane's contribution to the whiteout-blended normal. Maps are OpenGL style (green points up
// the image); v points down it, so green is flipped. Only RG is read, so the result is the same
// whether or not the importer stored the map as a two-channel normal map.
vec3 plane_normal(vec2 rg, vec3 n, vec3 axis, vec3 u, vec3 v) {
	vec2 t = (rg * 2.0 - 1.0) * vec2(1.0, -1.0) * normal_depth;
	float tz = sqrt(clamp(1.0 - dot(t, t), 0.0, 1.0));
	vec3 b = vec3(t + vec2(dot(n, u), dot(n, v)), tz * dot(n, axis));
	return u * b.x + v * b.y + axis * b.z;
}

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_normal = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_space ? v_world_pos : v_obj_pos;
	vec3 n = normalize(world_space ? v_world_normal : v_obj_normal);
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	w /= max(w.x + w.y + w.z, 1e-5);
	vec3 ps = p * tiles_per_metre;
	// Offsets keep the three planes from repeating the same patch where they blend.
	vec2 ux = vec2(dot(ps, UX), dot(ps, VX)) + vec2(0.37, 0.11);
	vec2 uy = vec2(dot(ps, UY), dot(ps, VY));
	vec2 uz = vec2(dot(ps, UZ), dot(ps, VZ)) + vec2(0.71, 0.53);

	vec3 col = TRI(albedo_tex, ux, uy, uz, w).rgb;
	float rough = TRI(roughness_tex, ux, uy, uz, w).r;
	float ao = TRI(ao_tex, ux, uy, uz, w).r;
	float metal = use_metal_tex ? TRI(metal_tex, ux, uy, uz, w).r : metallic_value;
	vec3 nn = normalize(
		plane_normal(texture(normal_tex, ux).rg, n, AX, UX, VX) * w.x
		+ plane_normal(texture(normal_tex, uy).rg, n, AY, UY, VY) * w.y
		+ plane_normal(texture(normal_tex, uz).rg, n, AZ, UZ, VZ) * w.z);

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, saturation) * brightness;
	col = mix(col, tint.rgb * (lum / albedo_mean) * brightness, tint_strength);
	col *= mix(1.0, ao, cavity_darkening);

	// Large-scale drift: brightness and a warm/cool shift that hide the repeat. Weathering noise uses
	// the projection position so it sticks to moving parts; heights (grime, waterline) use world Y.
	vec3 wp = v_world_pos;
	vec3 np = p;
	vec3 wn = world_space ? n : normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float macro = fbm(np * macro_scale);
	col *= 1.0 + (macro - 0.5) * 2.0 * macro_strength;
	float warm = smoothstep(0.4, 0.75, fbm(np * macro_scale * 0.6 + vec3(11.0)));
	col = mix(col, col * vec3(1.08, 1.0, 0.9), warm * macro_strength);

	// Edge wear: the raised parts of the relief (bright AO, strong normal tilt) are polished lighter.
	if (edge_wear > 0.0) {
		float raised = smoothstep(0.85, 1.0, ao) * smoothstep(0.08, 0.3, 1.0 - dot(nn, n));
		float chips = smoothstep(0.55, 0.75, vnoise(p * 14.0));
		float wear = clamp(raised * chips * edge_wear * 2.0, 0.0, 1.0);
		col = mix(col, col * 1.6 + vec3(0.03), wear);
		rough = mix(rough, rough * 0.6, wear);
	}

	// Moss settles on upward faces and in the crevices, in clumps.
	if (moss > 0.0) {
		float up = smoothstep(0.25, 0.9, wn.y);
		float clump = smoothstep(0.42, 0.68, fbm(np * 1.4 + vec3(3.0)));
		float crevice = clamp((1.0 - ao) * 2.0, 0.0, 1.0);
		float low = 1.0 - smoothstep(0.0, 1.2, wp.y);
		float m = clamp((up * 0.9 + crevice + low * 0.6) * clump * moss * 1.4, 0.0, 1.0);
		vec3 moss_col = moss_color * (0.55 + 0.9 * vnoise(np * 11.0));
		col = mix(col, moss_col, m);
		rough = mix(rough, 0.95, m);
		nn = normalize(mix(nn, n, m * 0.5));
	}

	// Soot and mud around the base.
	if (grime_height > 0.0) {
		float h = wp.y + (fbm(np * 2.2) - 0.5) * grime_height;
		float g = 1.0 - smoothstep(0.0, grime_height, h);
		col = mix(col, grime_color * (0.6 + lum), g * 0.85);
		rough = mix(rough, 1.0, g * 0.3);
	}

	// Damp: dark streaks running down the vertical faces, and the drowned band below the waterline.
	float wet = 0.0;
	if (damp > 0.0) {
		float vertical = 1.0 - abs(wn.y);
		float streak = smoothstep(0.5, 0.78, fbm(vec3(np.x * 2.6, np.y * 0.22, np.z * 2.6)));
		float top_seep = smoothstep(0.55, 0.8, fbm(vec3(np.x * 1.3, 4.0, np.z * 1.3)));
		wet = max(wet, streak * vertical * damp * (0.6 + 0.4 * top_seep));
	}
	if (waterline > 0.0) {
		float jitter = (vnoise(np * 2.7) - 0.5) * 0.18;
		float band = 1.0 - smoothstep(waterline * 0.55, waterline, wp.y + jitter);
		wet = max(wet, band);
		float tide = 1.0 - smoothstep(0.0, 0.06, abs(wp.y + jitter - waterline - 0.05));
		col = mix(col, col * 1.35 + vec3(0.025, 0.03, 0.025), tide * 0.6);
	}
	col *= mix(1.0, 0.5, wet);
	rough = mix(rough, 0.16, wet);

	ALBEDO = col;
	ROUGHNESS = clamp(rough * roughness_scale + roughness_bias, 0.03, 1.0);
	METALLIC = metal;
	AO = mix(1.0, ao, ao_strength);
	AO_LIGHT_AFFECT = 0.15;
	vec3 world_nn = world_space ? nn : normalize((MODEL_MATRIX * vec4(nn, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_nn, 0.0)).xyz);
	EMISSION = emission_color * emission_energy * mix(1.0, clamp((1.0 - ao) * 4.0, 0.0, 1.0), glow_in_cracks);
}
