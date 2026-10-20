// Full-screen PS1 post effect: colour quantisation with ordered dithering and faint scanlines.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Levels per colour channel (PS1 framebuffers were 5 bits = 32 levels).
uniform float color_levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.06;
// Gameplay effects: dreaminess (warm milk, the dreamcore map), colour (0 = black and
// white), brightness gain and a green tint for night vision.
uniform float dream : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float gain = 1.0;
uniform bool night_vision = false;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 uv = SCREEN_UV;
	if (dream > 0.0) {
		uv += vec2(sin(uv.y * 14.0 + TIME * 1.3), cos(uv.x * 11.0 + TIME * 1.1)) * 0.006 * dream;
	}
	vec3 c = texture(screen_texture, uv).rgb;
	if (dream > 0.0) {
		// Soft, pastel and slowly shifting hue.
		vec3 bloom = texture(screen_texture, uv + vec2(0.004, 0.0)).rgb + texture(screen_texture, uv - vec2(0.004, 0.0)).rgb;
		c = mix(c, (c + bloom) / 3.0, 0.5 * dream);
		vec3 drift = vec3(sin(TIME * 0.4), sin(TIME * 0.4 + 2.1), sin(TIME * 0.4 + 4.2)) * 0.08;
		c = mix(c, c * 0.8 + vec3(0.25, 0.2, 0.28) + drift, 0.45 * dream);
	}
	if (night_vision) {
		float l = dot(c, vec3(0.3, 0.59, 0.11)) * gain;
		c = vec3(l * 0.35, l, l * 0.4);
	}
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(grey), c, saturation);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
	float steps = color_levels - 1.0;
	c += threshold * dither_strength / steps;
	c = floor(clamp(c, 0.0, 1.0) * steps + 0.5) / steps;
	c *= 1.0 - scanline_strength * float(int(FRAGCOORD.y) % 2);
	COLOR = vec4(c, 1.0);
}
