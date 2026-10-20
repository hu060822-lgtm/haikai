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
	await _test_watcher()
	await _test_greeter()
	await _test_collector()
	await _test_rats()
	await _test_centipede()
	await _test_mother()
	await _test_fog_walker()
	await _test_tuner()
	await _test_child()
	await _test_items()
	await _test_gear()
	await _test_squads()
	Run.forced_monsters = ["colossus"]
	await _test_traps()
	await _test_maps()
	await _test_wings()
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
	_check(LootTable.ITEMS.size() == 100 and ids.size() == 100, "100 distinct loot items (%d)" % LootTable.ITEMS.size())
	var pool_rng := RandomNumberGenerator.new()
	pool_rng.seed = 11
	var pool := LootTable.make_pool(pool_rng)
	_check(pool.size() == 31 and not 94 in pool, "each run draws a pool of 31 kinds, never the colossus bolt (%d)" % pool.size())
	var pooled := true
	for i in 200:
		if not LootTable.roll(pool_rng, 0.5, pool).id in pool:
			pooled = false
	_check(pooled, "rolls stay inside the run's pool")
	var letters := []
	for letter in LootTable.NEON_LETTERS:
		var sign := LootTable.make(LootTable.NEON_ID)
		sign.letter = letter
		letters.append(sign)
	_check(LootTable.payout(letters).bonus == LootTable.NEON_BONUS, "neon letters spelling OPEN pay the set bonus")
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
		if kinds.size() < MonsterRoster.MIN_KINDS or kinds.size() > MonsterRoster.MAX_KINDS or large > 1:
			ok = false
	_check(ok, "monster draws have 3 to 5 kinds and at most one large")


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


## Sidestep left and right on the spot for the given number of physics frames.
func _shuffle(frames: int) -> void:
	for i in frames:
		var left := (i / 20) % 2 == 0
		Input.action_press("move_left" if left else "move_right")
		Input.action_release("move_right" if left else "move_left")
		await physics_frame
	Input.action_release("move_left")
	Input.action_release("move_right")


func _test_watcher() -> void:
	print("watcher")
	Run.forced_monsters = ["watcher"]
	var main = await _new_run()
	var player: Player = main.player
	var watcher: Watcher = _monster(main, Watcher)
	_check(watcher != null, "watcher spawns")
	watcher.global_position = Vector3(0, 0.1, -8)
	watcher._pause = 999.0
	player.global_position = Vector3(0, 0.1, 4)
	await _frames(30)
	_check(not watcher.can_see(player), "watcher can't see a player standing still")
	await _shuffle(40)
	_check(watcher.staring, "watcher locks on to a moving player")
	await _frames(240)
	_check(not watcher.staring and not player.is_dead, "freezing makes its stare slide off")
	player.global_position = Vector3(13.5, 0.1, 0)
	await _frames(10)
	_check(watcher.is_covered(player), "a catwalk overhead hides you")
	player.global_position = Vector3(0, 0.1, 4)
	await _frames(10)
	_check(not watcher.is_covered(player), "the open floor doesn't")
	await _shuffle(300)
	await _frames(5)
	_check(player.is_dead, "moving under its stare for 3 seconds gets you taken")
	await _end_run(main)


func _test_greeter() -> void:
	print("greeter")
	Run.forced_monsters = ["greeter"]
	var main = await _new_run()
	var player: Player = main.player
	var greeter: Greeter = _monster(main, Greeter)
	_check(greeter != null, "greeter spawns")
	player.global_position = Vector3(2, 0.1, 8)
	player.rotation.y = 0.0
	greeter.global_position = Vector3(2, 0.1, 13)
	await _frames(30)
	_check(greeter.following, "greeter falls in behind you")
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	_check(player.health == Player.MAX_HEALTH, "walking is fine")
	player.global_position = Vector3(2, 0.1, 8)
	await _frames(20)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(40)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	_check(player.health < Player.MAX_HEALTH and greeter.angry, "running makes it snap (hp=%d)" % player.health)
	await _frames(90)
	greeter._cooldown = 0.0
	player.pickup(LootTable.ITEMS[0])
	greeter.interact(player)
	await _frames(5)
	_check(greeter._ignore.has(player), "showing it something you carry sends it away")
	greeter._ignore.clear()
	player.take_all_items()
	var hp := player.health
	greeter.interact(player)
	await _frames(5)
	_check(player.health < hp, "answering empty-handed is a mistake")
	await _end_run(main)


func _test_collector() -> void:
	print("collector")
	Run.forced_monsters = ["collector"]
	var main = await _new_run()
	var player: Player = main.player
	var collector: Collector = _monster(main, Collector)
	_check(collector != null, "collector spawns")
	player.global_position = Vector3(-13, 0.1, 18)  # tucked away in the tool room
	player.set_lantern(false)
	collector.global_position = Vector3(2, 0.1, 0)
	# Unfrozen, so it is taken whether the collector is wandering or (having spotted you) chasing.
	main.run.host_spawn_loot(LootTable.ITEMS[3], collector.global_position + Vector3(0.4, 0.3, 0), 0.0, false)
	await _frames(45)
	_check(collector.cart_load >= 1, "it clears loot off the floor into its cart")
	collector.state = Collector.State.WANDER
	player.global_position = Vector3(2, 0.1, 8)
	player.set_lantern(true)
	await _frames(20)
	_check(collector.state == Collector.State.CHASE, "it comes after a scavenger it sees")
	main.run.host_spawn_loot(LootTable.ITEMS[7], collector.global_position + Vector3(0, 0.5, 1.0), 0.0, false)
	await _frames(30)
	_check(collector.state == Collector.State.CONTENT, "a bribe thrown at it buys you peace")
	await _end_run(main)


func _test_rats() -> void:
	print("rats")
	Run.forced_monsters = ["rats"]
	var main = await _new_run()
	var player: Player = main.player
	var swarms: Array = main.run.monsters_root.get_children().filter(func(node) -> bool: return node is RatSwarm)
	_check(swarms.size() >= 1, "rat swarms spawn (%d)" % swarms.size())
	var rats: RatSwarm = swarms[0]
	for other in swarms.slice(1):
		other.global_position = Vector3(0, 0.1, -100)
		other.home = other.global_position
	rats.global_position = Vector3(0, 0.1, 0)
	rats.home = Vector3(-8, 0.1, -16)
	player.global_position = Vector3(0, 0.1, 3)
	for i in 3:
		player.pickup(LootTable.ITEMS[10 + i])
	var waited := 0
	while player.items.size() == 3 and waited < 400:
		await physics_frame
		waited += 1
	_check(player.items.size() < 3 and player.health < Player.MAX_HEALTH, "they swarm you and rob your pack (%d left, hp=%d)" % [player.items.size(), player.health])
	await _frames(10)
	_check(rats.state == RatSwarm.State.FETCH or rats.state == RatSwarm.State.HOME, "then drag the loot off")
	rats.state = RatSwarm.State.WANDER
	GameNoise.emit(self, rats.global_position + Vector3(1, 0, 0), 8.0, GameNoise.Kind.LANDING)
	await _frames(2)
	_check(rats.state == RatSwarm.State.SCATTER, "a landing next to them scatters them")
	await _end_run(main)


func _test_centipede() -> void:
	print("centipede")
	Run.forced_monsters = ["centipede"]
	var main = await _new_run()
	var player: Player = main.player
	var centipede: Centipede = _monster(main, Centipede)
	_check(centipede != null and centipede.route.size() >= 4, "centipede spawns with a fixed loop")
	player.global_position = Vector3(-13, 0.1, 18)
	centipede._rest = 0.01
	var start := centipede.global_position
	await _frames(60)
	_check(centipede.running and centipede.global_position.distance_to(start) > 3.0, "it tears along its route")
	player.global_position = centipede.global_position + Vector3.UP * 0.1
	await _frames(5)
	_check(player.is_dead, "anything on the track gets run over")
	await _end_run(main)


func _test_mother() -> void:
	print("mother")
	Run.forced_monsters = ["mother"]
	var main = await _new_run()
	var player: Player = main.player
	var mother: LullabyMother = _monster(main, LullabyMother)
	_check(mother != null, "mother spawns")
	mother.global_position = Vector3(2, 0.1, -6)
	player.global_position = Vector3(2, 0.1, 10)
	player.set_lantern(true)
	await _frames(120)
	_check(mother.global_position.distance_to(player.global_position) < 15.0, "she drifts toward you")
	GameNoise.emit(self, mother.global_position + Vector3(3, 0, 0), 10.0, GameNoise.Kind.MUSIC)
	await _frames(10)
	var held := mother.global_position
	await _frames(60)
	_check(mother.listening and mother.global_position.distance_to(held) < 0.3, "music stops her to listen")
	mother._listen = 0.0
	var waited := 0
	while not player.is_dead and waited < 900:
		await physics_frame
		waited += 1
	_check(player.is_dead, "once she holds you, you don't get up")
	await _end_run(main)


func _test_fog_walker() -> void:
	print("fog walker")
	Run.forced_monsters = ["fog_walker"]
	var main = await _new_run({"weapon": "crowbar"})
	var player: Player = main.player
	var walker: FogWalker = _monster(main, FogWalker)
	_check(walker != null and not walker.revealed, "fog walker spawns unseen")
	walker.global_position = Vector3(2, 0.1, 2)
	player.global_position = Vector3(2, 0.1, 9)
	var waited := 0
	while player.health == Player.MAX_HEALTH and waited < 300:
		await physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "it strikes out of nowhere (hp=%d)" % player.health)
	walker.weapon_hit()
	await _frames(3)
	_check(walker.revealed, "hitting it makes it show up")
	await _end_run(main)


func _test_tuner() -> void:
	print("tuner")
	Run.forced_monsters = ["tuner"]
	var main = await _new_run()
	var player: Player = main.player
	var tuner: Tuner = _monster(main, Tuner)
	_check(tuner != null, "tuner spawns")
	tuner.global_position = Vector3(8, 0.1, -16)
	player.global_position = Vector3(-13, 0.1, 18)
	await _frames(300)
	_check(not tuner.memory.is_empty(), "it remembers where scavengers go")
	# It only hears noises within earshot, and it has been wandering: throw it near where it is now.
	var thrown: Vector3 = tuner.global_position + Vector3(6, 0, 0)
	GameNoise.emit(self, thrown, 12.0, GameNoise.Kind.IMPACT)
	await _frames(2)
	_check(tuner._agent.target_position.distance_to(thrown) < 1.0, "a thrown noise pulls it the wrong way")
	GameNoise.emit(self, tuner.global_position, 8.0, GameNoise.Kind.MUSIC)
	await _frames(2)
	_check(tuner.stunned, "a tune scrambles it")
	tuner._stun = 0.0
	tuner.global_position = Vector3(-3, 0.1, 16.5)
	player.global_position = Vector3(-8.4, 0.1, 16.5)
	await _frames(20)
	_check(main.level.gates[0].closed, "it shuts the door on you")
	await _end_run(main)


func _test_child() -> void:
	print("child")
	Run.forced_monsters = ["child"]
	var main = await _new_run()
	var player: Player = main.player
	var child: HideChild = _monster(main, HideChild)
	_check(child != null, "child spawns")
	child.global_position = Vector3(2, 0.1, 0)
	player.global_position = Vector3(2, 0.1, 9)
	player.rotation.y = PI
	await _frames(20)
	_check(child.state == HideChild.State.COUNT, "it starts counting when you come near")
	await _frames(340)
	_check(child.state == HideChild.State.HIDE, "then it hides")
	var loot_before: int = main.run.loot_root.get_child_count()
	child.global_position = Vector3(2, 0.1, 4)
	player.rotation.y = 0.0
	player.set_lantern(true)
	await _frames(10)
	_check(child.state == HideChild.State.AWAY and main.run.loot_root.get_child_count() > loot_before, "finding it first earns a present")
	child.global_position = Vector3(2, 0.1, 2)
	child.state = HideChild.State.HIDE
	child._timer = 0.0
	player.rotation.y = PI
	var waited := 0
	while player.lantern_on and waited < 400:
		await physics_frame
		waited += 1
	_check(not player.lantern_on, "if it finds you, your lantern goes out")
	await _end_run(main)


func _test_items() -> void:
	print("items")
	Run.forced_monsters = ["colossus"]
	var main = await _new_run()
	var player: Player = main.player
	var colossus: BoilerColossus = main.colossus
	colossus.global_position = Vector3(8, 0.1, -16)
	colossus.set_physics_process(false)

	player.stamina = 0.1
	player.pickup(LootTable.make(17))
	player.use_item()
	await _frames(2)
	_check(player.stamina == 1.0 and not player.carries(17) and player.dream > 0.5, "warm milk restores stamina and makes the world dreamy")

	player.pickup(LootTable.make(85))
	_check(player._heavy_slowed(), "heavy loot slows a lone scavenger")
	_check(player.carries_tag("heavy"), "the backpack's tags are known (for the host's monsters)")
	player.take_all_items()

	player.pickup(LootTable.make(14))
	var loot_before: int = main.run.loot_root.get_child_count()
	for i in 40:
		player._alive_timer = 0.0
		await _frames(1)
		if not player.carries(14):
			break
	await _frames(5)
	_check(not player.carries(14) and main.run.loot_root.get_child_count() > loot_before, "a live fish wriggles out of your hands")

	player.pickup(LootTable.make(81))
	colossus.global_position = player.global_position + Vector3(4, 0, 0)
	player.use_item()
	await _frames(2)
	_check(TimeWarp.instance._slow.has(colossus), "the hourglass slows monsters nearby")
	colossus.global_position = Vector3(8, 0.1, -16)

	var locker: Locker = main.level.lockers[0]
	player.pickup(LootTable.make(43))
	player._focused = locker
	player.use_item()
	await _frames(5)
	_check(locker.is_open and not player.carries(43), "the spare key opens a locker")

	player.pickup(LootTable.make(71))
	await _frames(40)
	_check(main.hud._readout.text.begins_with("溫度計"), "the thermometer shows a reading (%s)" % main.hud._readout.text)

	player.pickup(LootTable.make(77))
	player.use_item()
	await _frames(5)
	_check(player._use_cooldown.has("button"), "the don't-press button can be pressed")

	colossus.set_physics_process(true)
	colossus._enter(BoilerColossus.State.VENT)
	colossus.host_action("bolt", player)
	await _frames(5)
	_check(player.carries(94) and colossus.bolt_taken, "you can wrench the bolt off a venting colossus")
	colossus.set_physics_process(false)

	player.take_all_items()
	player.pickup(LootTable.make(26))
	player.global_position = main.level.player_spawn + Vector3(0, 9, 0)
	player.velocity = Vector3.ZERO
	await _frames(40)
	_check(player.velocity.y >= -Player.UMBRELLA_FALL_SPEED - 0.5 and not player.is_dead, "an umbrella slows your fall")
	await _end_run(main)


func _test_gear() -> void:
	print("gear")
	Run.forced_monsters = ["greeter", "rats", "fog_walker"]
	var main = await _new_run({"weapon": "shotgun", "boosts": ["exoskeleton", "heart_detector", "second_life"]})
	var player: Player = main.player
	var greeter: Greeter = _monster(main, Greeter)
	var rats: RatSwarm = _monster(main, RatSwarm)
	var walker: FogWalker = _monster(main, FogWalker)
	for monster in [greeter, rats, walker]:
		monster.global_position = Vector3(-10, 0.1, -16)
		monster.set_physics_process(false)
	player.global_position = Vector3(2, 0.1, 9)
	player.rotation.y = 0.0
	player.get_node("Head").rotation.x = 0.0
	await _frames(5)

	greeter.global_position = Vector3(2, 0.1, 4)
	player.use_weapon()
	await _frames(3)
	_check(TimeWarp.is_stunned(greeter) and player.weapon_ammo == 1, "a shotgun blast knocks a medium monster down")
	greeter.global_position = Vector3(-10, 0.1, -16)

	_check(player.can_carry({"weight": 40.0}) and Player.max_carry(player) == 45.0, "the exoskeleton carries 15kg more")
	Input.action_press("crouch")
	await _frames(5)
	Input.action_release("crouch")
	_check(not player.is_crouching, "but you can't crouch in it")

	walker.global_position = Vector3(5, 0.1, 6)
	await _frames(40)
	_check(main.hud._readout.text.begins_with("心跳偵測：") and not main.hud._readout.text.contains("沒有"), "the heartbeat detector senses what's near (%s)" % main.hud._readout.text)

	player.global_position = Vector3(2, 0.1, 9)
	player._rewind.clear()
	await _frames(30)
	var safe: Vector3 = player._rewind[0]
	player.global_position = Vector3(2, 0.1, 5)
	player.die("test")
	await _frames(2)
	_check(not player.is_dead and player.global_position.distance_to(safe) < 1.0 and not player.has_gear("second_life"),
		"the second-life watch rewinds death once")

	player.equip({"weapon": "nail_gun", "boosts": ["cat_eye"]})
	player.global_position = Vector3(2, 0.1, 9)
	player.get_node("Head").rotation.x = -0.4
	rats.global_position = Vector3(2, 0.1, 6)
	await _frames(2)
	player.use_weapon()
	await _frames(3)
	_check(not is_instance_valid(rats) or rats.is_queued_for_deletion(), "the nail gun pins a small monster for good")

	walker.global_position = Vector3(2, 0.1, 5)
	player.get_node("Head").rotation.x = 0.0
	player.use_boost()
	await _frames(3)
	_check(walker._model.visible, "cat-eye drops show the invisible")
	player._cat_eye = 0.01
	await _frames(3)
	_check(player.view_saturation() == 0.0, "then the world goes black and white")

	player.equip({"weapon": "megaphone"})
	walker.global_position = Vector3(-10, 0.1, -16)
	greeter.global_position = Vector3(3, 0.1, 4)
	await _frames(2)
	player.use_weapon()
	await _frames(3)
	_check(TimeWarp.is_stunned(greeter), "the megaphone stuns everything in front")

	player.equip({"weapon": "railgun"})
	TimeWarp.instance._stun.clear()
	greeter.set_physics_process(false)
	greeter.global_position = Vector3(2, 0.1, 3)
	player.use_weapon()
	await _frames(int(Player.RAILGUN_CHARGE * 60) + 10)
	_check(TimeWarp.is_stunned(greeter) and player.weapon_ammo == 0, "the railgun fires after charging")

	player.equip({"weapon": "rubber_duck"})
	TimeWarp.instance._stun.clear()
	greeter.set_physics_process(false)
	greeter.global_position = Vector3(2, 0.1, 7.5)
	player.global_position = Vector3(2, 0.1, 14)
	player.use_weapon()
	await _frames(int(RubberDuck.FUSE * 60) + 20)
	_check(player.weapon_ammo == 1 and TimeWarp.is_stunned(greeter), "the rubber duck quacks, then blows up whatever came to look")

	var before := get_nodes_in_group("monsters").size()
	player.equip({"boosts": ["rabbit_foot"]})
	await _frames(10)
	_check(get_nodes_in_group("monsters").size() == before + 1, "the rabbit's foot brings one more monster")
	await _end_run(main)


func _test_field_control() -> void:
	print("field control")
	var main = await _new_run()
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Player = main.player
	var field: FieldControl = main.run.field
	var level: BoilerFactory = main.level
	_check(level.gates.size() >= 4, "the factory has its 4 gates, plus any in the wings")
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


## Another squad's scavenger, standing in front of you: weapons hurt them, never teammates.
func _test_squads() -> void:
	print("squads")
	Run.forced_monsters = ["colossus"]
	var main = await _new_run({"weapon": "shotgun"})
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	var rival := Player.new()
	rival.name = "99"
	rival.display_name = "對手"
	rival.squad = 1
	main.run.players_root.add_child(rival)
	await _frames(2)
	rival.set_physics_process(false)
	player._camera.current = true
	var origin: Vector3 = player._camera.global_position
	var aim: Vector3 = -player._camera.global_basis.z
	aim.y = 0.0
	aim = aim.normalized()
	rival.global_position = player.global_position + aim * 3.0
	await _frames(2)
	_check(not rival._name_label.visible, "a rival's name doesn't float over their head")
	var rule: Dictionary = Gear.WEAPON_HITS.shotgun
	_check(main.run.player_targets(rule, origin, aim, player) == [rival], "the shotgun's aim line finds the rival")
	_check(main.run.player_targets(rule, origin, -aim, player).is_empty(), "aiming away misses")
	rival.squad = 0
	_check(main.run.player_targets(rule, origin, aim, player).is_empty(), "no friendly fire")
	rival.squad = 1
	main.run._weapon("shotgun", origin, aim)
	await _frames(2)
	_check(rival.health == Player.MAX_HEALTH - rule.player, "a shotgun hit hurts the rival (hp=%d)" % rival.health)
	main.run._weapon("crowbar", origin, aim)
	await _frames(2)
	_check(rival.health == Player.MAX_HEALTH - rule.player, "the crowbar only reaches arm's length")
	rival.global_position = player.global_position + aim * 1.5
	await _frames(2)
	main.run._weapon("crowbar", origin, aim)
	await _frames(2)
	_check(rival.is_dead, "a crowbar finishes them off")
	await _end_run(main)


## Traps (scripts/traps/): each kind builds cheaply and the same from the same seed,
## and the main ones go off on a player with the right effect.
class _TrapEar extends Node:
	var heard: Array = []

	func hear(pos: Vector3, radius: float, kind: int) -> void:
		heard.append([pos, radius, kind])

	func loudest(kind := -1) -> float:
		var best := 0.0
		for h in heard:
			if kind < 0 or h[2] == kind:
				best = maxf(best, h[1])
		return best


func _test_traps() -> void:
	print("traps")
	Run.forced_map = "factory"
	var main = await _new_run()
	var level: GameMap = main.level
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	for style in Traps.STYLES:
		var kinds := Traps.kinds_for(style)
		_check(not kinds.is_empty() and kinds.all(func(k: String) -> bool: return Traps.KINDS.has(k)), "traps: %s has trap kinds %s" % [style, kinds])
	var heavy := []
	var same := true
	for kind in Traps.KINDS:
		var a := Traps.create(kind, level, Vector3(40, -30, 40), 30.0, 99)
		var b := Traps.create(kind, level, Vector3(40, -30, 40), 30.0, 99)
		var tris := [0, 0]
		for i in 2:
			for node in [a, b][i].find_children("*", "MeshInstance3D", true, false):
				for s in node.mesh.get_surface_count():
					tris[i] += node.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size() / 3
		if tris[0] >= 300:
			heavy.append([kind, tris[0]])
		if tris[0] != tris[1] or a.name == b.name:
			same = false
		a.queue_free()
		b.queue_free()
	_check(heavy.is_empty(), "traps: every kind stays under 300 triangles %s" % [heavy])
	_check(same, "traps: same seed builds the same trap, each under its own name")
	await _frames(2)
	var ear := _TrapEar.new()
	ear.add_to_group("listeners")
	root.add_child(ear)
	player.global_position = Vector3(0, 0.1, 2)
	player.velocity = Vector3.ZERO
	await _frames(20)
	var floor_at := Vector3(0, player.global_position.y, 2)
	var reset := func(at: Vector3) -> void:
		player.global_position = at + Vector3.UP * 0.05
		player.velocity = Vector3.ZERO
		player.health = Player.MAX_HEALTH
		player.snared = 0.0
		player.trap_slow = 0.0
		ear.heard.clear()

	# Bear trap: snaps shut, bites, holds you, clangs; mashing E frees you sooner.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var bear: BearTrap = Traps.create("bear_trap", level, floor_at, 0.0, 1)
	reset.call(floor_at)
	await _frames(4)
	_check(bear.state == BearTrap.SPRUNG, "bear trap: stepping on it springs it")
	_check(player.health < Player.MAX_HEALTH and player.snared > 1.5, "bear trap: it bites and holds you (hp=%d, held %.1fs)" % [player.health, player.snared])
	_check(ear.loudest() >= 20.0, "bear trap: the clang is loud (%.0f)" % ear.loudest())
	var held_at := player.global_position
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	_check(player.global_position.distance_to(held_at) < 0.15, "bear trap: you can't walk away while held")
	var before: float = player.snared
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(1)
	_check(player.snared < before - 0.4, "bear trap: mashing E works you free sooner (%.2f -> %.2f)" % [before, player.snared])
	player.snared = 0.0
	reset.call(floor_at + Vector3(0, 0, 3))
	bear._rearm = 0.0
	await _frames(3)
	_check(bear.state == BearTrap.ARMED, "bear trap: the host re-arms it once nobody is on it")
	Input.action_press("crouch")
	await _frames(3)
	bear.interact(player)
	await _frames(2)
	Input.action_release("crouch")
	_check(bear.state == BearTrap.SAFE, "bear trap: crouch and E disarms it")
	reset.call(floor_at)
	await _frames(4)
	_check(player.snared == 0.0 and player.health == Player.MAX_HEALTH, "bear trap: a disarmed trap is harmless")
	bear.queue_free()

	# Tripwire: walking through rattles the cans loud enough to draw monsters.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var wire: Tripwire = Traps.create("tripwire", level, floor_at, 0.0, 2, {"width": 1.4})
	reset.call(floor_at + Vector3(0.3, 0, 0.1))
	await _frames(4)
	_check(wire.state == Tripwire.TRIPPED, "tripwire: walking into it trips it")
	_check(ear.loudest(GameNoise.Kind.MACHINE) >= 40.0, "tripwire: the rattle carries far (%.0f)" % ear.loudest())
	wire.queue_free()
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var cut: Tripwire = Traps.create("tripwire", level, floor_at, 90.0, 3)
	Input.action_press("crouch")
	await _frames(3)
	cut.interact(player)
	await _frames(2)
	Input.action_release("crouch")
	reset.call(floor_at)
	await _frames(4)
	_check(cut.state == Tripwire.CUT and ear.loudest() < 40.0, "tripwire: crouch and E cuts it quietly")
	cut.queue_free()

	# Steam vent: hisses first, then the burst burns you and throws you back.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var vent: SteamVent = Traps.create("steam_vent", level, floor_at, 0.0, 4)
	vent._clock = SteamVent.PERIOD - SteamVent.BURST_TIME - SteamVent.HISS_TIME + 0.05
	await _frames(3)
	_check(vent.state == SteamVent.HISS, "steam vent: it hisses before it bursts")
	reset.call(floor_at + Vector3(0.3, 0, 0))
	vent._clock = SteamVent.PERIOD - SteamVent.BURST_TIME + 0.02
	await _frames(2)
	_check(vent.state == SteamVent.BURST and player.health < Player.MAX_HEALTH, "steam vent: the burst scalds you (hp=%d)" % player.health)
	await _frames(20)
	_check(Vector2(player.global_position.x - floor_at.x, player.global_position.z - floor_at.z).length() > 0.6,
		"steam vent: it throws you off the grate")
	vent.queue_free()

	# Electrified puddle: shocks you while the power is on, safe in a blackout.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var puddle: LivePuddle = Traps.create("live_puddle", level, floor_at, 0.0, 5)
	level.power_on = false
	reset.call(floor_at)
	await _frames(10)
	_check(player.health == Player.MAX_HEALTH, "live puddle: harmless with the power off")
	level.power_on = true
	await _frames(10)
	_check(player.health < Player.MAX_HEALTH, "live puddle: shocks you with the power on (hp=%d)" % player.health)
	puddle.queue_free()

	# Shop alarm gate: only screams when you carry loot through it.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var gate: AlarmGate = Traps.create("alarm_gate", level, floor_at, 0.0, 6)
	reset.call(floor_at + Vector3(0, 0, 1.0))
	await _frames(3)
	reset.call(floor_at)
	await _frames(3)
	_check(gate.state == AlarmGate.STANDBY, "alarm gate: empty-handed walks through quietly")
	reset.call(floor_at + Vector3(0, 0, 1.0))
	player.pickup(LootTable.make(1))
	await _frames(3)
	reset.call(floor_at)
	await _frames(3)
	_check(gate.state == AlarmGate.ALARM and ear.loudest(GameNoise.Kind.MACHINE) >= 40.0, "alarm gate: carrying loot through sets it screaming")
	player.items.clear()
	player._recalculate()
	gate.queue_free()

	# Pressure plate: click, a moment, then the sandbag drops on whoever stayed.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var plate: DebrisPlate = Traps.create("debris_plate", level, floor_at, 0.0, 7)
	reset.call(floor_at)
	await _frames(3)
	_check(plate.state == DebrisPlate.CLICKED and player.health == Player.MAX_HEALTH, "debris plate: it clicks first")
	await _frames(60)
	_check(plate.state == DebrisPlate.FALLEN and player.health < Player.MAX_HEALTH, "debris plate: the bag lands on you if you stay (hp=%d)" % player.health)
	plate.queue_free()

	# Music box: wakes up when you come close, plays a lure for monsters, E shuts it.
	reset.call(floor_at + Vector3(0, 0, 6))
	await _frames(3)
	var box: MusicBox = Traps.create("music_box", level, floor_at, 0.0, 8)
	await _frames(3)
	_check(box.state == MusicBox.WAITING, "music box: quiet until someone comes near")
	reset.call(floor_at + Vector3(0, 0, 1.2))
	await _frames(5)
	_check(box.state == MusicBox.PLAYING and box._music.playing, "music box: it opens and plays as you approach")
	_check(ear.loudest(GameNoise.Kind.MUSIC) >= 25.0, "music box: its tune is a lure monsters hear (%.0f)" % ear.loudest(GameNoise.Kind.MUSIC))
	box.interact(player)
	await _frames(3)
	_check(box.state == MusicBox.SHUT and not box._music.playing, "music box: E snaps it shut")
	box.queue_free()

	# Soft floor: wading is slow and every step squeaks.
	reset.call(floor_at + Vector3(0, 0, 3))
	await _frames(3)
	var mat: SqueakFloor = Traps.create("squeak_floor", level, floor_at, 0.0, 9)
	reset.call(floor_at + Vector3(-0.6, 0, 0))
	player.rotation.y = -PI / 2.0
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	_check(player.trap_slow > 0.0 and ear.loudest(GameNoise.Kind.FOOTSTEP) >= 10.0, "squeak floor: slows you and squeaks loudly")
	mat.queue_free()
	await _end_run(main)

	# Thin ice on the station: cracks first, breaks on the next step, the water chills you.
	Run.forced_map = "station"
	main = await _new_run()
	var station := main.level as ResearchStation
	player = main.player
	if main.colossus != null:
		main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0, 0.1, 6)
	player.velocity = Vector3.ZERO
	await _frames(20)
	var ice_at := Vector3(0, player.global_position.y, 9)
	var ice: ThinIce = Traps.create("thin_ice", station, ice_at, 0.0, 10)
	player.global_position = ice_at + Vector3.UP * 0.05
	await _frames(3)
	_check(ice.state == ThinIce.CRACKED, "thin ice: the first step cracks it")
	player.global_position = ice_at + Vector3(0, 0.05, 2.5)
	await _frames(3)
	station.body_heat = 60.0
	player.global_position = ice_at + Vector3.UP * 0.05
	await _frames(3)
	_check(ice.state == ThinIce.BROKEN, "thin ice: the second step breaks through")
	_check(player.trap_slow > 0.0 and station.body_heat < 50.0, "thin ice: freezing water slows you and steals body heat (%d)" % station.body_heat)
	var icicles: Icicles = Traps.create("icicles", station, ice_at + Vector3(4, 0, 0), 0.0, 11)
	player.health = Player.MAX_HEALTH
	player.global_position = ice_at + Vector3(4, 0.05, 0)
	await _frames(60)
	_check(icicles.state == Icicles.FALLEN and player.health < Player.MAX_HEALTH, "icicles: they drop on you if you linger (hp=%d)" % player.health)
	await _end_run(main)
	ear.queue_free()
	Run.forced_map = "factory"


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
		var starts: Array[Vector3] = []
		for slot in Session.SQUADS:
			starts.append(main.run.squad_start(slot).pos)
		var close := []
		for a in starts.size():
			for b in range(a + 1, starts.size()):
				if starts[a].distance_to(starts[b]) < 12.0:
					close.append([a, b])
		_check(close.is_empty(), "%s: squads start apart %s" % [id, close])
		# Slot 0 is the map's own spawn; the others come from patrol points.
		_check(starts.slice(1).all(func(point: Vector3) -> bool:
			return NavigationServer3D.map_get_closest_point(nav_map, point).distance_to(point) < 1.0),
			"%s: squad starts are on walkable floor" % id)
		_check(not level.extraction_zone.powered, "%s: exit starts unpowered" % id)
		main.run._lever_pulled()
		await _frames(2)
		_check(level.extraction_zone.powered, "%s: objective powers the exit" % id)
		match id:
			"mall":
				await _test_mall(main, level, player)
			"station":
				await _test_station(main, level as ResearchStation, player)
			"afternoon":
				await _test_afternoon(main, level as EndlessAfternoon, player)
		await _end_run(main)
	Run.forced_map = "factory"


## Every map grows random side wings; the same seed must give every peer the same layout.
func _test_wings() -> void:
	print("wings")
	for id in MapRoster.MAPS:
		var layouts := []
		for seed in [7, 7, 8]:
			var level: GameMap = MapRoster.create(id)
			level.rng.seed = seed
			root.add_child(level)
			var room_count: int = level.wings.reduce(func(n: int, w: RoomGrid) -> int: return n + w.rooms.size(), 0)
			layouts.append([room_count, level.loot_spots.duplicate(), level.bounds])
			level.free()
		_check(layouts[0][0] >= 10, "%s: wings add rooms (%d)" % [id, layouts[0][0]])
		_check(layouts[0][1] == layouts[1][1], "%s: same seed, same layout" % id)
		_check(layouts[0][1] != layouts[2][1], "%s: other seed, other layout" % id)
		_check(layouts[0][2].size.x * layouts[0][2].size.z >= 9000.0, "%s: map is big (%s)" % [id, layouts[0][2].size])
		await _frames(1)


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


func _test_afternoon(main: Node, dream: EndlessAfternoon, player: Player) -> void:
	_check(dream.bright and player.is_lit(), "afternoon: too bright for darkness to hide you")
	player.global_position = Vector3(16.5, 0.1, 0)
	player.rotation.y = -PI / 2.0
	Input.action_press("move_forward")
	await _frames(60)
	Input.action_release("move_forward")
	_check(player.global_position.x < EndlessAfternoon.LOOP_AT, "afternoon: the corridor loops (x=%.1f)" % player.global_position.x)
	var door: DreamDoor = dream.find_children("*", "DreamDoor", true, false)[0]
	var before := player.global_position
	door.interact(player)
	var first := player.global_position
	door.interact(player)
	_check(first.distance_to(before) > 3.0 and player.global_position.distance_to(first) > 1.0, "afternoon: the white door opens onto a different room each time")
	var start := dream.clarity
	await _frames(120)
	_check(dream.clarity < start and dream.status_text().begins_with("清醒度"), "afternoon: clarity drains (%s)" % dream.status_text())
	dream.clarity = 20.0
	await _frames(2)
	_check(player.dream > 0.5, "afternoon: the dream thickens as clarity falls")
	for id in [1, 2, 3, 4]:
		player.pickup(LootTable.make(id))
	dream.clarity = 0.0
	await _frames(5)
	_check(main.run.finished and main.last_result.get("survived", false) and main.last_result.items.size() == 2,
		"afternoon: at zero you're woken up with half your loot (%d items)" % main.last_result.get("items", []).size())


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
	# Something light: heavy loot would slow the crawl below.
	var item: LootItem = loot.filter(func(node: LootItem) -> bool: return not LootTable.has_tag(node.data, "heavy"))[0]
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
