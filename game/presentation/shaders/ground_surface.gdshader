shader_type spatial;
// Arena floor: photoscanned crypt flagstones (CC0, ambientCG Tiles093) weathered in layers, with the
// elemental surface grid drawn on top. Surfaces follow the stone's height map, so a spreading puddle
// or oil slick fills the mortar first and climbs onto the stones only where it is deep.
// The grid writes one texel per 0.5 m cell: R = material code, G = flags, B = cloud.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D surface_tex : filter_nearest, repeat_disable;
uniform vec2 grid_origin = vec2(-18.0, -14.0);
uniform vec2 grid_size = vec2(36.0, 28.0);

group_uniforms stone;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_gray, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
// Tiles093 covers 2.45 m.
uniform float tiles_per_metre = 0.408;
uniform float brightness = 0.85;
uniform float macro_strength : hint_range(0.0, 1.0) = 0.28;
uniform float normal_depth = 1.2;
// Height below which the map is mortar rather than stone.
uniform float mortar_level : hint_range(0.0, 1.0) = 0.32;

group_uniforms weathering;
uniform vec3 moss_color : source_color = vec3(0.10, 0.14, 0.05);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.65;
uniform vec3 mud_color : source_color = vec3(0.075, 0.062, 0.05);
// Standing water left in the low spots of the drowned crypt.
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.55;
uniform vec3 murk_color : source_color = vec3(0.02, 0.05, 0.055);
// Metres of soot, mud and damp creeping in from the walls.
uniform float wall_grime = 3.0;

varying vec3 world_pos;

const vec3 UP = vec3(0.0, 1.0, 0.0);


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amp * vnoise(p);
		p = p * 2.07 + vec2(5.3, 1.9);
		amp *= 0.5;
	}
	return total;
}

// Wind-blown ripples as a height field; the normal comes from finite differences.
float ripple_height(vec2 p, float t, float speed) {
	return vnoise(p * 1.7 + vec2(t * 0.31, t * 0.22) * speed)
		+ 0.5 * vnoise(p * 3.9 - vec2(t * 0.52, -t * 0.13) * speed)
		+ 0.25 * vnoise(p * 8.3 + vec2(-t * 0.27, t * 0.61) * speed);
}

vec3 ripple_normal(vec2 p, float t, float speed, float amp) {
	float e = 0.04;
	float h0 = ripple_height(p, t, speed);
	float hx = ripple_height(p + vec2(e, 0.0), t, speed);
	float hz = ripple_height(p + vec2(0.0, e), t, speed);
	return normalize(vec3(-(hx - h0) * amp / e, 1.0, -(hz - h0) * amp / e));
}

// Bilinear coverage of one material code over the four nearest cells.
float cover(ivec4 codes, int code, vec2 f) {
	float a = codes.x == code ? 1.0 : 0.0;
	float b = codes.y == code ? 1.0 : 0.0;
	float c = codes.z == code ? 1.0 : 0.0;
	float d = codes.w == code ? 1.0 : 0.0;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float flag_cover(ivec4 flags, int bit, vec2 f) {
	float a = (flags.x & bit) != 0 ? 1.0 : 0.0;
	float b = (flags.y & bit) != 0 ? 1.0 : 0.0;
	float c = (flags.z & bit) != 0 ? 1.0 : 0.0;
	float d = (flags.w & bit) != 0 ? 1.0 : 0.0;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = world_pos.xz;
	float t = TIME;
	vec2 uv = w * tiles_per_metre;

	// --- Photoscanned stone ---------------------------------------------------------------
	vec3 col = texture(albedo_tex, uv).rgb * brightness;
	float h = texture(height_tex, uv).r;
	float ao = texture(ao_tex, uv).r;
	float rough = texture(roughness_tex, uv).r;
	vec2 nrg = (texture(normal_tex, uv).rg * 2.0 - 1.0) * normal_depth;
	// OpenGL green points up the image, which is world -Z when the map is laid on X/Z.
	vec3 n = normalize(vec3(nrg.x, sqrt(clamp(1.0 - dot(nrg, nrg), 0.0, 1.0)), -nrg.y));
	float mortar = 1.0 - smoothstep(mortar_level - 0.12, mortar_level + 0.06, h);

	// Large-scale drift so the 2.45 m repeat disappears: brightness, a warm/cool shift and
	// pale dusty patches on the high stones.
	float macro = fbm(w * 0.11);
	col *= 1.0 + (macro - 0.5) * 2.0 * macro_strength;
	col = mix(col, col * vec3(1.12, 1.0, 0.84), smoothstep(0.45, 0.8, fbm(w * 0.07 + 31.0)) * macro_strength);
	float dust = smoothstep(0.55, 0.8, fbm(w * 0.35 + 13.0)) * smoothstep(0.45, 0.8, h);
	col = mix(col, col * 1.3 + vec3(0.03, 0.028, 0.024), dust * 0.6);
	rough = mix(rough, 1.0, dust * 0.5);
	col *= mix(1.0, ao, 0.55);

	// Moss and mud in the mortar, in clumps, creeping onto the low edges of the stones.
	float clump = smoothstep(0.36, 0.68, fbm(w * 0.42 + 7.0));
	float edge_low = 1.0 - smoothstep(mortar_level, mortar_level + 0.25, h);
	float moss_m = clamp((mortar + edge_low * 0.45) * clump * moss_amount * 1.3, 0.0, 1.0);
	vec3 moss_col = moss_color * (0.55 + 0.9 * vnoise(w * 13.0)) + vec3(0.02, 0.025, 0.0) * vnoise(w * 41.0);
	col = mix(col, mud_color * (0.8 + 0.4 * vnoise(w * 7.0)), mortar * (1.0 - clump) * 0.55);
	col = mix(col, moss_col, moss_m);
	rough = mix(rough, 0.92, moss_m);
	n = normalize(mix(n, UP, moss_m * 0.35));

	// Soot, mud and damp creeping in from the walls.
	vec2 rel = w - grid_origin;
	float border = min(min(rel.x, grid_size.x - rel.x), min(rel.y, grid_size.y - rel.y));
	float grime = 1.0 - smoothstep(0.0, wall_grime, border + (fbm(w * 0.8) - 0.5) * 1.6);
	col = mix(col, mud_color * (0.6 + 0.6 * h), grime * 0.7);

	// Standing water left in the low spots: a level per area; anything below it is submerged,
	// a damp halo darkens the stone just above it.
	float pool = smoothstep(0.5, 0.78, fbm(w * 0.16 + 101.0)) * puddle_amount;
	float level = pool * 0.85 + grime * 0.25 - 0.02;
	float depth = clamp(level - h, 0.0, 1.0);
	float standing = smoothstep(0.0, 0.035, depth);
	float wet = max(standing, (1.0 - smoothstep(level, level + 0.22, h)) * step(0.02, level));
	wet = max(wet, mortar * 0.35);
	col *= mix(1.0, 0.5, wet);
	rough = mix(rough, 0.22, wet);
	col = mix(col, murk_color + col * 0.3, smoothstep(0.0, 0.35, depth) * 0.75);
	rough = mix(rough, 0.035, standing);
	n = normalize(mix(n, ripple_normal(w, t, 0.25, 0.03), standing));

	float metal = 0.0;
	vec3 emit = vec3(0.0);

	// --- Elemental surfaces -------------------------------------------------------------
	vec2 cells = vec2(textureSize(surface_tex, 0));
	vec2 wobble = (vec2(vnoise(w * 2.3), vnoise(w * 2.3 + 17.0)) - 0.5) * 0.7;
	vec2 cf = (w - grid_origin) / grid_size * cells - 0.5 + wobble;
	ivec2 c0 = ivec2(floor(cf));
	vec2 f = fract(cf);
	ivec2 last = ivec2(cells) - 1;
	vec4 s00 = texelFetch(surface_tex, clamp(c0, ivec2(0), last), 0);
	vec4 s10 = texelFetch(surface_tex, clamp(c0 + ivec2(1, 0), ivec2(0), last), 0);
	vec4 s01 = texelFetch(surface_tex, clamp(c0 + ivec2(0, 1), ivec2(0), last), 0);
	vec4 s11 = texelFetch(surface_tex, clamp(c0 + ivec2(1, 1), ivec2(0), last), 0);
	ivec4 codes = ivec4(round(vec4(s00.r, s10.r, s01.r, s11.r) * 255.0));
	ivec4 flags = ivec4(round(vec4(s00.g, s10.g, s01.g, s11.g) * 255.0));
	float edge_noise = (vnoise(w * 3.1) - 0.5) * 0.18;

	float c_water = cover(codes, 1, f);
	if (c_water > 0.001) {
		// Fills the mortar first; deep in the pool the stones go under too.
		float lv = c_water * 1.25 - 0.22 + edge_noise;
		float d = clamp(lv - h, 0.0, 1.0);
		float sub = smoothstep(0.0, 0.04, d);
		float halo = (1.0 - smoothstep(lv, lv + 0.3, h)) * smoothstep(0.0, 0.3, c_water);
		col *= mix(1.0, 0.48, max(halo, sub));
		col = mix(col, vec3(0.025, 0.062, 0.075) + col * 0.22, smoothstep(0.0, 0.4, d) * 0.85);
		float caustic = smoothstep(0.62, 0.9, vnoise(w * 4.0 + vec2(t * 0.4, -t * 0.3)) * vnoise(w * 6.5 - vec2(t * 0.25, t * 0.5)) * 2.2);
		col += vec3(0.03, 0.06, 0.06) * caustic * smoothstep(0.02, 0.2, d);
		rough = mix(rough, mix(0.3, 0.025, sub), max(halo, sub));
		n = normalize(mix(n, ripple_normal(w, t, 1.0, 0.05), sub));
	}

	float c_ice = cover(codes, 2, f);
	if (c_ice > 0.001) {
		float frost_edge = smoothstep(0.2, 0.7, c_ice + edge_noise * 1.5);
		float crack = 1.0 - smoothstep(0.0, 0.022, abs(vnoise(w * 2.2) - 0.5));
		crack = max(crack, (1.0 - smoothstep(0.0, 0.016, abs(vnoise(w * 5.3 + 9.0) - 0.5))) * 0.55);
		float frosty = clamp(smoothstep(0.4, 0.8, fbm(w * 1.2 + 5.0)) * 0.7 + (1.0 - frost_edge) * 0.6 + mortar * 0.3, 0.0, 1.0);
		vec3 under_ice = col * vec3(0.5, 0.72, 0.9) + vec3(0.07, 0.14, 0.19);
		vec3 ice_col = mix(under_ice, vec3(0.82, 0.92, 0.98), frosty);
		ice_col = mix(ice_col, vec3(0.95, 0.99, 1.0), crack);
		vec2 grain = floor(w * 55.0);
		float glint = step(0.993, hash(grain)) * (0.5 + 0.5 * sin(t * 2.5 + hash(grain + 3.0) * 30.0));
		col = mix(col, ice_col, frost_edge);
		rough = mix(rough, mix(0.04, 0.5, frosty), frost_edge);
		n = normalize(mix(n, UP, frost_edge * 0.75));
		emit += (vec3(0.03, 0.08, 0.12) + glint * vec3(1.4, 1.6, 1.8)) * frost_edge;
	}

	float c_oil = cover(codes, 3, f);
	if (c_oil > 0.001) {
		float lv = c_oil * 1.3 - 0.25 + edge_noise;
		float d = clamp(lv - h, 0.0, 1.0);
		float sub = smoothstep(0.0, 0.03, d);
		float halo = (1.0 - smoothstep(lv, lv + 0.25, h)) * smoothstep(0.0, 0.3, c_oil);
		col *= mix(1.0, 0.35, halo);
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
		float thickness = fbm(w * 0.9 + vec2(t * 0.03, 0.0)) * 2.2 + to_cam.y * 0.8;
		vec3 film = 0.5 + 0.5 * cos(6.2831 * (thickness + vec3(0.0, 0.33, 0.67)));
		float film_mask = smoothstep(0.45, 0.85, fbm(w * 0.7 + vec2(3.0, t * 0.02)));
		col = mix(col, vec3(0.022, 0.018, 0.013) + film * 0.07 * film_mask, sub);
		rough = mix(rough, 0.05, max(sub, halo * 0.6));
		n = normalize(mix(n, ripple_normal(w, t, 0.15, 0.015), sub));
	}

	float c_fire = cover(codes, 4, f);
	if (c_fire > 0.001) {
		float burn = smoothstep(0.1, 0.6, c_fire + edge_noise);
		col = mix(col, col * 0.12 + vec3(0.02, 0.014, 0.01), burn);
		rough = mix(rough, 1.0, burn);
		float flick = vnoise(w * 2.5 + vec2(0.0, t * 2.5)) * 0.6 + 0.4 * vnoise(w * 7.0 - vec2(t * 4.0));
		float cracks = 1.0 - smoothstep(0.1, mortar_level + 0.1, h);
		float hot = clamp(cracks * 1.3 + flick * 0.7 - 0.25, 0.0, 1.6) * burn;
		emit += mix(vec3(1.9, 0.32, 0.04), vec3(2.8, 1.25, 0.32), flick) * hot * 1.3;
	}

	float c_holy = cover(codes, 5, f);
	if (c_holy > 0.001) {
		float glow = smoothstep(0.2, 0.7, c_holy + edge_noise);
		float pulse = 0.65 + 0.35 * sin(t * 2.0 + vnoise(w * 2.0) * 6.0);
		col = mix(col, col * vec3(1.6, 1.4, 0.95) + vec3(0.14, 0.11, 0.04), glow * 0.6);
		emit += (vec3(1.3, 0.9, 0.32) * mortar * 0.9 + vec3(0.3, 0.22, 0.07) * 0.35) * pulse * glow;
	}

	float c_shock = flag_cover(flags, 1, f);
	if (c_shock > 0.001) {
		// Arcs crawl along the mortar and through any water.
		float arc = smoothstep(0.8, 0.95, vnoise(w * 5.0 + vec2(t * 9.0, -t * 7.0)));
		float path = max(mortar, c_water);
		float strobe = step(0.3, fract(sin(floor(t * 20.0) * 12.9898) * 43758.5453));
		emit += vec3(0.5, 0.65, 1.8) * c_shock * (0.22 + path * (0.5 + arc * 3.2) * strobe);
	}
	float c_bless = flag_cover(flags, 2, f);
	if (c_bless > 0.001) {
		emit += vec3(0.5, 0.42, 0.18) * 0.4 * c_bless * (0.6 + 0.4 * mortar);
	}
	float c_curse = flag_cover(flags, 4, f);
	if (c_curse > 0.001) {
		float swirl = fbm(w * 1.5 + vec2(t * 0.2, -t * 0.15));
		col = mix(col, col * vec3(0.55, 0.42, 0.65), c_curse * 0.7);
		emit += vec3(0.28, 0.06, 0.4) * c_curse * smoothstep(0.45, 0.75, swirl) * (0.4 + mortar);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.2;
	EMISSION = emit;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
