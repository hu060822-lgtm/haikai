class_name RoomGrid
extends RefCounted
## A wing of randomly arranged rooms bolted onto the side of a map's hand-built core.
## The wing is a grid of cells; some cells are left out, neighbours are merged into
## bigger rooms, and rooms are joined by a random spanning tree plus a few extra doors
## so there are loops to run around. Doors are wide (big monsters fit) or narrow (they
## don't), so some rooms end up as safe pockets. Each room gets a themed kit from the
## map (props, loot, lockers), and rooms deeper from the core roll better loot.
##
## Everything comes from the map's rng after its seed is set, so every peer builds the
## same wing. Open-plan wings (a car park, a snowfield) have no inner walls at all.

const DOOR_WIDE := Vector2(3.4, 5.0)
const DOOR_NARROW := Vector2(1.1, 2.2)
## Props stay this far from the middle of each cell, so monsters can patrol through it.
const CLEAR_RADIUS := 2.0
## Loot luck gained per room away from the core.
const LUCK_PER_DEPTH := 0.12

var map: GameMap
var rng: RandomNumberGenerator
var name := "wing"
## World position of the grid's minimum corner (x, floor height, z).
var origin := Vector3.ZERO
var cols := 3
var rows := 3
var cell := 12.0
var height := 5.6
## Cells that open into the core, and the direction from those cells towards it.
var ports: Array[Vector2i] = []
var core_side := Vector2i(1, 0)
## Where along the core-facing edge the core's wall actually is (world x or z ranges).
## Empty means all of it; anywhere else on that edge gets the wing's own wall.
var core_spans: Array[Vector2] = []
var open_plan := false
var roofed := true
var outer_walls := true
var drop_chance := 0.15
var merge_chance := 0.35
var big_chance := 0.12
var loop_chance := 0.3
var narrow_chance := 0.25
var gate_chance := 0.4
var dark_chance := 0.15
## floor, floor_tint, wall, wall_tint, roof, roof_tint, light, light_energy, pillars, density,
## clutter (a RoomKits.clutter set name), clutter_chance
var theme := {}
## Room kits: {name, weight, build: Callable(grid, room), min_depth, max_count, min_cells, floor, floor_tint}
var kits: Array = []

var rooms: Array = []
var doors: Array = []
var _free := {}
var _room_of := {}


func build() -> void:
	_choose_cells()
	_make_rooms()
	_connect()
	_measure()
	_assign_kits()
	for room in rooms:
		_build_room(room)
	_build_walls()
	_build_gates()
	_finish()


func world_bounds() -> AABB:
	return AABB(origin + Vector3(0, -0.5, 0), Vector3(cols * cell, height + 1.0, rows * cell))


## Where each port's doorway sits on the core's wall (floor height, middle of the cell side).
func port_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for port in ports:
		points.append(_side_centre(port, core_side))
	return points


# --- Layout ----------------------------------------------------------------------------

func _choose_cells() -> void:
	for c in cols:
		for r in rows:
			var at := Vector2i(c, r)
			if at in ports or open_plan or rng.randf() >= drop_chance:
				_free[at] = true
	# Keep only what can be reached from a port.
	var seen := {}
	var queue: Array[Vector2i] = ports.duplicate()
	for port in ports:
		seen[port] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for dir in _dirs():
			var next: Vector2i = at + dir
			if _free.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	_free = seen


func _make_rooms() -> void:
	var cells: Array = _free.keys()
	cells.sort()
	_shuffle(cells)
	for at in cells:
		if _room_of.has(at):
			continue
		var group: Array[Vector2i] = [at]
		if not open_plan:
			var roll := rng.randf()
			var square: Array[Vector2i] = [at, at + Vector2i(1, 0), at + Vector2i(0, 1), at + Vector2i(1, 1)]
			if roll < big_chance and square.all(func(c: Vector2i) -> bool: return _free.has(c) and not _room_of.has(c)):
				group = square
			elif roll < merge_chance:
				var options := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
				_shuffle(options)
				for dir in options:
					var other: Vector2i = at + dir
					if _free.has(other) and not _room_of.has(other):
						group.append(other)
						break
		var room := {"id": rooms.size(), "cells": group, "doors": [], "depth": 999, "wide": false, "kit": ""}
		for c in group:
			_room_of[c] = room.id
		rooms.append(room)
	for room in rooms:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c in room.cells:
			lo = Vector2(minf(lo.x, origin.x + c.x * cell), minf(lo.y, origin.z + c.y * cell))
			hi = Vector2(maxf(hi.x, origin.x + (c.x + 1) * cell), maxf(hi.y, origin.z + (c.y + 1) * cell))
		room.min = lo
		room.max = hi
		room.center = Vector3((lo.x + hi.x) / 2.0, origin.y, (lo.y + hi.y) / 2.0)


func _connect() -> void:
	# Candidate links between neighbouring rooms, with the cell pairs that touch.
	var links := {}
	for at in _free:
		for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = at + dir
			if not _free.has(other) or _room_of[at] == _room_of[other]:
				continue
			var a: int = mini(_room_of[at], _room_of[other])
			var b: int = maxi(_room_of[at], _room_of[other])
			var key := Vector2i(a, b)
			if not links.has(key):
				links[key] = []
			links[key].append([at, other])
	var keys: Array = links.keys()
	keys.sort()
	var joined := {}
	for port in ports:
		joined[_room_of[port]] = true
	var chosen := {}
	if open_plan:
		for key in keys:
			chosen[key] = true
	else:
		# Random spanning tree from the port rooms, then some extra doors for loops.
		var progress := true
		while progress:
			progress = false
			var frontier := keys.filter(func(k: Vector2i) -> bool: return joined.has(k.x) != joined.has(k.y))
			if not frontier.is_empty():
				var key: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
				chosen[key] = true
				joined[key.x] = true
				joined[key.y] = true
				progress = true
		for key in keys:
			if not chosen.has(key) and rng.randf() < loop_chance:
				chosen[key] = true
	for key in keys:
		if not chosen.has(key):
			continue
		var pairs: Array = links[key]
		var pair: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
		var kind := "open" if open_plan else ("narrow" if rng.randf() < narrow_chance else "wide")
		var size: Vector2 = DOOR_NARROW if kind == "narrow" else DOOR_WIDE
		var dir: Vector2i = pair[1] - pair[0]
		var slack := cell / 2.0 - size.x / 2.0 - 1.0
		var offset := rng.randf_range(-slack, slack) if kind != "open" else 0.0
		var centre := _side_centre(pair[0], dir)
		centre += (Vector3(0, 0, offset) if dir.x != 0 else Vector3(offset, 0, 0))
		var door := {"rooms": [key.x, key.y], "cells": pair, "kind": kind, "pos": centre, "size": size, "offset": offset}
		doors.append(door)
		rooms[key.x].doors.append(door)
		rooms[key.y].doors.append(door)
	for port in ports:
		var door := {"rooms": [_room_of[port]], "cells": [port], "kind": "port", "pos": _side_centre(port, core_side), "size": DOOR_WIDE}
		rooms[_room_of[port]].doors.append(door)


## Depth (rooms away from the core) and whether big monsters can get in.
func _measure() -> void:
	var queue := []
	for port in ports:
		var room: Dictionary = rooms[_room_of[port]]
		room.depth = 0
		room.wide = true
		if not room.id in queue:
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
			if door.kind == "narrow" or door.kind == "port":
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
	for room in order:
		var options := []
		var total := 0.0
		for kit in kits:
			if room.depth < kit.get("min_depth", 0) or room.cells.size() < kit.get("min_cells", 1):
				continue
			if counts.get(kit.name, 0) >= kit.get("max_count", 999):
				continue
			if kit.get("deep", false) and room != order[0]:
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
	if roofed:
		map._roof(Vector3(size.x, 0.3, size.y), room.center + Vector3(0, height + 0.15, 0),
			theme.get("roof", "rust_metal"), theme.get("roof_tint", Color.WHITE))
		if kit.get("lit", false) or rng.randf() >= dark_chance:
			var reach := maxf(size.x, size.y) * 0.75 + 3.0
			map._light(room.center + Vector3(0, height - 0.6, 0), theme.get("light", Color(1.0, 0.85, 0.6)),
				theme.get("light_energy", 0.6), reach, rng.randf() < 0.35)
	if kit.has("build"):
		kit.build.call(self, room)
	if theme.has("clutter") and not open_plan and not kit.get("tidy", false):
		_clutter(room)


## Fills room corners with small junk so rooms don't read as empty boxes. Kit props stand
## near the middle of each wall, so the corners are free.
func _clutter(room: Dictionary) -> void:
	var chance: float = theme.get("clutter_chance", 0.45)
	for c in room.cells:
		for corner in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			var side_x := Vector2i(corner.x, 0)
			var side_z := Vector2i(0, corner.y)
			if _same_room(c, side_x, room) or _same_room(c, side_z, room) or rng.randf() >= chance:
				continue
			var pos := _cell_centre(c) + Vector3(corner.x, 0, corner.y) * (cell / 2.0 - 1.0)
			if _near_door(room, pos, 2.4):
				continue
			RoomKits.clutter(self, room, pos, rad_to_deg(atan2(-corner.x, -corner.y)))


func _same_room(c: Vector2i, dir: Vector2i, room: Dictionary) -> bool:
	return _free.has(c + dir) and _room_of[c + dir] == room.id


func _build_walls() -> void:
	var thickness: float = theme.get("wall_thickness", 0.3)
	for at in _free:
		for dir in _dirs():
			var other: Vector2i = at + dir
			var inside := other.x >= 0 and other.y >= 0 and other.x < cols and other.y < rows
			if _free.has(other):
				if _room_of[other] == _room_of[at] or open_plan or not (dir == Vector2i(1, 0) or dir == Vector2i(0, 1)):
					continue
				var openings := []
				for door in doors:
					if (door.cells[0] == at and door.cells[1] == other):
						openings.append([cell / 2.0 + door.offset, door.size.x, door.size.y])
				_wall_on_side(at, dir, openings, thickness, theme.get("inner_wall", theme.get("wall", "brick")))
			elif dir == core_side and not inside:
				_core_edge_wall(at, dir, thickness)  # the core's own wall is here, ports cut in it
			elif outer_walls:
				_wall_on_side(at, dir, [], thickness, theme.get("wall", "brick"))
	if open_plan and theme.get("pillars", false):
		for c in range(1, cols):
			for r in range(1, rows):
				var touching := 0
				for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
					if _free.has(Vector2i(c, r) + d):
						touching += 1
				if touching == 4:
					Props.pillar(map, origin + Vector3(c * cell, 0, r * cell), height, 0.45, theme.get("wall", "concrete"),
						theme.get("wall_tint", Color.WHITE))


## On the core-facing edge, wall off only the stretches the core doesn't cover.
func _core_edge_wall(at: Vector2i, dir: Vector2i, thickness: float) -> void:
	if core_spans.is_empty() or not outer_walls:
		return
	var along_x := dir.y != 0
	var a := origin.x + at.x * cell if along_x else origin.z + at.y * cell
	var gaps: Array[Vector2] = [Vector2(a, a + cell)]
	for span in core_spans:
		var next: Array[Vector2] = []
		for gap in gaps:
			if span.y <= gap.x or span.x >= gap.y:
				next.append(gap)
				continue
			if span.x > gap.x:
				next.append(Vector2(gap.x, span.x))
			if span.y < gap.y:
				next.append(Vector2(span.y, gap.y))
		gaps = next
	var edge := _side_centre(at, dir)
	for gap in gaps:
		if gap.y - gap.x < 0.05:
			continue
		var from := Vector3(gap.x, origin.y, edge.z) if along_x else Vector3(edge.x, origin.y, gap.x)
		var to := Vector3(gap.y, origin.y, edge.z) if along_x else Vector3(edge.x, origin.y, gap.y)
		map._wall(from, to, height, theme.get("wall", "brick"), [], thickness, theme.get("wall_tint", Color.WHITE))


func _wall_on_side(at: Vector2i, dir: Vector2i, openings: Array, thickness: float, texture: String) -> void:
	var x0 := origin.x + at.x * cell
	var z0 := origin.z + at.y * cell
	var from: Vector3
	var to: Vector3
	match dir:
		Vector2i(1, 0): from = Vector3(x0 + cell, origin.y, z0); to = Vector3(x0 + cell, origin.y, z0 + cell)
		Vector2i(-1, 0): from = Vector3(x0, origin.y, z0); to = Vector3(x0, origin.y, z0 + cell)
		Vector2i(0, 1): from = Vector3(x0, origin.y, z0 + cell); to = Vector3(x0 + cell, origin.y, z0 + cell)
		_: from = Vector3(x0, origin.y, z0); to = Vector3(x0 + cell, origin.y, z0)
	# Run each wall half its thickness past the corners, so corners close up.
	var along := (to - from).normalized()
	from -= along * thickness / 2.0
	to += along * thickness / 2.0
	var shifted := []
	for opening in openings:
		shifted.append([opening[0] + thickness / 2.0, opening[1], opening[2]])
	map._wall(from, to, height, texture, shifted, thickness, theme.get("wall_tint", Color.WHITE))


func _build_gates() -> void:
	for door in doors:
		if door.kind == "open" or rng.randf() >= (gate_chance if door.kind == "narrow" else gate_chance * 0.3):
			continue
		var dir: Vector2i = door.cells[1] - door.cells[0]
		var size: Vector2 = door.size
		var gate_size := Vector3(0.15, size.y, size.x) if dir.x != 0 else Vector3(size.x, size.y, 0.15)
		map._add_gate(door.pos + Vector3(0, size.y / 2.0, 0), gate_size)


func _finish() -> void:
	for room in rooms:
		if not room.wide:
			continue
		for c in room.cells:
			# Kits keep the centre clear, but big props can still reach it: then try nearby.
			for offset in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3),
					Vector3(3, 0, 3), Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(-3, 0, 3)]:
				var point: Vector3 = _cell_centre(c) + offset
				if map.is_clear(point):
					map.patrol_points.append(point)
					break
	var spots := 0
	for room in rooms:
		spots += room.get("loot", 0)
	map.loot_count += Vector2i(int(spots * 0.45), int(spots * 0.6))


# --- Helpers for kits -------------------------------------------------------------------

## Registers a loot spot in a room (deeper rooms roll luckier).
func add_loot(room: Dictionary, pos: Vector3, bonus := 0.0) -> void:
	map.loot_spots.append(pos)
	map.loot_luck[pos] = room.depth * LUCK_PER_DEPTH + bonus
	room.loot = room.get("loot", 0) + 1


## Places along the room's walls, facing into the room: [{pos, yaw (degrees)}].
## Keeps clear of doorways.
func wall_slots(room: Dictionary, inset := 0.7, spacing := 2.6) -> Array:
	var slots := []
	for c in room.cells:
		for dir in _dirs():
			var other: Vector2i = c + dir
			if _free.has(other) and _room_of[other] == room.id:
				continue
			if open_plan and _free.has(other):
				continue
			var centre := _side_centre(c, dir)
			var normal := -Vector3(dir.x, 0, dir.y)
			var along := Vector3(dir.y, 0, dir.x).abs()
			var count := int((cell - 2.0) / spacing)
			for i in count:
				var t := (i - (count - 1) / 2.0) * spacing
				var pos := centre + along * t + normal * inset
				if _near_door(room, pos, 2.6):
					continue
				slots.append({"pos": pos, "yaw": rad_to_deg(atan2(normal.x, normal.z))})
	_shuffle(slots)
	return slots


## Random spots on the floor away from walls, doors and the cells' patrol middles.
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
	if not room.wide:
		return false
	for c in room.cells:
		var centre := _cell_centre(c)
		if Vector2(pos.x - centre.x, pos.z - centre.z).length() < clear:
			return true
	return false


func _cell_centre(c: Vector2i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * cell, 0, (c.y + 0.5) * cell)


func _side_centre(c: Vector2i, dir: Vector2i) -> Vector3:
	return _cell_centre(c) + Vector3(dir.x, 0, dir.y) * cell / 2.0


func _dirs() -> Array[Vector2i]:
	return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
