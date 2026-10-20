shader_type canvas_item;
// Full-screen overlay for the menus: chromatic aberration, scanlines, grain,
// flicker, a rolling bar and occasional horizontal glitch slices.
// Reads the screen behind it, so it must be drawn last.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float glitch = 1.0;      // how strong the glitch bursts are (0 = never)
uniform float burst = 0.0;       // forced glitch from script (0..1)
uniform float aberration = 1.5;  // base RGB split in pixels
uniform float scanlines = 0.22;
uniform float grain = 0.05;
uniform float flicker = 0.03;
uniform float vignette = 0.35;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void fragment() {
	vec2 suv = SCREEN_UV;
	float t = TIME;
	float tick = floor(t * 14.0);
	// Bursts come in clusters: a slow gate and a fast flicker inside it.
	float gate = step(0.8, hash(floor(t * 1.7) + 3.0)) * step(0.45, hash(tick));
	float g = clamp(gate * glitch + burst, 0.0, 1.0);

	float row = floor(suv.y * 22.0 + hash(tick) * 9.0);
	float slice = step(0.62, hash(row * 1.37 + tick)) * (hash(row + tick * 0.7) - 0.5);
	suv.x += slice * 0.09 * g;
	// Thin tear lines.
	float tear = step(0.985, hash(floor(suv.y * 180.0) + tick)) * g;
	suv.x += tear * 0.02;

	float ca = SCREEN_PIXEL_SIZE.x * (aberration + g * 9.0);
	vec3 col;
	col.r = texture(screen_tex, suv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, suv).g;
	col.b = texture(screen_tex, suv - vec2(ca, 0.0)).b;

	// Scanlines every 3 screen pixels.
	float line = 0.5 + 0.5 * sin(FRAGCOORD.y * 2.0944);
	col *= 1.0 - scanlines * (1.0 - line);
	// Rolling bright bar.
	float bar = fract(SCREEN_UV.y * 0.6 - t * 0.08);
	col += vec3(0.025) * smoothstep(0.08, 0.0, abs(bar - 0.5));
	// Grain and flicker.
	float n = fract(sin(dot(FRAGCOORD.xy + fract(t) * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	col *= 1.0 - flicker * hash(floor(t * 24.0));
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette * 2.0;
	COLOR = vec4(col, 1.0);
}
