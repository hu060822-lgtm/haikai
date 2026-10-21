extends RefCounted
## Smoke tests for gun handling: fire modes, aiming in, recoil and the bipod, jams and
## clearing them, heat, empty reloads, muzzle flash and light, falloff and penetration,
## suppressors and the sound barrier, bleeding, the shooter's gadgets (laser, night
## sight, strobe) and the build's tune surviving the trip to the host.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/weapon_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


class Ear extends Node:
	var heard: Array = []

	func _ready() -> void:
		add_to_group("listeners")

	func hear(position: Vector3, radius: float, kind: int) -> void:
		heard.append([position, radius, kind])

	func loudest_at(at: Vector3) -> float:
		var loud := 0.0
		for entry: Array in heard:
			if (entry[0] as Vector3).distance_to(at) < 0.1:
				loud = maxf(loud, entry[1])
		return loud


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("weapons")
	_test_numbers()
	Run.forced_monsters = ["greeter", "colossus"]
	var main = await _new_run()
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0.1, -100)
	for monster in main.run.monsters_root.get_children():
		if monster is Node3D:
			monster.set_physics_process(false)
			if monster is Greeter:
				monster.global_position = Vector3(-10, 0.1, -16)
	var player: Player = main.player
	player.global_position = Vector3(2, 0.1, 9)
	player.rotation.y = 0.0
	await _frames(5)
	await _test_modes(main, player)
	await _test_aim(main, player)
	await _test_jam(main, player)
	await _test_heat(main, player)
	await _test_reload(player)
	await _test_flash(main, player)
	await _test_ballistics(main, player)
	await _test_gadgets(main, player)
	await _test_tune(main, player)
	await _end_run(main)
	Run.forced_monsters = ["colossus"]
	GameState.reset()
	return failures


## Plain numbers: falloff, penetration, the sound barrier, flash strength.
func _test_numbers() -> void:
	var carbine := Arsenal.stats({"frame": "carbine", "parts": {}})
	_check(Run.falloff_factor(carbine, 5.0) == 1.0 and Run.falloff_factor(carbine, float(carbine.falloff)) == 1.0,
		"full damage up to the falloff distance (%.0f m)" % carbine.falloff)
	_check(absf(Run.falloff_factor(carbine, float(carbine.range)) - Run.FALLOFF_MIN) < 0.001
		and Run.falloff_factor(carbine, float(carbine.range) * 3.0) == Run.FALLOFF_MIN, "down to 60% at the weapon's range")
	var middle := Run.falloff_factor(carbine, (float(carbine.falloff) + float(carbine.range)) * 0.5)
	_check(absf(middle - 0.8) < 0.01, "and linear in between (%.2f)" % middle)
	_check(absf(Run.pen_factor(0.0) - 0.6) < 0.001 and absf(Run.pen_factor(100.0) - 1.3) < 0.001 and Run.pen_factor(60.0) > Run.pen_factor(20.0),
		"penetration scales hits on large monsters from ×0.6 to ×1.3")
	var loud := Arsenal.stats({"frame": "smg", "parts": {"muzzle": "suppressor"}})
	var hushed := Arsenal.stats({"frame": "smg", "parts": {"muzzle": "suppressor", "ammo": "subsonic"}})
	_check(loud.suppressed and hushed.suppressed and loud.supersonic and not hushed.supersonic,
		"a suppressor counts as suppressed; subsonic ammo is under the sound barrier")
	_check(hushed.noise < loud.noise, "suppressed + subsonic is quieter than suppressed + supersonic (%.0f < %.0f m)" % [hushed.noise, loud.noise])
	var rifle := Arsenal.stats({"frame": "carbine", "parts": {"muzzle": "suppressor"}})
	var rifle_sub := Arsenal.stats({"frame": "carbine", "parts": {"muzzle": "suppressor", "ammo": "subsonic"}})
	_check(rifle_sub.noise < rifle.noise and not rifle_sub.supersonic, "subsonic rifle rounds too (%.0f < %.0f m)" % [rifle_sub.noise, rifle.noise])
	_check(ShotFx.flash_strength(Arsenal.stats({"frame": "nail_gun", "parts": {}})) == 0.0
		and ShotFx.flash_strength(carbine) > 0.5, "a gun with almost no flash shows none")
	var flash_hider := Arsenal.stats({"frame": "carbine", "parts": {"muzzle": "flash_hider"}})
	_check(ShotFx.flash_strength(flash_hider) < ShotFx.flash_strength(carbine), "a flash hider shrinks the flash")
	var dragon := Arsenal.stats({"frame": "shotgun", "parts": {"ammo": "dragon_breath"}})
	_check(Player.shot_light_time(dragon) > Player.shot_light_time(Arsenal.stats({"frame": "shotgun", "parts": {}})) * 1.5,
		"dragon's breath lights the shooter up far longer")
	_check(not Player.rail_effect(dragon, "light") and Player.rail_effect(Arsenal.stats({"frame": "smg", "parts": {"rail_l": "flashlight"}}), "light"),
		"only a lamp on a rail is a gun light")


func _equip(player: Player, build: Dictionary) -> void:
	player.equip({"build": build})
	player.weapon.jam = 0.0
	player.hold_trigger = false
	player.force_aim = false
	await _frames(2)


func _test_modes(main: Node, player: Player) -> void:
	var carbine := {"frame": "carbine", "parts": {"trigger": "burst_group"}}
	await _equip(player, carbine)
	_check(player.weapon.modes == ["semi", "auto", "burst"] and player.fire_mode == "semi", "a burst trigger group adds a burst mode")
	await _frames(2)
	_check(Arsenal.MODE_NAMES.semi in main.hud._weapon_name.text, "the HUD shows the fire mode by the gun's name (%s)" % main.hud._weapon_name.text)
	player.cycle_fire_mode()
	_check(player.fire_mode == "auto", "B cycles the fire mode")
	player.cycle_fire_mode()
	_check(player.fire_mode == "burst", "and on to burst")
	await _frames(2)
	_check(Arsenal.MODE_NAMES.burst in main.hud._weapon_name.text, "the HUD follows the switch")
	var full: int = player.mag_ammo
	player.hold_trigger = true
	await _frames(60)
	player.hold_trigger = false
	_check(full - player.mag_ammo == 3, "a burst fires three rounds per pull (%d)" % (full - player.mag_ammo))
	await _frames(3)
	player.cycle_fire_mode()
	_check(player.fire_mode == "semi", "and back round to semi")
	full = player.mag_ammo
	player.hold_trigger = true
	await _frames(40)
	player.hold_trigger = false
	_check(full - player.mag_ammo == 1, "semi fires once per pull")
	await _frames(3)
	player.fire_mode = "auto"
	full = player.mag_ammo
	player.hold_trigger = true
	await _frames(40)
	player.hold_trigger = false
	_check(full - player.mag_ammo > 4, "auto keeps firing while held (%d)" % (full - player.mag_ammo))
	await _frames(3)

	# Both barrels at once: two rounds, twice the pellets, one bigger kick.
	await _equip(player, {"frame": "double_barrel", "parts": {}})
	player._recoil = 0.0
	_check(player.fire() and player.mag_ammo == 1 and main.run.last_shot_pellets == 8, "one barrel fires one round (8 pellets)")
	var single: float = player._recoil
	await _equip(player, {"frame": "double_barrel", "parts": {}})
	player.cycle_fire_mode()
	_check(player.fire_mode == "double", "the double-barrel has a both-barrels mode")
	player._recoil = 0.0
	_check(player.fire() and player.mag_ammo == 0, "both barrels fire two rounds at once")
	_check(main.run.last_shot_pellets == 16, "with twice the pellets (%d)" % main.run.last_shot_pellets)
	_check(absf(player._recoil - single * 1.6) < 0.01, "and one kick 1.6 times as hard (%.2f vs %.2f)" % [player._recoil, single])


func _test_aim(main: Node, player: Player) -> void:
	await _equip(player, {"frame": "dmr", "parts": {"sight": "acog"}})
	var aim_time: float = player.weapon.aim_time
	var hip := player.current_spread()
	_check(absf(hip - float(player.weapon.spread)) < 0.01, "the hip cone is the gun's spread")
	player.force_aim = true
	await _frames(maxi(int(aim_time * 60.0 * 0.5), 1))
	_check(player.aim_blend > 0.2 and player.aim_blend < 0.9, "the sights take a while to come up (%.2f)" % player.aim_blend)
	await _frames(int(aim_time * 60.0 * 0.5) + 4)
	_check(player.aim_blend == 1.0, "fully aimed after aim_time (%.2fs)" % aim_time)
	_check(absf(player.current_spread() - float(player.weapon.aim_spread)) < 0.01,
		"the aimed cone is the gun's aim_spread (%.2f°)" % player.current_spread())
	_check(absf(player.view_fov() - Player.BASE_FOV / float(player.weapon.zoom)) < 0.1, "zoom follows the aim")
	_check(player._view.aim == 1.0, "and so does the gun in your hands")
	await _frames(30)
	var camera: Camera3D = player._camera
	_check(absf(camera.rotation.y) > 0.0001, "the sights drift while aiming (sway)")
	player.force_aim = false
	await _frames(int(aim_time * 60.0) + 4)
	_check(player.aim_blend == 0.0, "and come back down")

	# A bipod set: aiming and standing still.
	await _equip(player, {"frame": "carbine", "parts": {"handguard": "long_handguard", "foregrip": "bipod"}})
	player.force_aim = true
	await _frames(int(player.weapon.aim_time * 60.0) + 6)
	_check(player.bipod_ready() and player.bipod_factor() == 0.3, "a bipod sets down when aiming still")
	await _frames(2)
	_check(main.hud._weapon_hint.text == "腳架架好了", "the HUD says so")
	player._recoil = 0.0
	player.fire()
	var steady: float = player._recoil
	await _equip(player, {"frame": "carbine", "parts": {"handguard": "long_handguard", "foregrip": "grip_pod"}})
	player.force_aim = true
	await _frames(int(player.weapon.aim_time * 60.0) + 6)
	_check(player.bipod_factor() == 0.5, "the grip pod does less")
	player.force_aim = false
	await _frames(int(player.weapon.aim_time * 60.0) + 4)
	_check(player.bipod_factor() == 1.0, "and nothing at the hip")
	player._recoil = 0.0
	player.fire()
	_check(steady < player._recoil * 0.3, "set on its bipod the gun hardly kicks (%.2f vs %.2f)" % [steady, player._recoil])


func _test_jam(main: Node, player: Player) -> void:
	await _equip(player, {"frame": "smg", "parts": {}})
	player.weapon.jam = 1.0
	var full: int = player.mag_ammo
	_check(not player.fire() and player.jammed and player.mag_ammo == full, "a jam: the gun doesn't fire")
	player._fire_cooldown = 0.0
	player.weapon.jam = 0.0
	_check(not player.fire(), "and stays jammed")
	await _frames(2)
	_check(main.hud._weapon_hint.text == Player.JAM_MESSAGE, "the HUD says to clear it with R")
	_check(player.reload() and player.clearing == Player.CLEAR_TIME and player.reloading == 0.0, "R clears a jam instead of reloading")
	await _frames(30)
	_check(player.jammed, "it takes a moment")
	await _frames(40)
	_check(not player.jammed and player.fire(), "then the gun fires again")
	await _equip(player, {"frame": "smg", "parts": {"charging": "ambi_charging"}})
	player.weapon.jam = 1.0
	player.fire()
	_check(player.jammed and player.reload() and player.clearing == Player.QUICK_CLEAR_TIME, "a quick-clear charging handle clears it faster")
	# The jam roll comes from the player's own shot rng: the same seed jams the same shots.
	var pattern := []
	for attempt in 2:
		await _equip(player, {"frame": "smg", "parts": {}})
		player.weapon.jam = 0.3
		player._shot_rng.seed = 1234
		var jams := ""
		for i in 12:
			player._fire_cooldown = 0.0
			player.jammed = false
			player.fire()
			jams += "x" if player.jammed else "."
		pattern.append(jams)
	_check(pattern[0] == pattern[1] and "x" in pattern[0] and "." in pattern[0], "jams are deterministic per seed (%s)" % pattern[0])


func _test_heat(main: Node, player: Player) -> void:
	await _equip(player, {"frame": "machine_pistol", "parts": {}})
	await _frames(2)
	_check(main.hud._heat_bar.visible, "a gun that heats up shows a heat bar")
	var cool := player.current_spread()
	player.heat = 0.8
	_check(player.current_spread() > cool * 1.3, "a hot barrel scatters more")
	player.heat = 0.99
	_check(player.fire() and player.overheated and player.heat >= 1.0, "past 1.0 the gun overheats")
	player._fire_cooldown = 0.0
	_check(not player.fire(), "and won't fire")
	await _frames(30)
	player._fire_cooldown = 0.0
	_check(player.overheated and not player.fire(), "until it cools down")
	await _frames(60)
	_check(not player.overheated and player.heat < Player.OVERHEAT_CLEAR, "under half heat it's usable again")
	player._fire_cooldown = 0.0
	_check(player.fire(), "and fires")
	await _equip(player, {"frame": "revolver", "parts": {}})
	await _frames(2)
	_check(not main.hud._heat_bar.visible, "a gun that never heats up has no heat bar")


func _test_reload(player: Player) -> void:
	await _equip(player, {"frame": "carbine", "parts": {}})
	player.mag_ammo = 5
	_check(player.reload() and absf(player.reload_time - float(player.weapon.reload)) < 0.001, "a tactical reload takes the gun's reload time")
	player.reloading = 0.0
	player.mag_ammo = 0
	_check(player.reload() and absf(player.reload_time - float(player.weapon.reload) * Arsenal.EMPTY_RELOAD) < 0.001,
		"a reload from empty takes %.2f× longer" % Arsenal.EMPTY_RELOAD)
	await _frames(int(player.reload_time * 60.0) + 4)
	_check(player.reloading == 0.0 and player.mag_ammo == int(player.weapon.mag), "and fills the magazine")


func _test_flash(main: Node, player: Player) -> void:
	await _equip(player, {"frame": "revolver", "parts": {}})
	player.set_lantern(false)
	await _frames(2)
	var bright: bool = main.run.level.bright
	_check(bright or not player.is_lit(), "lantern off: in the dark")
	player.fire()
	_check(player.is_lit(), "the muzzle flash lights you up for a moment")
	await _frames(int(Player.shot_light_time(player.weapon) * 60.0) + 12)
	_check(bright or not player.is_lit(), "then you're dark again")
	await _equip(player, {"frame": "nail_gun", "parts": {}})
	player.fire()
	_check(bright or not player.is_lit(), "a flashless nail gun keeps you dark")
	player.set_lantern(true)
	await _equip(player, {"frame": "smg", "parts": {"rail_l": "flashlight"}})
	_check(player.gun_light_on and player._gun_light.visible, "a flashlight on the rail is a gun light")


func _test_ballistics(main: Node, player: Player) -> void:
	var run: Run = main.run
	var colossus: BoilerColossus = main.colossus
	var max_hp := float(MonsterRoster.MONSTERS.colossus.get("health", Run.SIZE_HEALTH.large))
	colossus.global_position = Vector3(2, 0.1, 4)
	player.global_position = Vector3(2, 0.1, 9)
	player.rotation.y = 0.0
	(player.get_node("Head") as Node3D).rotation.x = 0.0
	await _frames(3)
	var origin: Vector3 = player._camera.global_position
	var aim := (colossus.global_position + Vector3.UP * 1.4 - origin).normalized()
	var dealt := func(build: Dictionary) -> float:
		colossus.set_meta("hp", max_hp)
		run.host_fire(Arsenal.stats(build), origin, [aim], player)
		return max_hp - float(colossus.get_meta("hp", max_hp))
	var plain: float = dealt.call({"frame": "revolver", "parts": {}})
	var fmj: float = dealt.call({"frame": "revolver", "parts": {"ammo": "fmj"}})
	var want := Run.pen_factor(35.0) / Run.pen_factor(25.0)
	_check(plain > 0.0 and absf(fmj / plain - want) < 0.01, "more penetration hurts a large monster more (×%.2f, want ×%.2f)" % [fmj / maxf(plain, 0.01), want])
	var hollow: float = dealt.call({"frame": "revolver", "parts": {"ammo": "hollow_point"}})
	want = Run.pen_factor(10.0) / Run.pen_factor(25.0) * 0.7
	_check(absf(hollow / plain - want) < 0.01, "and stacks with hollow points' soft-target penalty (×%.2f)" % (hollow / maxf(plain, 0.01)))
	colossus.global_position = Vector3(0, 0.1, -100)
	TimeWarp.instance._stun.clear()

	# Bleeding: damage over time, no fire.
	var greeter: Greeter = null
	for monster in run.monsters_root.get_children():
		if monster is Greeter:
			greeter = monster
	if greeter != null:
		greeter.global_position = Vector3(2, 0.1, 6)
		await _frames(2)
		var greeter_max := float(MonsterRoster.MONSTERS.greeter.get("health", Run.SIZE_HEALTH.medium))
		greeter.set_meta("max_hp", greeter_max)
		greeter.set_meta("hp", greeter_max)
		run.host_damage_monster(greeter, 1.0, {"bleed": 2.0}, player.global_position)
		_check(run._bleeding.has(greeter) and not run._burning.has(greeter), "a bleed effect makes a monster bleed (not burn)")
		await _frames(140)
		var lost := greeter_max - 1.0 - float(greeter.get_meta("hp"))
		_check(lost > Run.BURN_DPS * Run.BLEED_SHARE * 1.4, "it keeps losing health while it bleeds (%.1f)" % lost)
		_check(not run._bleeding.has(greeter), "until the bleeding stops")
		greeter.global_position = Vector3(-10, 0.1, -16)
	var spike := Arsenal.stats({"frame": "shotgun", "parts": {"underbarrel": "spike_bayonet"}})
	var broadhead := Arsenal.stats({"frame": "crossbow", "parts": {"ammo": "broadhead"}})
	_check(spike.effects.has("bleed") and not run._hit_effects(spike).has("bleed"), "a spike bayonet makes stabs bleed, not bullets")
	_check(run._hit_effects(broadhead).has("bleed"), "broadhead bolts bleed")
	_check(not run._hit_effects(Arsenal.stats({"frame": "smg", "parts": {"muzzle": "suppressor", "rail_l": "laser"}})).has("suppressed"),
		"shooter-only effects never reach what is hit")

	# The host hears exactly how loud the build is.
	var ear := Ear.new()
	run.add_child(ear)
	var down := Vector3(0, -1, -0.2).normalized()
	run.host_fire(Arsenal.stats({"frame": "smg", "parts": {"muzzle": "suppressor"}}), origin, [down], player)
	var loud := ear.loudest_at(origin)
	ear.heard.clear()
	run.host_fire(Arsenal.stats({"frame": "smg", "parts": {"muzzle": "suppressor", "ammo": "subsonic"}}), origin, [down], player)
	var hushed := ear.loudest_at(origin)
	_check(hushed > 0.0 and hushed < loud, "a subsonic suppressed shot is heard from less far than a supersonic one (%.0f < %.0f m)" % [hushed, loud])
	ear.queue_free()


func _test_gadgets(main: Node, player: Player) -> void:
	var head: Node3D = player.get_node("Head")
	head.rotation.x = -0.6
	await _equip(player, {"frame": "smg", "parts": {"rail_l": "laser"}})
	await _frames(3)
	_check(player._laser_dot.visible, "a laser puts a red dot where the gun points")
	await _equip(player, {"frame": "smg", "parts": {"rail_l": "laser_ir"}})
	await _frames(3)
	_check(not player._laser_dot.visible, "the infrared laser shows no dot")
	await _equip(player, {"frame": "smg", "parts": {"sight": "night_vision"}})
	_check(player.view_gain() == 1.0 or main.run.level.bright, "a night sight does nothing at the hip")
	player.force_aim = true
	await _frames(int(player.weapon.aim_time * 60.0) + 4)
	_check(main.run.level.bright or player.view_gain() > 2.0, "aimed, it lights the dark up green (gain %.1f)" % player.view_gain())
	player.force_aim = false
	await _frames(int(player.weapon.aim_time * 60.0) + 4)
	head.rotation.x = 0.0
	player.remote_strobe(Player.STROBE_BLIND)
	await _frames(2)
	_check(player.blinded > 0.0 and main.hud._whiteout.color.a > 0.3, "a strobe in the eyes whites out the screen")
	await _frames(int(Player.STROBE_BLIND * 60.0) + 4)
	_check(main.hud._whiteout.color.a == 0.0, "and it passes")
	_check(player.strobe_targets().is_empty(), "nobody else is in this beam")


func _test_tune(main: Node, player: Player) -> void:
	var build := {"frame": "carbine", "parts": {"gas": "adjustable_gas"}, "tune": {"gas": -0.5}}
	var tuned := Arsenal.stats(build)
	var untuned := Arsenal.stats({"frame": "carbine", "parts": {"gas": "adjustable_gas"}})
	_check(tuned.rate < untuned.rate, "turning the gas down slows the gun")
	var wire = bytes_to_var(var_to_bytes(build))
	_check(Arsenal.stats(wire).tune == {"gas": -0.5} and Arsenal.stats(wire).rate == tuned.rate, "the tune survives being sent")
	main.run._shot(build, player.head_position(), [Vector3(0, -1, -0.2).normalized()])
	_check(main.run.last_shot.get("tune", {}).get("gas", 0.0) == -0.5 and main.run.last_shot.rate == tuned.rate,
		"the host fires the shot with the build's tune")
	await _equip(player, build)
	_check(player.code_stats.get("tune", {}).get("gas", 0.0) == -0.5, "and other players see the tuned build (gun_code)")


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
