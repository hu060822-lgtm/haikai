class_name LootShapes
## Builds the mesh for a loot item from its "shape" ("box" if missing) and "size".
## Meshes are cached per shape and size, since many items share them.

static var _cache := {}


static func mesh_for(data: Dictionary) -> Mesh:
	var shape: String = data.get("shape", "box")
	var size: Vector3 = data.size
	var key := "%s:%s" % [shape, size]
	if _cache.has(key):
		return _cache[key]
	var mesh: Mesh
	match shape:
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = maxf(size.x, size.z) / 2.0
			cylinder.bottom_radius = cylinder.top_radius
			cylinder.height = size.y
			cylinder.radial_segments = 8
			cylinder.rings = 1
			mesh = cylinder
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = maxf(size.x, size.z) * 0.18
			cone.bottom_radius = maxf(size.x, size.z) / 2.0
			cone.height = size.y
			cone.radial_segments = 8
			cone.rings = 1
			mesh = cone
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = maxf(size.x, size.z) / 2.0
			sphere.height = size.y
			sphere.radial_segments = 8
			sphere.rings = 4
			mesh = sphere
		"capsule":
			var capsule := CapsuleMesh.new()
			capsule.radius = minf(size.x, size.z) / 2.0
			capsule.height = maxf(size.y, capsule.radius * 2.0)
			capsule.radial_segments = 8
			capsule.rings = 2
			mesh = capsule
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	_cache[key] = mesh
	return mesh
