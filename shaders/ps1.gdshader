// PS1-style surface: vertex snapping, affine texture warping, nearest filtering.
shader_type spatial;
render_mode cull_back, specular_disabled, diffuse_lambert;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
// When false, UVs are projected from world space so tiling stays consistent on any box size.
uniform bool use_mesh_uv = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
// Texture repeats per meter for world-projected UVs.
uniform float texel_density = 0.5;
// Vertical resolution of the vertex snapping grid; lower = more wobble.
uniform float snap_height = 120.0;
// 0 = perspective-correct, 1 = full PS1 affine warping.
uniform float affine_strength : hint_range(0.0, 1.0) = 0.6;

varying vec2 v_uv;
varying vec3 v_affine;

void vertex() {
	vec2 uv;
	if (use_mesh_uv) {
		uv = UV * uv_scale;
	} else {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		if (wn.y >= wn.x && wn.y >= wn.z) {
			uv = wp.xz;
		} else if (wn.x >= wn.z) {
			uv = vec2(wp.z, -wp.y);
		} else {
			uv = vec2(wp.x, -wp.y);
		}
		uv *= texel_density;
	}

	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_height * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_height) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;

	v_uv = uv;
	// Interpolating uv*w and w separately and dividing in fragment() cancels
	// the perspective correction, which gives the classic affine warp.
	v_affine = vec3(uv * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(v_uv, v_affine.xy / v_affine.z, affine_strength);
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * albedo_color.rgb;
	EMISSION = emission_color;
}
