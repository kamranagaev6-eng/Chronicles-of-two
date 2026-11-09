shader_type spatial;
// Arena floor: photoscanned crypt flagstones (CC0, ambientCG Tiles093) weathered in layers, with the
// elemental surface grid drawn on top. Surfaces follow the stone's height map, so a spreading puddle
// or oil slick fills the mortar first and climbs onto the stones only where it is deep.
// The grid writes one texel per 0.5 m cell: R = material code, G = flags, B = cloud.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D surface_tex : hint_default_black, filter_nearest, repeat_disable;
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

group_uniforms surfaces;
// Brightest any surface may glow (luminance of the summed emission). Enemy telegraphs are unshaded
// red-orange at about 0.45-0.7, so surface effects stay below them and the stone shows through.
uniform float emission_cap : hint_range(0.0, 4.0) = 0.6;

varying vec3 world_pos;

const vec3 UP = vec3(0.0, 1.0, 0.0);


// Sine-free hashes (stable on every GPU at world-space magnitudes).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Value noise: only for soft masks (moss clumps, dust, puddles), never for normals or lines,
// because its slope is flat along the lattice and would draw a grid.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

const mat2 ROT = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += amp * vnoise(p);
		p = ROT * p * 2.07 + vec2(5.3, 1.9);
		amp *= 0.5;
	}
	return total;
}

// Gradient noise in about [-1, 1] with a quintic fade: no flat spots on the lattice, so its slope
// can drive normals and its zero crossings can draw lines.
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash2(i) * 2.0 - 1.0, f);
	float b = dot(hash2(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.6;
}

// Distance to the nearest Voronoi cell border: crack networks in ice.
float voronoi_edge(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return md;
}

// Water surface normal: four directional swells (analytic slope) plus drifting gradient-noise chop.
vec3 ripple_normal(vec2 p, float t, float speed, float amp) {
	vec2 slope = vec2(0.0);
	vec2 dirs[4] = vec2[](vec2(0.96, 0.28), vec2(-0.6, 0.8), vec2(0.2, -0.98), vec2(-0.87, -0.5));
	float freqs[4] = float[](2.1, 3.3, 5.2, 7.9);
	float rates[4] = float[](1.3, 1.7, 2.3, 2.9);
	float amps[4] = float[](0.5, 0.3, 0.18, 0.1);
	for (int i = 0; i < 4; i++) {
		float phase = dot(dirs[i], p) * freqs[i] + t * rates[i] * speed;
		slope += dirs[i] * freqs[i] * amps[i] * cos(phase);
	}
	float e = 0.05;
	vec2 q = p * 2.3 + vec2(t * 0.21, t * 0.17) * speed;
	float h0 = gnoise(q);
	slope += vec2(gnoise(q + vec2(e, 0.0)) - h0, gnoise(q + vec2(0.0, e)) - h0) / e * 0.9;
	vec2 q2 = ROT * p * 5.7 - vec2(t * 0.33, -t * 0.12) * speed;
	float h1 = gnoise(q2);
	slope += vec2(gnoise(q2 + vec2(e, 0.0)) - h1, gnoise(q2 + vec2(0.0, e)) - h1) / e * 0.35;
	return normalize(vec3(-slope.x * amp, 1.0, -slope.y * amp));
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
		col = mix(col, vec3(0.012, 0.03, 0.036) + col * 0.2, smoothstep(0.0, 0.4, d) * 0.85);
		// Caustic web: where the ridges of two drifting gradient-noise fields cross.
		float r1 = 1.0 - abs(gnoise(w * 2.6 + vec2(t * 0.35, -t * 0.27)));
		float r2 = 1.0 - abs(gnoise(ROT * w * 3.4 - vec2(t * 0.22, t * 0.41)));
		float caustic = pow(r1, 9.0) + pow(r2, 9.0);
		col += vec3(0.02, 0.045, 0.045) * caustic * smoothstep(0.02, 0.25, d);
		rough = mix(rough, mix(0.3, 0.03, sub), max(halo, sub));
		n = normalize(mix(n, ripple_normal(w, t, 1.0, 0.035), sub));
	}

	float c_ice = cover(codes, 2, f);
	if (c_ice > 0.001) {
		float frost_edge = smoothstep(0.2, 0.7, c_ice + edge_noise * 1.5);
		// Crack network: Voronoi borders, bent by a gentle warp, at two scales.
		vec2 warp = vec2(gnoise(w * 0.9), gnoise(w * 0.9 + 4.7)) * 0.3;
		float crack = 1.0 - smoothstep(0.0, 0.03, voronoi_edge(w * 1.1 + warp));
		crack = max(crack, (1.0 - smoothstep(0.0, 0.022, voronoi_edge(w * 3.6 + warp * 2.0 + 7.0))) * 0.45);
		float frosty = clamp(smoothstep(0.42, 0.75, fbm(w * 1.2 + 5.0)) * 0.45 + (1.0 - frost_edge) * 0.6 + mortar * 0.25, 0.0, 1.0);
		vec3 under_ice = col * vec3(0.6, 0.8, 0.95) + vec3(0.025, 0.06, 0.085);
		vec3 frost_col = vec3(0.34, 0.42, 0.48) * (0.85 + 0.3 * vnoise(w * 23.0));
		vec3 ice_col = mix(under_ice, frost_col, frosty);
		ice_col = mix(ice_col, vec3(0.5, 0.58, 0.64), crack * 0.7);
		vec2 grain = floor(w * 90.0);
		float glint = step(0.9975, hash(grain)) * (0.5 + 0.5 * sin(t * 2.5 + hash(grain + 3.0) * 30.0));
		col = mix(col, ice_col, frost_edge);
		rough = mix(rough, mix(0.05, 0.55, max(frosty, crack * 0.6)), frost_edge);
		n = normalize(mix(n, UP, frost_edge * 0.7));
		emit += (vec3(0.006, 0.015, 0.024) + glint * vec3(0.3, 0.35, 0.4)) * frost_edge;
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
		float film_mask = smoothstep(0.4, 0.8, fbm(w * 0.7 + vec2(3.0, t * 0.02)));
		col = mix(col, vec3(0.03, 0.025, 0.018) + film * 0.11 * film_mask, sub);
		rough = mix(rough, 0.05, max(sub, halo * 0.6));
		n = normalize(mix(n, ripple_normal(w, t, 0.12, 0.012), sub));
	}

	float c_fire = cover(codes, 4, f);
	if (c_fire > 0.001) {
		float burn = smoothstep(0.1, 0.6, c_fire + edge_noise);
		col = mix(col, col * 0.12 + vec3(0.02, 0.014, 0.01), burn);
		rough = mix(rough, 1.0, burn);
		float flick = clamp(0.5 + 0.35 * gnoise(w * 2.5 + vec2(0.0, t * 2.5)) + 0.25 * gnoise(ROT * w * 7.0 - vec2(t * 4.0)), 0.0, 1.0);
		float cracks = 1.0 - smoothstep(0.1, mortar_level + 0.1, h);
		// Embers glow in the cracks; the charred stone between them stays visible.
		float hot = clamp(cracks * 1.1 + flick * 0.5 - 0.3, 0.0, 1.0) * burn;
		emit += mix(vec3(1.9, 0.32, 0.04), vec3(2.8, 1.25, 0.32), flick) * (hot * 0.8 + 0.04 * burn);
	}

	float c_holy = cover(codes, 5, f);
	if (c_holy > 0.001) {
		float glow = smoothstep(0.2, 0.7, c_holy + edge_noise);
		float pulse = 0.65 + 0.35 * sin(t * 2.0 + gnoise(w * 1.5) * 4.0);
		col = mix(col, col * vec3(1.35, 1.2, 0.9) + vec3(0.05, 0.04, 0.015), glow * 0.5);
		emit += (vec3(1.2, 0.82, 0.3) * mortar * 0.6 + vec3(0.25, 0.18, 0.06) * 0.2) * pulse * glow;
	}

	float c_shock = flag_cover(flags, 1, f);
	if (c_shock > 0.001) {
		// Thin arcs (gradient-noise ridges) crawl along the mortar and through any water.
		float arc = pow(1.0 - abs(gnoise(w * 3.0 + vec2(t * 9.0, -t * 7.0))), 14.0);
		arc += pow(1.0 - abs(gnoise(ROT * w * 5.5 - vec2(t * 6.0, t * 11.0))), 18.0) * 0.6;
		// Only drifting patches crackle at any moment, so the pool reads as live current, not a lamp.
		float crawl = smoothstep(0.15, 0.55, gnoise(w * 0.6 + vec2(t * 1.3, -t * 0.9)));
		float path = max(mortar, c_water * 0.5);
		float strobe = step(0.3, hash(vec2(floor(t * 20.0), 7.0)));
		emit += vec3(0.5, 0.65, 1.8) * c_shock * (0.02 + path * (0.03 + arc * crawl * 1.6) * strobe);
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

	emit *= min(1.0, emission_cap / max(dot(emit, vec3(0.2126, 0.7152, 0.0722)), 1e-4));

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.2;
	EMISSION = emit;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}
