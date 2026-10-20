shader_type canvas_item;
// Edge-only tint for the HUD (damage flash, low health).

uniform vec4 tint : source_color = vec4(0.75, 0.0, 0.02, 1.0);
uniform float amount = 0.0;

void fragment() {
	vec2 v = UV - 0.5;
	float edge = smoothstep(0.18, 0.75, length(v * vec2(1.25, 1.0)));
	COLOR = vec4(tint.rgb, edge * amount);
}
