class_name FacilityKits
## The big set pieces of the random sprawl (see RoomGrid): halls and rooms that give
## each map its own character, plus the dressing for its corridors. Used like RoomKits:
## FacilityKits.kit(name, weight, extra fields).

static func kit(kit_name: String, weight := 1.0, extra := {}) -> Dictionary:
	var entry := {"name": kit_name, "weight": weight, "build": Callable(FacilityKits, kit_name)}
	entry.merge(extra, true)
	return entry


static func _size(room: Dictionary) -> Vector2:
	return Vector2(room.max.x - room.min.x, room.max.y - room.min.y)


## The room's long axis as a world direction, and the short one.
static func _axes(room: Dictionary) -> Array[Vector3]:
	var size := _size(room)
	if size.x >= size.y:
		return [Vector3(1, 0, 0), Vector3(0, 0, 1)]
	return [Vector3(0, 0, 1), Vector3(1, 0, 0)]


static func _yaw_of(dir: Vector3) -> float:
	return rad_to_deg(atan2(dir.x, dir.z))


# --- Factory ---------------------------------------------------------------------------

## A furnace the size of a house, still burning, with coal heaped round it.
static func furnace_hall(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var spots := grid.floor_spots(room, 1, 4.5, 5.5)
	if spots.is_empty():
		spots = [room.center]
	var pos: Vector3 = spots[0]
	var top: float = room.height
	var body := LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(2.4, 0), Vector2(2.5, 0.4), Vector2(2.3, 3.2),
		Vector2(1.6, 4.4), Vector2(0.9, 4.8), Vector2(0, 4.8)]), 8)
	var parts := [[body, "brick", Color(0.7, 0.45, 0.35), Transform3D.IDENTITY],
		[LowPoly.prism(6, 0.7, 0.6, top - 4.6), "rust_metal", Color(0.5, 0.4, 0.35), LowPoly.at(Vector3(0, 4.6, 0))],
		[LowPoly.extrude(LowPoly.arch_outline(1.6, 1.4), 0.3), "rust_metal", Color(0.2, 0.1, 0.05), LowPoly.at(Vector3(0, 0.3, 2.25)),
			Color(1.0, 0.4, 0.05)],
	]
	for i in 6:
		var angle := TAU * i / 6.0
		parts.append([LowPoly.prism(4, 0.12, 0.12, 4.0), "rust_metal", Color(0.35, 0.3, 0.28),
			LowPoly.at(Vector3(cos(angle) * 2.45, 2.0, sin(angle) * 2.45))])
	map._prop(parts, pos, grid.rng.randf_range(0, 360), Vector3(4.8, top, 4.8))
	map._light(pos + Vector3(0, 1.5, 0), Color(1.0, 0.45, 0.1), 1.2, 9.0, true)
	for i in 3 + grid.units(room) / 3:
		var heap := grid.floor_spots(room, 1, 2.0, 3.0)
		if heap.is_empty():
			continue
		Props.rock(map, heap[0], grid.rng.randf_range(0.6, 1.1), grid.rng.randi(), Color(0.12, 0.11, 0.1))
		if grid.rng.randf() < 0.5:
			grid.add_loot(room, heap[0] + Vector3(1.2, 0.2, 0))
	for slot in grid.wall_slots(room, 0.5, 4.0).slice(0, 3):
		Props.barrel(map, slot.pos, Color(0.3, 0.3, 0.32), grid.rng.randf() < 0.3)


## Rows of dead conveyor belts with the last shift's boxes still on them.
static func conveyor_hall(grid: RoomGrid, room: Dictionary) -> void:
	var axes := _axes(room)
	var yaw := _yaw_of(axes[0]) + 90.0
	for pos in grid.floor_spots(room, 3 + grid.units(room), 2.5, 3.5):
		var parts := [
			[LowPoly.chamfer_box(Vector3(4.0, 0.25, 1.2), 0.04), "rust_metal", Color(0.25, 0.25, 0.27), LowPoly.at(Vector3(0, 0.85, 0))],
			[LowPoly.chamfer_box(Vector3(4.0, 0.12, 1.3), 0.02), "rust_metal", Color(0.55, 0.45, 0.2), LowPoly.at(Vector3(0, 0.66, 0))],
		]
		for x: float in [-1.8, -0.6, 0.6, 1.8]:
			for z: float in [-0.5, 0.5]:
				parts.append([LowPoly.prism(4, 0.06, 0.06, 0.62), "rust_metal", Color(0.35, 0.35, 0.36), LowPoly.at(Vector3(x, 0, z))])
		grid.map._prop(parts, pos, yaw, Vector3(4.0, 1.0, 1.3))
		var along := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
		for i in grid.rng.randi_range(0, 2):
			var box_pos: Vector3 = pos + along * grid.rng.randf_range(-1.4, 1.4) + Vector3(0, 0.98, 0)
			Props.crate(grid.map, box_pos, grid.rng.randf_range(-20, 20), Vector3(0.7, 0.55, 0.6), Color(0.75, 0.6, 0.42))
		if grid.rng.randf() < 0.45:
			grid.add_loot(room, pos + Vector3(0, 1.3, 0))
	var y: float = room.height - 1.0
	Props.pipe_bundle(grid.map, Vector3(room.min.x + 0.5, y, room.center.z), Vector3(room.max.x - 0.5, y, room.center.z), 2, 0.18)


## A field of storage tanks joined by pipes overhead.
static func tank_farm(grid: RoomGrid, room: Dictionary) -> void:
	var tanks := grid.floor_spots(room, 2 + grid.units(room) / 2, 2.6, 4.2)
	for i in tanks.size():
		var pos: Vector3 = tanks[i]
		Props.tank(grid.map, pos, grid.rng.randf_range(1.1, 1.7), grid.rng.randf_range(3.5, 5.5), Color(0.55, 0.5, 0.42))
		if i > 0:
			Props.pipe_bundle(grid.map, tanks[i - 1] + Vector3(0, 4.4, 0), pos + Vector3(0, 4.4, 0), 1, 0.22)
		if grid.rng.randf() < 0.5:
			grid.add_loot(room, pos + Vector3(2.0, 0.2, 0.5))
	for slot in grid.wall_slots(room, 0.6, 5.0).slice(0, 2):
		Props.machine(grid.map, slot.pos, slot.yaw)


## Chains and hooks hang from the dark; something used to be hung on them.
static func chain_room(grid: RoomGrid, room: Dictionary) -> void:
	var size := _size(room)
	var count := int(size.x * size.y / 10.0)
	var parts := []
	for i in count:
		var x: float = grid.rng.randf_range(room.min.x + 1.0, room.max.x - 1.0) - room.center.x
		var z: float = grid.rng.randf_range(room.min.y + 1.0, room.max.y - 1.0) - room.center.z
		var low := grid.rng.randf_range(1.6, 3.0)
		var length: float = room.height - low
		parts.append([LowPoly.prism(4, 0.035, 0.035, length), "rust_metal", Color(0.4, 0.33, 0.28), LowPoly.at(Vector3(x, low, z))])
		parts.append([LowPoly.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, -0.25, 0), Vector3(0.12, -0.38, 0), Vector3(0.22, -0.25, 0)]),
			PackedFloat32Array([0.025, 0.025, 0.025, 0.02]), 4), "rust_metal", Color(0.5, 0.4, 0.32), LowPoly.at(Vector3(x, low, z))])
	grid.map._prop(parts, room.center, 0.0, Vector3.ZERO)
	var spots := grid.floor_spots(room, 2)
	if not spots.is_empty():
		Props.table(grid.map, spots[0], grid.rng.randf_range(0, 90), Vector3(2.0, 0.85, 0.9), Color(0.45, 0.3, 0.25))
		grid.add_loot(room, spots[0] + Vector3(0, 0.95, 0), 0.1)
	if spots.size() > 1:
		Props.barrel(grid.map, spots[1], Color(0.4, 0.15, 0.1))


## Factory corridors: pipes along the walls, a valve now and then.
static func pipe_corridor(grid: RoomGrid, room: Dictionary) -> void:
	var axes := _axes(room)
	var size := _size(room)
	var half := (size.x if axes[0].x > 0 else size.y) / 2.0 - 0.3
	var side := axes[1] * ((size.y if axes[0].x > 0 else size.x) / 2.0 - 0.35)
	var y: float = room.height - 0.8
	for s: float in [-1.0, 1.0]:
		if grid.rng.randf() < 0.75:
			Props.pipe_bundle(grid.map, room.center - axes[0] * half + side * s + Vector3(0, y - grid.rng.randf_range(0, 1.5), 0),
				room.center + axes[0] * half + side * s + Vector3(0, y - grid.rng.randf_range(0, 1.5), 0), grid.rng.randi_range(1, 3), 0.12)
	if grid.rng.randf() < 0.4:
		grid.add_loot(room, room.center + side * 0.7 + axes[0] * grid.rng.randf_range(-half * 0.6, half * 0.6) + Vector3(0, 0.2, 0))


# --- Mall ------------------------------------------------------------------------------

## A department store: aisle after aisle of shelving, most of it picked clean.
static func department_store(grid: RoomGrid, room: Dictionary) -> void:
	var axes := _axes(room)
	var size := _size(room)
	var long_len := size.x if axes[0].x > 0 else size.y
	var short_len := size.y if axes[0].x > 0 else size.x
	var yaw := _yaw_of(axes[1])
	var row := -long_len / 2.0 + 3.0
	while row < long_len / 2.0 - 2.5:
		var t := -short_len / 2.0 + 2.2
		while t < short_len / 2.0 - 2.0:
			var pos: Vector3 = room.center + axes[0] * row + axes[1] * t
			if not grid._near_door(room, pos, 2.2) and not grid._near_centre(room, pos, 2.6):
				Props.shelf(grid.map, pos, yaw, 2.0, 2.0, Color(0.7, 0.72, 0.75))
				if grid.rng.randf() < 0.22:
					var shelf_spots := Props.shelf_spots(pos, yaw, 2.0, 2.0)
					grid.add_loot(room, shelf_spots[grid.rng.randi_range(0, shelf_spots.size() - 1)])
			t += 2.1
		row += 4.2
	grid.map._glow(Vector3(3.0, 0.6, 0.05), Vector3(room.center.x, room.height - 1.2, room.min.y + 0.2), Color(1.0, 0.3, 0.25))


## Food court: stalls along the walls under dead menu boards, tables in the middle.
static func food_court(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.8, 4.5)
	for i in mini(slots.size(), 2 + grid.units(room) / 2):
		var slot: Dictionary = slots[i]
		Props.counter(grid.map, slot.pos, slot.yaw, 3.2, Color.from_hsv(grid.rng.randf(), 0.35, 0.85))
		var back := Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw)))
		grid.map._glow(Vector3(2.6, 0.7, 0.05) if absf(back.z) > 0.5 else Vector3(0.05, 0.7, 2.6),
			slot.pos - back * 0.7 + Vector3(0, 2.7, 0), Color.from_hsv(grid.rng.randf(), 0.6, 1.0))
		if grid.rng.randf() < 0.5:
			grid.add_loot(room, slot.pos + Vector3(0, 1.05, 0))
	for pos in grid.floor_spots(room, 3 + grid.units(room), 2.0, 2.8):
		Props.round_table(grid.map, pos, 0.6, Color(0.9, 0.88, 0.8))
		for i in grid.rng.randi_range(1, 3):
			var angle := grid.rng.randf() * TAU
			Props.chair(grid.map, pos + Vector3(cos(angle), 0, sin(angle)) * 0.9, rad_to_deg(angle) + 90.0,
				Color(0.85, 0.3, 0.25), grid.rng.randf() < 0.2)
		if grid.rng.randf() < 0.2:
			grid.add_loot(room, pos + Vector3(0, 0.8, 0))


## Racks of clothes, headless dress forms and a cracked mirror wall.
static func clothing_store(grid: RoomGrid, room: Dictionary) -> void:
	for pos in grid.floor_spots(room, 3 + grid.units(room), 1.8, 2.4):
		var yaw := grid.rng.randf_range(0, 180)
		if grid.rng.randf() < 0.65:
			var parts := [
				[LowPoly.prism(5, 0.03, 0.03, 1.5), "rust_metal", Color(0.7, 0.7, 0.72), LowPoly.at(Vector3(-0.8, 0, 0))],
				[LowPoly.prism(5, 0.03, 0.03, 1.5), "rust_metal", Color(0.7, 0.7, 0.72), LowPoly.at(Vector3(0.8, 0, 0))],
				[LowPoly.prism(5, 0.025, 0.025, 1.6), "rust_metal", Color(0.7, 0.7, 0.72), LowPoly.at(Vector3(-0.8, 1.5, 0), Vector3(0, 0, -90))],
			]
			for i in 6:
				parts.append([LowPoly.chamfer_box(Vector3(0.08, 0.8, 0.5), 0.02), "carpet", Color.from_hsv(grid.rng.randf(), 0.45, 0.7),
					LowPoly.at(Vector3(-0.6 + i * 0.24, 1.05, 0), Vector3(0, grid.rng.randf_range(-10, 10), 0))])
			grid.map._prop(parts, pos, yaw, Vector3(1.7, 1.6, 0.6))
		else:
			var form := LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.2, 0), Vector2(0.03, 0.05), Vector2(0.03, 0.9),
				Vector2(0.17, 0.95), Vector2(0.14, 1.15), Vector2(0.19, 1.4), Vector2(0.08, 1.55), Vector2(0, 1.6)]), 7)
			grid.map._prop([[form, "panel", Color(0.85, 0.8, 0.72), Transform3D.IDENTITY]], pos, yaw, Vector3(0.45, 1.6, 0.45))
		if grid.rng.randf() < 0.3:
			grid.add_loot(room, pos + Vector3(0.5, 0.2, 0.5))
	var slots := grid.wall_slots(room, 0.08, 3.0)
	if not slots.is_empty():
		var slot: Dictionary = slots[0]
		var flat := absf(sin(deg_to_rad(slot.yaw))) < 0.5
		grid.map._glow(Vector3(2.0, 2.2, 0.04) if flat else Vector3(0.04, 2.2, 2.0), slot.pos + Vector3(0, 1.3, 0), Color(0.55, 0.62, 0.68))


## Toy store: shelves of toys, balls everywhere.
static func toy_store(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.45)
	for i in mini(slots.size(), 2 + grid.units(room) * 2):
		Props.shelf(grid.map, slots[i].pos, slots[i].yaw, 2.0, 1.8, Color(0.9, 0.5, 0.4))
		if i % 2 == 0:
			grid.add_loot(room, Props.shelf_spots(slots[i].pos, slots[i].yaw, 2.0, 1.8)[0])
	for pos in grid.floor_spots(room, 2 + grid.units(room), 1.5, 2.2):
		if grid.rng.randf() < 0.5:
			Props.giant_ball(grid.map, pos, grid.rng.randf_range(0.3, 0.7), Color.from_hsv(grid.rng.randf(), 0.6, 0.95))
		else:
			Props.toy_blocks(grid.map, pos, grid.rng.randi())


## Back-of-house corridors: roll cages and flattened boxes.
static func service_corridor(grid: RoomGrid, room: Dictionary) -> void:
	var axes := _axes(room)
	var size := _size(room)
	var half := (size.x if axes[0].x > 0 else size.y) / 2.0 - 2.0
	var side := axes[1] * ((size.y if axes[0].x > 0 else size.x) / 2.0 - 0.6)
	for i in grid.rng.randi_range(1, 3):
		var pos: Vector3 = room.center + axes[0] * grid.rng.randf_range(-half, half) + side * (1.0 if grid.rng.randf() < 0.5 else -1.0)
		if grid._near_door(room, pos, 1.6):
			continue
		Props.crate(grid.map, pos, _yaw_of(axes[0]), Vector3(0.7, 0.9, 1.1), Color(0.8, 0.66, 0.45))
		if grid.rng.randf() < 0.3:
			grid.add_loot(room, pos + Vector3(0, 1.0, 0))


# --- Subway: the tunnels and back rooms of the dead station -------------------------

const GRAFFITI := ["別上車", "它在隧道裡", "末班車不載活人", "不要回頭", "23:59", "下一站：沒有", "我們還在等車",
	"聽到喇叭就跑", "誰拿了我的票", "永夜站"]


## A pair of rails on sleepers from `from` to `to` (floor points, same height), in props of
## about 12 m so lights stay within the renderer's per-object limit. Visual only.
static func rails(map: GameMap, from: Vector3, to: Vector3, rusty := false) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / length
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var pieces := maxi(1, ceili(length / 12.0))
	var piece_len := length / pieces
	var steel := Color(0.5, 0.45, 0.4) if rusty else Color(0.62, 0.62, 0.64)
	for p in pieces:
		var centre := from + dir * piece_len * (p + 0.5)
		var parts := []
		for side: float in [-0.72, 0.72]:
			parts.append([LowPoly.chamfer_box(Vector3(0.08, 0.13, piece_len), 0.015), "rust_metal", steel,
				LowPoly.at(Vector3(side, 0.2, 0))])
		var count := int(piece_len / 0.75)
		for i in count:
			var z := -piece_len / 2.0 + (i + 0.5) * piece_len / count
			parts.append([LowPoly.chamfer_box(Vector3(2.3, 0.12, 0.26), 0.02), "wood", Color(0.3, 0.25, 0.2), LowPoly.at(Vector3(0, 0.07, z))])
		map._prop(parts, centre, yaw, Vector3.ZERO)


## A station sign: white Chinese text on a lit coloured board. yaw faces the reader.
static func station_sign(map: GameMap, pos: Vector3, yaw: float, text: String, board := Color(0.1, 0.35, 0.25),
		width := 0.0, lit := true) -> Node3D:
	var estimate := 0.6
	for ch in text:
		estimate += 0.6 if ch.unicode_at(0) > 0x2000 else 0.33
	var w := maxf(width, estimate)
	var facing := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var parts := [[LowPoly.chamfer_box(Vector3(w, 0.8, 0.08), 0.02), "panel", board, Transform3D.IDENTITY,
		board * (0.35 if lit else 0.08)]]
	var node := map._prop(parts, pos, yaw, Vector3.ZERO)
	var label := Label3D.new()
	label.text = text
	label.font_size = 128
	label.pixel_size = 0.0046
	label.outline_size = 0
	label.modulate = Color(0.95, 0.95, 0.88) if lit else Color(0.6, 0.6, 0.55)
	label.shaded = false
	label.double_sided = false
	label.position = pos + facing * 0.05
	label.rotation.y = deg_to_rad(yaw)
	map.add_child(label)
	return node


## Spray paint on a wall. yaw faces the reader.
static func graffiti(map: GameMap, pos: Vector3, yaw: float, text: String, tint: Color, size := 1.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 128
	label.pixel_size = 0.005 * size
	label.modulate = tint
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.position = pos
	label.rotation = Vector3(0, deg_to_rad(yaw), deg_to_rad(float(text.length() % 5) * 3.0 - 6.0))
	map.add_child(label)


## A hanging fluorescent tube fitting (visual) with its light; most of them flicker.
static func tube_light(map: GameMap, pos: Vector3, yaw: float, energy := 0.8, reach := 9.0, flicker := true,
		color := Color(0.82, 1.0, 0.9)) -> OmniLight3D:
	var parts := [[LowPoly.chamfer_box(Vector3(1.3, 0.08, 0.22), 0.02), "rust_metal", Color(0.55, 0.55, 0.52), Transform3D.IDENTITY],
		[LowPoly.prism(6, 0.04, 0.04, 1.2), "concrete", color, LowPoly.at(Vector3(0, -0.07, 0), Vector3(0, 0, 90)), color * 0.9]]
	map._prop(parts, pos, yaw, Vector3.ZERO)
	return map._light(pos + Vector3(0, -0.3, 0), color, energy, reach, flicker)


## A slatted station bench on two legs.
static func bench(map: GameMap, pos: Vector3, yaw: float, tint := Color(0.75, 0.55, 0.2)) -> Node3D:
	var parts := []
	for i in 4:
		parts.append([LowPoly.chamfer_box(Vector3(1.9, 0.04, 0.09), 0.01), "wood", tint, LowPoly.at(Vector3(0, 0.46, -0.16 + i * 0.11))])
	for i in 2:
		parts.append([LowPoly.chamfer_box(Vector3(1.9, 0.09, 0.04), 0.01), "wood", tint, LowPoly.at(Vector3(0, 0.62 + i * 0.13, -0.22), Vector3(-8, 0, 0))])
	for x: float in [-0.8, 0.8]:
		parts.append([LowPoly.chamfer_box(Vector3(0.06, 0.45, 0.42), 0.01), "rust_metal", Color(0.3, 0.3, 0.32), LowPoly.at(Vector3(x, 0.22, -0.02))])
	return map._prop(parts, pos, yaw, Vector3(1.9, 0.5, 0.5))


## Tunnels off the main line: rails down the middle, cables along the walls, red lamps.
static func rail_tunnel(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var axes := _axes(room)
	var size := _size(room)
	var long_len := size.x if axes[0].x > 0 else size.y
	var short_len := size.y if axes[0].x > 0 else size.x
	rails(map, room.center - axes[0] * (long_len / 2.0 - 0.3), room.center + axes[0] * (long_len / 2.0 - 0.3), true)
	var side := axes[1] * (short_len / 2.0 - 0.25)
	var y: float = minf(room.height - 1.2, 3.2)
	Props.pipe_bundle(map, room.center - axes[0] * (long_len / 2.0 - 0.4) + side + Vector3(0, y, 0),
		room.center + axes[0] * (long_len / 2.0 - 0.4) + side + Vector3(0, y, 0), 3, 0.05, Color(0.15, 0.15, 0.15))
	var lamps := int(long_len / 9.0)
	for i in lamps:
		var at: Vector3 = room.center + axes[0] * (-long_len / 2.0 + (i + 0.5) * long_len / lamps) - side * 0.98 + Vector3(0, 2.0, 0)
		map._glow(Vector3(0.14, 0.2, 0.14), at, Color(1.0, 0.15, 0.08))
	if grid.rng.randf() < 0.45:
		var at: Vector3 = room.center + axes[0] * grid.rng.randf_range(-long_len / 3.0, long_len / 3.0) + side * 0.55
		grid.place_trap("third_rail", at, _yaw_of(axes[0]) + 90.0)
	if grid.rng.randf() < 0.5:
		grid.add_loot(room, room.center + axes[0] * grid.rng.randf_range(-long_len / 3.0, long_len / 3.0) - side * 0.7 + Vector3(0, 0.2, 0))
	if grid.rng.randf() < 0.4:
		graffiti(map, room.center - side * 0.99 + axes[0] * grid.rng.randf_range(-long_len / 3.0, long_len / 3.0) + Vector3(0, 1.6, 0),
			_yaw_of(axes[1]), GRAFFITI[grid.rng.randi_range(0, GRAFFITI.size() - 1)], Color(0.85, 0.15, 0.12))


## An old side platform: a dead track along one wall, benches, a sign to nowhere.
static func side_platform(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var axes := _axes(room)
	var size := _size(room)
	var long_len := size.x if axes[0].x > 0 else size.y
	var short_len := size.y if axes[0].x > 0 else size.x
	var edge := axes[1] * (short_len / 2.0 - 1.6)
	# The track bed: a dark band with rails and a yellow edge line beside it.
	var bed := Vector3(long_len - 0.6, 0.02, 2.6) if axes[0].x > 0 else Vector3(2.6, 0.02, long_len - 0.6)
	map._box(bed, room.center + edge + Vector3(0, 0.01, 0), "concrete", Vector3.ZERO, 0, Color(0.12, 0.12, 0.11))
	rails(map, room.center + edge - axes[0] * (long_len / 2.0 - 0.4), room.center + edge + axes[0] * (long_len / 2.0 - 0.4), true)
	var line := Vector3(long_len - 0.6, 0.02, 0.25) if axes[0].x > 0 else Vector3(0.25, 0.02, long_len - 0.6)
	map._box(line, room.center + edge - axes[1] * 1.45 + Vector3(0, 0.02, 0), "concrete", Vector3.ZERO, 0, Color(0.95, 0.8, 0.15))
	var yaw_in := _yaw_of(-axes[1])
	var count := int(long_len / 6.0)
	for i in count:
		var at: Vector3 = room.center + axes[0] * (-long_len / 2.0 + (i + 0.5) * long_len / count) - axes[1] * (short_len / 2.0 - 0.7)
		if grid._near_door(room, at, 1.4) or grid._near_centre(room, at):
			continue
		bench(map, at, _yaw_of(axes[1]))
		if grid.rng.randf() < 0.35:
			grid.add_loot(room, at + Vector3(0, 0.55, 0))
	var names := ["往 永夜站", "往 終點", "往 舊城", "往 第十三月台"]
	station_sign(map, room.center - axes[1] * (short_len / 2.0 - 0.06) + Vector3(0, 2.6, 0), _yaw_of(axes[1]),
		names[grid.rng.randi_range(0, names.size() - 1)], Color(0.12, 0.3, 0.45), 0.0, grid.rng.randf() < 0.5)
	grid.add_loot(room, room.center + edge + axes[0] * grid.rng.randf_range(-long_len / 3.0, long_len / 3.0) + Vector3(0, 0.3, 0), 0.1)
	if grid.rng.randf() < 0.6:
		graffiti(map, room.center - axes[1] * (short_len / 2.0 - 0.05) + axes[0] * long_len * 0.3 + Vector3(0, 1.3, 0),
			_yaw_of(axes[1]), GRAFFITI[grid.rng.randi_range(0, GRAFFITI.size() - 1)], Color(0.2, 0.75, 0.9), 1.3)


## The staff room: lockers, a table with the last shift's cups, a tiny television.
static func staff_room(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var slots := grid.wall_slots(room, 0.45, 1.4)
	for i in mini(slots.size(), 2 + grid.units(room)):
		var slot: Dictionary = slots[i]
		if i == 0:
			map._add_locker(slot.pos, deg_to_rad(slot.yaw))
		elif i % 2 == 1:
			Props.cabinet(map, slot.pos, slot.yaw, Color(0.45, 0.55, 0.5))
		else:
			Props.desk(map, slot.pos, slot.yaw, Color(0.55, 0.5, 0.42))
			Props.tv(map, slot.pos + Vector3(0, 0.78, 0), slot.yaw, grid.rng.randf() < 0.4)
			grid.add_loot(room, slot.pos + Vector3(0, 0.85, 0))
	for pos in grid.floor_spots(room, 1, 1.8):
		Props.table(map, pos, grid.rng.randf_range(0, 90), Vector3(1.8, 0.78, 0.9), Color(0.6, 0.55, 0.45))
		for k in 3:
			var angle := grid.rng.randf() * TAU
			Props.chair(map, pos + Vector3(cos(angle) * 1.1, 0, sin(angle) * 1.1), rad_to_deg(angle) + 90.0, Color(0.3, 0.4, 0.45),
				grid.rng.randf() < 0.25)
		grid.add_loot(room, pos + Vector3(0, 0.85, 0), 0.05)


## A stretch where the ceiling came down: slabs, rubble, a gap with a light hanging in it.
static func collapsed_section(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	for pos in grid.floor_spots(room, 2 + grid.units(room), 1.8, 2.6):
		if grid.rng.randf() < 0.55:
			Props.rock(map, pos, grid.rng.randf_range(0.7, 1.5), grid.rng.randi(), Color(0.5, 0.5, 0.48))
		else:
			var tilt := grid.rng.randf_range(15, 35)
			map._box(Vector3(2.6, 0.35, 1.8), pos + Vector3(0, 0.7, 0), "concrete", Vector3(grid.rng.randf_range(-10, 10),
				grid.rng.randf_range(0, 180), tilt), Layers.WORLD, Color(0.6, 0.6, 0.57))
			for k in 3:
				map._box(Vector3(0.03, 1.2, 0.03), pos + Vector3(grid.rng.randf_range(-0.8, 0.8), 1.3, grid.rng.randf_range(-0.6, 0.6)),
					"rust_metal", Vector3(grid.rng.randf_range(-30, 30), 0, grid.rng.randf_range(-30, 30)), 0, Color(0.45, 0.3, 0.2))
		if grid.rng.randf() < 0.4:
			grid.add_loot(room, pos + Vector3(1.3, 0.2, 0.3), 0.1)
	for pos in grid.floor_spots(room, 1 + grid.units(room) / 2, 1.5, 0.0):
		grid.place_trap("ceiling_tiles", pos, grid.rng.randf_range(0, 90), {"ceiling": room.height})
	map._light(room.center + Vector3(0, room.height - 1.5, 0), Color(1.0, 0.75, 0.45), 0.5, 7.0, true)


## A tunnel stretch under black water: the rails run on under the surface.
static func flooded_tunnel(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var axes := _axes(room)
	var size := _size(room)
	var long_len := size.x if axes[0].x > 0 else size.y
	rails(map, room.center - axes[0] * (long_len / 2.0 - 0.3), room.center + axes[0] * (long_len / 2.0 - 0.3), true)
	map._box(Vector3(size.x - 0.2, 0.04, size.y - 0.2), room.center + Vector3(0, 0.3, 0), "tile", Vector3.ZERO, 0,
		Color(0.06, 0.12, 0.12)).get_child(0).material_override = PS1Materials.get_material(
			"tile", Color(0.05, 0.1, 0.1), false, Vector2.ONE, Color(0.01, 0.04, 0.04), 1.5)
	for pos in grid.floor_spots(room, 2 + grid.units(room), 1.2, 0.0):
		if grid.rng.randf() < 0.5:
			Props.crate(map, pos + Vector3(0, 0.05, 0), grid.rng.randf_range(0, 90), Vector3(0.7, 0.4, 0.6), Color(0.45, 0.4, 0.3))
		else:
			grid.add_loot(room, pos + Vector3(0, 0.45, 0), 0.1)
	map._light(room.center + Vector3(0, 1.4, 0), Color(0.35, 0.8, 0.75), 0.5, maxf(size.x, size.y) * 0.5, true)


## A newsstand kiosk: a counter, magazine racks, a fridge still humming.
static func kiosk(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var slots := grid.wall_slots(room, 0.45, 2.2)
	for i in mini(slots.size(), 3 + grid.units(room)):
		var slot: Dictionary = slots[i]
		match i % 3:
			0:
				Props.vending(map, slot.pos, slot.yaw, Color(0.6, 0.95, 1.0))
			1:
				Props.shelf(map, slot.pos, slot.yaw, 2.0, 1.7, Color(0.8, 0.35, 0.2))
				grid.add_loot(room, Props.shelf_spots(slot.pos, slot.yaw, 2.0, 1.7)[0])
			_:
				Props.counter(map, slot.pos, slot.yaw, 2.4, Color(0.85, 0.7, 0.3))
				grid.add_loot(room, slot.pos + Vector3(0, 1.05, 0))
	if not slots.is_empty():
		var slot: Dictionary = slots[0]
		station_sign(map, slot.pos + Vector3(0, 2.7, 0) - Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw))) * 0.35, slot.yaw,
			"書報攤", Color(0.55, 0.12, 0.1))


## 失物招領: shelf after shelf of umbrellas, suitcases and bags nobody came back for.
static func lost_and_found(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var slots := grid.wall_slots(room, 0.45, 2.2)
	for i in mini(slots.size(), 4 + grid.units(room) * 2):
		var slot: Dictionary = slots[i]
		Props.shelf(map, slot.pos, slot.yaw, 2.0, 2.2, Color(0.5, 0.48, 0.42))
		var spots := Props.shelf_spots(slot.pos, slot.yaw, 2.0, 2.2)
		grid.add_loot(room, spots[grid.rng.randi_range(0, spots.size() - 1)], 0.25)
	for pos in grid.floor_spots(room, 3 + grid.units(room), 1.4, 1.8):
		var tint := Color.from_hsv(grid.rng.randf(), 0.4, 0.5)
		Props.crate(map, pos, grid.rng.randf_range(0, 90), Vector3(0.75, 0.5, 0.3), tint)  # a suitcase
		grid.add_loot(room, pos + Vector3(0, 0.7, 0), 0.2)
	if not slots.is_empty():
		var slot: Dictionary = slots[0]
		station_sign(map, slot.pos + Vector3(0, 2.75, 0) - Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw))) * 0.38, slot.yaw,
			"失物招領", Color(0.5, 0.35, 0.1))
	map._light(room.center + Vector3(0, room.height - 0.8, 0), Color(1.0, 0.9, 0.7), 0.6, 9.0, true)


# --- Dreamcore -------------------------------------------------------------------------

## A room where the furniture is three times too big. You can walk under the table.
static func giant_room(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var spots := grid.floor_spots(room, 2, 4.5, 5.0)
	if not spots.is_empty():
		var pos: Vector3 = spots[0]
		var tint := Color(0.95, 0.8, 0.65)
		for sx: float in [-3.0, 3.0]:
			for sz: float in [-1.8, 1.8]:
				map._box(Vector3(0.5, 3.0, 0.5), pos + Vector3(sx, 1.5, sz), "wood", Vector3.ZERO, Layers.WORLD, tint)
		map._box(Vector3(7.0, 0.35, 4.2), pos + Vector3(0, 3.17, 0), "wood", Vector3.ZERO, Layers.WORLD, tint)
		var cup := LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.7, 0), Vector2(0.9, 1.6), Vector2(0.82, 1.6), Vector2(0, 0.2)]), 9)
		map._prop([[cup, "panel", Color(1.0, 0.75, 0.8), Transform3D.IDENTITY]], pos + Vector3(1.2, 3.35, 0.4), 0.0, Vector3.ZERO)
		grid.add_loot(room, pos + Vector3(0, 0.2, 0), 0.15)
	if spots.size() > 1:
		var pos: Vector3 = spots[1]
		var tint := Color(0.7, 0.85, 1.0)
		for sx: float in [-1.3, 1.3]:
			for sz: float in [-1.3, 1.3]:
				map._box(Vector3(0.35, 2.0, 0.35), pos + Vector3(sx, 1.0, sz), "wood", Vector3.ZERO, Layers.WORLD, tint)
		map._box(Vector3(3.0, 0.3, 3.0), pos + Vector3(0, 2.15, 0), "wood", Vector3.ZERO, Layers.WORLD, tint)
		map._box(Vector3(3.0, 3.2, 0.3), pos + Vector3(0, 3.9, -1.35), "wood", Vector3.ZERO, Layers.WORLD, tint)
	for pos in grid.floor_spots(room, 2, 2.0, 3.0):
		Props.giant_ball(map, pos, grid.rng.randf_range(0.9, 1.4), Color.from_hsv(grid.rng.randf(), 0.35, 1.0))


## A staircase that goes up to a door in the wall, and nowhere else.
static func stair_room(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 2.4, 6.0)
	if slots.is_empty():
		return
	var slot: Dictionary = slots[0]
	var map := grid.map
	var facing := Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw)))  # into the room
	var along := Vector3(facing.z, 0, -facing.x)
	var tint := Color(0.95, 0.9, 1.0)
	var landing: Vector3 = slot.pos - facing * 1.3 + Vector3(0, 2.4, 0)
	map._box(Vector3(2.6, 0.3, 2.6) if absf(facing.x) < 0.5 else Vector3(2.6, 0.3, 2.6), landing + Vector3(0, -0.15, 0), "panel",
		Vector3.ZERO, Layers.WORLD, tint)
	for leg: float in [-1.1, 1.1]:
		map._box(Vector3(0.3, 2.25, 0.3), landing + along * leg + Vector3(0, -1.4, 0), "panel", Vector3.ZERO, Layers.WORLD, tint)
	# The ramp up to it, a 25 degree slope with the look of stairs.
	var run := 2.4 / tan(deg_to_rad(25.0))
	var ramp_centre: Vector3 = slot.pos - facing * 1.3 + along * (1.3 + run / 2.0) + Vector3(0, 1.2, 0)
	map._box(Vector3(run / cos(deg_to_rad(25.0)) + 0.4, 0.3, 1.8), ramp_centre, "wood",
		Vector3(0, rad_to_deg(atan2(-along.z, along.x)), -25.0), Layers.WORLD, Color(0.95, 0.85, 0.72))
	var door_pos: Vector3 = slot.pos - facing * 2.35 + Vector3(0, 2.4, 0)
	map._box(Vector3(1.3, 2.3, 0.1) if absf(facing.x) < 0.5 else Vector3(0.1, 2.3, 1.3), door_pos + Vector3(0, 1.15, 0), "wood",
		Vector3.ZERO, Layers.WORLD, Color.WHITE)
	grid.add_loot(room, landing + Vector3(0, 0.2, 0), 0.25)


## A room of doors. Most of them are painted on; one is real, and goes anywhere.
static func door_room(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.08, 2.2)
	var real_door := grid.map is EndlessAfternoon
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if i == 0 and real_door:
			var door := DreamDoor.new()
			door.map = grid.map
			door.position = slot.pos
			door.rotation.y = deg_to_rad(slot.yaw)
			grid.map._nav.add_child(door)
			continue
		var facing := Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw)))
		grid.map._box(Vector3(1.2, 2.2, 0.04) if absf(facing.z) > 0.5 else Vector3(0.04, 2.2, 1.2), slot.pos + Vector3(0, 1.1, 0),
			"wood", Vector3.ZERO, 0, Color.from_hsv(grid.rng.randf(), 0.15, 1.0))
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


## Everything is on the ceiling: table, chairs, a lamp. The floor is bare.
static func upside_down(grid: RoomGrid, room: Dictionary) -> void:
	var map := grid.map
	var top: float = room.height
	var parts := []
	var tint := Color(0.95, 0.8, 0.65)
	parts.append([LowPoly.chamfer_box(Vector3(2.0, 0.08, 1.1), 0.02), "wood", tint, LowPoly.at(Vector3(0, top - 0.78, 0))])
	for sx: float in [-0.9, 0.9]:
		for sz: float in [-0.45, 0.45]:
			parts.append([LowPoly.prism(4, 0.04, 0.04, 0.74), "wood", tint, LowPoly.at(Vector3(sx, top - 0.74, sz))])
	for i in 4:
		var angle := TAU * i / 4.0 + 0.4
		var at := Vector3(cos(angle) * 1.4, 0, sin(angle) * 1.1)
		parts.append([LowPoly.chamfer_box(Vector3(0.45, 0.06, 0.45), 0.01), "wood", Color(0.7, 0.85, 1.0), LowPoly.at(at + Vector3(0, top - 0.46, 0))])
		parts.append([LowPoly.chamfer_box(Vector3(0.45, 0.5, 0.05), 0.01), "wood", Color(0.7, 0.85, 1.0),
			LowPoly.at(at + Vector3(0, top - 0.75, 0), Vector3(0, -rad_to_deg(angle) + 90.0, 0))])
	parts.append([LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.35, 0), Vector2(0.15, 0.4), Vector2(0, 0.4)]), 7),
		"panel", Color(1.0, 0.9, 0.6), LowPoly.at(Vector3(0, top - 0.4, 2.0)), Color(0.6, 0.5, 0.25)])
	map._prop(parts, room.center, grid.rng.randf_range(0, 360), Vector3.ZERO)
	map._light(room.center + Vector3(0, 0.3, 0), Color(1.0, 0.9, 0.7), 0.8, 9.0, false)
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


## Dream corridors: pictures of nothing in frames, the odd chair facing the wall.
static func dream_corridor(grid: RoomGrid, room: Dictionary) -> void:
	for slot in grid.wall_slots(room, 0.06, 3.5):
		if grid.rng.randf() < 0.6:
			var facing := Vector3(sin(deg_to_rad(slot.yaw)), 0, cos(deg_to_rad(slot.yaw)))
			grid.map._glow(Vector3(0.9, 0.7, 0.03) if absf(facing.z) > 0.5 else Vector3(0.03, 0.7, 0.9), slot.pos + Vector3(0, 1.7, 0),
				Color.from_hsv(grid.rng.randf(), 0.25, 0.95))
	if grid.rng.randf() < 0.35:
		var spots := grid.floor_spots(room, 1, 0.8, 0.0)
		if not spots.is_empty():
			Props.chair(grid.map, spots[0], grid.rng.randf_range(0, 360), Color(1.0, 0.75, 0.8))
