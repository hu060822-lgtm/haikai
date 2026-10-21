class_name RoomGrid
extends RefCounted
## The random part of a map: rooms that grow outward from doorways in the hand-built
## core until the map is big. Each step picks an open doorway at random and tries to
## fit a corridor, a room or a big hall behind it on a 4 m grid; whatever fits gets one
## to four new doorways of its own, so the layout branches, doubles back and dead-ends
## differently every match. Afterwards some neighbouring rooms get extra doors so there
## are loops to run around. Doors are wide (big monsters fit) or narrow (they don't),
## so some rooms end up as safe pockets. Each room gets a themed kit from the map
## (props, loot, traps), and rooms further from the core roll better loot.
##
## Everything comes from the map's rng after its seed is set, so every peer builds the
## same layout.

const DOOR_WIDE := Vector2(3.4, 5.0)
const DOOR_NARROW := Vector2(1.1, 2.2)
## Props stay this far from a room's patrol points, so monsters can walk through.
const CLEAR_RADIUS := 2.0
## Loot luck gained per room away from the core.
const LUCK_PER_DEPTH := 0.06
const CELL := 4.0
## Room sizes in cells (along the way in, across it).
const SHAPES := {
	"corridor": {"weight": 3.0, "length": Vector2i(3, 8), "width": Vector2i(1, 1), "exits": Vector2i(1, 2)},
	"room": {"weight": 4.0, "length": Vector2i(2, 6), "width": Vector2i(2, 6), "exits": Vector2i(1, 3)},
	"hall": {"weight": 1.2, "length": Vector2i(6, 10), "width": Vector2i(5, 9), "exits": Vector2i(2, 4)},
}

var map: GameMap
var rng: RandomNumberGenerator
var name := "sprawl"
## Which trap set and look to use: factory, mall, subway, dream.
var style := "any"
## The grid's corner; lines every CELL metres from here. Floor height is origin.y.
var origin := Vector3.ZERO
## Doorways in the core's walls: {pos: world point on the wall's outer face, dir: outward}.
var ports: Array = []
## World areas nothing may be built on (the core, a corridor that runs past it).
var blocked: Array[Rect2] = []
## Nothing is built outside this world rectangle.
var limit := Rect2(-100, -100, 200, 200)
var target_rooms := 50
var height := 5.6
var hall_height := Vector2(7.0, 9.0)
var loop_chance := 0.35
var narrow_chance := 0.2
var gate_chance := 0.35
var max_gates := 10
var dark_chance := 0.2
var trap_chance := 0.22
## Weights for corridor / room / hall, on top of SHAPES.
var shape_weights := {}
## floor, floor_tint, wall, wall_tint, inner_wall, roof, roof_tint, light, light_energy,
## density, wall_density, wall_thickness, clutter (a RoomKits.clutter set), clutter_chance, roofless_chance
var theme := {}
## Room kits: {name, weight, build: Callable(grid, room), min_depth, max_count, min_cells
## (in 12x12 m units), shape ("corridor"/"room"/"hall", or an array), deep, floor, floor_tint,
## lit, tidy, roofless}
var kits: Array = []

var rooms: Array = []
var doors: Array = []
var _owner := {}  # Vector2i cell -> room id
## Ports that ended up with no room behind them: _build_ports bricks their doorways up.
var sealed_ports: Array[int] = []
var _gates := 0
var _traps_script: GDScript = null


func build() -> void:
	if ResourceLoader.exists("res://scripts/traps/traps.gd"):
		_traps_script = load("res://scripts/traps/traps.gd")
	_grow()
	_add_loops()
	_place_port_doors()
	_measure()
	_assign_kits()
	for room in rooms:
		_build_room(room)
	_build_walls()
	_build_ports()
	_build_gates()
	_finish()


func world_bounds() -> AABB:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for room in rooms:
		lo = Vector2(minf(lo.x, room.min.x), minf(lo.y, room.min.y))
		hi = Vector2(maxf(hi.x, room.max.x), maxf(hi.y, room.max.y))
	if rooms.is_empty():
		return AABB(origin, Vector3.ZERO)
	return AABB(Vector3(lo.x, origin.y - 0.5, lo.y), Vector3(hi.x - lo.x, hall_height.y + 1.0, hi.y - lo.y))


## Where each port's doorway sits on the core's wall (floor height).
func port_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for port in ports:
		points.append(port.pos)
	return points


## A room's size in 12x12 m units (how much a kit should put in it).
func units(room: Dictionary) -> int:
	return maxi(1, roundi((room.max.x - room.min.x) * (room.max.y - room.min.y) / 144.0))


# --- Layout ----------------------------------------------------------------------------

func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori((x - origin.x) / CELL), floori((z - origin.z) / CELL))


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(origin.x + c.x * CELL, origin.z + c.y * CELL, CELL, CELL)


func _free(c: Vector2i) -> bool:
	if _owner.has(c):
		return false
	var rect := _cell_rect(c)
	if not limit.encloses(rect):
		return false
	for area in blocked:
		if area.intersects(rect.grow(-0.01)):
			return false
	return true


func _grow() -> void:
	var frontier := []
	for i in ports.size():
		var port: Dictionary = ports[i]
		var dir: Vector2i = port.dir
		var across := Vector2i(absi(dir.y), absi(dir.x))
		# Step out from the wall until clear of the core.
		var probe: Vector3 = port.pos + Vector3(dir.x, 0, dir.y) * 0.05
		var c := _cell_of(probe.x, probe.z)
		var steps := 0
		while not _free(c) and steps < 4:
			c += dir
			steps += 1
		# The doorway is 4 m wide around the port, so the room must cover both cells it touches.
		var p: Vector3 = port.pos
		var lo := _cell_of(p.x - across.x * 1.9, p.z - across.y * 1.9)
		var hi := _cell_of(p.x + across.x * 1.9, p.z + across.y * 1.9)
		var need := Vector2i(lo.x * across.x + lo.y * across.y, hi.x * across.x + hi.y * across.y)
		frontier.append({"from": -1, "a": c - dir, "b": c, "dir": dir, "port": i, "depth": 0, "need": need})
	# Every port gets its room first, then growth picks doorways at random.
	var first := ports.size()
	while not frontier.is_empty() and rooms.size() < target_rooms:
		var index := 0 if first > 0 else rng.randi_range(0, frontier.size() - 1)
		first -= 1
		var entry: Dictionary = frontier.pop_at(index)
		if not _free(entry.b):
			continue
		var room := _try_room(entry)
		if room.is_empty():
			if entry.has("port"):
				push_warning("%s: port %d has no room" % [name, entry.port])
			continue
		if entry.has("port"):
			var door := {"rooms": [room.id], "kind": "port", "pos": ports[entry.port].pos, "size": DOOR_WIDE,
				"port": entry.port}
			room.doors.append(door)
		else:
			_add_door(entry.from, room.id, entry.a, entry.b, "narrow" if rng.randf() < narrow_chance else "wide")
		for exit in _exits(room):
			exit.depth = entry.depth + 1
			frontier.append(exit)
	_claim_orphan_ports()


## A port whose cells another room grew over gets its doorway on that room (the core's
## wall already has the opening cut, so it must lead somewhere); one with no room at all
## is bricked up.
func _claim_orphan_ports() -> void:
	var served := {}
	for room in rooms:
		for door in room.doors:
			if door.kind == "port":
				served[door.port] = true
	for i in ports.size():
		if served.has(i):
			continue
		var port: Dictionary = ports[i]
		var dir: Vector2i = port.dir
		var p: Vector3 = port.pos
		var c := _cell_of(p.x + dir.x * 0.05, p.z + dir.y * 0.05)
		var steps := 0
		while not _owner.has(c) and steps < 4:
			c += dir
			steps += 1
		if _owner.has(c) and _covers_doorway(rooms[_owner[c]], port):
			rooms[_owner[c]].doors.append({"rooms": [_owner[c]], "kind": "port", "pos": p, "size": DOOR_WIDE, "port": i})
		else:
			sealed_ports.append(i)


## Does this room's wall facing the port run the whole width of the port's doorway?
func _covers_doorway(room: Dictionary, port: Dictionary) -> bool:
	var dir: Vector2i = port.dir
	var p: Vector3 = port.pos
	var half := DOOR_WIDE.x / 2.0 + 0.3
	if dir.x != 0:
		return room.min.y <= p.z - half and room.max.y >= p.z + half
	return room.min.x <= p.x - half and room.max.x >= p.x + half


func _try_room(entry: Dictionary) -> Dictionary:
	var dir: Vector2i = entry.dir
	var across := Vector2i(absi(dir.y), absi(dir.x))
	var b: Vector2i = entry.b
	var b_across := b.x * across.x + b.y * across.y
	var need: Vector2i = entry.get("need", Vector2i(b_across, b_across))
	for attempt in 10:
		var shape := _pick_shape(attempt)
		var spec: Dictionary = SHAPES[shape]
		var shrink := attempt / 3
		var length := maxi(spec.length.x, rng.randi_range(spec.length.x, spec.length.y) - shrink)
		var width := maxi(spec.width.x, rng.randi_range(spec.width.x, spec.width.y) - shrink)
		if need.y - need.x + 1 > width:
			continue
		var start_across := rng.randi_range(need.y - width + 1, need.x)
		var cells: Array[Vector2i] = []
		var fits := true
		for l in length:
			for w in width:
				var along_c := b + dir * l
				var c := Vector2i(along_c.x * absi(dir.x) + (start_across + w) * across.x,
					along_c.y * absi(dir.y) + (start_across + w) * across.y)
				if not _free(c):
					fits = false
					break
				cells.append(c)
			if not fits:
				break
		if fits:
			return _add_room(cells, shape)
	return {}


func _pick_shape(attempt: int) -> String:
	if attempt >= 7:
		return "corridor"
	var total := 0.0
	for shape in SHAPES:
		total += shape_weights.get(shape, SHAPES[shape].weight)
	var pick := rng.randf() * total
	for shape in SHAPES:
		pick -= shape_weights.get(shape, SHAPES[shape].weight)
		if pick <= 0.0:
			return shape
	return "room"


func _add_room(cells: Array[Vector2i], shape: String) -> Dictionary:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var room := {"id": rooms.size(), "cells": cells, "shape": shape, "doors": [], "depth": 999, "wide": false,
		"kit": "", "lo": lo, "hi": hi,
		"min": Vector2(origin.x + lo.x * CELL, origin.z + lo.y * CELL),
		"max": Vector2(origin.x + (hi.x + 1) * CELL, origin.z + (hi.y + 1) * CELL),
		"height": rng.randf_range(hall_height.x, hall_height.y) if shape == "hall" else height}
	room.center = Vector3((room.min.x + room.max.x) / 2.0, origin.y, (room.min.y + room.max.y) / 2.0)
	room.clear_points = _clear_points(room)
	for c in cells:
		_owner[c] = room.id
	rooms.append(room)
	return room


## Points through the room a big monster should be able to walk: the middle, or a
## 12 m lattice in big rooms, along the length of corridors.
func _clear_points(room: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var size := Vector2(room.max.x - room.min.x, room.max.y - room.min.y)
	var nx := maxi(1, roundi(size.x / 12.0))
	var nz := maxi(1, roundi(size.y / 12.0))
	for i in nx:
		for j in nz:
			points.append(Vector3(room.min.x + size.x * (i + 0.5) / nx, origin.y, room.min.y + size.y * (j + 0.5) / nz))
	return points


## Doorways out of a new room: edge cells on random sides that open onto free ground.
func _exits(room: Dictionary) -> Array:
	var spec: Dictionary = SHAPES[room.shape]
	var count := rng.randi_range(spec.exits.x, spec.exits.y)
	var options := []
	for c in room.cells:
		for dir in _dirs():
			var out: Vector2i = c + dir
			if _owner.get(out, -1) != room.id and _free(out):
				options.append([c, out, dir])
	_shuffle(options)
	var exits := []
	for option in options:
		if exits.size() >= count:
			break
		# Not two doorways side by side.
		if exits.any(func(e: Dictionary) -> bool: return (e.a as Vector2i).distance_to(option[0]) < 2.5):
			continue
		exits.append({"from": room.id, "a": option[0], "b": option[1], "dir": option[2]})
	return exits


func _add_door(room_a: int, room_b: int, cell_a: Vector2i, cell_b: Vector2i, kind: String) -> void:
	var size: Vector2 = DOOR_NARROW if kind == "narrow" else DOOR_WIDE
	var dir := cell_b - cell_a
	var slack := CELL / 2.0 - size.x / 2.0 - 0.35
	var offset := rng.randf_range(-slack, slack)
	var centre := _side_centre(cell_a, dir) + (Vector3(0, 0, offset) if dir.x != 0 else Vector3(offset, 0, 0))
	var door := {"rooms": [room_a, room_b], "cells": [cell_a, cell_b], "kind": kind, "pos": centre, "size": size}
	doors.append(door)
	rooms[room_a].doors.append(door)
	rooms[room_b].doors.append(door)


## Extra doors between rooms that already touch, so there are loops.
func _add_loops() -> void:
	var touching := {}
	var cells: Array = _owner.keys()
	cells.sort()
	for c in cells:
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = c + dir
			if not _owner.has(other) or _owner[other] == _owner[c]:
				continue
			var key := Vector2i(mini(_owner[c], _owner[other]), maxi(_owner[c], _owner[other]))
			if not touching.has(key):
				touching[key] = []
			touching[key].append([c, other])
	var linked := {}
	for door in doors:
		linked[Vector2i(mini(door.rooms[0], door.rooms[1]), maxi(door.rooms[0], door.rooms[1]))] = true
	var keys: Array = touching.keys()
	keys.sort()
	for key in keys:
		if linked.has(key) or rng.randf() >= loop_chance:
			continue
		var pairs: Array = touching[key]
		var pair: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
		_add_door(_owner[pair[0]], _owner[pair[1]], pair[0], pair[1], "narrow" if rng.randf() < narrow_chance else "wide")


## Depth (rooms away from the core) and whether big monsters can get in.
func _measure() -> void:
	var queue := []
	for room in rooms:
		if room.doors.any(func(d: Dictionary) -> bool: return d.kind == "port"):
			room.depth = 0
			room.wide = true
			queue.append(room.id)
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for door in rooms[id].doors:
			if door.kind == "port":
				continue
			var other: int = door.rooms[0] if door.rooms[1] == id else door.rooms[1]
			if rooms[other].depth > rooms[id].depth + 1:
				rooms[other].depth = rooms[id].depth + 1
				queue.append(other)
	var wide_queue := []
	for room in rooms:
		if room.wide:
			wide_queue.append(room.id)
	while not wide_queue.is_empty():
		var id: int = wide_queue.pop_front()
		for door in rooms[id].doors:
			if door.kind != "wide":
				continue
			var other: int = door.rooms[0] if door.rooms[1] == id else door.rooms[1]
			if not rooms[other].wide:
				rooms[other].wide = true
				wide_queue.append(other)


func _assign_kits() -> void:
	var counts := {}
	var order: Array = rooms.duplicate()
	# The deepest room is picked first, so a kit marked "deep" (a vault) lands there.
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth > b.depth)
	var deepest: Dictionary = order[0] if not order.is_empty() else {}
	for room in order:
		var options := []
		var total := 0.0
		for kit in kits:
			var shapes = kit.get("shape", ["room", "hall"])
			if shapes is String:
				shapes = [shapes]
			if not room.shape in shapes:
				continue
			if room.depth < kit.get("min_depth", 0) or units(room) < kit.get("min_cells", 1):
				continue
			if counts.get(kit.name, 0) >= kit.get("max_count", 999):
				continue
			if kit.get("deep", false) and room != deepest:
				continue
			options.append(kit)
			total += kit.get("weight", 1.0)
		if options.is_empty():
			continue
		var pick := rng.randf() * total
		for kit in options:
			pick -= kit.get("weight", 1.0)
			if pick <= 0.0:
				room.kit = kit.name
				room.kit_data = kit
				counts[kit.name] = counts.get(kit.name, 0) + 1
				break


# --- Building ---------------------------------------------------------------------------

func _build_room(room: Dictionary) -> void:
	var kit: Dictionary = room.get("kit_data", {})
	var size := Vector2(room.max.x - room.min.x, room.max.y - room.min.y)
	var floor_tex: String = kit.get("floor", theme.get("floor", "concrete"))
	var floor_tint: Color = kit.get("floor_tint", theme.get("floor_tint", Color.WHITE))
	map._box(Vector3(size.x, 1.0, size.y), room.center + Vector3(0, -0.5, 0), floor_tex, Vector3.ZERO,
		Layers.WORLD, floor_tint, theme.get("density", 0.5))
	room.roofed = not kit.get("roofless", rng.randf() < theme.get("roofless_chance", 0.0))
	if room.roofed:
		map._roof(Vector3(size.x, 0.3, size.y), room.center + Vector3(0, room.height + 0.15, 0),
			theme.get("roof", "rust_metal"), theme.get("roof_tint", Color.WHITE))
	if kit.get("lit", false) or rng.randf() >= dark_chance:
		var reach := maxf(size.x, size.y) * 0.6 + 3.0
		var spots := [room.center]
		if room.shape == "corridor" and maxf(size.x, size.y) > 20.0:
			var along := Vector3(size.x, 0, 0) if size.x > size.y else Vector3(0, 0, size.y)
			spots = [room.center - along * 0.25, room.center + along * 0.25]
			reach = maxf(size.x, size.y) * 0.4 + 3.0
		elif room.clear_points.size() > 1:
			# Big rooms get a lamp over each 12 m patch, at most four.
			spots = []
			var step := ceili(room.clear_points.size() / 4.0)
			for i in range(0, room.clear_points.size(), step):
				spots.append(room.clear_points[i])
			reach = 12.0 + room.height * 0.5
		for spot in spots:
			map._light(spot + Vector3(0, room.height - 0.6, 0), theme.get("light", Color(1.0, 0.85, 0.6)),
				theme.get("light_energy", 0.6), reach, rng.randf() < 0.35)
	if kit.has("build"):
		kit.build.call(self, room)
	if theme.has("clutter") and not kit.get("tidy", false):
		_clutter(room)
	_place_traps(room)


## Fills room corners with small junk so rooms don't read as empty boxes.
func _clutter(room: Dictionary) -> void:
	var chance: float = theme.get("clutter_chance", 0.45)
	if room.shape == "corridor":
		chance *= 0.4
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		if rng.randf() >= chance:
			continue
		var pos := Vector3(room.min.x + 1.0 if corner.x < 0 else room.max.x - 1.0, origin.y,
			room.min.y + 1.0 if corner.y < 0 else room.max.y - 1.0)
		if _near_door(room, pos, 2.4) or _near_centre(room, pos, 2.6):
			continue
		RoomKits.clutter(self, room, pos, rad_to_deg(atan2(-corner.x, -corner.y)))


## Traps from the map's set: on the floor of a room, or across a doorway.
func _place_traps(room: Dictionary) -> void:
	if _traps_script == null or room.depth == 0:
		return
	var chance := minf(trap_chance + room.depth * 0.02, 0.6)
	if rng.randf() >= chance:
		return
	var kinds: Array = _traps_script.kinds_for(style)
	if kinds.is_empty():
		return
	var count := 1 if room.shape != "hall" else rng.randi_range(1, 3)
	for i in count:
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var info: Dictionary = _traps_script.KINDS.get(kind, {})
		var params := {"ceiling": room.height}
		if info.get("wall", "") == "back":
			var slots := wall_slots(room, info.get("footprint", Vector2.ONE).y / 2.0 + 0.1, 3.0)
			if not slots.is_empty():
				_traps_script.create(kind, map, slots[0].pos, slots[0].yaw, rng.randi(), params)
		elif info.get("doorway", false):
			var options: Array = room.doors.filter(func(d: Dictionary) -> bool: return d.kind == "wide" and d.has("cells"))
			if options.is_empty():
				continue
			var door: Dictionary = options[rng.randi_range(0, options.size() - 1)]
			var dir: Vector2i = door.cells[1] - door.cells[0]
			var yaw := 0.0 if dir.y != 0 else 90.0
			_traps_script.create(kind, map, door.pos, yaw, rng.randi(), {"width": door.size.x})
		else:
			var spots := floor_spots(room, 1, 1.6, 0.0)
			if not spots.is_empty():
				_traps_script.create(kind, map, spots[0], rng.randf_range(0, 360), rng.randi(), params)


## Walls go on every grid edge between two different rooms, or between a room and
## nothing. Straight runs are merged into one wall with door openings cut in.
func _build_walls() -> void:
	var thickness: float = theme.get("wall_thickness", 0.3)
	var door_at := {}
	for door in doors:
		door_at[[door.cells[0], door.cells[1]]] = door
		door_at[[door.cells[1], door.cells[0]]] = door
	# Runs keyed by axis, line, the two sides' rooms; each holds edge indices along the line.
	var runs := {}
	for c in _owner:
		var id: int = _owner[c]
		for dir in _dirs():
			var other: Vector2i = c + dir
			var other_id: int = _owner.get(other, -1)
			if other_id == id:
				continue
			if other_id >= 0 and not (dir == Vector2i(1, 0) or dir == Vector2i(0, 1)):
				continue  # built from the other side
			var vertical := dir.x != 0  # the wall runs along z
			var line: int = (c.x + (1 if dir.x > 0 else 0)) if vertical else (c.y + (1 if dir.y > 0 else 0))
			var index: int = c.y if vertical else c.x
			var a := id
			var b := other_id
			var key := [vertical, line, mini(a, b) if b >= 0 else a, maxi(a, b) if b >= 0 else -1]
			if not runs.has(key):
				runs[key] = []
			runs[key].append([index, door_at.get([c, other], {})])
	var keys: Array = runs.keys()
	keys.sort()
	for key in keys:
		var edges: Array = runs[key]
		edges.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var start := 0
		while start < edges.size():
			var end := start
			while end + 1 < edges.size() and edges[end + 1][0] == edges[end][0] + 1:
				end += 1
			_wall_run(key, edges.slice(start, end + 1), thickness)
			start = end + 1


func _wall_run(key: Array, edges: Array, thickness: float) -> void:
	var vertical: bool = key[0]
	var line: float = key[1]
	var first: int = edges[0][0]
	var count := edges.size()
	var room_a: Dictionary = rooms[key[2]]
	var wall_height: float = room_a.height
	var inner: bool = key[3] >= 0
	if inner:
		wall_height = maxf(wall_height, rooms[key[3]].height)
	var from: Vector3
	var to: Vector3
	if vertical:
		from = Vector3(origin.x + line * CELL, origin.y, origin.z + first * CELL - thickness / 2.0)
		to = Vector3(origin.x + line * CELL, origin.y, origin.z + (first + count) * CELL + thickness / 2.0)
	else:
		from = Vector3(origin.x + first * CELL - thickness / 2.0, origin.y, origin.z + line * CELL)
		to = Vector3(origin.x + (first + count) * CELL + thickness / 2.0, origin.y, origin.z + line * CELL)
	var openings := []
	for edge in edges:
		var door: Dictionary = edge[1]
		if door.is_empty():
			continue
		var along: float = (door.pos.z - from.z) if vertical else (door.pos.x - from.x)
		openings.append([along, door.size.x, door.size.y])
	if not inner:
		var at := origin.x + line * CELL if vertical else origin.z + line * CELL
		for door in room_a.doors:
			if door.kind != "port":
				continue
			var across: float = door.pos.x if vertical else door.pos.z
			var along: float = (door.pos.z - from.z) if vertical else (door.pos.x - from.x)
			if absf(across - at) < 0.05 and along > 0.0 and along < from.distance_to(to):
				openings.append([along, door.size.x, door.size.y])
	var texture: String = theme.get("inner_wall", theme.get("wall", "brick")) if inner else theme.get("wall", "brick")
	map._wall(from, to, wall_height, texture, openings, thickness, theme.get("wall_tint", Color.WHITE), Layers.WORLD,
		theme.get("wall_density", 0.5))


## Moves each port's doorway onto its room's own wall, which may stand a little off the
## core's wall where the grid and the core don't line up.
func _place_port_doors() -> void:
	for room in rooms:
		for door in room.doors:
			if door.kind != "port":
				continue
			var port: Dictionary = ports[door.port]
			var dir: Vector2i = port.dir
			var p: Vector3 = port.pos
			var edge: float
			match dir:
				Vector2i(1, 0): edge = room.min.x
				Vector2i(-1, 0): edge = room.max.x
				Vector2i(0, 1): edge = room.min.y
				_: edge = room.max.y
			door.pos = Vector3(edge, origin.y, p.z) if dir.x != 0 else Vector3(p.x, origin.y, edge)
			door.gap = absf(edge - (p.x if dir.x != 0 else p.z))


## A short passage from each port in the core's wall to the room behind it.
func _build_ports() -> void:
	for i in sealed_ports:
		var port: Dictionary = ports[i]
		var dir: Vector2i = port.dir
		var plug := Vector3(0.4, DOOR_WIDE.y + 0.4, DOOR_WIDE.x + 0.6) if dir.x != 0 else Vector3(DOOR_WIDE.x + 0.6, DOOR_WIDE.y + 0.4, 0.4)
		map._box(plug, port.pos + Vector3(dir.x, 0, dir.y) * 0.2 + Vector3(0, plug.y / 2.0 - 0.2, 0), theme.get("wall", "brick"),
			Vector3.ZERO, Layers.WORLD, theme.get("wall_tint", Color.WHITE))
	for room in rooms:
		for door in room.doors:
			if door.kind != "port" or door.gap < 0.05:
				continue
			var port: Dictionary = ports[door.port]
			var dir: Vector2i = port.dir
			var p: Vector3 = port.pos
			var mid: Vector3 = (p + door.pos) / 2.0
			var w := DOOR_WIDE.x + 0.6
			var gap: float = door.gap
			var floor_size := Vector3(gap + 0.4, 1.0, w) if dir.x != 0 else Vector3(w, 1.0, gap + 0.4)
			map._box(floor_size, mid + Vector3(0, -0.5, 0), theme.get("floor", "concrete"), Vector3.ZERO, Layers.WORLD,
				theme.get("floor_tint", Color.WHITE))
			map._roof(Vector3(floor_size.x, 0.3, floor_size.z), mid + Vector3(0, DOOR_WIDE.y + 0.15, 0),
				theme.get("roof", "rust_metal"), theme.get("roof_tint", Color.WHITE))
			for side in [-1.0, 1.0]:
				var offset := Vector3(0, 0, side * w / 2.0) if dir.x != 0 else Vector3(side * w / 2.0, 0, 0)
				var wall_size := Vector3(gap + 0.4, DOOR_WIDE.y, 0.3) if dir.x != 0 else Vector3(0.3, DOOR_WIDE.y, gap + 0.4)
				map._box(wall_size, mid + offset + Vector3(0, DOOR_WIDE.y / 2.0, 0), theme.get("wall", "brick"),
					Vector3.ZERO, Layers.WORLD, theme.get("wall_tint", Color.WHITE))


func _build_gates() -> void:
	var order := doors.duplicate()
	_shuffle(order)
	for door in order:
		if _gates >= max_gates:
			return
		if rng.randf() >= (gate_chance if door.kind == "narrow" else gate_chance * 0.3):
			continue
		var dir: Vector2i = door.cells[1] - door.cells[0]
		var size: Vector2 = door.size
		var gate_size := Vector3(0.15, size.y, size.x) if dir.x != 0 else Vector3(size.x, size.y, 0.15)
		map._add_gate(door.pos + Vector3(0, size.y / 2.0, 0), gate_size)
		_gates += 1


func _finish() -> void:
	for room in rooms:
		if not room.wide:
			continue
		for centre in room.clear_points:
			# Kits keep these clear, but big props can still reach them: then try nearby.
			for offset in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3),
					Vector3(3, 0, 3), Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(-3, 0, 3)]:
				var point: Vector3 = centre + offset
				if _inside(room, point, 1.4) and map.is_clear(point):
					map.patrol_points.append(point)
					break
	_add_bulky_spots()
	var spots := 0
	for room in rooms:
		spots += room.get("loot", 0)
	# More spots than items, so every match spreads them differently; capped so a big
	# layout doesn't flood the network with loot.
	map.loot_count += Vector2i(mini(int(spots * 0.4), 48), mini(int(spots * 0.52), 62))


func _inside(room: Dictionary, pos: Vector3, margin: float) -> bool:
	return pos.x > room.min.x + margin and pos.x < room.max.x - margin and pos.z > room.min.y + margin and pos.z < room.max.y - margin


# --- Helpers for kits -------------------------------------------------------------------

## Places one trap of the given kind (does nothing until the traps are in the game).
func place_trap(kind: String, pos: Vector3, yaw := 0.0, params := {}) -> void:
	if _traps_script != null and _traps_script.KINDS.has(kind):
		_traps_script.create(kind, map, pos, yaw, rng.randi(), params)


## Floor spots for the map's bulky hauls: one try per room away from the core (not in
## corridors), clear of solid props. Luck grows with depth like loot spots.
func _add_bulky_spots() -> void:
	for room in rooms:
		if room.depth < 1 or room.depth >= 999 or room.shape == "corridor":
			continue
		for attempt in 4:
			var pos := Vector3(rng.randf_range(room.min.x + 1.5, room.max.x - 1.5), origin.y, rng.randf_range(room.min.y + 1.5, room.max.y - 1.5))
			if _inside(room, pos, 1.4) and map.is_clear(pos, 1.0):
				map.bulky_spots.append({"pos": pos, "luck": room.depth * LUCK_PER_DEPTH * 1.5})
				break


## Registers a loot spot in a room (deeper rooms roll luckier).
func add_loot(room: Dictionary, pos: Vector3, bonus := 0.0) -> void:
	map.loot_spots.append(pos)
	map.loot_luck[pos] = room.depth * LUCK_PER_DEPTH + bonus
	room.loot = room.get("loot", 0) + 1


## Places along the room's walls, facing into the room: [{pos, yaw (degrees)}].
## Keeps clear of doorways.
func wall_slots(room: Dictionary, inset := 0.7, spacing := 2.6) -> Array:
	var slots := []
	var sides := [
		[Vector3(room.min.x, 0, room.min.y), Vector3(room.max.x, 0, room.min.y), Vector3(0, 0, 1)],
		[Vector3(room.min.x, 0, room.max.y), Vector3(room.max.x, 0, room.max.y), Vector3(0, 0, -1)],
		[Vector3(room.min.x, 0, room.min.y), Vector3(room.min.x, 0, room.max.y), Vector3(1, 0, 0)],
		[Vector3(room.max.x, 0, room.min.y), Vector3(room.max.x, 0, room.max.y), Vector3(-1, 0, 0)],
	]
	for side in sides:
		var a: Vector3 = side[0] + Vector3(0, origin.y, 0)
		var b: Vector3 = side[1] + Vector3(0, origin.y, 0)
		var normal: Vector3 = side[2]
		var length := a.distance_to(b)
		var count := int((length - 2.0) / spacing)
		for i in count:
			var t := length / 2.0 + (i - (count - 1) / 2.0) * spacing
			var pos := a + (b - a).normalized() * t + normal * inset
			if _near_door(room, pos, 2.6) or _near_centre(room, pos, CLEAR_RADIUS):
				continue
			slots.append({"pos": pos, "yaw": rad_to_deg(atan2(normal.x, normal.z))})
	_shuffle(slots)
	return slots


## Random spots on the floor away from walls, doors and the room's patrol points.
func floor_spots(room: Dictionary, count: int, margin := 1.5, clear := CLEAR_RADIUS) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var tries := 0
	while spots.size() < count and tries < count * 20:
		tries += 1
		var pos := Vector3(rng.randf_range(room.min.x + margin, room.max.x - margin), origin.y,
			rng.randf_range(room.min.y + margin, room.max.y - margin))
		if _near_door(room, pos, 2.4) or _near_centre(room, pos, clear):
			continue
		if spots.any(func(other: Vector3) -> bool: return other.distance_to(pos) < 1.6):
			continue
		spots.append(pos)
	return spots


func _near_door(room: Dictionary, pos: Vector3, distance: float) -> bool:
	for door in room.doors:
		if Vector2(pos.x - door.pos.x, pos.z - door.pos.z).length() < distance + door.size.x / 2.0:
			return true
	return false


func _near_centre(room: Dictionary, pos: Vector3, clear := CLEAR_RADIUS) -> bool:
	if not room.wide or clear <= 0.0:
		return false
	for centre in room.clear_points:
		if Vector2(pos.x - centre.x, pos.z - centre.z).length() < clear:
			return true
	return false


func _cell_centre(c: Vector2i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)


func _side_centre(c: Vector2i, dir: Vector2i) -> Vector3:
	return _cell_centre(c) + Vector3(dir.x, 0, dir.y) * CELL / 2.0


func _dirs() -> Array[Vector2i]:
	return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
