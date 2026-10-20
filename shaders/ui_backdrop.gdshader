shader_type canvas_item;
// Animated grimy backdrop for the menus: drifting smoke over stained concrete,
// a neon glow, halftone print dots and rising embers. All procedural, one pass.

uniform vec4 base_color : source_color = vec4(0.03, 0.028, 0.034, 1.0);
uniform vec4 acid : source_color = vec4(0.78, 1.0, 0.16, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.16, 0.42, 1.0);
uniform float glow = 1.0;
uniform float embers = 1.0;
uniform float halftone = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 1e-6);
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = TIME;

	// Stained concrete.
	float grime = fbm(p * 3.0);
	float stains = smoothstep(0.55, 0.8, fbm(p * 7.0 + 3.1));
	vec3 col = base_color.rgb * (0.55 + grime * 0.9) - stains * 0.015;

	// Slow smoke.
	vec2 q = p * 1.6 + vec2(t * 0.025, -t * 0.04);
	float smoke = fbm(q + fbm(q * 1.3 + t * 0.03));
	col += vec3(0.05, 0.045, 0.06) * smoke;

	// Neon: acid haze from below, hot pink bleeding in from the top-right corner.
	float low = pow(uv.y, 2.6);
	col += acid.rgb * low * smoke * 0.20 * glow;
	float corner = smoothstep(1.1, 0.0, distance(uv, vec2(1.0, 0.0)) * 1.3);
	col += hot.rgb * corner * (0.10 + 0.06 * smoke) * glow;

	// Halftone print dots that swell with the smoke.
	vec2 cell = fract(FRAGCOORD.xy / 7.0) - 0.5;
	float radius = clamp((smoke - 0.45) * 0.9, 0.0, 0.45) * (0.35 + low);
	col += hot.rgb * 0.07 * halftone * step(length(cell), radius);

	// Rising embers / sparks, three parallax layers.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float scale = 9.0 + fi * 7.0;
		vec2 e = p * scale;
		e.y += t * (0.9 + fi * 0.55);
		e.x += sin(e.y * 0.35 + fi * 2.1 + t * 0.4) * 0.45;
		vec2 id = floor(e);
		vec2 f = fract(e) - 0.5;
		float h = hash(id + fi * 17.3);
		if (h > 0.88) {
			vec2 o = vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5;
			float d = length((f - o * 0.6) * vec2(1.0, 0.6));
			float spark = smoothstep(0.09 - fi * 0.02, 0.0, d);
			float blink = 0.55 + 0.45 * sin(t * 7.0 + h * 50.0);
			vec3 c = mix(vec3(1.0, 0.55, 0.15), hot.rgb, fract(h * 9.0));
			col += c * spark * blink * (0.25 + uv.y) * embers;
		}
	}

	// Vignette.
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 1.25;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
