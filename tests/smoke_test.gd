extends SceneTree
## Headless smoke test for the phase 0 slice.
## Run: godot --headless --path . --script res://tests/smoke_test.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	main.auto_restart = false
	root.add_child(main)
	await _frames(40)

	var player: Player = main.player
	_check(player != null, "player spawns")
	_check(player.is_on_floor(), "player lands on the floor")

	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start) > 1.5, "player walks forward")

	var loot := get_nodes_in_group("loot")
	_check(loot.size() == BoilerFactoryTest.LOOT_COUNT, "loot spawns (%d)" % loot.size())

	var item: LootItem = loot[0]
	var value := item.value
	item.interact(player)
	await _frames(2)
	_check(player.items.size() == 1, "item is picked up")
	_check(player.carried_value == value, "carried value matches item")
	_check(not is_instance_valid(item), "picked item leaves the world")

	# Standing is too tall for the crawl duct; crouching fits.
	player.global_position = Vector3(-5.0, 0.05, 9.0)
	player.rotation.y = 0.0
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(60)
	_check(player.global_position.z > 7.5, "standing player is blocked by the duct")
	Input.action_press("crouch")
	await _frames(240)
	Input.action_release("move_forward")
	_check(player.global_position.z < 5.0, "crouching player crawls into the duct (z=%.2f)" % player.global_position.z)
	Input.action_release("crouch")
	await _frames(10)
	_check(player.is_crouching, "player stays crouched under the duct ceiling")

	# Walk out on the walkway pipe from the east catwalk.
	player.global_position = Vector3(12.5, 3.1, -4.0)
	player.rotation.y = PI / 2.0  # face -x
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	_check(player.global_position.y > 2.8 and player.global_position.x < 10.0,
		"player can walk along the pipe (pos=%s)" % player.global_position)

	# Extraction.
	var zone: ExtractionZone = main.level.extraction_zone
	player.global_position = zone.global_position - Vector3(0.0, 1.2, 0.0)
	var waited := 0
	while main.extraction_count == 0 and waited < 400:
		await physics_frame
		waited += 1
	_check(main.extraction_count == 1, "extraction triggers after holding in the zone")
	_check(main.last_extract_value == value, "extraction counts carried loot value")
	_check(player.items.is_empty(), "backpack is emptied on extraction")

	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
