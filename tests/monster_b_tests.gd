extends RefCounted
## Smoke tests for monster worker B's five monsters (hound pack, web weaver, shield knight,
## shadow stalker, drift eyes). Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/monster_b_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


class Ear extends Node:
	var heard: Array = []

	func hear(position: Vector3, radius: float, kind: int) -> void:
		heard.append([position, radius, kind])


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	await _test_hounds()
	await _test_weaver()
	await _test_shield_knight()
	await _test_stalker()
	await _test_eyes()
	Run.forced_monsters = ["colossus"]
	return failures


func _test_hounds() -> void:
	print("hounds")
	Run.forced_monsters = ["hounds"]
	var main = await _new_run()
	var player: Player = main.player
	var pack: Array = _all(main, Hound)
	_check(pack.size() >= 2 and pack.size() <= 3, "a pack of 2-3 hounds spawns (%d)" % pack.size())
	await _frames(5)
	var leaders := pack.filter(func(h: Hound) -> bool: return h.is_leader)
	_check(leaders.size() == 1, "exactly one of them leads the pack")
	var leader: Hound = leaders[0] if not leaders.is_empty() else pack[0]
	player.global_position = Vector3(4.0, 0.1, 15.0)
	player.rotation.y = 0.0  # facing -z, toward the pack
	for i in pack.size():
		pack[i].global_position = Vector3(3.0 + i, 0.1, 7.0)
	var waited := 0
	while leader.state == Hound.State.ROAM and waited < 120:
		await tree.physics_frame
		waited += 1
	_check(leader.state != Hound.State.ROAM, "the leader sees you and howls")
	var followers := pack.filter(func(h: Hound) -> bool: return h != leader)
	_check(followers.all(func(h: Hound) -> bool: return h.state == Hound.State.HUNT and h._target == player), "the howl marks you for the whole pack")
	waited = 0
	while player.health == Player.MAX_HEALTH and waited < 900:
		await tree.physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "they circle round and bite (hp=%.0f, %d frames)" % [player.health, waited])
	var biter_behind := false
	for hound: Hound in pack:
		var to := hound.global_position - player.global_position
		to.y = 0.0
		if to.length() < 3.5 and player.look_direction().dot(to.normalized()) < 0.0:
			biter_behind = true
	_check(biter_behind, "the bite comes from behind")
	player.health = Player.MAX_HEALTH
	await _damage(main, leader, 75.0, {}, player.global_position)
	await _frames(2)
	_check(pack.all(func(h) -> bool: return not is_instance_valid(h) or h.state == Hound.State.FLEE), "hurting the leader badly breaks the pack's nerve")
	var victim: Hound = followers[0]
	await _damage(main, victim, 500.0, {}, player.global_position)
	await _frames(3)
	_check(not is_instance_valid(victim), "a hound can be killed")
	await _end_run(main)


func _test_weaver() -> void:
	print("weaver")
	Run.forced_monsters = ["weaver"]
	var main = await _new_run()
	var player: Player = main.player
	var weaver: WebWeaver = _monster(main, WebWeaver)
	_check(weaver != null, "web weaver spawns")
	await _frames(120)
	_check(not weaver._spots.is_empty(), "it finds doorways to web (%d)" % weaver._spots.size())
	# A web across the walkway right where the player stands, the spider a few metres off.
	weaver.state = WebWeaver.State.WAIT
	weaver._spots.clear()
	weaver.web_pos = PackedVector3Array()
	weaver.web_info = PackedVector3Array()
	weaver.global_position = Vector3(4.0, 0.1, 9.0)
	weaver._lair = weaver.global_position
	player.global_position = Vector3(4.0, 0.1, 15.5)
	weaver.host_add_web(Vector3(4.0, 0.1, 15.0), 0.0, 3.0)
	_check(weaver.web_count() == 1, "it can string up a web")
	await _frames(1)
	_check(weaver._web_nodes.size() == 1, "the web is built on every peer")
	player.global_position = Vector3(4.0, 0.1, 15.0)
	await _frames(3)
	_check(player.snared > 0.0 and player.trap_slow > 0.0, "walking into a web snares you")
	var start := player.global_position.distance_to(weaver.global_position)
	var waited := 0
	while weaver.state != WebWeaver.State.REEL and waited < 120:
		await tree.physics_frame
		waited += 1
	_check(weaver.state == WebWeaver.State.REEL, "it shoots a thread at the snared player")
	await _frames(40)
	var now := player.global_position.distance_to(weaver.global_position)
	_check(now < start - 0.5 or player.health < Player.MAX_HEALTH, "and reels them in (%.1f -> %.1f m)" % [start, now])
	_check(weaver.reel_to != Vector3.ZERO, "the thread shows while it reels")
	await _damage(main, weaver, 10.0, {}, player.global_position)
	await _frames(2)
	_check(weaver.state == WebWeaver.State.RETREAT and weaver.reel_to == Vector3.ZERO, "shooting it snaps the thread")
	weaver.host_add_web(Vector3(4.0, 0.1, 12.0), 0.0, 3.0)
	var hp_before: float = weaver.get_meta("hp", 170.0)
	var multiplier: float = weaver.on_hit({"amount": 10.0, "effects": {"burn": 2.5}, "from": player.global_position, "point": weaver.global_position})
	_check(weaver.web_count() == 0, "fire burns its webs")
	_check(MonsterRoster.MONSTERS.weaver.weak.burn * multiplier >= 2.0, "and fire hurts it double")
	_check(hp_before > 0.0, "it has health")
	await _damage(main, weaver, 1000.0, {}, player.global_position)
	await _frames(3)
	_check(not is_instance_valid(weaver), "the weaver can be killed")
	await _end_run(main)


func _test_shield_knight() -> void:
	print("shield knight")
	Run.forced_monsters = ["shield_knight"]
	var main = await _new_run()
	var player: Player = main.player
	var knight: ShieldKnight = _monster(main, ShieldKnight)
	_check(knight != null, "shield knight spawns")
	player.global_position = Vector3(-13, 0.1, 18)
	knight.global_position = Vector3(4.0, 0.1, 10.0)
	knight.rotation.y = 0.0  # facing -z
	await _frames(5)
	var front := knight.global_position + Vector3(0, 1.5, -6.0)
	var back := knight.global_position + Vector3(0, 1.5, 6.0)
	_check(knight.on_hit({"amount": 20.0, "effects": {}, "from": front}) == 0.0, "the door blocks shots from the front")
	_check(knight.on_hit({"amount": 20.0, "effects": {}, "from": back}) > 1.0, "its bare back takes extra damage")
	if Run.instance.has_method("host_damage_monster"):
		knight.state = ShieldKnight.State.PATROL
		knight.rotation.y = 0.0
		var hp: float = knight.get_meta("hp", 800.0)
		Run.instance.host_damage_monster(knight, 50.0, {}, front)
		_check(knight.get_meta("hp", 800.0) >= hp, "a frontal hit does no damage at all")
	# Charge into a wall: find one 4-15 m away in some direction and send it at it.
	knight.state = ShieldKnight.State.PATROL
	var space: PhysicsDirectSpaceState3D = knight.get_world_3d().direct_space_state
	var dir := Vector3.ZERO
	for probe: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var from := knight.global_position + Vector3.UP
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + probe * 15.0, Layers.WORLD))
		if not hit.is_empty() and from.distance_to(hit.position) > 4.0:
			dir = probe
			break
	_check(dir != Vector3.ZERO, "there is a wall to charge into")
	if dir != Vector3.ZERO:
		knight._charge_dir = dir
		knight.state = ShieldKnight.State.CHARGE
		knight._timer = ShieldKnight.CHARGE_TIME
		knight.rotation.y = atan2(-dir.x, -dir.z)
		var waited := 0
		while knight.state == ShieldKnight.State.CHARGE and waited < 200:
			await tree.physics_frame
			waited += 1
		_check(knight.state == ShieldKnight.State.STAGGER, "charging into a wall staggers it")
		_check(knight.on_hit({"amount": 20.0, "effects": {}, "from": knight.global_position + knight.forward() * 5.0 + Vector3.UP}) >= 2.0,
			"a staggered knight's guard is down")
	# It sees a player down a straight line and charges them.
	knight.state = ShieldKnight.State.PATROL
	knight.downed = false
	knight.global_position = Vector3(4.0, 0.1, 6.0)
	knight.rotation.y = 0.0
	player.global_position = Vector3(4.0, 0.1, 15.0)
	knight.rotation.y = PI  # facing +z, toward the player
	var waited := 0
	var charged := false
	while player.health == Player.MAX_HEALTH and waited < 400:
		await tree.physics_frame
		waited += 1
		charged = charged or knight.state == ShieldKnight.State.CHARGE
	_check(charged, "it winds up and charges in a straight line")
	_check(player.health < Player.MAX_HEALTH, "the charge tramples you (hp=%.0f)" % player.health)
	player.health = Player.MAX_HEALTH
	if Run.instance.has_method("host_damage_monster"):
		knight.state = ShieldKnight.State.STAGGER
		knight._timer = 5.0
		Run.instance.host_damage_monster(knight, 100000.0, {}, knight.global_position + Vector3(0, 1, 6))
		await _frames(3)
		_check(is_instance_valid(knight) and knight.downed, "at zero it is broken, not killed")
	await _end_run(main)


func _test_stalker() -> void:
	print("stalker")
	Run.forced_monsters = ["stalker"]
	var main = await _new_run()
	var player: Player = main.player
	var stalker: ShadowStalker = _monster(main, ShadowStalker)
	_check(stalker != null, "shadow stalker spawns")
	player.set_lantern(false)
	# Find a dark spot on the walkway.
	var spot := Vector3.INF
	for point: Vector3 in main.level.patrol_points:
		stalker.global_position = point + Vector3.UP * 0.1
		player.global_position = point + Vector3(0, 0.1, 4.0)
		if not stalker.in_light():
			spot = point
			break
	_check(spot != Vector3.INF, "there is somewhere dark for it")
	if spot == Vector3.INF:
		await _end_run(main)
		return
	stalker.global_position = spot + Vector3.UP * 0.1
	player.global_position = spot + Vector3(0, 0.1, 5.0)
	player.rotation.y = 0.0  # facing -z, at the stalker
	player.get_node("Head").rotation.x = 0.0
	await _frames(10)
	_check(not stalker.lit, "in the dark it is only a shimmer")
	_check(stalker.on_hit({"amount": 10.0, "effects": {}}) < 0.5, "bullets pass through it in the dark")
	player.set_lantern(true)
	stalker.global_position = spot + Vector3.UP * 0.1
	await _frames(12)
	_check(stalker.lit, "the lantern beam catches it")
	var held := stalker.global_position
	await _frames(30)
	_check(stalker.global_position.distance_to(held) < 0.15, "and it freezes in the light")
	_check(stalker.on_hit({"amount": 10.0, "effects": {}}) > 1.0, "lit, it can be hurt")
	stalker._retreat = 0.0
	# Light off, back turned: it comes up behind you.
	player.set_lantern(false)
	player.rotation.y = PI  # facing +z, away from it
	stalker.global_position = spot + Vector3.UP * 0.1
	var waited := 0
	while player.health == Player.MAX_HEALTH and waited < 400:
		await tree.physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "turn your back in the dark and it strikes (hp=%.0f)" % player.health)
	player.health = Player.MAX_HEALTH
	stalker.lit = true
	await _damage(main, stalker, 1000.0, {}, player.global_position)
	await _frames(3)
	_check(not is_instance_valid(stalker) or stalker.get_meta("hp", 1.0) <= 0.0 or stalker.is_queued_for_deletion(), "a lit stalker can be killed")
	await _end_run(main)


func _test_eyes() -> void:
	print("eyes")
	Run.forced_monsters = ["eyes"]
	var main = await _new_run()
	var player: Player = main.player
	var eyes: Array = _all(main, DriftEye)
	_check(eyes.size() >= 2 and eyes.size() <= 4, "a flock of 2-4 eyes spawns (%d)" % eyes.size())
	var eye: DriftEye = eyes[0]
	for other in eyes.slice(1):
		other.global_position = Vector3(0, 30, -100)
		other.home = other.global_position
		other.process_mode = Node.PROCESS_MODE_DISABLED
	var ear := Ear.new()
	ear.add_to_group("listeners")
	main.run.add_child(ear)
	player.global_position = Vector3(4.0, 0.1, 15.0)
	eye.global_position = Vector3(4.0, 2.8, 11.0)
	eye.home = eye.global_position
	var waited := 0
	while eye.state != DriftEye.State.WATCH and waited < 60:
		await tree.physics_frame
		waited += 1
	_check(eye.state == DriftEye.State.WATCH, "an eye spots you and hovers to watch")
	waited = 0
	while ear.heard.filter(func(h: Array) -> bool: return h[2] == GameNoise.Kind.VOICE).is_empty() and waited < 300:
		await tree.physics_frame
		waited += 1
	var marks := ear.heard.filter(func(h: Array) -> bool: return h[2] == GameNoise.Kind.VOICE)
	_check(not marks.is_empty() and (marks[0][0] as Vector3).distance_to(player.global_position) < 2.0, "its shriek marks your position for other monsters")
	_check(eye.global_position.y > player.global_position.y + 1.5, "it keeps above you")
	waited = 0
	while player.health == Player.MAX_HEALTH and waited < 900:
		await tree.physics_frame
		waited += 1
	_check(player.health < Player.MAX_HEALTH, "then it dives at your face (hp=%.0f)" % player.health)
	eye.on_hit({"amount": 1.0, "effects": {"stun": 0.4}})
	_check(eye.state == DriftEye.State.DOWNED, "a stun drops it out of the air")
	var y := eye.global_position.y
	await _frames(30)
	_check(eye.global_position.y < y - 0.3, "it falls to the floor")
	await _damage(main, eye, 30.0, {}, player.global_position)
	await _frames(3)
	_check(not is_instance_valid(eye), "an eye can be popped")
	await _end_run(main)


# --- Helpers --------------------------------------------------------------------------

## Damage through Run (the combat code) when it is there; otherwise via on_hit + host_kill.
func _damage(_main: Node, monster: Node3D, amount: float, effects: Dictionary, from: Vector3) -> void:
	if not is_instance_valid(monster):
		return
	if Run.instance != null and Run.instance.has_method("host_damage_monster"):
		Run.instance.host_damage_monster(monster, amount, effects, from)
		return
	var kind: String = monster.get_meta("kind", "")
	var entry: Dictionary = MonsterRoster.MONSTERS.get(kind, {})
	var top: float = monster.get_meta("max_hp", float(entry.get("health", 100.0)))
	monster.set_meta("max_hp", top)
	var hp: float = monster.get_meta("hp", top)
	var mult: float = monster.on_hit({"amount": amount, "effects": effects, "from": from, "point": monster.global_position, "attacker": null}) \
		if monster.has_method("on_hit") else 1.0
	hp -= amount * mult
	monster.set_meta("hp", hp)
	if hp <= 0.0:
		if entry.get("size", "medium") == "large":
			if monster.has_method("on_broken"):
				monster.on_broken()
			monster.set_meta("hp", top)
		elif monster.has_method("host_kill"):
			monster.host_kill()
		else:
			monster.queue_free()


func _monster(main: Node, script: Script) -> Node:
	for node in main.run.monsters_root.get_children():
		if node.get_script() == script:
			return node
	return null


func _all(main: Node, script: Script) -> Array:
	return main.run.monsters_root.get_children().filter(func(node) -> bool: return node.get_script() == script)


func _new_run() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.show_menus = false
	tree.root.add_child(main)
	main.start_run({})
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
