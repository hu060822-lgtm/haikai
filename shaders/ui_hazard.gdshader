shader_type canvas_item;
// Scrolling diagonal hazard stripes for bars and stickers.

uniform vec4 color_a : source_color = vec4(0.78, 1.0, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.03, 0.03, 0.035, 1.0);
uniform float stripe = 14.0;  // stripe width in pixels
uniform float speed = 18.0;   // pixels per second

void fragment() {
	float d = (FRAGCOORD.x + FRAGCOORD.y + TIME * speed) / stripe;
	COLOR = mix(color_a, color_b, step(0.5, fract(d * 0.5)));
	COLOR.a *= texture(TEXTURE, UV).a;
}
