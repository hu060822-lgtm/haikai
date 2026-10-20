extends RefCounted
## Smoke tests for monster worker A: the five new monsters (spitter, burrower, splitter and
## its crawlers, ceiling dropper, screamer) and the hit reactions of the older ones.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/monster_a_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


class Ear extends Node:
	var heard: Array = []

	func _ready() -> void:
		add_to_group("listeners")

	func hear(position: Vector3, radius: float, kind: int) -> void:
		heard.append([position, radius, kind])

	func loudest(kind := -1) -> float:
		var best := 0.0
		for entry: Array in heard:
			if kind < 0 or entry[2] == kind:
				best = maxf(best, entry[1])
		return best


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	await _test_screamer()
	await _test_spitter()
	await _test_splitter()
	await _test_dropper()
	await _test_burrower()
	await _test_old_reactions()
	Run.forced_monsters = ["colossus"]
	return failures


## Hit a monster the way a gun does: through Run.host_damage_monster when it exists,
## otherwise the same rules done here (on_hit multiplier, roster weakness, kill or break).
func hit(monster: Node3D, amount: float, effects := {}, from := Vector3.INF, point := Vector3.INF, attacker: Player = null) -> void:
	if not is_instance_valid(monster) or monster.is_queued_for_deletion():
		return
	if from == Vector3.INF:
		from = monster.global_position + Vector3(0, 1.5, -6.0)
	if point == Vector3.INF:
		point = monster.global_position + Vector3.UP
	var run := Run.instance
	if run != null and run.has_method("host_damage_monster"):
		run.host_damage_monster(monster, amount, effects, from, attacker, point)
		return
	var kind: String = monster.get_meta("kind", "")
	var entry: Dictionary = MonsterRoster.MONSTERS.get(kind, {})
	var size: String = entry.get("size", "medium")
	var max_hp: float = entry.get("health", {"small": 40.0, "medium": 160.0, "large": 600.0}[size])
	if not monster.has_meta("hp"):
		monster.set_meta("hp", max_hp)
		monster.set_meta("max_hp", max_hp)
	var mult := 1.0
	if monster.has_method("on_hit"):
		mult = monster.on_hit({"amount": amount, "effects": effects, "from": from, "point": point, "attacker": attacker})
	var weak: Dictionary = entry.get("weak", {})
	if effects.is_empty():
		mult *= weak.get("bullet", 1.0)
	for effect in effects:
		mult *= weak.get(effect, 1.0)
	var hp: float = monster.get_meta("hp") - amount * mult
	if hp > 0.0:
		monster.set_meta("hp", hp)
		return
	if size == "large":
		TimeWarp.stun(monster, 8.0)
		if monster.has_method("on_broken"):
			monster.on_broken()
		monster.set_meta("hp", max_hp)
	elif monster.has_method("host_kill"):
		monster.host_kill()
	else:
		monster.queue_free()


func _test_screamer() -> void:
	print("screamer")
	Run.forced_monsters = ["screamer"]
	var main = await _new_run()
	var player: Player = main.player
	var masks := _all(main, Screamer)
	_check(masks.size() >= 1, "screamers spawn (%d)" % masks.size())
	var mask: Screamer = masks[0]
	for other in masks.slice(1):
		other.queue_free()
	var ear := Ear.new()
	main.add_child(ear)
	player.global_position = Vector3(4.0, 0.1, 15.0)
	player.rotation.y = PI  # back turned: no gun on it
	mask.global_position = Vector3(4.0, 0.1, 8.0)
	var waited := 0
	while ear.loudest(GameNoise.Kind.VOICE) < 100.0 and waited < 300:
		await tree.physics_frame
		waited += 1
	_check(ear.loudest(GameNoise.Kind.VOICE) >= Screamer.SCREAM_RADIUS, "it sees you and screams to the whole map (%d frames)" % waited)
	_check(waited > int(Screamer.WINDUP * 50.0), "after a breath you can hear coming")
	# Now point a gun at it: it can't scream with a barrel on it.
	ear.heard.clear()
	mask._cooldown = 0.0
	mask.state = Screamer.State.WANDER
	player.rotation.y = 0.0  # facing -z, right at it
	player.get_node("Head").rotation.x = -0.1
	await _frames(20)
	_check(mask.state == Screamer.State.FLEE, "a gun pointed at it sends it running")
	await _frames(60)
	_check(ear.loudest(GameNoise.Kind.VOICE) < 100.0, "and it doesn't scream while aimed at")
	hit(mask, 30.0, {}, player.head_position(), mask.global_position + Vector3.UP * 0.6, player)
	await _frames(3)
	_check(not is_instance_valid(mask), "one revolver round kills it")
	await _end_run(main)


func _test_spitter() -> void:
	print("spitter")
	Run.forced_monsters = ["spitter"]
	var main = await _new_run()
	var player: Player = main.player
	var spitters := _all(main, Spitter)
	_check(spitters.size() >= 1, "spitters spawn (%d)" % spitters.size())
	var spitter: Spitter = spitters[0]
	for other in spitters.slice(1):
		other.queue_free()
	player.global_position = Vector3(4.0, 0.1, 17.0)
	spitter.global_position = Vector3(4.0, 0.1, 5.0)
	var waited := 0
	while player.health == Player.MAX_HEALTH and tree.get_nodes_in_group("acid_puddles").is_empty() and waited < 600:
		await tree.physics_frame
		waited += 1
	_check(not tree.get_nodes_in_group("acid_puddles").is_empty(), "it lobs acid that leaves a puddle (%d frames)" % waited)
	_check(spitter.global_position.distance_to(player.global_position) > 6.0, "while keeping its distance (%.1f m)" % spitter.global_position.distance_to(player.global_position))
	var sac := spitter.global_transform * Vector3(0, 1.55, -0.4)
	var back := spitter.global_transform * Vector3(0, 1.0, 0.3)
	_check(spitter.is_sac_hit(sac) and not spitter.is_sac_hit(back), "the throat sac is its weak spot, the back isn't")
	spitter.set_meta("hp", 140.0)
	spitter.set_meta("max_hp", 140.0)
	var mult := spitter.on_hit({"amount": 10.0, "effects": {}, "from": player.head_position(), "point": sac, "attacker": player})
	_check(mult >= 3.0 and spitter.state == Spitter.State.RETREAT, "a sac hit does triple damage and it runs (x%.1f)" % mult)
	# A puddle hurts whoever stands in it.
	var puddle: Node3D = tree.get_nodes_in_group("acid_puddles")[0]
	var before := player.health
	player.global_position = puddle.global_position + Vector3.UP * 0.05
	await _frames(40)
	_check(player.health < before or player.is_dead, "standing in the acid burns (hp %.0f -> %.0f)" % [before, player.health])
	for i in 10:
		if is_instance_valid(spitter):
			hit(spitter, 40.0, {}, player.head_position(), Vector3.INF, player)
	await _frames(3)
	_check(not is_instance_valid(spitter), "enough hits kill it")
	await _end_run(main)


func _test_splitter() -> void:
	print("splitter")
	Run.forced_monsters = ["splitter"]
	var main = await _new_run()
	var player: Player = main.player
	var splitter: Splitter = _all(main, Splitter)[0] if not _all(main, Splitter).is_empty() else null
	_check(splitter != null, "a splitter spawns")
	player.global_position = Vector3(4.0, 0.1, 15.0)
	splitter.global_position = Vector3(4.0, 0.1, 9.0)
	var waited := 0
	while player.health == Player.MAX_HEALTH and waited < 600:
		await tree.physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "it shambles over and grabs you (hp=%.0f)" % player.health)
	player.health = Player.MAX_HEALTH
	player.global_position = Vector3(4.0, 0.1, 20.0)
	for i in 20:
		if is_instance_valid(splitter):
			hit(splitter, 30.0, {}, player.head_position(), Vector3.INF, player)
	await _frames(10)
	var crawlers := _all(main, SplitterCrawler)
	_check(not is_instance_valid(splitter) and crawlers.size() >= Splitter.SPLIT_MIN and crawlers.size() <= Splitter.SPLIT_MAX,
		"killed with bullets, it splits into crawlers (%d)" % crawlers.size())
	_check(crawlers.all(func(c: Node) -> bool: return c.get_meta("kind", "") == "crawler"), "the crawlers are roster monsters")
	waited = 0
	player.health = Player.MAX_HEALTH
	while player.health == Player.MAX_HEALTH and waited < 400:
		await tree.physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "the crawlers run you down and bite")
	var crawler: SplitterCrawler = crawlers[0]
	hit(crawler, 25.0, {}, player.head_position(), Vector3.INF, player)
	await _frames(3)
	_check(not is_instance_valid(crawler), "one shot kills a crawler")
	for other in _all(main, SplitterCrawler):
		other._life = 0.5
	await _frames(40)
	_check(_all(main, SplitterCrawler).is_empty(), "the rest starve on their own")
	await _end_run(main)
	# Fire seals it: no crawlers.
	main = await _new_run()
	splitter = _all(main, Splitter)[0]
	splitter.global_position = Vector3(4.0, 0.1, -10.0)
	for i in 20:
		if is_instance_valid(splitter):
			hit(splitter, 30.0, {"burn": 2.0}, Vector3(4.0, 1.5, -4.0))
	await _frames(10)
	_check(not is_instance_valid(splitter) and _all(main, SplitterCrawler).is_empty(), "burned to death, it doesn't split")
	await _end_run(main)


func _test_dropper() -> void:
	print("ceiling dropper")
	Run.forced_monsters = ["dropper"]
	var main = await _new_run()
	var player: Player = main.player
	var droppers := _all(main, CeilingDropper)
	_check(droppers.size() >= 1, "ceiling droppers spawn (%d)" % droppers.size())
	var dropper: CeilingDropper = droppers[0]
	for other in droppers.slice(1):
		other.queue_free()
	var spot := Vector3(4.0, 0.1, 12.0)
	dropper.global_position = dropper.ceiling_above(spot)
	dropper.state = CeilingDropper.State.HANG
	_check(dropper.global_position.y > spot.y + 2.0, "it hangs from the ceiling (%.1f m up)" % (dropper.global_position.y - spot.y))
	# With the lantern lit it won't drop.
	player.set_lantern(true)
	player.global_position = spot + Vector3(0, 0, 3.0)
	await _frames(5)
	player.global_position = spot
	await _frames(30)
	_check(dropper.state != CeilingDropper.State.GRAB, "it won't drop on someone with a lit lantern")
	await _frames(10)
	dropper.global_position = dropper.ceiling_above(spot)
	dropper.state = CeilingDropper.State.HANG
	dropper._cooldown = 0.0
	player.set_lantern(false)
	player.global_position = spot + Vector3(0, 0, 3.0)
	await _frames(5)
	player.global_position = spot
	var waited := 0
	while dropper.state != CeilingDropper.State.GRAB and waited < 120:
		await tree.physics_frame
		waited += 1
	_check(dropper.state == CeilingDropper.State.GRAB, "in the dark it drops on you and grabs")
	await _frames(60)
	_check(player.health < Player.MAX_HEALTH and not player.is_dead, "it hurts while it drags you (hp=%.0f)" % player.health)
	_check(player.global_position.distance_to(spot) > 0.3, "and drags you off (%.1f m)" % player.global_position.distance_to(spot))
	player.set_lantern(true)
	await _frames(5)
	_check(dropper.state != CeilingDropper.State.GRAB, "relighting the lantern makes it let go")
	await _frames(60)
	hit(dropper, 40.0, {"burn": 2.0}, player.head_position(), Vector3.INF, player)
	await _frames(3)
	_check(not is_instance_valid(dropper), "fire kills it fast")
	await _end_run(main)


func _test_burrower() -> void:
	print("burrower")
	Run.forced_monsters = ["burrower"]
	var main = await _new_run()
	var player: Player = main.player
	var digger: Burrower = _all(main, Burrower)[0] if not _all(main, Burrower).is_empty() else null
	_check(digger != null, "a burrower spawns")
	_check(digger.state == Burrower.State.TUNNEL and digger.collision_layer == 0, "it starts under the floor")
	_check(digger.on_hit({"amount": 10.0, "effects": {}, "from": Vector3.ZERO, "point": digger.global_position}) == 0.0,
		"you can't shoot it underground")
	player.global_position = Vector3(4.0, 0.1, 18.0)
	digger.global_position = Vector3(4.0, 0.1, 8.0)
	digger._quiet = 0.0
	await _frames(5)
	# A noise high up (on a catwalk) goes unheard.
	digger.hear(Vector3(4.0, 4.5, 10.0), 14.0, GameNoise.Kind.FOOTSTEP)
	_check(not digger.hunting, "it can't hear noises above the ground floor")
	var noise := Vector3(4.0, 0.1, 13.0)
	player.global_position = noise
	digger.hear(noise, 14.0, GameNoise.Kind.FOOTSTEP)
	_check(digger.hunting, "it hears footsteps on its floor")
	var waited := 0
	while digger.state == Burrower.State.TUNNEL and waited < 300:
		await tree.physics_frame
		waited += 1
	_check(digger.state == Burrower.State.SURFACE, "it tunnels over and bursts out (%d frames)" % waited)
	_check(player.health < Player.MAX_HEALTH, "right under whoever made the noise (hp=%.0f)" % player.health)
	_check(digger.collision_layer == Layers.MONSTER, "above ground it can be hit")
	var front := digger.global_position - digger.global_basis.z * 3.0 + Vector3.UP * 1.6
	var belly := digger.global_position - digger.global_basis.z * 0.8 + Vector3.UP * 1.8
	var behind := digger.global_position + digger.global_basis.z * 4.0 + Vector3.UP * 1.6
	var on_belly := digger.on_hit({"amount": 10.0, "effects": {}, "from": front, "point": belly, "attacker": player})
	var on_back := digger.on_hit({"amount": 10.0, "effects": {}, "from": behind, "point": digger.global_position + digger.global_basis.z + Vector3.UP * 1.6, "attacker": player})
	_check(on_belly >= 2.0 and on_back <= 0.15, "reared up, its belly is soft (x%.1f) and its back armour (x%.2f)" % [on_belly, on_back])
	player.global_position = Vector3(4.0, 0.1, 25.0)
	digger.set_meta("hp", 50.0)
	digger.set_meta("max_hp", 750.0)
	hit(digger, 30.0, {}, front, belly, player)
	_check(digger.state == Burrower.State.BROKEN, "at zero it is broken, not killed: flipped on its back")
	_check(is_instance_valid(digger), "large monsters never die")
	await _end_run(main)


## The older monsters' reactions to being shot.
func _test_old_reactions() -> void:
	print("old monsters shot")
	Run.forced_monsters = ["mannequin", "fog_walker", "colossus", "child", "rats"]
	var main = await _new_run()
	var player: Player = main.player
	var dummy: Mannequin = _all(main, Mannequin)[0]
	player.global_position = Vector3(0, 0.1, 4.5)
	player.rotation.y = 0.0
	dummy.global_position = Vector3(0, 0.1, -0.5)
	await _frames(5)
	_check(dummy.is_watched() and dummy.on_hit({"amount": 10.0, "effects": {}, "from": player.head_position(), "point": dummy.global_position + Vector3.UP, "attacker": player}) == 0.0,
		"a watched mannequin can't be hurt")
	var walker: FogWalker = _all(main, FogWalker)[0]
	walker.revealed = false
	walker._reveal = 0.0
	_check(walker.on_hit({"amount": 10.0, "effects": {}, "from": player.head_position(), "point": walker.global_position + Vector3.UP}) == 0.0,
		"bullets pass through an unrevealed fog walker")
	_check(walker.on_hit({"amount": 10.0, "effects": {"reveal": true}, "from": player.head_position(), "point": walker.global_position + Vector3.UP}) > 0.0 and walker.revealed,
		"rock salt shows it, and then it can be hurt")
	var giant: BoilerColossus = _all(main, BoilerColossus)[0]
	giant.on_broken()
	_check(giant.state == BoilerColossus.State.VENT and giant.enraged, "a broken colossus vents steam and comes back enraged")
	var child: HideChild = _all(main, HideChild)[0]
	_check(child.on_hit({"amount": 50.0, "effects": {}, "from": player.head_position(), "point": child.global_position}) == 0.0,
		"the child can't be hurt")
	var rats: RatSwarm = _all(main, RatSwarm)[0]
	rats.on_hit({"amount": 10.0, "effects": {}, "from": player.head_position(), "point": rats.global_position})
	_check(rats.state == RatSwarm.State.SCATTER, "shot rats scatter")
	await _end_run(main)


func _all(main: Node, script: Script) -> Array:
	return main.run.monsters_root.get_children().filter(func(node: Node) -> bool:
		return node.get_script() == script and not node.is_queued_for_deletion())


func _new_run(loadout := {}) -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run(loadout)
	await _frames(40)
	return main


func _end_run(main: Node) -> void:
	main.queue_free()
	await _frames(5)


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
