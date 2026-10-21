// The HUD minimap disc (scripts/ui/minimap.gd): the rasterised floor plan turned so
// the player faces up, pixelated, scanlined, with dream static and an acid rim.
shader_type canvas_item;
uniform sampler2D map_tex : filter_nearest;
uniform vec2 centre_uv;
uniform vec2 right_uv;
uniform vec2 down_uv;
uniform float pixels = 84.0;
uniform float fuzz = 0.0;
uniform float clock = 0.0;
uniform vec4 rim_color : source_color = vec4(0.78, 1.0, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 q = (floor(UV * pixels) + 0.5) / pixels * 2.0 - 1.0;
	float t = floor(clock * 12.0);
	// The dream bends the plan.
	q += fuzz * 0.06 * vec2(sin(q.y * 7.0 + clock * 1.7), cos(q.x * 6.0 + clock * 1.3));
	vec2 uv = centre_uv + right_uv * q.x + down_uv * q.y;
	vec4 m = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		m = vec4(0.0);
	}
	// Inside a big solid block (all eight neighbours wall too): dark hatching, so walls
	// read as outlines and thick slabs don't flood the map with bone white.
	if (m.a > 0.5 && m.r > 0.7) {
		vec2 px = 1.0 / vec2(textureSize(map_tex, 0));
		float solid = 1.0;
		for (int i = -1; i <= 1; i++) {
			for (int j = -1; j <= 1; j++) {
				vec4 o = texture(map_tex, uv + vec2(float(i), float(j)) * px);
				solid *= step(0.7, o.r) * step(0.5, o.a);
			}
		}
		vec2 cell = floor(uv / px);
		float hatch = step(0.5, fract((cell.x + cell.y) * 0.25));
		m.rgb = mix(m.rgb, vec3(0.1, 0.1, 0.1) + hatch * 0.05, solid);
	}
	vec3 col = mix(vec3(0.025, 0.025, 0.03), m.rgb, m.a);
	// Scanlines and a little grain.
	float row = floor(UV.y * pixels);
	col *= 0.86 + 0.14 * mod(row, 2.0);
	float n = hash(floor(UV * pixels) + t);
	col += (n - 0.5) * 0.05;
	col = mix(col, vec3(n * 0.75), clamp(fuzz, 0.0, 1.0) * (0.55 + 0.45 * fuzz));
	// Darker towards the rim, then the rim itself.
	col *= 1.0 - smoothstep(0.55, 1.0, r) * 0.45;
	float alpha = 0.86;
	float rim = smoothstep(0.955, 0.965, r);
	col = mix(col, rim_color.rgb, rim);
	alpha = mix(alpha, 1.0, rim);
	alpha *= 1.0 - smoothstep(0.985, 1.0, r);
	COLOR = vec4(col, alpha);
}
