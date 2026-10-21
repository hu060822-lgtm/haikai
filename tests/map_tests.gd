extends RefCounted
## Smoke tests for holes in the maps: every doorway cut in a core's wall leads into a
## room (or is bricked up), there is floor just past every open one, and a player who
## somehow falls under the map is put back on the last floor they stood on.
## The full floor walk is tools/hole_scan.gd (slow; run it after changing map code).
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/map_tests.gd").new().run(self)

const SEEDS := 8

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("map holes")
	await _test_ports()
	await _test_safety_net()
	return failures


func _test_ports() -> void:
	var orphans := []
	var no_floor := []
	var sealed := 0
	for map_id in MapRoster.MAPS:
		for seed in range(1, SEEDS + 1):
			var level: GameMap = MapRoster.create(map_id)
			level.rng.seed = seed
			level.build_navigation = false
			tree.root.add_child(level)
			await tree.physics_frame
			await tree.physics_frame
			var space := level.get_world_3d().direct_space_state
			for grid in level.wings:
				var served := {}
				for room in grid.rooms:
					for door in room.doors:
						if door.kind == "port":
							served[door.port] = true
				for i in grid.ports.size():
					if grid.sealed_ports.has(i):
						sealed += 1
						continue
					if not served.has(i):
						orphans.append("%s/%d port %d" % [map_id, seed, i])
						continue
					var port: Dictionary = grid.ports[i]
					var past: Vector3 = port.pos + Vector3(port.dir.x, 0, port.dir.y) * 0.6
					var query := PhysicsRayQueryParameters3D.create(past + Vector3.UP, past + Vector3.DOWN * 20.0, Layers.WORLD | Layers.WALKWAY)
					if space.intersect_ray(query).is_empty():
						no_floor.append("%s/%d port %d" % [map_id, seed, i])
			level.queue_free()
			await tree.process_frame
	_check(orphans.is_empty(), "every doorway in a core wall leads to a room or is bricked up %s (%d bricked)" % [orphans, sealed])
	_check(no_floor.is_empty(), "there is floor just past every open doorway %s" % [no_floor])


func _test_safety_net() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run({})
	for i in 60:
		await tree.physics_frame
	var player: Player = main.player
	var stood := player.global_position
	var bottom: float = main.run.level.bounds.position.y
	player.global_position = Vector3(stood.x, bottom - Player.FALL_OUT_DEPTH - 2.0, stood.z)
	for i in 3:
		await tree.physics_frame
	_check(player.global_position.y > bottom and player.global_position.distance_to(stood) < 2.0 and not player.is_dead,
		"falling under the map puts you back where you last stood (%.1f m off)" % player.global_position.distance_to(stood))
	main.queue_free()
	for i in 5:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
