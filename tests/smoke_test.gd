extends SceneTree
## Headless smoke test for the single-player game.
## Run: godot --headless --path . --script res://tests/smoke_test.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_enabled = false
	GameState.reset()
	Run.forced_monsters = ["colossus"]
	_test_economy()
	_test_content()
	await _test_player_basics()
	await _test_colossus()
	await _test_extraction()
	await _test_death()
	await _test_mannequin()
	await _test_moth()
	await _test_mimic()
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures > 0 else 0)


func _test_economy() -> void:
	print("economy")
	GameState.reset()
	_check(GameState.take("crowbar"), "can buy a crowbar")
	_check(GameState.money == GameState.START_MONEY - 60, "buying costs money")
	GameState.give_back("crowbar")
	_check(GameState.owned("crowbar") == 1, "returned gear goes to the stash")
	_check(GameState.take("crowbar") and GameState.money == GameState.START_MONEY - 60, "stash gear is free to take")
	var socks := [LootTable.ITEMS[4], LootTable.ITEMS[4], LootTable.ITEMS[0]]
	var payout := LootTable.payout(socks)
	_check(payout.bonus == 200 and payout.total == 3 + 3 + 35 + 200, "a pair of socks pays the set bonus")
	GameState.reset()


func _test_content() -> void:
	print("content")
	var ids := {}
	for item in LootTable.ITEMS:
		ids[item.id] = true
	_check(LootTable.ITEMS.size() == 60 and ids.size() == 60, "60 distinct loot items (%d)" % LootTable.ITEMS.size())
	var dinos := [LootTable.ITEMS[0], LootTable.ITEMS[0]]
	for item in LootTable.ITEMS:
		if item.id == 19:
			dinos = [item, item, item]
	_check(LootTable.payout(dinos).bonus == 150, "three plastic dinosaurs pay the set bonus")
	var card := {}
	for item in LootTable.ITEMS:
		if item.id == 91:
			card = item
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var paid := LootTable.payout([card], rng)
	_check(paid.total >= 1 and paid.items_list[0].value == paid.total, "a scratch card pays its prize ($%d)" % paid.total)
	var ok := true
	for seed in 300:
		rng.seed = seed
		var kinds := MonsterRoster.pick(rng)
		var large := 0
		for kind in kinds:
			if MonsterRoster.MONSTERS[kind].size == "large":
				large += 1
		if kinds.size() < 2 or kinds.size() > 4 or large > 1:
			ok = false
	_check(ok, "monster draws have 2 to 4 kinds and at most one large")


func _monster(main: Node, script: Script) -> Node:
	for node in main.run.monsters_root.get_children():
		if node.get_script() == script:
			return node
	return null


func _test_mannequin() -> void:
	print("mannequin")
	Run.forced_monsters = ["mannequin"]
	var main = await _new_run()
	var player: Player = main.player
	var dummy: Mannequin = _monster(main, Mannequin)
	_check(dummy != null, "mannequin spawns")
	player.global_position = Vector3(0, 0.1, 4.5)
	player.rotation.y = 0.0  # facing -z
	dummy.global_position = Vector3(0, 0.1, -0.5)
	await _frames(30)
	var start := dummy.global_position
	await _frames(90)
	_check(dummy.is_watched(), "mannequin knows it's being watched")
	_check(dummy.global_position.distance_to(start) < 0.2, "a watched mannequin does not move")
	player.rotation.y = PI  # look away
	var waited := 0
	while player.health == Player.MAX_HEALTH and waited < 300:
		await physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH and not player.is_dead, "it rushes you the moment you look away (hp=%.0f)" % player.health)
	_check(dummy.global_position.distance_to(player.global_position) > 8.0, "then it is somewhere else")
	await _end_run(main)


func _test_moth() -> void:
	print("moth")
	Run.forced_monsters = ["moth"]
	var main = await _new_run()
	var player: Player = main.player
	var moths: Array = main.run.monsters_root.get_children().filter(func(node) -> bool: return node is Moth)
	_check(moths.size() >= 2, "moths spawn (%d)" % moths.size())
	var moth: Moth = moths[0]
	for other in moths.slice(1):
		other.global_position = Vector3(0, 30, -100)
		other.home = other.global_position
	player.global_position = Vector3(4.0, 0.1, 15.0)
	moth.global_position = Vector3(4.0, 2.0, 9.0)
	player.set_lantern(false)
	await _frames(120)
	_check(player.lantern_on == false and moth.global_position.distance_to(player.head_position()) > 3.0,
		"moth ignores a player with the lantern off")
	player.set_lantern(true)
	var waited := 0
	while player.lantern_on and waited < 400:
		await physics_frame
		waited += 1
	_check(not player.lantern_on, "moth flies at the lantern and puts it out")
	_check(moth.resting, "then it rests for a while")
	await _end_run(main)


func _test_mimic() -> void:
	print("mimic")
	Run.forced_monsters = ["mimic"]
	var main = await _new_run({"weapon": "crowbar", "boosts": ["adrenaline"]})
	var player: Player = main.player
	var mimics: Array = main.run.monsters_root.get_children().filter(func(node) -> bool: return node is Mimic)
	_check(mimics.size() >= 2, "mimics spawn (%d)" % mimics.size())
	var mimic: Mimic = mimics[0]
	_check(mimic.get_prompt(player).begins_with("[E] 撿起"), "a mimic reads like loot: %s" % mimic.get_prompt(player))
	mimic.interact(player)
	await _frames(5)
	_check(player.health < Player.MAX_HEALTH and player.items.is_empty(), "picking up a mimic bites instead")
	player.use_boost()
	_check("adrenaline" in player.boosts, "a bitten hand can't use gear")
	_check(not mimic.disguised, "the mimic drops its disguise and runs")
	var other: Mimic = mimics[1]
	other.pry(player)
	await _frames(5)
	_check(not is_instance_valid(other), "a crowbar poke kills a mimic")
	await _end_run(main)
	Run.forced_monsters = ["colossus"]


func _new_run(loadout := {}) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	root.add_child(main)
	main.start_run(loadout)
	await _frames(40)
	return main


func _end_run(main: Node) -> void:
	main.queue_free()
	await _frames(5)


func _test_player_basics() -> void:
	print("player")
	var main = await _new_run({"weapon": "crowbar", "boosts": ["spring_boots"]})
	var player: Player = main.player
	# Park the monster far away and asleep for the movement tests.
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	_check(player.is_on_floor(), "player lands on the floor")

	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(start) > 1.5, "player walks forward")

	var loot := get_nodes_in_group("loot")
	_check(loot.size() >= BoilerFactory.LOOT_MIN, "loot spawns (%d)" % loot.size())
	var item: LootItem = loot[0]
	var value := item.value
	item.interact(player)
	await _frames(2)
	_check(player.items.size() == 1 and player.carried_value == value, "item is picked up")

	# Crawl duct: standing is blocked, crouching fits.
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
	await _frames(20)

	# Ladder up to the east catwalk.
	player.global_position = Vector3(10.6, 0.05, 12.0)
	player.rotation.y = -PI / 2.0  # face +x
	await _frames(10)
	Input.action_press("move_forward")
	await _frames(240)
	Input.action_release("move_forward")
	await _frames(30)
	_check(player.global_position.y > 5.8 and player.global_position.x > 11.4,
		"player climbs the ladder onto the catwalk (pos=%s)" % player.global_position)

	# Walk along the pipe toward the west.
	player.global_position = Vector3(11.0, 6.1, -4.0)
	player.rotation.y = PI / 2.0  # face -x
	await _frames(20)
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	_check(player.global_position.y > 5.8 and player.global_position.x < 9.0,
		"player can walk along the pipe (pos=%s)" % player.global_position)

	# Spring boots: a drop from the catwalk does no damage.
	player.global_position = Vector3(0.0, 6.2, 8.0)
	await _frames(90)
	_check(player.health == Player.MAX_HEALTH, "spring boots prevent fall damage")
	player.boosts.clear()
	player.global_position = Vector3(0.0, 9.0, 8.0)
	await _frames(120)
	_check(player.health < Player.MAX_HEALTH, "falling without spring boots hurts (hp=%.0f)" % player.health)

	# Crowbar opens a locker and drops loot.
	var locker: Locker = main.level.lockers[0]
	var loot_before := get_nodes_in_group("loot").size()
	locker.interact(player)
	await _frames(5)
	_check(locker.is_open and get_nodes_in_group("loot").size() > loot_before, "crowbar pries a locker open")
	await _end_run(main)


func _test_colossus() -> void:
	print("colossus")
	var main = await _new_run()
	var player: Player = main.player
	var colossus: BoilerColossus = main.colossus
	await _frames(30)
	_check(colossus.is_on_floor(), "colossus stands on the floor")
	# Hide the player up on the catwalk so they don't get caught while we test hearing.
	player.global_position = Vector3(13.5, 6.1, 10.0)
	player.set_lantern(false)
	colossus.global_position = Vector3(0, 0.1, 10)
	colossus.state = BoilerColossus.State.PATROL
	await _frames(10)
	var target := Vector3(-6.0, 0.0, -8.0)
	GameNoise.emit(self, target, 50.0, GameNoise.Kind.IMPACT)
	await _frames(5)
	_check(colossus.state == BoilerColossus.State.INVESTIGATE, "colossus investigates a loud noise")
	var start_distance := colossus.global_position.distance_to(target)
	await _frames(180)
	_check(colossus.global_position.distance_to(target) < start_distance - 4.0,
		"colossus walks toward the noise (%.1f -> %.1f)" % [start_distance, colossus.global_position.distance_to(target)])

	# Catwalk is safe: it can't reach the player up there.
	player.set_lantern(true)
	player.global_position = Vector3(-13.5, 6.1, -8.0)
	colossus.global_position = Vector3(-8.0, 0.1, -8.0)
	colossus.rotation.y = PI / 2.0  # face -x, toward the player
	await _frames(240)
	_check(not player.is_dead, "player on the catwalk is out of reach")

	# On the floor, in front of it, the player gets caught.
	player.global_position = colossus.global_position + (-colossus.global_basis.z) * 6.0
	player.global_position.y = 0.1
	var waited := 0
	while not player.is_dead and waited < 300:
		await physics_frame
		waited += 1
	_check(player.is_dead, "colossus catches a player on the floor")
	_check(main.last_result.get("survived", true) == false, "death ends the run")

	# Venting: blind and harmless.
	await _end_run(main)
	main = await _new_run()
	player = main.player
	colossus = main.colossus
	colossus._enter(BoilerColossus.State.VENT)
	player.global_position = colossus.global_position + Vector3(0, 0, 1.0)
	await _frames(30)
	_check(not player.is_dead, "venting colossus can't kill")
	await _end_run(main)


func _test_extraction() -> void:
	print("extraction")
	GameState.reset()
	var main = await _new_run({"weapon": "slingshot", "boosts": []})
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	var item: LootItem = get_nodes_in_group("loot")[0]
	var value := item.value
	item.interact(player)
	var zone: ExtractionZone = main.level.extraction_zone
	player.global_position = zone.global_position - Vector3(0.0, 1.2, 0.0)
	await _frames(300)
	_check(main.run_active, "unpowered elevator does not extract")
	main.level.lever.interact(player)
	_check(zone.powered, "lever powers the elevator")
	var waited := 0
	while main.run_active and waited < 400:
		await physics_frame
		waited += 1
	_check(not main.run_active and main.last_result.survived, "extraction ends the run alive")
	_check(GameState.money == GameState.START_MONEY + value, "extraction pays the loot value ($%d)" % GameState.money)
	_check(GameState.owned("slingshot") == 1, "surviving gear returns to the stash")
	await _end_run(main)


func _test_death() -> void:
	print("death")
	GameState.reset()
	var main = await _new_run({"weapon": "crowbar", "boosts": []})
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.time_left = 0.5
	await _frames(60)
	_check(main.player.is_dead and not main.run_active, "the boiler explodes when time runs out")
	_check(GameState.owned("crowbar") == 0 and GameState.deaths == 1, "gear is lost on death")
	await _end_run(main)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)
