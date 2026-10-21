extends RefCounted
## Smoke tests for the HUD minimap: the M binding, the floor plan rasterised from the
## map's colliders, facing-up rotation and the compass, only squadmates and the open
## exit on it, small -> large -> hidden, hiding with the bag and on death, and the
## dream map's static in the looping corridor.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/minimap_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("minimap")
	_test_binding()
	await _test_factory()
	await _test_afternoon()
	Run.forced_map = "factory"
	return failures


func _test_binding() -> void:
	InputSetup.ensure()
	_check(InputMap.has_action("minimap"), "there is a minimap action")
	var m := InputEventKey.new()
	m.physical_keycode = KEY_M
	_check(InputMap.action_has_event("minimap", m), "M toggles the minimap")
	_check(not InputMap.action_has_event("toggle_mic", m), "M no longer mutes the mic as well")


func _test_factory() -> void:
	Run.forced_map = "factory"
	var main = await _new_run()
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	var map: Minimap = main.hud.minimap
	_check(map != null and map.player == player, "the HUD has a minimap bound to the player")
	map.rasterise_now()
	_check(map.is_ready(), "the floor plan is drawn")
	var walls := 0
	var floors := 0
	var image: Image = map._images[0]
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			if c.a > 0.0 and c.r > 0.7:
				walls += 1
			elif c.a > 0.0:
				floors += 1
	_check(walls > 50 and floors > walls, "the plan has walls and more floor than wall (%d / %d)" % [walls, floors])
	var at := (Vector2(player.global_position.x, player.global_position.z) - map._origin) / Minimap.CELL
	var own := image.get_pixel(int(at.x), int(at.y))
	_check(own.a > 0.0 and own.r < 0.7, "the player's own body isn't drawn as a wall")
	await _frames(2)
	_check(map.visible and map._strip.visible, "the minimap and compass show during the run")

	# Facing-up: something ahead is straight up the disc; the compass reads the yaw.
	player.rotation.y = 0.0
	await _frames(1)
	_check(absf(map.heading()) < 0.5 or absf(map.heading() - 360.0) < 0.5, "facing -z is north (%.1f)" % map.heading())
	var ahead := map._to_disc(player.global_position + Vector3(0, 0, -5))
	_check(ahead.distance_to(Vector2(0, -5)) < 0.01, "a point ahead sits straight up the disc")
	player.rotation.y = -PI / 2.0
	await _frames(1)
	_check(absf(map.heading() - 90.0) < 0.5, "facing +x is east (%.1f)" % map.heading())
	_check(Minimap.bearing_name(map.heading()) == "東", "the caption names the bearing")
	var east := map._to_disc(player.global_position + Vector3(5, 0, 0))
	_check(east.distance_to(Vector2(0, -5)) < 0.01, "the map turns with you")

	# Only your squad shows; the exit only once it's open.
	var mate := Player.new()
	mate.name = "98"
	mate.squad = player.squad
	var rival := Player.new()
	rival.name = "99"
	rival.squad = player.squad + 1
	main.run.players_root.add_child(mate)
	main.run.players_root.add_child(rival)
	await _frames(2)
	mate.set_physics_process(false)
	rival.set_physics_process(false)
	player._camera.current = true
	_check(map._teammates() == [mate], "squadmates are on the map, rivals aren't")
	_check(map._exit_point() == null, "the exit stays off the map until it opens")
	main.level.objective_on = true
	_check(map._exit_point() != null, "the open exit is marked")
	main.level.objective_on = false

	# M: small -> large -> hidden -> small.
	var small := map.size.x
	map.cycle()
	await _frames(1)
	_check(map.mode == Minimap.Mode.LARGE and map.size.x > small, "M makes it bigger")
	map.cycle()
	await _frames(1)
	_check(map.mode == Minimap.Mode.HIDDEN and not map.visible and not map._strip.visible, "then hides it")
	var press := InputEventAction.new()
	press.action = "minimap"
	press.pressed = true
	main.hud._unhandled_input(press)
	await _frames(1)
	_check(map.mode == Minimap.Mode.SMALL and map.visible, "and brings it back small")

	main.set_bag_open(true)
	await _frames(1)
	_check(not map.visible and not map._strip.visible, "the bag screen covers it")
	main.set_bag_open(false)
	await _frames(1)
	_check(map.visible, "back after the bag closes")
	player.die("test")
	await _frames(1)
	_check(not map.visible, "gone once you're dead")
	main.queue_free()
	await _frames(5)


func _test_afternoon() -> void:
	Run.forced_map = "afternoon"
	var main = await _new_run()
	var player: Player = main.player
	if main.colossus != null:
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
		main.colossus.global_position = Vector3(0, 0, -100)
	var map: Minimap = main.hud.minimap
	map.rasterise_now()
	_check(map.is_ready(), "the dream house's plan is drawn too")
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 6.0)
	await _frames(2)
	_check(map.fuzz > 0.0 and map.fuzz < 0.95, "the dream map wobbles but reads (%.2f)" % map.fuzz)
	player.global_position = Vector3(14.0, 0.1, 0.0)
	await _frames(2)
	_check(map.fuzz >= 0.95, "the looping corridor is static on the minimap")
	_check(map.visible, "and nothing breaks there")
	main.queue_free()
	await _frames(5)


func _new_run() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run({})
	await _frames(40)
	return main


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)
