extends SceneTree
## Looks for holes a player can fall out of the map through. Builds a map, then walks
## its floor from the player spawn on a 0.5 m grid (stepping up at most STEP, dropping
## any distance onto something below) and reports every spot next to walkable floor
## where a player-sized sphere falls past the bottom of the map.
## Run (headless is fine):
##   godot --headless --path . --script res://tools/hole_scan.gd -- <map|all> [seeds] [first_seed]

const CELL := 0.5
const STEP := 0.55
const BOTTOM := -30.0
const MASK := Layers.WORLD | Layers.WALKWAY

var holes_found := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var which: String = args[0] if args.size() > 0 else "all"
	var seeds: int = int(args[1]) if args.size() > 1 else 4
	var first: int = int(args[2]) if args.size() > 2 else 1
	var maps: Array = MapRoster.MAPS if which == "all" else [which]
	for map_id in maps:
		for seed in range(first, first + seeds):
			await _scan(map_id, seed)
	print("HOLE SCAN DONE: %d holes" % holes_found)
	quit(1 if holes_found > 0 else 0)


func _scan(map_id: String, seed: int) -> void:
	var level: GameMap = MapRoster.create(map_id)
	level.rng.seed = seed
	level.build_navigation = false
	root.add_child(level)
	for i in 3:
		await physics_frame
	var space := level.get_world_3d().direct_space_state
	var start := level.player_spawn
	var floor_y := _floor(space, Vector3(start.x, start.y + 1.0, start.z))
	if is_nan(floor_y):
		print("%s seed %d: spawn has no floor" % [map_id, seed])
		holes_found += 1
		level.queue_free()
		await process_frame
		return
	var seen := {}
	var queue: Array = [[Vector2i(roundi(start.x / CELL), roundi(start.z / CELL)), floor_y]]
	seen[_key(queue[0][0], floor_y)] = true
	var holes: Array[Vector3] = []
	var bounds := level.bounds.grow(6.0)
	var visited := 0
	while not queue.is_empty() and visited < 400000:
		var item: Array = queue.pop_back()
		visited += 1
		var cell: Vector2i = item[0]
		var y: float = item[1]
		var here := Vector3(cell.x * CELL, y, cell.y * CELL)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + d
			var there := Vector3(next.x * CELL, y, next.y * CELL)
			if not bounds.has_point(Vector3(there.x, bounds.position.y + 0.1, there.z)):
				continue
			# A wall (or anything a player can't pass) between the two cells.
			if _blocked(space, here, there):
				continue
			var ny := _floor(space, there + Vector3.UP * (STEP + 0.4))
			if is_nan(ny):
				if _sphere_falls(space, there):
					holes.append(there)
				continue
			if ny > y + STEP:
				continue
			var key := _key(next, ny)
			if seen.has(key):
				continue
			seen[key] = true
			queue.append([next, ny])
	print("%s seed %d: %d floor cells walked, %d hole cells" % [map_id, seed, visited, holes.size()])
	for cluster in _clusters(holes):
		holes_found += 1
		print("  HOLE near (%.1f, %.1f, %.1f) — %d cells" % [cluster[0].x, cluster[0].y, cluster[0].z, cluster[1]])
	level.queue_free()
	await process_frame


## Height of the first walkable surface straight below `from`, or NAN.
func _floor(space: PhysicsDirectSpaceState3D, from: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, Vector3(from.x, BOTTOM, from.z), MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return hit.position.y


## Is the way from one cell to the next blocked at knee and chest height?
func _blocked(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	for h in [0.6, 1.2]:
		var query := PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, b + Vector3.UP * h, MASK)
		if not space.intersect_ray(query).is_empty():
			return true
	return false


## Would a player-sized sphere dropped here fall past the bottom of the map?
func _sphere_falls(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = MASK
	query.transform = Transform3D(Basis(), at + Vector3.UP * 0.5)
	query.motion = Vector3(0, BOTTOM - at.y, 0)
	var result := space.cast_motion(query)
	return result.size() == 2 and result[0] >= 0.999


func _key(cell: Vector2i, y: float) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, roundi(y * 2.0)]


## Groups neighbouring hole cells: [[first point, count], ...].
func _clusters(points: Array[Vector3]) -> Array:
	var result := []
	var used := {}
	for i in points.size():
		if used.has(i):
			continue
		var stack := [i]
		used[i] = true
		var count := 0
		while not stack.is_empty():
			var j: int = stack.pop_back()
			count += 1
			for k in points.size():
				if not used.has(k) and points[k].distance_to(points[j]) < CELL * 1.6:
					used[k] = true
					stack.append(k)
		result.append([points[i], count])
	return result
