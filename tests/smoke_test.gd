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
	Run.director_enabled = false
	Run.forced_map = "factory"
	_test_economy()
	_test_content()
	await _test_player_basics()
	await _test_colossus()
	await _test_extraction()
	await _test_death()
	await _test_mannequin()
	await _test_moth()
	await _test_mimic()
	await _test_field_control()
	await _test_director()
	await _test_maps()
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


func _test_field_control() -> void:
	print("field control")
	var main = await _new_run()
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Player = main.player
	var field: FieldControl = main.run.field
	var level: BoilerFactory = main.level
	_check(level.gates.size() == 4, "the factory has 4 gates")
	var before := field.energy
	GameNoise.emit(self, player.global_position, 14.0, GameNoise.Kind.FOOTSTEP)
	_check(field.energy > before, "scavenger noise feeds the guardian's energy")
	field.energy = 10.0
	_check(not field.use_gate(0), "no energy, no gate")
	field.energy = 100.0
	player.global_position = Vector3(4.0, 0.1, 19.0)
	_check(field.use_gate(0) and level.gates[0].closed, "a gate can be slammed shut")
	_check(field.energy == 75.0 and not field.can_use("gate"), "it costs energy and goes on cooldown")
	await _frames(5)
	# The tool-room door now blocks the way in.
	player.global_position = Vector3(-8.0, 0.1, 16.5)
	player.rotation.y = PI / 2.0  # face -x, into the room
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	_check(player.global_position.x > -9.4, "a closed gate blocks the doorway (x=%.2f)" % player.global_position.x)
	field._gate_timers[0] = 0.01
	await _frames(5)
	_check(not level.gates[0].closed, "the gate rolls back up after a while")
	# Can't shut a gate on someone standing in it.
	field.cooldowns.gate = 0.0
	player.global_position = Vector3(-9.5, 0.1, 16.5)
	await _frames(3)
	_check(not field.use_gate(0), "a gate won't close on a player in the doorway")

	main.level.lever.interact(player)
	_check(level.extraction_zone.powered, "lever powers the lift")
	_check(field.use_power() and not level.extraction_zone.powered, "a blackout stops the lift")
	field._power_timer = 0.01
	await _frames(5)
	_check(level.extraction_zone.powered, "power comes back after the blackout")

	field.energy = 100.0
	var moths_before: int = main.run.monsters_root.get_children().filter(func(n) -> bool: return n is Moth).size()
	_check(not field.use_monster("moth", player.global_position + Vector3(1, 0, 0)), "can't release a monster on top of someone")
	_check(field.use_monster("moth", Vector3(0, 0.1, -8.0)), "can release a monster away from players")
	await _frames(3)
	var moths_after: int = main.run.monsters_root.get_children().filter(func(n) -> bool: return n is Moth).size()
	_check(moths_after == moths_before + 1, "the released moth appears")
	await _end_run(main)


func _test_director() -> void:
	print("director")
	Run.director_enabled = true
	var main = await _new_run()
	Run.director_enabled = false
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	var director: Director = main.run.director
	_check(director != null, "the AI director stands in when nobody is the guardian")
	var player: Player = main.player
	var field: FieldControl = main.run.field
	field.energy = 100.0
	main.level.lever.interact(player)
	player.global_position = main.level.extraction_zone.global_position + Vector3(0, -1.2, 4.0)
	await _frames(3)
	_check(director.decide() == "power", "the director cuts the power when someone nears the lift")
	field.energy = 100.0
	player.global_position = Vector3(-8.0, 0.1, 16.5)
	await _frames(3)
	_check(director.decide() == "gate", "the director slams a gate near a scavenger")
	GameState.reset()
	await _end_run(main)


func _test_maps() -> void:
	print("maps")
	for id in MapRoster.MAPS:
		Run.forced_map = id
		var main = await _new_run()
		var level: GameMap = main.level
		var player: Player = main.player
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
		_check(level.map_name != "", "%s: has a name (%s)" % [id, level.map_name])
		_check(player.is_on_floor(), "%s: player lands on the floor" % id)
		_check(main.run.loot_root.get_child_count() >= level.loot_count.x, "%s: loot spawns (%d)" % [id, main.run.loot_root.get_child_count()])
		_check(level.loot_spots.all(func(spot: Vector3) -> bool: return level.in_bounds(spot)), "%s: loot spots are inside the map" % id)
		_check(level.gates.size() >= 4, "%s: guardian has gates to close (%d)" % [id, level.gates.size()])
		var nav_map: RID = level.get_world_3d().navigation_map
		var off_mesh := level.patrol_points.filter(func(point: Vector3) -> bool:
			return NavigationServer3D.map_get_closest_point(nav_map, point).distance_to(point) > 1.0)
		_check(off_mesh.is_empty(), "%s: patrol points are on the navmesh %s" % [id, off_mesh])
		_check(not level.extraction_zone.powered, "%s: exit starts unpowered" % id)
		main.run._lever_pulled()
		await _frames(2)
		_check(level.extraction_zone.powered, "%s: objective powers the exit" % id)
		match id:
			"mall":
				await _test_mall(main, level, player)
			"station":
				await _test_station(main, level as ResearchStation, player)
		await _end_run(main)
	Run.forced_map = "factory"


func _test_mall(_main: Node, level: GameMap, player: Player) -> void:
	# Walk up the stopped escalator onto the upper floor.
	player.global_position = Vector3(3.6, 0.1, 8.5)
	player.rotation.y = PI / 2.0
	Input.action_press("move_forward")
	await _frames(240)
	Input.action_release("move_forward")
	_check(player.global_position.y > MidnightMall.UPPER_Y - 0.3, "mall: escalator reaches the upper floor (pos=%s)" % player.global_position)
	# Shutters drop on their own.
	var mall := level as MidnightMall
	player.global_position = Vector3(0, 0.1, 20)
	for attempt in 6:
		mall._shutter_timer = 0.0
		await _frames(2)
	_check(level.gates.any(func(gate: Gate) -> bool: return gate.closed), "mall: a shop shutter rolls down by itself")
	mall._announce_timer = 0.0
	await _frames(2)
	_check(mall._announce_timer > 0.0, "mall: the PA makes an announcement")


func _test_station(_main: Node, station: ResearchStation, player: Player) -> void:
	_check(not station.is_outdoors(station.player_spawn), "station: spawn is indoors")
	player.global_position = Vector3(0, 0.1, 6)
	player.velocity = Vector3.ZERO
	await _frames(5)
	var start := station.body_heat
	await _frames(120)
	_check(station.body_heat < start - 1.0, "station: the cold drains body heat outside (%d -> %d)" % [start, station.body_heat])
	_check(station.status_text().contains("室外"), "station: HUD shows body heat (%s)" % station.status_text())
	player.global_position = Vector3(-24.0, 0.1, 0.5)
	var cold := station.body_heat
	await _frames(120)
	_check(station.body_heat > cold + 1.0, "station: a stove warms you back up (%d -> %d)" % [cold, station.body_heat])
	player.global_position = Vector3(0, 0.1, 6)
	station.body_heat = 0.0
	var hp := player.health
	await _frames(200)
	_check(player.health < hp, "station: freezing hurts (hp=%d)" % player.health)


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
