class_name RoomKits
## What goes inside the random rooms of a wing (see RoomGrid). Each kit fills one
## room: props along the walls and in clusters, loot spots, sometimes a locker.
## Maps pick kits for their wings with RoomKits.kit(name, weight, extra fields).

static func kit(kit_name: String, weight := 1.0, extra := {}) -> Dictionary:
	var entry := {"name": kit_name, "weight": weight, "build": Callable(RoomKits, kit_name)}
	entry.merge(extra, true)
	return entry


# --- Industrial (the factory) ----------------------------------------------------------

static func storage(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.45)
	for i in mini(slots.size(), 3 + grid.units(room) * 2):
		var slot: Dictionary = slots[i]
		Props.shelf(grid.map, slot.pos, slot.yaw, 2.0, 2.2)
		if i % 2 == 0:
			for spot in Props.shelf_spots(slot.pos, slot.yaw):
				grid.add_loot(room, spot)
				break
	for pos in grid.floor_spots(room, 2 + grid.units(room)):
		var roll := grid.rng.randi_range(0, 2)
		if roll == 0:
			Props.crate(grid.map, pos, grid.rng.randf_range(0, 90))
			Props.crate(grid.map, pos + Vector3(0, 1.2, 0), grid.rng.randf_range(0, 90), Vector3(0.9, 0.9, 0.9))
		elif roll == 1:
			Props.pallet_stack(grid.map, pos, grid.rng.randf_range(0, 90), grid.rng.randi_range(2, 5))
		else:
			grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func pump_room(grid: RoomGrid, room: Dictionary) -> void:
	var spots := grid.floor_spots(room, 1 + grid.units(room), 2.4)
	for pos in spots:
		Props.tank(grid.map, pos, grid.rng.randf_range(0.9, 1.4), grid.rng.randf_range(2.4, 3.6))
		grid.add_loot(room, pos + Vector3(1.8, 0.2, 0.4))
	var y: float = room.height - 0.8
	Props.pipe_bundle(grid.map, Vector3(room.min.x + 0.6, y, room.min.y + 0.6), Vector3(room.max.x - 0.6, y, room.min.y + 0.6), 3, 0.14)
	Props.pipe_bundle(grid.map, Vector3(room.min.x + 0.6, y - 0.9, room.max.y - 0.6), Vector3(room.max.x - 0.6, y - 0.9, room.max.y - 0.6), 2, 0.2)
	var slots := grid.wall_slots(room)
	if not slots.is_empty():
		Props.machine(grid.map, slots[0].pos, slots[0].yaw)


static func workshop(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.6, 3.0)
	for i in mini(slots.size(), 2 + grid.units(room)):
		var slot: Dictionary = slots[i]
		if i % 3 == 2:
			Props.machine(grid.map, slot.pos, slot.yaw)
		else:
			Props.workbench(grid.map, slot.pos, slot.yaw)
			grid.add_loot(room, slot.pos + Vector3(0, 1.1, 0))
	for pos in grid.floor_spots(room, 2):
		Props.barrel(grid.map, pos, Color(0.5, 0.45, 0.3), grid.rng.randf() < 0.3)


static func locker_room(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.45, 1.4)
	var placed := 0
	for slot in slots:
		if placed >= 2:
			break
		grid.map._add_locker(slot.pos, deg_to_rad(slot.yaw))
		placed += 1
	for slot in slots.slice(placed, placed + 3):
		Props.cabinet(grid.map, slot.pos, slot.yaw)
	for pos in grid.floor_spots(room, 2):
		Props.table(grid.map, pos, grid.rng.randf_range(0, 180), Vector3(1.8, 0.45, 0.4), Color(0.5, 0.4, 0.3))
		grid.add_loot(room, pos + Vector3(0, 0.6, 0))


static func coal_bunker(grid: RoomGrid, room: Dictionary) -> void:
	for pos in grid.floor_spots(room, 3 + grid.units(room), 2.0):
		var size := grid.rng.randf_range(0.8, 1.6)
		Props.rock(grid.map, pos, size, grid.rng.randi(), Color(0.15, 0.14, 0.14), "concrete")
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))
	var slots := grid.wall_slots(room)
	if not slots.is_empty():
		Props.sacks(grid.map, slots[0].pos, grid.rng.randi())


static func office(grid: RoomGrid, room: Dictionary) -> void:
	var spots := grid.floor_spots(room, 2 + grid.units(room), 2.0)
	for pos in spots:
		var yaw := grid.rng.randf_range(-20, 20) + 180.0 * grid.rng.randi_range(0, 1)
		Props.desk(grid.map, pos, yaw)
		Props.chair(grid.map, pos + Vector3(0, 0, 0.7).rotated(Vector3.UP, deg_to_rad(yaw)), yaw + 180.0, Color(0.3, 0.3, 0.35), grid.rng.randf() < 0.25)
		grid.add_loot(room, pos + Vector3(0.4, 0.85, 0).rotated(Vector3.UP, deg_to_rad(yaw)))
	for slot in grid.wall_slots(room, 0.4).slice(0, 3):
		Props.cabinet(grid.map, slot.pos, slot.yaw)


static func boiler_annex(grid: RoomGrid, room: Dictionary) -> void:
	var centre: Vector3 = room.center
	var spots := grid.floor_spots(room, 1, 3.0)
	if not spots.is_empty():
		centre = spots[0]
	Props.tank(grid.map, centre, 1.8, 4.2, Color(0.45, 0.35, 0.28))
	var glow := grid.map._glow(Vector3(0.9, 0.6, 0.1), centre + Vector3(0, 1.0, 1.82), Color(1.0, 0.4, 0.1))
	glow.rotation = Vector3.ZERO
	grid.map._light(centre + Vector3(0, 1.0, 2.6), Color(1.0, 0.45, 0.15), 1.0, 7.0, true)
	grid.add_loot(room, centre + Vector3(2.4, 0.2, 1.5))
	grid.add_loot(room, centre + Vector3(-2.4, 0.2, -1.0))
	Props.pipe_bundle(grid.map, centre + Vector3(0, 4.2, 0), centre + Vector3(0, room.height, 0), 1, 0.4)


## The deepest room: a locked-up stash worth the walk.
static func vault(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.45, 1.6)
	if not slots.is_empty():
		grid.map._add_locker(slots[0].pos, deg_to_rad(slots[0].yaw))
	for slot in slots.slice(1, 3):
		Props.crate(grid.map, slot.pos, slot.yaw, Vector3(1.0, 0.8, 0.8), Color(0.45, 0.5, 0.4))
		grid.add_loot(room, slot.pos + Vector3(0, 1.0, 0), 0.6)
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0), 0.6)


static func bare(grid: RoomGrid, room: Dictionary) -> void:
	for pos in grid.floor_spots(room, 1 + grid.units(room)):
		Props.barrel(grid.map, pos, Color(0.45, 0.3, 0.2), grid.rng.randf() < 0.4)
	for pos in grid.floor_spots(room, 1):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


# --- Mall back-of-house ----------------------------------------------------------------

static func stockroom(grid: RoomGrid, room: Dictionary) -> void:
	# Rows of tall shelving through the room.
	var w: float = room.max.x - room.min.x
	var d: float = room.max.y - room.min.y
	var along_x := w >= d
	var rows := int((d if along_x else w) / 3.2) - 1
	for r in rows:
		var t: float = (r + 1) * (d if along_x else w) / (rows + 1)
		var length: float = (w if along_x else d) - 5.0
		var count := int(length / 2.2)
		for i in count:
			var u: float = 2.5 + 1.1 + i * 2.2
			var pos := Vector3(room.min.x + u, 0, room.min.y + t) if along_x else Vector3(room.min.x + t, 0, room.min.y + u)
			if grid._near_door(room, pos, 1.8) or grid._near_centre(room, pos):
				continue
			Props.shelf(grid.map, pos, 0.0 if along_x else 90.0, 2.0, 2.4, Color(0.7, 0.7, 0.72))
			if grid.rng.randf() < 0.3:
				grid.add_loot(room, Props.shelf_spots(pos, 0.0 if along_x else 90.0, 2.0, 2.4)[grid.rng.randi_range(0, 1)])


static func back_office(grid: RoomGrid, room: Dictionary) -> void:
	office(grid, room)
	var slots := grid.wall_slots(room)
	if slots.size() > 3:
		Props.vending(grid.map, slots[3].pos, slots[3].yaw, Color(0.9, 0.9, 0.5))


static func restroom(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.45, 1.2)
	for i in mini(slots.size(), 6):
		var slot: Dictionary = slots[i]
		if i % 2 == 0:
			Props.toilet(grid.map, slot.pos, slot.yaw)
		else:
			Props.sink(grid.map, slot.pos, slot.yaw)
	for pos in grid.floor_spots(room, 1):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func food_stall(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.6, 3.4)
	for i in mini(slots.size(), 2):
		Props.counter(grid.map, slots[i].pos, slots[i].yaw, 3.0, Color(0.8, 0.6, 0.4))
		grid.add_loot(room, slots[i].pos + Vector3(0, 1.1, 0))
	for pos in grid.floor_spots(room, 3 + grid.units(room), 1.8):
		Props.round_table(grid.map, pos)
		Props.chair(grid.map, pos + Vector3(0.7, 0, 0), -90.0, Color(0.8, 0.3, 0.25), grid.rng.randf() < 0.3)
		Props.chair(grid.map, pos + Vector3(-0.7, 0, 0), 90.0, Color(0.8, 0.3, 0.25))


static func arcade_hall(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.5, 1.3)
	var colors := [Color(0.3, 1.0, 0.6), Color(1.0, 0.4, 0.8), Color(0.4, 0.7, 1.0), Color(1.0, 0.8, 0.3)]
	for i in mini(slots.size(), 10):
		Props.arcade(grid.map, slots[i].pos, slots[i].yaw, colors[i % colors.size()])
		if i % 4 == 1:
			grid.add_loot(room, slots[i].pos + Vector3(0, 0.2, 0).rotated(Vector3.UP, 0) + Vector3(sin(deg_to_rad(slots[i].yaw)), 0, cos(deg_to_rad(slots[i].yaw))) * 0.8)


static func cinema(grid: RoomGrid, room: Dictionary) -> void:
	# Rows of seats facing a dead screen on the north wall.
	grid.map._glow(Vector3(room.max.x - room.min.x - 3.0, 2.4, 0.05), Vector3(room.center.x, 3.0, room.min.y + 0.25), Color(0.25, 0.27, 0.32))
	var rows := int((room.max.y - room.min.y - 6.0) / 1.6)
	for r in rows:
		var z: float = room.min.y + 4.5 + r * 1.6
		var x: float = room.min.x + 2.0
		while x < room.max.x - 2.0:
			var pos := Vector3(x, 0, z)
			if not grid._near_door(room, pos, 1.6) and not grid._near_centre(room, pos):
				Props.chair(grid.map, pos, 180.0, Color(0.55, 0.15, 0.18))
			x += 0.75
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func parking(grid: RoomGrid, room: Dictionary) -> void:
	var colors := [Color(0.5, 0.15, 0.15), Color(0.2, 0.3, 0.45), Color(0.6, 0.6, 0.55), Color(0.25, 0.4, 0.3)]
	for pos in grid.floor_spots(room, grid.rng.randi_range(1, 2), 2.6, 4.4):
		Props.car(grid.map, pos, 90.0 * grid.rng.randi_range(0, 1) + grid.rng.randf_range(-8, 8),
			colors[grid.rng.randi_range(0, colors.size() - 1)], grid.rng.randf() < 0.3)
		grid.add_loot(room, pos + Vector3(2.0, 0.2, 0))
	if grid.rng.randf() < 0.5:
		var spots := grid.floor_spots(room, 1)
		if not spots.is_empty():
			Props.lamp_post(grid.map, spots[0], 3.2, Color(1.0, 0.75, 0.4))


## One piece of corner junk from the grid theme's clutter set.
static func clutter(grid: RoomGrid, room: Dictionary, pos: Vector3, yaw: float) -> void:
	var r := grid.rng
	var map := grid.map
	match grid.theme.clutter:
		"industrial":
			match r.randi_range(0, 4):
				0: Props.crate(map, pos, yaw + r.randf_range(-15, 15), Vector3.ONE * r.randf_range(0.8, 1.3))
				1: Props.barrel(map, pos, Color(0.5, 0.32, 0.2).lerp(Color(0.3, 0.35, 0.4), r.randf()))
				2: Props.sacks(map, pos, r.randi())
				3: Props.pallet_stack(map, pos, yaw, r.randi_range(1, 4))
				4: Props.fuel_drums(map, pos, r.randi())
		"backroom":
			match r.randi_range(0, 4):
				0, 1: Props.crate(map, pos, yaw + r.randf_range(-20, 20), Vector3(1.0, 0.7, 0.8) * r.randf_range(0.7, 1.2),
					Color(0.8, 0.65, 0.45))
				2: Props.pallet_stack(map, pos, yaw, r.randi_range(1, 3))
				3: Props.cabinet(map, pos, yaw)
				4: Props.plant(map, pos, Color(0.35, 0.4, 0.25), r.randi())
		"dream":
			match r.randi_range(0, 4):
				0: Props.toy_blocks(map, pos, r.randi())
				1: Props.giant_ball(map, pos, 0.5, Color.from_hsv(r.randf(), 0.35, 1.0))
				2: Props.plant(map, pos, Color(0.5, 0.75, 0.55), r.randi())
				3: Props.chair(map, pos, yaw + r.randf_range(-30, 30), Color.from_hsv(r.randf(), 0.3, 1.0), r.randf() < 0.3)
				4: Props.crate(map, pos, yaw, Vector3.ONE * 0.8, Color.from_hsv(r.randf(), 0.3, 1.0))
	if r.randf() < 0.15:
		grid.add_loot(room, pos + Vector3(sin(deg_to_rad(yaw)), 0.2, cos(deg_to_rad(yaw))) * Vector3(1.2, 1, 1.2))


# --- Dreamcore (the endless afternoon) -------------------------------------------------

static func classroom(grid: RoomGrid, room: Dictionary) -> void:
	grid.map._glow(Vector3(4.0, 1.6, 0.05), Vector3(room.center.x, 2.0, room.min.y + 0.2), Color(0.35, 0.5, 0.4))
	var x: float = room.min.x + 2.0
	while x < room.max.x - 2.0:
		var z: float = room.min.y + 4.0
		while z < room.max.y - 2.0:
			var pos := Vector3(x, 0, z)
			if not grid._near_door(room, pos, 1.4) and not grid._near_centre(room, pos):
				Props.table(grid.map, pos, 0.0, Vector3(0.9, 0.62, 0.6), Color(0.95, 0.85, 0.6))
				Props.chair(grid.map, pos + Vector3(0, 0, 0.55), 180.0, Color(0.6, 0.8, 1.0))
				if grid.rng.randf() < 0.12:
					grid.add_loot(room, pos + Vector3(0, 0.75, 0))
			z += 2.0
		x += 2.2


static func bathroom(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.5)
	if not slots.is_empty():
		Props.bathtub(grid.map, slots[0].pos, slots[0].yaw + 90.0, true)
	for i in range(1, mini(slots.size(), 4)):
		Props.sink(grid.map, slots[i].pos, slots[i].yaw)
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func nursery(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.8, 3.0)
	for i in mini(slots.size(), 3):
		Props.bed(grid.map, slots[i].pos, slots[i].yaw, Vector3(0.9, 0.7, 1.4), Color(1.0, 0.85, 0.9), Color(1.0, 1.0, 1.0))
		grid.add_loot(room, slots[i].pos + Vector3(0, 0.95, 0))
	for pos in grid.floor_spots(room, 1):
		Props.toy_blocks(grid.map, pos, grid.rng.randi())


static func kitchen(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.5, 3.2)
	for i in mini(slots.size(), 3):
		Props.counter(grid.map, slots[i].pos, slots[i].yaw, 3.0, Color(1.0, 0.95, 0.85))
		grid.add_loot(room, slots[i].pos + Vector3(0, 1.1, 0))
	for pos in grid.floor_spots(room, 1, 2.0):
		Props.table(grid.map, pos, 0.0, Vector3(1.8, 0.78, 1.0), Color(1.0, 0.9, 0.8), "panel")
		for side: float in [-1.0, 1.0]:
			Props.chair(grid.map, pos + Vector3(0, 0, side * 0.75), 90.0 - side * 90.0, Color(1.0, 0.7, 0.75))


static func ball_room(grid: RoomGrid, room: Dictionary) -> void:
	var colors := [Color(1.0, 0.55, 0.6), Color(0.55, 0.8, 1.0), Color(1.0, 0.9, 0.5), Color(0.6, 1.0, 0.7)]
	for pos in grid.floor_spots(room, 4 + grid.units(room) * 2, 1.4):
		Props.giant_ball(grid.map, pos, grid.rng.randf_range(0.4, 1.1), colors[grid.rng.randi_range(0, 3)])
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func toy_room(grid: RoomGrid, room: Dictionary) -> void:
	for pos in grid.floor_spots(room, 2 + grid.units(room)):
		Props.toy_blocks(grid.map, pos, grid.rng.randi())
	var slots := grid.wall_slots(room)
	if not slots.is_empty():
		Props.slide(grid.map, slots[0].pos, slots[0].yaw + 90.0)
	if slots.size() > 1:
		Props.tv(grid.map, slots[1].pos, slots[1].yaw, true)
	for pos in grid.floor_spots(room, 2):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))


static func living(grid: RoomGrid, room: Dictionary) -> void:
	var slots := grid.wall_slots(room, 0.7, 3.0)
	if not slots.is_empty():
		Props.sofa(grid.map, slots[0].pos, slots[0].yaw, Color(0.8, 0.7, 0.95))
		grid.add_loot(room, slots[0].pos + Vector3(0, 0.6, 0))
	if slots.size() > 1:
		Props.tv(grid.map, slots[1].pos, slots[1].yaw, grid.rng.randf() < 0.5)
	if slots.size() > 2:
		Props.plant(grid.map, slots[2].pos, Color(0.5, 0.75, 0.5), grid.rng.randi())
	for pos in grid.floor_spots(room, 1):
		grid.add_loot(room, pos + Vector3(0, 0.2, 0))
