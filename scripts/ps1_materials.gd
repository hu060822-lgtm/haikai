class_name PS1Materials
## Builds and caches ShaderMaterials that use the shared PS1 surface shader.

const SHADER := preload("res://shaders/ps1.gdshader")

static var _cache := {}


static func get_material(
	texture_name: String,
	tint := Color.WHITE,
	use_mesh_uv := false,
	uv_scale := Vector2.ONE,
	emission := Color.BLACK,
	texel_density := 0.5
) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s|%s" % [texture_name, tint, use_mesh_uv, uv_scale, emission, texel_density]
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", load("res://textures/%s.png" % texture_name))
	material.set_shader_parameter("albedo_color", tint)
	material.set_shader_parameter("use_mesh_uv", use_mesh_uv)
	material.set_shader_parameter("uv_scale", uv_scale)
	material.set_shader_parameter("emission_color", emission)
	material.set_shader_parameter("texel_density", texel_density)
	_cache[key] = material
	return material
