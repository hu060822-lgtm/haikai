class_name LowPoly
## Flat-shaded low-poly meshes built in code: prisms, lathed profiles, chamfered boxes,
## swept tubes, extruded outlines and lumpy spheres. Everything the PS1 look needs
## without falling back to plain boxes. Meshes are cached by their parameters, so a
## hundred identical chairs share one mesh.
##
## Conventions: y is up; prisms, lathes and boxes are centred on the origin like Godot's
## primitive meshes. Pass triangles to _tri() in counter-clockwise order seen from the
## outside; it flips them to Godot's clockwise front faces and gives each face its own
## normal, which is what makes the facets read.

static var _cache := {}


## An n-sided prism or frustum (a cone when top is 0). Centred on the origin.
static func prism(sides: int, bottom: float, top: float, height: float, caps := true) -> ArrayMesh:
	var key := "prism:%d:%s:%s:%s:%s" % [sides, bottom, top, height, caps]
	if _cache.has(key):
		return _cache[key]
	var profile := PackedVector2Array()
	if caps:
		profile.append(Vector2(0.0, -height / 2.0))
	profile.append(Vector2(bottom, -height / 2.0))
	profile.append(Vector2(top, height / 2.0))
	if caps:
		profile.append(Vector2(0.0, height / 2.0))
	var mesh := lathe(profile, sides)
	_cache[key] = mesh
	return mesh


## Spin a (radius, y) profile, listed bottom to top, around the y axis.
## A point with radius 0 closes the shape there (a cap or a tip).
static func lathe(profile: PackedVector2Array, sides: int, twist := 0.0) -> ArrayMesh:
	var key := "lathe:%s:%d:%s" % [profile, sides, twist]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		for s in sides:
			var t0 := TAU * s / sides + twist * i
			var t1 := TAU * (s + 1) / sides + twist * i
			var u0 := TAU * s / sides + twist * (i + 1)
			var u1 := TAU * (s + 1) / sides + twist * (i + 1)
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(u0) * b.x, b.y, sin(u0) * b.x)
			var p11 := Vector3(cos(u1) * b.x, b.y, sin(u1) * b.x)
			# The profile runs bottom to top, so its outward normal in (r, y) is (dy, -dr).
			var d := b - a
			var mid := (t0 + t1) / 2.0
			var out := Vector3(cos(mid) * d.y, -d.x, sin(mid) * d.y)
			if a.x > 0.0001:
				_tri_facing(st, p00, p01, p11 if b.x > 0.0001 else p10, out)
			if b.x > 0.0001:
				_tri_facing(st, p00, p11, p10, out)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A box with its edges and corners cut off, so it catches light like a real object.
static func chamfer_box(size: Vector3, bevel := 0.08) -> ArrayMesh:
	var key := "chamfer:%s:%s" % [size, bevel]
	if _cache.has(key):
		return _cache[key]
	var h := size / 2.0
	var b := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	var st := _begin()
	# A corner point on the face whose normal is along axis `axis` (0 x, 1 y, 2 z).
	var corner := func(sx: float, sy: float, sz: float, axis: int) -> Vector3:
		var p := Vector3(sx * (h.x - b), sy * (h.y - b), sz * (h.z - b))
		match axis:
			0: p.x = sx * h.x
			1: p.y = sy * h.y
			2: p.z = sz * h.z
		return p
	var signs := [-1.0, 1.0]
	# The six faces.
	for axis in 3:
		for s in signs:
			var quad: Array[Vector3] = []
			for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var v := [0.0, 0.0, 0.0]
				v[axis] = s
				var others := [0, 1, 2]
				others.erase(axis)
				v[others[0]] = c[0]
				v[others[1]] = c[1]
				quad.append(corner.call(v[0], v[1], v[2], axis))
			_quad_outward(st, quad, Vector3.ZERO)
	# The twelve edges: between the faces of two axes, at each pair of signs.
	for pair in [[0, 1], [0, 2], [1, 2]]:
		var free: int = 3 - pair[0] - pair[1]
		for s0 in signs:
			for s1 in signs:
				var quad: Array[Vector3] = []
				for f in signs:
					for ax in [pair[0], pair[1]]:
						var v := [0.0, 0.0, 0.0]
						v[pair[0]] = s0
						v[pair[1]] = s1
						v[free] = f
						quad.append(corner.call(v[0], v[1], v[2], ax))
				_quad_outward(st, [quad[0], quad[1], quad[3], quad[2]], Vector3.ZERO)
	# The eight corners.
	for sx in signs:
		for sy in signs:
			for sz in signs:
				var a: Vector3 = corner.call(sx, sy, sz, 0)
				var c: Vector3 = corner.call(sx, sy, sz, 1)
				var d: Vector3 = corner.call(sx, sy, sz, 2)
				_tri_outward(st, a, c, d, Vector3.ZERO)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A lumpy low-poly ball (an icosahedron, optionally split once). `lump` pushes vertices
## in and out by up to that fraction, the same way every time for the same seed.
static func blob(radius: float, scale := Vector3.ONE, detail := 1, lump := 0.0, seed := 0) -> ArrayMesh:
	var key := "blob:%s:%s:%d:%s:%d" % [radius, scale, detail, lump, seed]
	if _cache.has(key):
		return _cache[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(v.normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for d in detail:
		var next := []
		var mids := {}
		var mid := func(i: int, j: int) -> int:
			var k := "%d_%d" % [mini(i, j), maxi(i, j)]
			if not mids.has(k):
				verts.append(((verts[i] + verts[j]) / 2.0).normalized())
				mids[k] = verts.size() - 1
			return mids[k]
		for f in faces:
			var a: int = mid.call(f[0], f[1])
			var b: int = mid.call(f[1], f[2])
			var c: int = mid.call(f[2], f[0])
			next.append_array([[f[0], a, c], [f[1], b, a], [f[2], c, b], [a, b, c]])
		faces = next
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var placed: Array[Vector3] = []
	for v in verts:
		var r := radius * (1.0 + rng.randf_range(-lump, lump))
		placed.append(v * r * scale)
	var st := _begin()
	for f in faces:
		_tri_outward(st, placed[f[0]], placed[f[1]], placed[f[2]], Vector3.ZERO)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A tube swept along a path with a radius per point (limbs, tails, cables, bent pipes).
## Ends are capped with a point, so a radius of 0 at an end makes a tip.
static func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides := 6) -> ArrayMesh:
	var key := "tube:%s:%s:%d" % [path, radii, sides]
	if _cache.has(key):
		return _cache[key]
	var rings: Array = []
	var up := Vector3.UP
	for i in path.size():
		var forward: Vector3
		if i == 0:
			forward = path[1] - path[0]
		elif i == path.size() - 1:
			forward = path[i] - path[i - 1]
		else:
			forward = (path[i + 1] - path[i - 1])
		forward = forward.normalized()
		if absf(forward.dot(up)) > 0.95:
			up = Vector3.FORWARD
		var side := forward.cross(up).normalized()
		var normal := side.cross(forward).normalized()
		up = normal
		var ring: Array[Vector3] = []
		for s in sides:
			var angle := TAU * s / sides
			ring.append(path[i] + (side * cos(angle) + normal * sin(angle)) * radii[i])
		rings.append(ring)
	var st := _begin()
	for i in path.size() - 1:
		var centre := (path[i] + path[i + 1]) / 2.0
		for s in sides:
			var n := (s + 1) % sides
			_quad_outward(st, [rings[i][s], rings[i][n], rings[i + 1][n], rings[i + 1][s]], centre)
	for end in [0, path.size() - 1]:
		if radii[end] > 0.0001:
			var inward := path[1 if end == 0 else end - 1]
			for s in sides:
				_tri_outward(st, path[end], rings[end][s], rings[end][(s + 1) % sides], inward)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## A flat outline (x, y), extruded `depth` along z and centred on it. Concave is fine.
static func extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var key := "extrude:%s:%s" % [outline, depth]
	if _cache.has(key):
		return _cache[key]
	var st := _begin()
	var z := depth / 2.0
	var tris := Geometry2D.triangulate_polygon(outline)
	var clockwise := Geometry2D.is_polygon_clockwise(outline)
	for i in range(0, tris.size(), 3):
		var a := outline[tris[i]]
		var b := outline[tris[i + 1]]
		var c := outline[tris[i + 2]]
		var front := [Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z)]
		var back := [Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(c.x, c.y, -z)]
		_tri_facing(st, front[0], front[1], front[2], Vector3.BACK)
		_tri_facing(st, back[0], back[1], back[2], Vector3.FORWARD)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var edge := b - a
		var out := Vector2(edge.y, -edge.x) if not clockwise else Vector2(-edge.y, edge.x)
		var quad := [Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(b.x, b.y, z), Vector3(a.x, a.y, z)]
		_tri_facing(st, quad[0], quad[1], quad[2], Vector3(out.x, out.y, 0.0))
		_tri_facing(st, quad[0], quad[2], quad[3], Vector3(out.x, out.y, 0.0))
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## An arch outline: a w x h rectangle with a round top (for doorways, windows, signs).
static func arch_outline(width: float, height: float, segments := 6) -> PackedVector2Array:
	var r := width / 2.0
	var points := PackedVector2Array([Vector2(-r, 0.0), Vector2(r, 0.0)])
	for i in range(1, segments):
		var angle := PI * i / segments
		points.append(Vector2(cos(angle) * r, height - r + sin(angle) * r))
	points.append(Vector2(-r, height - r))
	return points


## Several meshes merged into one, each placed by a transform (one draw call per prop).
static func merge(parts: Array) -> ArrayMesh:
	var st := _begin()
	for part in parts:
		var mesh: Mesh = part[0]
		var xform: Transform3D = part[1]
		st.append_from(mesh, 0, xform)
	return st.commit()


## A MeshInstance3D with the PS1 material: the usual way props use these meshes.
static func instance(mesh: Mesh, texture: String, tint := Color.WHITE, xform := Transform3D.IDENTITY,
		emission := Color.BLACK, density := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = xform
	node.material_override = PS1Materials.get_material(texture, tint, false, Vector2.ONE, emission, density)
	return node


## Shorthand for a transform: position, rotation in degrees, scale.
static func at(pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	var basis := Basis.from_euler(rot_deg * PI / 180.0).scaled(scale)
	return Transform3D(basis, pos)


# --- Building blocks ---------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## One flat triangle, given counter-clockwise as seen from the side it faces.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	normal = normal.normalized()
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(c)
	st.set_normal(normal)
	st.add_vertex(b)


## A triangle wound so it faces away from `inside`.
static func _tri_outward(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	_tri_facing(st, a, b, c, (a + b + c) / 3.0 - inside)


## A triangle wound so it faces along `direction`.
static func _tri_facing(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, direction: Vector3) -> void:
	if (b - a).cross(c - a).dot(direction) >= 0.0:
		_tri(st, a, b, c)
	else:
		_tri(st, a, c, b)


## A quad (corners in order round its edge) facing away from `inside`.
static func _quad_outward(st: SurfaceTool, q: Array, inside: Vector3) -> void:
	var centre: Vector3 = (q[0] + q[1] + q[2] + q[3]) / 4.0
	var direction := centre - inside
	_tri_facing(st, q[0], q[1], q[2], direction)
	_tri_facing(st, q[0], q[2], q[3], direction)
