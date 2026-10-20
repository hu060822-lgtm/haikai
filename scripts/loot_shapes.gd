class_name LootShapes
## Builds the mesh for a loot item from its "shape" ("box" if missing) and "size".
## Every mesh is a faceted low-poly model that fits inside the item's size box (the
## collider stays that box). The generic shapes get a more specific profile picked from
## the size and the name where it is obvious: a tall thin cylinder is a bottle or a rod,
## a flat one a disc, a "box" called 手冊 a book, and so on.
## Shapes: box, cylinder, cone, sphere, capsule, plus the specific ones it can pick or
## that can be set directly: book, crate, sheet, bottle, can, jar, mug, bucket, battery,
## spool, rod, bolt, hourglass, button, disc, clock, gear, ring, bulb, helmet, teapot,
## globe, bear, trophy, bell, flower, duster, fang.
## Meshes are cached per shape, size and name, since many items share them.

static var _cache := {}
static var _uv_cache := {}


static func mesh_for(data: Dictionary) -> Mesh:
	var size: Vector3 = data.size
	var item_name: String = data.get("name", "")
	var shape := _pick_shape(data.get("shape", "box"), size, item_name)
	var key := "%s:%s:%s" % [shape, size, item_name.hash()]
	if _cache.has(key):
		return _cache[key]
	var mesh := with_uvs(_build(shape, size, item_name), 1.0 / maxf(maxf(size.x, size.y), maxf(size.z, 0.05)))
	_cache[key] = mesh
	return mesh


## A copy of `mesh` with box-projected UVs (each face takes the two coordinates across
## its normal, times `texel`), so mesh-UV PS1 materials show their texture on LowPoly
## meshes, which come without UVs.
static func with_uvs(mesh: Mesh, texel := 1.0) -> ArrayMesh:
	var key := "%d:%s" % [mesh.get_instance_id(), texel]
	if _uv_cache.has(key):
		return _uv_cache[key]
	var result := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs := PackedVector2Array()
		uvs.resize(verts.size())
		for i in verts.size():
			var v := verts[i]
			var n := normals[i].abs() if i < normals.size() else Vector3.UP
			if n.y >= n.x and n.y >= n.z:
				uvs[i] = Vector2(v.x, v.z) * texel
			elif n.x >= n.z:
				uvs[i] = Vector2(v.z, -v.y) * texel
			else:
				uvs[i] = Vector2(v.x, -v.y) * texel
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_uv_cache[key] = result
	return result


## The specific profile for an item, from its declared shape, its proportions and name.
static func _pick_shape(shape: String, size: Vector3, item_name: String) -> String:
	var has := func(words: Array) -> bool:
		for word in words:
			if item_name.contains(word):
				return true
		return false
	var flat_z := size.z < 0.5 * minf(size.x, size.y)
	match shape:
		"box":
			if has.call(["手冊", "書", "字典", "筆記"]):
				return "book"
			if has.call(["箱"]) and size.y > 0.15:
				return "crate"
			if has.call(["扳手"]):
				return "wrench"
			if has.call(["鑰匙"]):
				return "key"
			if has.call(["襪"]):
				return "sock"
			if has.call(["三明治", "蛋糕"]):
				return "wedge"
			if has.call(["魚"]):
				return "fish"
			if has.call(["錨"]):
				return "anchor"
			if has.call(["電視"]):
				return "tv"
			if has.call(["馬桶"]):
				return "toilet"
			if has.call(["招財貓"]):
				return "bear"
			if size.y <= 0.02 and minf(size.x, size.z) >= 0.05:
				return "sheet"
			return "box"
		"cylinder":
			if flat_z:
				if has.call(["齒輪"]):
					return "gear"
				if has.call(["戒指", "眼鏡"]):
					return "ring"
				if has.call(["錶", "鐘", "計"]):
					return "clock"
				return "disc"
			var tall := size.y / maxf(size.x, size.z)
			if has.call(["螺絲", "螺栓"]):
				return "bolt"
			if has.call(["沙漏"]):
				return "hourglass"
			if has.call(["瓶", "奶"]) and tall > 1.6:
				return "bottle"
			if tall > 2.5:
				return "rod"
			if has.call(["罐頭"]):
				return "can"
			if has.call(["罐"]):
				return "jar"
			if has.call(["杯"]):
				return "mug"
			if has.call(["桶"]):
				return "bucket"
			if has.call(["電池"]):
				return "battery"
			if has.call(["線捲", "線圈"]):
				return "spool"
			if has.call(["按鈕"]):
				return "button"
			return "can"
		"sphere":
			if has.call(["燈泡"]):
				return "bulb"
			if has.call(["帽", "頭盔"]):
				return "helmet"
			if has.call(["壺"]):
				return "teapot"
			if has.call(["雪景球"]):
				return "globe"
			if has.call(["熊"]):
				return "bear"
			return "sphere"
		"cone":
			if has.call(["獎盃", "杯"]):
				return "trophy"
			if has.call(["鐘"]):
				return "bell"
			if has.call(["花"]):
				return "flower"
			if has.call(["撢"]):
				return "duster"
			if has.call(["牙"]):
				return "fang"
			return "cone"
	return shape


static func _build(shape: String, size: Vector3, item_name: String) -> Mesh:
	var r := minf(size.x, size.z) / 2.0
	var h := size.y
	var y0 := -h / 2.0
	match shape:
		"book":
			var cover := clampf(h * 0.18, 0.003, 0.01)
			return LowPoly.merge([
				[LowPoly.chamfer_box(Vector3(size.x, cover, size.z), cover * 0.4), LowPoly.at(Vector3(0, y0 + cover / 2.0, 0))],
				[LowPoly.chamfer_box(Vector3(size.x, cover, size.z), cover * 0.4), LowPoly.at(Vector3(0, -y0 - cover / 2.0, 0))],
				[LowPoly.chamfer_box(Vector3(size.x * 0.94, h - cover * 2.0, size.z * 0.95), 0.002), LowPoly.at(Vector3(size.x * 0.02, 0, 0))],
				[LowPoly.prism(6, h / 2.0, h / 2.0, size.z), LowPoly.at(Vector3(-size.x / 2.0 + h / 2.0, 0, 0), Vector3(90, 0, 0))],
			])
		"crate":
			var band := h * 0.14
			var inset := minf(size.x, size.z) * 0.04
			return LowPoly.merge([
				[LowPoly.chamfer_box(Vector3(size.x - inset * 2.0, h, size.z - inset * 2.0), inset), Transform3D.IDENTITY],
				[LowPoly.chamfer_box(Vector3(size.x, band, size.z), band * 0.3), LowPoly.at(Vector3(0, y0 + band / 2.0, 0))],
				[LowPoly.chamfer_box(Vector3(size.x, band, size.z), band * 0.3), LowPoly.at(Vector3(0, -y0 - band / 2.0, 0))],
				[LowPoly.chamfer_box(Vector3(size.x * 1.0, band * 0.6, size.z * 0.3), band * 0.2), LowPoly.at(Vector3(0, 0, 0))],
			])
		"sheet":
			# A slightly curled sheet: a bent strip across x, extruded along z.
			var t := maxf(h, 0.004)
			var top := PackedVector2Array()
			var bottom := PackedVector2Array()
			for i in 5:
				var f := i / 4.0
				var x := lerpf(-size.x / 2.0, size.x / 2.0, f)
				var lift := (0.5 - absf(f - 0.5)) * minf(size.x, size.z) * 0.06 * (1.0 if i % 2 == 0 else 0.7)
				bottom.append(Vector2(x, y0 + lift))
				top.append(Vector2(x, y0 + lift + t))
			top.reverse()
			bottom.append_array(top)
			return LowPoly.extrude(bottom, size.z)
		"bottle":
			return _lathe_y(size, [[0.0, 0.0], [0.85, 0.0], [1.0, 0.04], [1.0, 0.55], [0.75, 0.68],
				[0.38, 0.78], [0.36, 0.93], [0.44, 0.95], [0.42, 1.0], [0.0, 1.0]], 7)
		"can":
			return _lathe_y(size, [[0.0, 0.0], [0.86, 0.0], [0.97, 0.03], [0.93, 0.07], [0.96, 0.12],
				[0.96, 0.88], [0.93, 0.93], [1.0, 0.97], [0.88, 1.0], [0.0, 1.0]], 8)
		"jar":
			return _lathe_y(size, [[0.0, 0.0], [0.8, 0.0], [0.95, 0.08], [1.0, 0.45], [0.92, 0.7],
				[0.72, 0.78], [0.8, 0.8], [0.8, 0.95], [0.6, 1.0], [0.0, 1.0]], 8)
		"bucket":
			return _lathe_y(size, [[0.0, 0.0], [0.78, 0.0], [0.82, 0.04], [0.95, 0.9], [1.0, 0.92],
				[1.0, 1.0], [0.92, 1.0], [0.9, 0.9], [0.0, 0.9]], 8)
		"battery":
			return _lathe_y(size, [[0.0, 0.0], [0.92, 0.0], [1.0, 0.04], [1.0, 0.86], [0.92, 0.9],
				[0.35, 0.9], [0.35, 1.0], [0.0, 1.0]], 7)
		"spool":
			return _lathe_y(size, [[0.0, 0.0], [1.0, 0.0], [1.0, 0.14], [0.72, 0.16], [0.82, 0.3],
				[0.78, 0.5], [0.82, 0.7], [0.72, 0.84], [1.0, 0.86], [1.0, 1.0], [0.25, 1.0], [0.25, 0.92], [0.0, 0.92]], 8)
		"button":
			return _lathe_y(size, [[0.0, 0.0], [1.0, 0.0], [1.0, 0.35], [0.85, 0.4], [0.7, 0.42],
				[0.68, 0.7], [0.5, 0.92], [0.25, 1.0], [0.0, 1.0]], 8)
		"rod":
			return _lathe_y(size, [[0.0, 0.0], [0.7, 0.0], [1.0, 0.02], [0.85, 0.5], [0.9, 0.97],
				[0.6, 1.0], [0.0, 1.0]], 6)
		"bolt":
			var head := h * 0.16
			var shaft := r * 0.55
			var parts := [[LowPoly.prism(6, r, r, head), LowPoly.at(Vector3(0, -y0 - head / 2.0, 0))],
				[LowPoly.prism(8, r * 0.85, r * 0.7, head * 0.25), LowPoly.at(Vector3(0, -y0 - head - head * 0.12, 0))]]
			var thread := PackedVector2Array([Vector2(0, y0), Vector2(shaft * 0.7, y0)])
			var steps := 7
			for i in steps:
				var y := lerpf(y0 + h * 0.03, -y0 - head * 1.2, (i + 0.5) / steps)
				thread.append(Vector2(shaft, y - h * 0.03))
				thread.append(Vector2(shaft * 0.8, y + h * 0.03))
			thread.append(Vector2(shaft * 0.8, -y0 - head))
			thread.append(Vector2(0, -y0 - head))
			parts.append([LowPoly.lathe(thread, 6), Transform3D.IDENTITY])
			return LowPoly.merge(parts)
		"hourglass":
			return LowPoly.merge([
				[_lathe_y(size, [[0.0, 0.0], [1.0, 0.0], [1.0, 0.08], [0.0, 0.08]], 6), Transform3D.IDENTITY],
				[_lathe_y(size, [[0.0, 0.92], [1.0, 0.92], [1.0, 1.0], [0.0, 1.0]], 6), Transform3D.IDENTITY],
				[_lathe_y(size, [[0.0, 0.08], [0.75, 0.08], [0.8, 0.25], [0.15, 0.5], [0.8, 0.75], [0.75, 0.92], [0.0, 0.92]], 7), Transform3D.IDENTITY],
				[LowPoly.prism(4, r * 0.08, r * 0.08, h * 0.84), LowPoly.at(Vector3(r * 0.88, 0, 0))],
				[LowPoly.prism(4, r * 0.08, r * 0.08, h * 0.84), LowPoly.at(Vector3(-r * 0.88, 0, 0))],
			])
		"mug":
			var body_r := minf(size.x * 0.4, size.z / 2.0)
			var body := _lathe_y(Vector3(body_r * 2.0, h, body_r * 2.0), [[0.0, 0.0], [0.9, 0.0], [1.0, 0.06],
				[1.0, 1.0], [0.85, 1.0], [0.85, 0.15], [0.0, 0.15]], 8)
			var handle := PackedVector3Array()
			var radii := PackedFloat32Array()
			for i in 6:
				var a := lerpf(-PI * 0.45, PI * 0.45, i / 5.0)
				handle.append(Vector3(body_r * 0.85 + cos(a) * (size.x / 2.0 - body_r * 0.85) * 0.9, sin(a) * h * 0.3 + h * 0.05, 0))
				radii.append(h * 0.06)
			return LowPoly.merge([[body, Transform3D.IDENTITY], [LowPoly.tube(handle, radii, 4), Transform3D.IDENTITY]])
		"disc", "clock":
			var d := size.z
			var dr := minf(size.x, size.y) / 2.0
			var crown := 0.0
			var parts := []
			if shape == "clock" and size.y > size.x * 0.9:
				crown = size.y * 0.1
				dr = minf(size.x, size.y - crown * 2.0) / 2.0
				parts.append([LowPoly.prism(6, crown * 0.5, crown * 0.5, crown), LowPoly.at(Vector3(0, dr + crown / 2.0, 0))])
				parts.append([torus(crown * 0.55, crown * 0.18, 6, 4), LowPoly.at(Vector3(0, dr + crown * 1.3, 0), Vector3(90, 0, 0))])
			var face := PackedVector2Array([Vector2(0, -d / 2.0), Vector2(dr * 0.9, -d / 2.0), Vector2(dr, -d * 0.25),
				Vector2(dr, d * 0.3), Vector2(dr * 0.86, d / 2.0), Vector2(dr * 0.8, d * 0.25), Vector2(0, d * 0.25)])
			parts.append([LowPoly.lathe(face, 10), LowPoly.at(Vector3.ZERO, Vector3(90, 0, 0))])
			if shape == "clock":
				# Two hands on the face.
				parts.append([LowPoly.chamfer_box(Vector3(dr * 0.08, dr * 0.6, d * 0.1), 0.0005), LowPoly.at(Vector3(0, dr * 0.25, d * 0.28), Vector3(0, 0, 20))])
				parts.append([LowPoly.chamfer_box(Vector3(dr * 0.08, dr * 0.45, d * 0.1), 0.0005), LowPoly.at(Vector3(dr * 0.2, -dr * 0.05, d * 0.28), Vector3(0, 0, -100))])
			return LowPoly.merge(parts)
		"gear":
			var gr := minf(size.x, size.y) / 2.0
			var teeth := 10
			var outline := PackedVector2Array()
			for i in teeth:
				var a := TAU * i / teeth
				var step := TAU / teeth
				outline.append(Vector2.from_angle(a - step * 0.25) * gr * 0.8)
				outline.append(Vector2.from_angle(a - step * 0.14) * gr)
				outline.append(Vector2.from_angle(a + step * 0.14) * gr)
				outline.append(Vector2.from_angle(a + step * 0.25) * gr * 0.8)
			return LowPoly.merge([
				[LowPoly.extrude(outline, size.z * 0.7), Transform3D.IDENTITY],
				[LowPoly.prism(6, gr * 0.3, gr * 0.3, size.z), LowPoly.at(Vector3.ZERO, Vector3(90, 0, 0))],
			])
		"ring":
			var rr := minf(size.x, size.y) / 2.0
			var band := maxf(size.z * 0.3, rr * 0.14)
			var parts := [[torus(rr - band, band, 8, 4), LowPoly.at(Vector3(0, -band * 0.5, 0), Vector3(90, 0, 0))]]
			if item_name.contains("戒指"):
				parts.append([LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(band * 1.4, band * 0.7), Vector2(band * 1.0, band * 1.6), Vector2(0, band * 1.7)]), 6),
					LowPoly.at(Vector3(0, rr - band * 1.6, 0))])
			else:
				parts.append([LowPoly.prism(8, rr - band, rr - band, band * 0.3), LowPoly.at(Vector3(0, -band * 0.5, 0), Vector3(90, 0, 0))])
			return LowPoly.merge(parts)
		"bulb":
			return _lathe_y(size, [[0.0, 0.0], [0.42, 0.0], [0.46, 0.08], [0.42, 0.14], [0.46, 0.22],
				[0.45, 0.32], [0.75, 0.45], [1.0, 0.65], [0.9, 0.88], [0.5, 1.0], [0.0, 1.0]], 7)
		"helmet":
			return _lathe_y(size, [[0.0, 0.0], [1.0, 0.0], [1.0, 0.08], [0.82, 0.12], [0.8, 0.45],
				[0.66, 0.78], [0.38, 0.96], [0.0, 1.0]], 8, size.x / size.z)
		"teapot":
			var body_size := Vector3(size.x * 0.66, size.y * 0.78, size.z)
			var spout := PackedVector3Array([Vector3(-body_size.x * 0.4, -h * 0.12, 0), Vector3(-size.x * 0.42, h * 0.05, 0), Vector3(-size.x * 0.5, h * 0.2, 0)])
			var handle := PackedVector3Array([Vector3(body_size.x * 0.4, h * 0.15, 0), Vector3(size.x * 0.5, h * 0.05, 0), Vector3(size.x * 0.47, -h * 0.15, 0), Vector3(body_size.x * 0.4, -h * 0.2, 0)])
			return LowPoly.merge([
				[LowPoly.blob(0.5, body_size, 1, 0.0, 0), LowPoly.at(Vector3(0, y0 + body_size.y / 2.0, 0))],
				[LowPoly.tube(spout, PackedFloat32Array([h * 0.08, h * 0.05, h * 0.04]), 5), Transform3D.IDENTITY],
				[LowPoly.tube(handle, PackedFloat32Array([h * 0.04, h * 0.04, h * 0.04, h * 0.04]), 4), Transform3D.IDENTITY],
				[LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(body_size.x * 0.25, 0), Vector2(body_size.x * 0.12, h * 0.1), Vector2(body_size.x * 0.08, h * 0.12), Vector2(0, h * 0.2)]), 6),
					LowPoly.at(Vector3(0, y0 + body_size.y * 0.96, 0))],
			])
		"globe":
			var base_h := h * 0.28
			return LowPoly.merge([
				[_lathe_y(Vector3(size.x, base_h, size.z), [[0.0, 0.0], [1.0, 0.0], [0.8, 1.0], [0.0, 1.0]], 7), LowPoly.at(Vector3(0, y0 + base_h / 2.0, 0))],
				[LowPoly.blob(minf(r, (h - base_h * 0.8) / 2.0), Vector3.ONE, 1, 0.0, 0), LowPoly.at(Vector3(0, -y0 - minf(r, (h - base_h * 0.8) / 2.0), 0))],
			])
		"bear":
			var body_h := h * 0.58
			var head_r := minf(size.x * 0.3, h * 0.22)
			var parts := [
				[LowPoly.blob(0.5, Vector3(size.x * 0.7, body_h, size.z * 0.8), 1, 0.05, 2), LowPoly.at(Vector3(0, y0 + body_h / 2.0, 0))],
				[LowPoly.blob(head_r, Vector3.ONE, 1, 0.05, 5), LowPoly.at(Vector3(0, -y0 - head_r * 1.15, 0))],
				[LowPoly.blob(head_r * 0.4, Vector3(1, 0.8, 1), 0, 0.0, 0), LowPoly.at(Vector3(0, -y0 - head_r * 1.35, -head_r * 0.85))],
			]
			for side in [-1.0, 1.0]:
				parts.append([LowPoly.blob(head_r * 0.35, Vector3.ONE, 0, 0.0, 0), LowPoly.at(Vector3(head_r * 0.75 * side, -y0 - head_r * 0.4, 0))])
				parts.append([LowPoly.blob(0.5, Vector3(size.x * 0.22, body_h * 0.5, size.z * 0.3), 0, 0.0, 0), LowPoly.at(Vector3(size.x * 0.36 * side, y0 + body_h * 0.6, -size.z * 0.1))])
				parts.append([LowPoly.blob(0.5, Vector3(size.x * 0.25, body_h * 0.3, size.z * 0.4), 0, 0.0, 0), LowPoly.at(Vector3(size.x * 0.22 * side, y0 + body_h * 0.15, -size.z * 0.25))])
			return LowPoly.merge(parts)
		"trophy":
			return _lathe_y(size, [[0.0, 0.0], [0.8, 0.0], [0.8, 0.1], [0.55, 0.14], [0.5, 0.2], [0.18, 0.24],
				[0.12, 0.45], [0.3, 0.52], [0.7, 0.62], [1.0, 0.95], [0.92, 1.0], [0.0, 0.9]], 7)
		"bell":
			return _lathe_y(size, [[0.0, 0.0], [0.95, 0.0], [1.0, 0.05], [0.82, 0.18], [0.62, 0.5],
				[0.58, 0.78], [0.42, 0.88], [0.15, 0.9], [0.15, 1.0], [0.0, 1.0]], 8)
		"flower":
			return _lathe_y(size, [[0.0, 0.0], [0.2, 0.0], [0.12, 0.08], [0.1, 0.6], [0.35, 0.68],
				[1.0, 0.82], [0.7, 0.9], [0.3, 1.0], [0.0, 0.95]], 6)
		"duster":
			return _lathe_y(size, [[0.0, 0.0], [0.35, 0.0], [0.35, 0.45], [0.6, 0.5], [1.0, 0.68],
				[0.85, 0.88], [0.4, 1.0], [0.0, 1.0]], 6)
		"fang":
			var fang := PackedVector3Array([Vector3(0, y0, 0), Vector3(0, y0 + h * 0.5, size.z * 0.15), Vector3(0, -y0, -size.z * 0.1)])
			return LowPoly.tube(fang, PackedFloat32Array([r, r * 0.7, 0.0]), 5)
		"cone":
			return _lathe_y(size, [[0.0, 0.0], [1.0, 0.0], [1.0, 0.06], [0.88, 0.1], [0.3, 0.92], [0.0, 1.0]], 7)
		"cylinder":
			return _lathe_y(size, [[0.0, 0.0], [0.9, 0.0], [1.0, 0.05], [1.0, 0.92], [0.9, 1.0], [0.0, 1.0]], 8)
		"sphere":
			var lump := 0.0 if size.x > 0.5 else (0.16 if item_name.contains("煤") or item_name.contains("石") else 0.07)
			return LowPoly.blob(0.5, size, 1, lump, item_name.hash() & 0xffff)
		"capsule":
			return _capsule(size)
		"wrench":
			var length := maxf(size.x, size.z)
			var wide := minf(size.x, size.z)
			var hw := wide * 0.17
			var cx := length / 2.0 - wide * 0.5
			var outline := PackedVector2Array([Vector2(-length / 2.0 + wide * 0.3, -hw)])
			for deg in [-160, -120, -80, -40, -20]:
				outline.append(Vector2(cx, 0) + Vector2.from_angle(deg_to_rad(deg)) * wide * 0.5)
			outline.append(Vector2(cx + wide * 0.1, -wide * 0.13))
			outline.append(Vector2(cx + wide * 0.1, wide * 0.13))
			for deg in [20, 40, 80, 120, 160]:
				outline.append(Vector2(cx, 0) + Vector2.from_angle(deg_to_rad(deg)) * wide * 0.5)
			outline.append(Vector2(-length / 2.0 + wide * 0.3, hw))
			for deg in [60, 120, 180, 240, 300]:
				outline.append(Vector2(-length / 2.0 + wide * 0.3, 0) + Vector2.from_angle(deg_to_rad(deg)) * wide * 0.28)
			return _flat(outline, size)
		"key":
			var length := maxf(size.x, size.z)
			var wide := minf(size.x, size.z)
			var bow := wide * 0.5
			var outline := PackedVector2Array()
			for i in 7:
				var a := deg_to_rad(40.0 + i * 280.0 / 6.0)
				outline.append(Vector2(-length / 2.0 + bow, 0) + Vector2(cos(a), sin(a)) * bow)
			var shaft := wide * 0.13
			outline.append(Vector2(length / 2.0 - wide * 0.4, -shaft))
			outline.append(Vector2(length / 2.0 - wide * 0.4, -shaft - wide * 0.22))
			outline.append(Vector2(length / 2.0 - wide * 0.25, -shaft - wide * 0.22))
			outline.append(Vector2(length / 2.0 - wide * 0.2, -shaft - wide * 0.1))
			outline.append(Vector2(length / 2.0 - wide * 0.1, -shaft - wide * 0.25))
			outline.append(Vector2(length / 2.0, -shaft))
			outline.append(Vector2(length / 2.0, shaft))
			return _flat(outline, size)
		"sock":
			var foot := size.y * 0.32
			return LowPoly.extrude(PackedVector2Array([Vector2(-size.x * 0.1, size.y / 2.0), Vector2(size.x * 0.5, size.y / 2.0),
				Vector2(size.x * 0.45, -size.y / 2.0 + foot), Vector2(size.x * 0.3, -size.y / 2.0), Vector2(-size.x * 0.42, -size.y / 2.0),
				Vector2(-size.x * 0.5, -size.y / 2.0 + foot * 0.5), Vector2(-size.x * 0.2, -size.y / 2.0 + foot), Vector2(-size.x * 0.15, size.y * 0.3)]), size.z)
		"wedge":
			var outline := PackedVector2Array([Vector2(-size.x / 2.0, -size.z / 2.0), Vector2(size.x / 2.0, -size.z / 2.0),
				Vector2(size.x * 0.08, size.z / 2.0), Vector2(-size.x * 0.08, size.z / 2.0)])
			return LowPoly.merge([[LowPoly.extrude(outline, size.y), LowPoly.at(Vector3.ZERO, Vector3(90, 0, 0))]])
		"fish":
			var length := size.z
			var body := Vector3(size.x * 0.8, size.y * 0.9, length * 0.72)
			var tail := PackedVector2Array([Vector2(0, 0), Vector2(length * 0.24, size.y / 2.0), Vector2(length * 0.2, 0), Vector2(length * 0.24, -size.y / 2.0)])
			return LowPoly.merge([
				[LowPoly.blob(0.5, body, 1, 0.04, 9), LowPoly.at(Vector3(0, 0, -length * 0.12))],
				[LowPoly.extrude(tail, size.x * 0.15), LowPoly.at(Vector3(0, 0, length * 0.2), Vector3(0, -90, 0))],
				[LowPoly.extrude(PackedVector2Array([Vector2(-length * 0.15, 0), Vector2(length * 0.12, 0), Vector2(-length * 0.05, size.y * 0.12)]), size.x * 0.1),
					LowPoly.at(Vector3(0, body.y * 0.42, -length * 0.1), Vector3(0, 90, 0))],
			])
		"anchor":
			var stem_w := size.x * 0.1
			var ring_r := size.x * 0.12
			var arc := PackedVector3Array()
			var radii := PackedFloat32Array()
			for i in 7:
				var a := lerpf(PI * 0.15, PI * 0.85, i / 6.0)
				arc.append(Vector3(cos(a) * size.x * 0.42, y0 + size.y * 0.42 - sin(a) * size.y * 0.36, 0))
				radii.append(stem_w * 0.45)
			return LowPoly.merge([
				[LowPoly.chamfer_box(Vector3(stem_w, size.y * 0.78, size.z * 0.6), stem_w * 0.2), LowPoly.at(Vector3(0, y0 + size.y * 0.45, 0))],
				[LowPoly.chamfer_box(Vector3(size.x * 0.6, stem_w * 0.8, size.z * 0.5), stem_w * 0.2), LowPoly.at(Vector3(0, -y0 - ring_r * 2.6, 0))],
				[torus(ring_r, ring_r * 0.3, 8, 4), LowPoly.at(Vector3(0, -y0 - ring_r * 1.3, 0), Vector3(90, 0, 0))],
				[LowPoly.tube(arc, radii, 5), Transform3D.IDENTITY],
				[LowPoly.prism(3, stem_w * 1.1, 0.0, size.y * 0.16), LowPoly.at(arc[0] + Vector3(0, size.y * 0.06, 0), Vector3(0, 0, -20))],
				[LowPoly.prism(3, stem_w * 1.1, 0.0, size.y * 0.16), LowPoly.at(arc[6] + Vector3(0, size.y * 0.06, 0), Vector3(0, 0, 20))],
			])
		"tv":
			var body_h := h * 0.8
			var parts := [
				[LowPoly.chamfer_box(Vector3(size.x, body_h, size.z * 0.9), size.x * 0.05), LowPoly.at(Vector3(0, y0 + body_h / 2.0, -size.z * 0.05))],
				[LowPoly.chamfer_box(Vector3(size.x * 0.66, body_h * 0.68, size.z * 0.1), size.x * 0.04), LowPoly.at(Vector3(-size.x * 0.1, y0 + body_h * 0.52, size.z * 0.42))],
			]
			for i in 2:
				parts.append([LowPoly.prism(6, size.x * 0.035, size.x * 0.035, size.z * 0.08), LowPoly.at(Vector3(size.x * 0.36, y0 + body_h * (0.65 - i * 0.25), size.z * 0.41), Vector3(90, 0, 0))])
			for side in [-1.0, 1.0]:
				parts.append([LowPoly.prism(4, size.x * 0.012, size.x * 0.006, h * 0.32), LowPoly.at(Vector3(size.x * 0.08 * side, -y0 - h * 0.14, 0), Vector3(0, 0, -25 * side))])
			return LowPoly.merge(parts)
		"toilet":
			var bowl_h := h * 0.55
			var bowl := _lathe_y(Vector3(size.x, bowl_h, size.x), [[0.0, 0.0], [0.55, 0.0], [0.6, 0.1], [0.55, 0.3],
				[0.85, 0.75], [1.0, 0.92], [0.95, 1.0], [0.0, 1.0]], 8)
			var stretch := minf(size.z * 0.72 / size.x, 1.6)
			return LowPoly.merge([
				[bowl, LowPoly.at(Vector3(0, y0 + bowl_h / 2.0, -size.z * 0.12), Vector3.ZERO, Vector3(1, 1, stretch))],
				[LowPoly.chamfer_box(Vector3(size.x * 0.9, h * 0.45, size.z * 0.24), size.x * 0.04), LowPoly.at(Vector3(0, -y0 - h * 0.225, size.z * 0.38))],
				[LowPoly.chamfer_box(Vector3(size.x * 0.96, h * 0.05, size.z * 0.28), size.x * 0.02), LowPoly.at(Vector3(0, -y0 - h * 0.025, size.z * 0.36))],
			])
	var bevel := clampf(minf(size.x, minf(size.y, size.z)) * 0.2, 0.003, 0.04)
	return LowPoly.chamfer_box(size, bevel)


## A lathe profile given as (radius fraction, height fraction) pairs, scaled into `size`
## (radius = half the smaller of x and z, centred on the origin). `stretch` widens x.
static func _lathe_y(size: Vector3, points: Array, sides: int, stretch := 1.0) -> Mesh:
	var r := minf(size.x, size.z) / 2.0
	var profile := PackedVector2Array()
	for p in points:
		profile.append(Vector2(p[0] * r, (p[1] - 0.5) * size.y))
	var mesh := LowPoly.lathe(profile, sides)
	if absf(stretch - 1.0) < 0.01:
		return mesh
	return LowPoly.merge([[mesh, LowPoly.at(Vector3.ZERO, Vector3.ZERO, Vector3(maxf(stretch, 1.0), 1, maxf(1.0 / stretch, 1.0)))]])


## A capsule lathed along the item's longest axis.
static func _capsule(size: Vector3) -> Mesh:
	var length := maxf(size.x, maxf(size.y, size.z))
	var rot := Vector3.ZERO
	var across := Vector2(size.x, size.z)
	if length == size.x:
		rot = Vector3(0, 0, 90)
		across = Vector2(size.y, size.z)
	elif length == size.z:
		rot = Vector3(90, 0, 0)
		across = Vector2(size.x, size.y)
	var r := minf(across.x, across.y) / 2.0
	var profile := PackedVector2Array([Vector2(0, -length / 2.0)])
	for i in range(1, 3):
		var a := PI / 2.0 * (1.0 - i / 3.0)
		profile.append(Vector2(cos(a) * r, -length / 2.0 + r - sin(a) * r))
	profile.append(Vector2(r, -length / 2.0 + r))
	profile.append(Vector2(r * 0.92, 0.0))
	profile.append(Vector2(r, length / 2.0 - r))
	for i in range(1, 3):
		var a := PI / 2.0 * i / 3.0
		profile.append(Vector2(cos(a) * r, length / 2.0 - r + sin(a) * r))
	profile.append(Vector2(0, length / 2.0))
	return LowPoly.merge([[LowPoly.lathe(profile, 7), LowPoly.at(Vector3.ZERO, rot)]])


## A flat outline (u along the item's longer horizontal axis, v across it) extruded by
## the item's height and laid flat.
static func _flat(outline: PackedVector2Array, size: Vector3) -> Mesh:
	var yaw := 90.0 if size.z > size.x else 0.0
	return LowPoly.merge([[LowPoly.extrude(outline, size.y), LowPoly.at(Vector3.ZERO, Vector3(90, yaw, 0))]])


## A torus around the y axis: ring radius `major`, tube radius `minor`.
static func torus(major: float, minor: float, sides: int, tube_sides: int) -> Mesh:
	var profile := PackedVector2Array()
	for i in tube_sides + 1:
		var a := -PI / 2.0 + TAU * i / tube_sides
		profile.append(Vector2(major + cos(a) * minor, sin(a) * minor))
	return LowPoly.lathe(profile, sides)
