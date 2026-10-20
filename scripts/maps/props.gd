class_name Props
## Low-poly furniture and clutter for the maps, built from LowPoly meshes.
## Each prop is a list of [mesh, texture, tint, transform, (emission)] parts plus one box collider
## (or none). Props are placed through GameMap._prop(), which adds them under the
## navigation region so monsters path around them. Every function takes the position
## of the prop's footprint centre on the floor and a yaw in degrees.

# --- Industrial ----------------------------------------------------------------------

static func crate(map: GameMap, pos: Vector3, yaw := 0.0, size := Vector3(1.2, 1.2, 1.2), tint := Color(0.75, 0.6, 0.45)) -> Node3D:
	var parts := [[LowPoly.chamfer_box(size, 0.06), "wood", tint, LowPoly.at(Vector3(0, size.y / 2.0, 0))]]
	# Corner battens and a stencilled band.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(4, 0.06, 0.06, size.y), "wood", tint.darkened(0.3),
				LowPoly.at(Vector3(sx * (size.x / 2.0 - 0.03), size.y / 2.0, sz * (size.z / 2.0 - 0.03)), Vector3(0, 45, 0))])
	parts.append([LowPoly.chamfer_box(Vector3(size.x + 0.02, 0.12, size.z + 0.02), 0.02), "rust_metal", Color(0.6, 0.55, 0.5),
		LowPoly.at(Vector3(0, size.y * 0.7, 0))])
	return map._prop(parts, pos, yaw, size)


static func barrel(map: GameMap, pos: Vector3, tint := Color(0.55, 0.3, 0.2), tipped := false) -> Node3D:
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.33, 0.08), Vector2(0.36, 0.45),
		Vector2(0.33, 0.82), Vector2(0.3, 0.9), Vector2(0.27, 0.9), Vector2(0.27, 0.86), Vector2(0, 0.86)])
	var body := LowPoly.lathe(profile, 8)
	var parts := [[body, "rust_metal", tint, Transform3D.IDENTITY]]
	for y: float in [0.25, 0.62]:
		parts.append([LowPoly.prism(8, 0.37, 0.37, 0.05), "rust_metal", tint.darkened(0.4), LowPoly.at(Vector3(0, y, 0))])
	if tipped:
		for part in parts:
			part[3] = Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0.45, 0.36, 0)) * part[3]
		return map._prop(parts, pos, 0.0, Vector3(0.9, 0.72, 0.72), Vector3(0, 0.36, 0))
	return map._prop(parts, pos, 0.0, Vector3(0.7, 0.9, 0.7))


static func tank(map: GameMap, pos: Vector3, radius := 1.2, height := 3.0, tint := Color(0.6, 0.55, 0.5)) -> Node3D:
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(radius, 0), Vector2(radius, height * 0.85),
		Vector2(radius * 0.7, height * 0.97), Vector2(radius * 0.25, height), Vector2(0, height)])
	var parts := [[LowPoly.lathe(profile, 10), "rust_metal", tint, Transform3D.IDENTITY]]
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		parts.append([LowPoly.prism(4, 0.08, 0.08, 0.6), "rust_metal", tint.darkened(0.4),
			LowPoly.at(Vector3(cos(angle) * radius * 0.9, 0.3, sin(angle) * radius * 0.9))])
	parts.append([LowPoly.prism(8, 0.12, 0.12, 0.5), "brass", Color.WHITE, LowPoly.at(Vector3(radius, height * 0.5, 0), Vector3(0, 0, 90))])
	parts.append([LowPoly.prism(10, 0.18, 0.18, 0.08), "brass", Color.WHITE, LowPoly.at(Vector3(radius + 0.25, height * 0.5, 0), Vector3(0, 0, 90))])
	return map._prop(parts, pos, 0.0, Vector3(radius * 1.6, height, radius * 1.6))


static func machine(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.45, 0.5, 0.45)) -> Node3D:
	var size := Vector3(2.0, 1.5, 1.2)
	var parts := [
		[LowPoly.chamfer_box(size, 0.1), "panel", tint, LowPoly.at(Vector3(0, size.y / 2.0, 0))],
		[LowPoly.chamfer_box(Vector3(0.9, 0.6, 0.9), 0.08), "rust_metal", tint.darkened(0.2), LowPoly.at(Vector3(-0.4, 1.8, 0))],
		[LowPoly.prism(8, 0.35, 0.35, 0.25), "rust_metal", Color(0.4, 0.38, 0.35), LowPoly.at(Vector3(0.55, 1.6, 0.2), Vector3(90, 0, 0))],
		[LowPoly.prism(6, 0.05, 0.05, 0.5), "brass", Color.WHITE, LowPoly.at(Vector3(0.55, 1.6, 0.55), Vector3(90, 0, 0))],
		[LowPoly.chamfer_box(Vector3(0.5, 0.35, 0.05), 0.02), "panel", Color(0.2, 0.25, 0.2), LowPoly.at(Vector3(-0.5, 1.0, 0.62))],
	]
	return map._prop(parts, pos, yaw, Vector3(size.x, 2.1, size.z))


static func shelf(map: GameMap, pos: Vector3, yaw := 0.0, width := 2.0, height := 2.2, tint := Color(0.55, 0.55, 0.6),
		texture := "rust_metal") -> Node3D:
	var depth := 0.6
	var parts := []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(4, 0.04, 0.04, height), texture, tint.darkened(0.25),
				LowPoly.at(Vector3(sx * (width / 2.0 - 0.04), height / 2.0, sz * (depth / 2.0 - 0.04)), Vector3(0, 45, 0))])
	for i in 4:
		var y := 0.12 + i * (height - 0.2) / 3.0
		parts.append([LowPoly.chamfer_box(Vector3(width, 0.05, depth), 0.015), texture, tint, LowPoly.at(Vector3(0, y, 0))])
	return map._prop(parts, pos, yaw, Vector3(width, height, depth))


## Loot spots on a shelf's boards (world positions), for kits that stock it.
static func shelf_spots(pos: Vector3, yaw: float, width := 2.0, height := 2.2) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for i: int in [1, 2]:
		var y := 0.12 + i * (height - 0.2) / 3.0 + 0.15
		spots.append(pos + Vector3(width * 0.25, y, 0).rotated(Vector3.UP, deg_to_rad(yaw)))
	return spots


static func workbench(map: GameMap, pos: Vector3, yaw := 0.0) -> Node3D:
	var size := Vector3(2.2, 0.95, 0.9)
	var parts := [[LowPoly.chamfer_box(Vector3(size.x, 0.1, size.z), 0.03), "wood", Color(0.6, 0.45, 0.3), LowPoly.at(Vector3(0, 0.9, 0))]]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(4, 0.05, 0.05, 0.85), "rust_metal", Color(0.4, 0.4, 0.4),
				LowPoly.at(Vector3(sx * 1.0, 0.425, sz * 0.38), Vector3(0, 45, 0))])
	parts.append([LowPoly.chamfer_box(Vector3(2.0, 0.05, 0.8), 0.01), "wood", Color(0.5, 0.38, 0.25), LowPoly.at(Vector3(0, 0.2, 0))])
	# A vice and a toolbox on top.
	parts.append([LowPoly.chamfer_box(Vector3(0.25, 0.2, 0.3), 0.03), "rust_metal", Color(0.3, 0.35, 0.5), LowPoly.at(Vector3(-0.8, 1.05, 0.2))])
	parts.append([LowPoly.chamfer_box(Vector3(0.5, 0.25, 0.25), 0.04), "rust_metal", Color(0.75, 0.2, 0.15), LowPoly.at(Vector3(0.5, 1.07, -0.1), Vector3(0, 15, 0))])
	return map._prop(parts, pos, yaw, size)


static func pipe_bundle(map: GameMap, from: Vector3, to: Vector3, count := 3, radius := 0.15, tint := Color(0.6, 0.5, 0.4)) -> Node3D:
	var axis := to - from
	var parts := []
	var side := axis.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var length := axis.length()
	var basis := Basis(Quaternion(Vector3.UP, axis.normalized()))
	for i in count:
		var offset := side * (i - (count - 1) / 2.0) * radius * 2.6
		parts.append([LowPoly.prism(6, radius, radius, length), "pipe", tint, Transform3D(basis, (from + to) / 2.0 - from + offset)])
		# Flanges every couple of metres.
		var flanges := int(length / 2.5)
		for f in flanges:
			var t := (f + 1.0) / (flanges + 1.0)
			parts.append([LowPoly.prism(6, radius * 1.4, radius * 1.4, 0.08), "rust_metal", tint.darkened(0.3),
				Transform3D(basis, axis * t + offset)])
	return map._prop(parts, from, 0.0, Vector3.ZERO)


static func pillar(map: GameMap, pos: Vector3, height: float, radius := 0.35, texture := "concrete", tint := Color.WHITE) -> Node3D:
	var parts := [
		[LowPoly.prism(8, radius, radius, height), texture, tint, LowPoly.at(Vector3(0, height / 2.0, 0))],
		[LowPoly.prism(8, radius * 1.35, radius, 0.3), texture, tint.darkened(0.15), LowPoly.at(Vector3(0, 0.15, 0))],
		[LowPoly.prism(8, radius, radius * 1.35, 0.3), texture, tint.darkened(0.15), LowPoly.at(Vector3(0, height - 0.15, 0))],
	]
	return map._prop(parts, pos, 0.0, Vector3(radius * 2.0, height, radius * 2.0))


static func pallet_stack(map: GameMap, pos: Vector3, yaw := 0.0, layers := 3) -> Node3D:
	var parts := []
	for i in layers:
		var y := i * 0.16
		parts.append([LowPoly.chamfer_box(Vector3(1.2, 0.04, 1.0), 0.01), "wood", Color(0.7, 0.58, 0.42), LowPoly.at(Vector3(0, y + 0.14, 0), Vector3(0, i * 3.0, 0))])
		for x: float in [-0.5, 0.0, 0.5]:
			parts.append([LowPoly.chamfer_box(Vector3(0.1, 0.1, 1.0), 0.01), "wood", Color(0.6, 0.48, 0.34), LowPoly.at(Vector3(x, y + 0.07, 0))])
	return map._prop(parts, pos, yaw, Vector3(1.2, layers * 0.16, 1.0))


static func sacks(map: GameMap, pos: Vector3, seed := 0) -> Node3D:
	var parts := []
	for i in 4:
		var offset := Vector3((i % 2) * 0.55 - 0.27, 0.2 + (i / 2) * 0.32, (i % 2) * 0.1)
		parts.append([LowPoly.blob(0.32, Vector3(1.3, 0.6, 0.9), 1, 0.12, seed + i), "carpet", Color(0.6, 0.55, 0.4), LowPoly.at(offset, Vector3(0, i * 37.0, 0))])
	return map._prop(parts, pos, 0.0, Vector3(1.2, 0.8, 0.8))


# --- Furniture -----------------------------------------------------------------------

static func table(map: GameMap, pos: Vector3, yaw := 0.0, size := Vector3(1.6, 0.78, 0.9), tint := Color(0.6, 0.45, 0.32),
		texture := "wood") -> Node3D:
	var parts := [[LowPoly.chamfer_box(Vector3(size.x, 0.07, size.z), 0.025), texture, tint, LowPoly.at(Vector3(0, size.y - 0.035, 0))]]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(5, 0.035, 0.045, size.y - 0.07), texture, tint.darkened(0.2),
				LowPoly.at(Vector3(sx * (size.x / 2.0 - 0.1), (size.y - 0.07) / 2.0, sz * (size.z / 2.0 - 0.1)))])
	return map._prop(parts, pos, yaw, size)


static func round_table(map: GameMap, pos: Vector3, radius := 0.55, tint := Color(0.85, 0.85, 0.8)) -> Node3D:
	var parts := [
		[LowPoly.prism(10, radius, radius, 0.05), "panel", tint, LowPoly.at(Vector3(0, 0.74, 0))],
		[LowPoly.prism(6, 0.05, 0.05, 0.7), "rust_metal", Color(0.4, 0.4, 0.4), LowPoly.at(Vector3(0, 0.37, 0))],
		[LowPoly.prism(6, 0.3, 0.25, 0.04), "rust_metal", Color(0.4, 0.4, 0.4), LowPoly.at(Vector3(0, 0.02, 0))],
	]
	return map._prop(parts, pos, 0.0, Vector3(radius * 1.4, 0.76, radius * 1.4))


static func chair(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.55, 0.42, 0.3), tipped := false) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(0.44, 0.05, 0.44), 0.015), "wood", tint, LowPoly.at(Vector3(0, 0.45, 0))],
		[LowPoly.chamfer_box(Vector3(0.44, 0.45, 0.04), 0.015), "wood", tint, LowPoly.at(Vector3(0, 0.72, -0.2), Vector3(-8, 0, 0))],
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(4, 0.02, 0.025, 0.45), "wood", tint.darkened(0.25),
				LowPoly.at(Vector3(sx * 0.18, 0.225, sz * 0.18), Vector3(0, 45, 0))])
	if tipped:
		for part in parts:
			part[3] = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, 0.22, 0.45)) * part[3]
	return map._prop(parts, pos, yaw, Vector3.ZERO)


static func desk(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.5, 0.42, 0.35)) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(1.6, 0.06, 0.8), 0.02), "wood", tint, LowPoly.at(Vector3(0, 0.75, 0))],
		[LowPoly.chamfer_box(Vector3(0.45, 0.72, 0.75), 0.03), "panel", tint.darkened(0.15), LowPoly.at(Vector3(0.55, 0.36, 0))],
		[LowPoly.chamfer_box(Vector3(0.05, 0.72, 0.7), 0.01), "panel", tint.darkened(0.15), LowPoly.at(Vector3(-0.76, 0.36, 0))],
		# An old CRT monitor and keyboard.
		[LowPoly.chamfer_box(Vector3(0.45, 0.38, 0.4), 0.06), "panel", Color(0.75, 0.72, 0.62), LowPoly.at(Vector3(-0.2, 0.98, -0.1))],
		[LowPoly.prism(4, 0.22, 0.12, 0.25), "panel", Color(0.7, 0.67, 0.58), LowPoly.at(Vector3(-0.2, 0.98, -0.38), Vector3(-90, 45, 0))],
		[LowPoly.chamfer_box(Vector3(0.45, 0.03, 0.15), 0.01), "panel", Color(0.7, 0.67, 0.58), LowPoly.at(Vector3(-0.2, 0.8, 0.22))],
	]
	return map._prop(parts, pos, yaw, Vector3(1.6, 0.78, 0.8))


static func cabinet(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.5, 0.52, 0.5)) -> Node3D:
	var parts := [[LowPoly.chamfer_box(Vector3(0.9, 1.4, 0.6), 0.04), "panel", tint, LowPoly.at(Vector3(0, 0.7, 0))]]
	for i in 3:
		var y := 0.25 + i * 0.45
		parts.append([LowPoly.chamfer_box(Vector3(0.8, 0.38, 0.03), 0.01), "panel", tint.lightened(0.08), LowPoly.at(Vector3(0, y, 0.31))])
		parts.append([LowPoly.prism(4, 0.02, 0.02, 0.2), "brass", Color.WHITE, LowPoly.at(Vector3(0, y + 0.1, 0.34), Vector3(0, 0, 90))])
	return map._prop(parts, pos, yaw, Vector3(0.9, 1.4, 0.6))


static func bed(map: GameMap, pos: Vector3, yaw := 0.0, size := Vector3(1.0, 0.55, 2.0), sheet := Color(0.8, 0.8, 0.75),
		frame := Color(0.5, 0.5, 0.52)) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(size.x, 0.2, size.z), 0.08), "carpet", sheet, LowPoly.at(Vector3(0, size.y - 0.1, 0))],
		[LowPoly.blob(0.25, Vector3(1.4, 0.45, 0.8), 1, 0.08, 7), "carpet", sheet.lightened(0.15), LowPoly.at(Vector3(0, size.y + 0.05, -size.z / 2.0 + 0.3))],
		[LowPoly.chamfer_box(Vector3(size.x + 0.06, 0.06, size.z + 0.06), 0.02), "rust_metal", frame, LowPoly.at(Vector3(0, size.y - 0.22, 0))],
		[LowPoly.chamfer_box(Vector3(size.x + 0.06, 0.8, 0.06), 0.02), "rust_metal", frame, LowPoly.at(Vector3(0, 0.6, -size.z / 2.0))],
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([LowPoly.prism(5, 0.03, 0.03, size.y - 0.2), "rust_metal", frame,
				LowPoly.at(Vector3(sx * size.x / 2.0, (size.y - 0.2) / 2.0, sz * size.z / 2.0))])
	return map._prop(parts, pos, yaw, size)


static func sofa(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.55, 0.35, 0.35), width := 2.2) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(width, 0.4, 0.9), 0.1), "carpet", tint, LowPoly.at(Vector3(0, 0.25, 0))],
		[LowPoly.chamfer_box(Vector3(width, 0.55, 0.25), 0.1), "carpet", tint.darkened(0.1), LowPoly.at(Vector3(0, 0.65, -0.33), Vector3(-10, 0, 0))],
	]
	for sx: float in [-1.0, 1.0]:
		parts.append([LowPoly.chamfer_box(Vector3(0.22, 0.55, 0.9), 0.08), "carpet", tint.darkened(0.15), LowPoly.at(Vector3(sx * (width / 2.0 - 0.11), 0.4, 0))])
	var seats := int(width / 0.75)
	for i in seats:
		var x := (i - (seats - 1) / 2.0) * (width - 0.4) / seats
		parts.append([LowPoly.blob(0.3, Vector3(1.1, 0.35, 1.2), 0, 0.05, i), "carpet", tint.lightened(0.05), LowPoly.at(Vector3(x, 0.5, 0.05))])
	return map._prop(parts, pos, yaw, Vector3(width, 0.9, 0.9))


static func counter(map: GameMap, pos: Vector3, yaw := 0.0, length := 3.0, tint := Color(0.7, 0.68, 0.62)) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(length, 0.95, 0.7), 0.04), "panel", tint, LowPoly.at(Vector3(0, 0.475, 0))],
		[LowPoly.chamfer_box(Vector3(length + 0.1, 0.06, 0.8), 0.02), "tile", tint.lightened(0.1), LowPoly.at(Vector3(0, 0.98, 0))],
		[LowPoly.chamfer_box(Vector3(0.45, 0.25, 0.4), 0.05), "panel", Color(0.6, 0.6, 0.62), LowPoly.at(Vector3(length * 0.3, 1.13, 0))],
	]
	return map._prop(parts, pos, yaw, Vector3(length, 1.0, 0.8))


static func vending(map: GameMap, pos: Vector3, yaw := 0.0, glow := Color(0.5, 0.8, 1.0)) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(0.95, 1.9, 0.8), 0.06), "panel", Color(0.7, 0.2, 0.2), LowPoly.at(Vector3(0, 0.95, 0))],
		[LowPoly.chamfer_box(Vector3(0.6, 1.2, 0.04), 0.01), "panel", glow * 0.4, LowPoly.at(Vector3(-0.1, 1.15, 0.41)), glow * 0.6],
		[LowPoly.chamfer_box(Vector3(0.6, 0.2, 0.05), 0.02), "rust_metal", Color(0.2, 0.2, 0.2), LowPoly.at(Vector3(-0.1, 0.3, 0.41))],
	]
	return map._prop(parts, pos, yaw, Vector3(0.95, 1.9, 0.8))


static func arcade(map: GameMap, pos: Vector3, yaw := 0.0, glow := Color(0.3, 1.0, 0.6)) -> Node3D:
	var side := PackedVector2Array([Vector2(-0.35, 0), Vector2(0.35, 0), Vector2(0.35, 1.0), Vector2(0.15, 1.25),
		Vector2(0.3, 1.75), Vector2(-0.35, 1.8)])
	var parts := [
		[LowPoly.extrude(side, 0.7), "panel", Color(0.15, 0.15, 0.3), LowPoly.at(Vector3.ZERO, Vector3(0, 90, 0))],
		[LowPoly.chamfer_box(Vector3(0.6, 0.45, 0.04), 0.01), "panel", glow * 0.3, LowPoly.at(Vector3(0, 1.45, 0.25), Vector3(-15, 0, 0)), glow * 0.7],
		[LowPoly.chamfer_box(Vector3(0.62, 0.05, 0.3), 0.01), "panel", Color(0.1, 0.1, 0.1), LowPoly.at(Vector3(0, 1.02, 0.28), Vector3(10, 0, 0))],
		[LowPoly.prism(6, 0.03, 0.03, 0.12), "brass", Color(0.9, 0.2, 0.2), LowPoly.at(Vector3(-0.12, 1.1, 0.3))],
	]
	return map._prop(parts, pos, yaw, Vector3(0.7, 1.8, 0.7))


static func toilet(map: GameMap, pos: Vector3, yaw := 0.0) -> Node3D:
	var bowl := PackedVector2Array([Vector2(0, 0), Vector2(0.16, 0), Vector2(0.15, 0.25), Vector2(0.22, 0.4), Vector2(0.2, 0.42), Vector2(0, 0.42)])
	var parts := [
		[LowPoly.lathe(bowl, 8), "tile", Color(0.9, 0.9, 0.85), LowPoly.at(Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(1, 1, 1.3))],
		[LowPoly.chamfer_box(Vector3(0.45, 0.4, 0.2), 0.04), "tile", Color(0.88, 0.88, 0.84), LowPoly.at(Vector3(0, 0.6, -0.28))],
	]
	return map._prop(parts, pos, yaw, Vector3(0.5, 0.8, 0.7))


static func sink(map: GameMap, pos: Vector3, yaw := 0.0) -> Node3D:
	var basin := PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0), Vector2(0.08, 0.65), Vector2(0.28, 0.82), Vector2(0.27, 0.86), Vector2(0, 0.86)])
	var parts := [
		[LowPoly.lathe(basin, 8), "tile", Color(0.9, 0.9, 0.85), Transform3D.IDENTITY],
		[LowPoly.chamfer_box(Vector3(0.7, 0.9, 0.04), 0.01), "panel", Color(0.6, 0.7, 0.72), LowPoly.at(Vector3(0, 1.5, -0.3))],
	]
	return map._prop(parts, pos, yaw, Vector3(0.55, 0.86, 0.55))


static func plant(map: GameMap, pos: Vector3, tint := Color(0.3, 0.45, 0.25), seed := 0) -> Node3D:
	var pot := PackedVector2Array([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.33, 0.5), Vector2(0.3, 0.52), Vector2(0, 0.48)])
	var parts := [[LowPoly.lathe(pot, 7), "tile", Color(0.6, 0.4, 0.3), Transform3D.IDENTITY]]
	for i in 5:
		var angle := TAU * i / 5.0 + seed
		var tip := Vector3(cos(angle) * 0.45, 1.2 + (i % 2) * 0.3, sin(angle) * 0.45)
		parts.append([LowPoly.tube(PackedVector3Array([Vector3(0, 0.45, 0), tip * 0.5 + Vector3(0, 0.5, 0), tip]),
			PackedFloat32Array([0.06, 0.12, 0.0]), 4), "carpet", tint, Transform3D.IDENTITY])
	return map._prop(parts, pos, 0.0, Vector3(0.6, 0.6, 0.6))


static func tv(map: GameMap, pos: Vector3, yaw := 0.0, on := false) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(0.7, 0.55, 0.55), 0.07), "wood", Color(0.4, 0.3, 0.22), LowPoly.at(Vector3(0, 0.28, 0))],
		[LowPoly.chamfer_box(Vector3(0.5, 0.4, 0.03), 0.04), "panel", Color(0.4, 0.5, 0.6) if on else Color(0.15, 0.2, 0.2),
			LowPoly.at(Vector3(-0.05, 0.3, 0.28)), Color(0.5, 0.6, 0.7) if on else Color.BLACK],
		[LowPoly.prism(4, 0.008, 0.008, 0.5), "rust_metal", Color(0.3, 0.3, 0.3), LowPoly.at(Vector3(0.1, 0.75, -0.1), Vector3(0, 0, 25))],
		[LowPoly.prism(4, 0.008, 0.008, 0.5), "rust_metal", Color(0.3, 0.3, 0.3), LowPoly.at(Vector3(-0.1, 0.75, -0.1), Vector3(0, 0, -25))],
	]
	return map._prop(parts, pos, yaw, Vector3(0.7, 0.55, 0.55))


static func bathtub(map: GameMap, pos: Vector3, yaw := 0.0, water := false) -> Node3D:
	var parts := [[LowPoly.chamfer_box(Vector3(0.8, 0.55, 1.7), 0.2), "tile", Color(0.92, 0.92, 0.88), LowPoly.at(Vector3(0, 0.3, 0))]]
	if water:
		parts.append([LowPoly.chamfer_box(Vector3(0.62, 0.02, 1.5), 0.01), "tile", Color(0.3, 0.45, 0.5), LowPoly.at(Vector3(0, 0.5, 0))])
	return map._prop(parts, pos, yaw, Vector3(0.8, 0.6, 1.7))


static func lamp_post(map: GameMap, pos: Vector3, height := 3.0, glow := Color(1.0, 0.85, 0.6)) -> Node3D:
	var parts := [
		[LowPoly.prism(6, 0.06, 0.05, height), "rust_metal", Color(0.3, 0.3, 0.32), LowPoly.at(Vector3(0, height / 2.0, 0))],
		[LowPoly.prism(6, 0.18, 0.1, 0.2), "rust_metal", Color(0.3, 0.3, 0.32), LowPoly.at(Vector3(0, 0.1, 0))],
		[LowPoly.prism(6, 0.25, 0.08, 0.25), "rust_metal", Color(0.3, 0.3, 0.32), LowPoly.at(Vector3(0, height, 0))],
		[LowPoly.prism(6, 0.1, 0.1, 0.06), "panel", glow * 0.5, LowPoly.at(Vector3(0, height - 0.15, 0)), glow],
	]
	return map._prop(parts, pos, 0.0, Vector3(0.2, height, 0.2))


# --- Outdoors and toys ---------------------------------------------------------------

static func rock(map: GameMap, pos: Vector3, size := 1.0, seed := 0, tint := Color(0.55, 0.55, 0.58), texture := "concrete") -> Node3D:
	var parts := [[LowPoly.blob(size, Vector3(1.2, 0.75, 1.0), 1, 0.25, seed), texture, tint, LowPoly.at(Vector3(0, size * 0.45, 0), Vector3(0, seed * 47.0, 0))]]
	return map._prop(parts, pos, 0.0, Vector3(size * 1.9, size * 1.2, size * 1.6), Vector3(0, size * 0.45, 0))


static func pine(map: GameMap, pos: Vector3, height := 5.0, seed := 0) -> Node3D:
	var parts := [[LowPoly.prism(5, 0.18, 0.12, height * 0.35), "wood", Color(0.35, 0.28, 0.22), LowPoly.at(Vector3(0, height * 0.17, 0))]]
	for i in 3:
		var y := height * (0.3 + i * 0.22)
		var r := height * (0.32 - i * 0.08)
		parts.append([LowPoly.prism(7, r, 0.0, height * 0.42), "snow", Color(0.55, 0.65, 0.6), LowPoly.at(Vector3(0, y, 0), Vector3(0, seed * 31.0 + i * 20.0, 0))])
	return map._prop(parts, pos, 0.0, Vector3(0.5, height, 0.5))


static func fuel_drums(map: GameMap, pos: Vector3, seed := 0) -> void:
	barrel(map, pos, Color(0.6, 0.25, 0.15))
	barrel(map, pos + Vector3(0.75, 0, 0.1), Color(0.25, 0.35, 0.55))
	barrel(map, pos + Vector3(0.3, 0, 0.75) if seed % 2 == 0 else pos + Vector3(-0.2, 0, -0.8), Color(0.6, 0.55, 0.2), seed % 3 == 0)


static func car(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.4, 0.45, 0.5), wrecked := false) -> Node3D:
	var body := PackedVector2Array([Vector2(-2.1, 0.3), Vector2(2.1, 0.3), Vector2(2.15, 0.75), Vector2(1.2, 0.9),
		Vector2(0.7, 1.45), Vector2(-1.0, 1.45), Vector2(-1.6, 0.95), Vector2(-2.15, 0.85)])
	var parts := [
		[LowPoly.extrude(body, 1.7), "panel", tint, LowPoly.at(Vector3.ZERO, Vector3(0, 90, 0))],
		[LowPoly.extrude(PackedVector2Array([Vector2(1.1, 0.95), Vector2(0.65, 1.4), Vector2(-0.95, 1.4), Vector2(-1.5, 0.95)]), 1.72),
			"panel", Color(0.15, 0.18, 0.2), LowPoly.at(Vector3.ZERO, Vector3(0, 90, 0))],
	]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.3, 1.3]:
			parts.append([LowPoly.prism(8, 0.33, 0.33, 0.25), "rust_metal", Color(0.12, 0.12, 0.12), LowPoly.at(Vector3(sx * 0.8, 0.33, sz), Vector3(0, 0, 90))])
	if wrecked:
		for part in parts:
			part[3] = Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(0, 0.1, 0)) * part[3]
	return map._prop(parts, pos, yaw, Vector3(1.8, 1.45, 4.3))


static func slide(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(1.0, 0.75, 0.8)) -> Node3D:
	var parts := [
		[LowPoly.chamfer_box(Vector3(1.0, 0.1, 3.4), 0.03), "panel", tint, LowPoly.at(Vector3(0, 1.0, 1.3), Vector3(-32, 0, 0))],
		[LowPoly.chamfer_box(Vector3(1.0, 0.1, 1.0), 0.03), "panel", tint.darkened(0.1), LowPoly.at(Vector3(0, 1.9, -0.5))],
	]
	for sx: float in [-1.0, 1.0]:
		parts.append([LowPoly.prism(5, 0.05, 0.05, 1.9), "rust_metal", Color(0.9, 0.9, 0.9), LowPoly.at(Vector3(sx * 0.45, 0.95, -0.95))])
		parts.append([LowPoly.prism(5, 0.05, 0.05, 1.9), "rust_metal", Color(0.9, 0.9, 0.9), LowPoly.at(Vector3(sx * 0.45, 0.95, -0.05))])
	for i in 5:
		parts.append([LowPoly.prism(4, 0.03, 0.03, 0.9), "rust_metal", Color(0.9, 0.9, 0.9), LowPoly.at(Vector3(0, 0.3 + i * 0.35, -1.0), Vector3(0, 0, 90))])
	return map._prop(parts, pos, yaw, Vector3(1.0, 2.0, 1.2), Vector3(0, 1.0, -0.5))


static func toy_blocks(map: GameMap, pos: Vector3, seed := 0) -> void:
	var colors := [Color(1.0, 0.6, 0.6), Color(0.6, 0.8, 1.0), Color(1.0, 0.9, 0.5), Color(0.7, 1.0, 0.75)]
	for i in 5:
		var size := 0.5 + (i % 3) * 0.25
		var offset := Vector3((i % 3) * 0.9 - 0.9, 0.0, (i / 3) * 0.9)
		var parts := [[LowPoly.chamfer_box(Vector3.ONE * size, size * 0.12), "panel", colors[(i + seed) % colors.size()], LowPoly.at(Vector3(0, size / 2.0, 0))]]
		map._prop(parts, pos + offset, (seed * 17 + i * 23) % 90, Vector3.ONE * size)


static func giant_ball(map: GameMap, pos: Vector3, radius := 0.8, tint := Color(1.0, 0.55, 0.6)) -> Node3D:
	var parts := [[LowPoly.blob(radius, Vector3.ONE, 1, 0.0, 1), "panel", tint, LowPoly.at(Vector3(0, radius, 0))]]
	return map._prop(parts, pos, 0.0, Vector3.ONE * radius * 1.5, Vector3(0, radius, 0))


static func tent(map: GameMap, pos: Vector3, yaw := 0.0, tint := Color(0.75, 0.45, 0.2)) -> Node3D:
	var outline := PackedVector2Array([Vector2(-1.2, 0), Vector2(1.2, 0), Vector2(0, 1.5)])
	var parts := [
		[LowPoly.extrude(outline, 2.4), "carpet", tint, Transform3D.IDENTITY],
		[LowPoly.prism(4, 0.03, 0.03, 1.7), "rust_metal", Color(0.3, 0.3, 0.3), LowPoly.at(Vector3(0, 0.85, 1.25))],
	]
	return map._prop(parts, pos, yaw, Vector3(2.4, 1.5, 2.4))


static func radio_mast(map: GameMap, pos: Vector3, height := 12.0) -> Node3D:
	var parts := [[LowPoly.prism(3, 0.6, 0.15, height), "rust_metal", Color(0.75, 0.3, 0.25), LowPoly.at(Vector3(0, height / 2.0, 0))]]
	# Cross bracing up the lattice, and guy wires to the ground.
	var steps := int(height / 1.5)
	for i in steps:
		var y := 0.75 + i * 1.5
		var r := lerpf(0.6, 0.15, y / height)
		parts.append([LowPoly.prism(3, r + 0.05, r + 0.05, 0.08), "rust_metal", Color(0.8, 0.8, 0.8), LowPoly.at(Vector3(0, y, 0))])
	for i in 3:
		var angle := TAU * i / 3.0
		var foot := Vector3(cos(angle), 0, sin(angle)) * height * 0.45
		parts.append([LowPoly.tube(PackedVector3Array([Vector3(0, height * 0.8, 0), foot]), PackedFloat32Array([0.02, 0.02]), 3),
			"rust_metal", Color(0.4, 0.4, 0.4), Transform3D.IDENTITY])
	parts.append([LowPoly.blob(0.18, Vector3.ONE, 0), "panel", Color(1.0, 0.2, 0.1) * 0.5, LowPoly.at(Vector3(0, height + 0.1, 0)), Color(1.0, 0.15, 0.1)])
	return map._prop(parts, pos, 0.0, Vector3(1.0, height, 1.0))
