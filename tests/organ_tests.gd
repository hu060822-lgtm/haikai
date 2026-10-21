extends RefCounted
## Smoke tests for 怪物就是零件: organ parts, drops on kill / break, carrying them out into
## the stash, the gunsmith treating them as unbuyable, organ effects and the bestiary.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/organ_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


class Ear extends Node:
	var heard: Array = []

	func _ready() -> void:
		add_to_group("listeners")

	func hear(position: Vector3, radius: float, kind: int) -> void:
		heard.append([position, radius, kind])

	func heard_near(at: Vector3, kind: int, min_radius: float) -> bool:
		for entry: Array in heard:
			if entry[2] == kind and (entry[0] as Vector3).distance_to(at) < 1.5 and entry[1] >= min_radius:
				return true
		return false


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("organs")
	_test_data()
	_test_economy()
	await _test_gunsmith()
	await _test_drops()
	await _test_extract()
	await _test_effects()
	await _test_bestiary()
	return failures


func _test_data() -> void:
	var organs := Arsenal.organ_ids()
	_check(organs.size() >= 22, "there is an organ for every monster kind (%d)" % organs.size())
	var all_ok := true
	for kind: String in MonsterRoster.MONSTERS:
		var entry: Dictionary = MonsterRoster.MONSTERS[kind]
		if entry.get("spawned_only", false):
			continue
		var id := Organs.of_monster(kind)
		var part := Arsenal.part(id)
		if part.is_empty() or not part.get("organ", false) or part.price != 0 or part.get("monster", "") != kind:
			all_ok = false
			print("    bad organ for ", kind, ": ", id)
	_check(all_ok, "every roster monster names an organ part (organ: true, price 0, monster matches)")
	var fits_ok := true
	var models_ok := true
	for id in organs:
		var frames := 0
		for frame: String in Arsenal.FRAMES:
			if Arsenal.fits(frame, id):
				frames += 1
		if frames < 2:
			fits_ok = false
			print("    ", id, " fits only ", frames, " frames")
		var loot := Organs.loot_data(id)
		if not LootTable.has_tag(loot, "organ") or loot.value != 0 or loot.weight < 5.0 or loot.weight > 25.0 or loot.organ != id:
			models_ok = false
			print("    bad loot for ", id)
		var model := GunModels.organ(id, 0.5)
		var meshes := model.find_children("*", "MeshInstance3D", true, false).size()
		if meshes < 4:
			models_ok = false
			print("    ", id, " model has only ", meshes, " meshes")
		model.free()
	_check(fits_ok, "every organ fits several frames")
	_check(models_ok, "every organ is heavy loot (5-25 kg, tag organ, $0) with its own model")
	# Stats really apply.
	var split := Arsenal.stats({"frame": "revolver", "parts": {"barrel": "splitter_core"}})
	_check(split.pellets == 3 and absf(split.damage - 8.0) < 0.01, "the splitter's core makes three half-damage pellets")
	var door := Arsenal.stats({"frame": "smg", "parts": {"stock": "knight_door"}})
	_check(door.effects.has("guard") and door.weight > Arsenal.frame("smg").weight + 5.0, "the knight's door guards and is heavy")
	var pull := Arsenal.stats({"frame": "shotgun", "parts": {"underbarrel": "dropper_arm"}})
	_check(float(pull.effects.knock) < 0.0, "the dropper's arm pulls even on a shotgun that shoves")
	var gun := GunModels.build({"frame": "smg", "parts": {"muzzle": "screamer_mask", "ammo": "spitter_sac", "gadget": "mother_musicbox"}})
	var grown := 0
	for child in gun.get_children():
		if child.has_meta("organ"):
			grown += 1
	_check(grown == 3, "organs are grown onto the gun model (%d)" % grown)
	gun.free()


func _test_economy() -> void:
	GameState.reset()
	GameState.money = 5000
	_check(not GameState.take("spitter_sac") and not GameState.buy("spitter_sac"), "organs can't be bought")
	_check(GameState.money == 5000, "trying to buy an organ costs nothing")
	_check(not GameState.equip_build({"frame": "revolver", "parts": {"ammo": "spitter_sac"}}), "a build with an organ you lack can't be equipped")
	GameState.stash["spitter_sac"] = 1
	_check(GameState.equip_build({"frame": "revolver", "parts": {"ammo": "spitter_sac"}}), "with the organ in the stash it can")
	_check(GameState.owned("spitter_sac") == 0 and GameState.equipped.build.parts.ammo == "spitter_sac", "equipping takes the organ out of the stash")
	GameState.reset()


func _test_gunsmith() -> void:
	GameState.reset()
	var screen := LoadoutScreen.new()
	tree.root.add_child(screen)
	await _frames(2)
	screen.select_frame("revolver")
	screen.open_slot("ammo")
	await _frames(1)
	var row_text := _picker_text(screen, "噴吐者的酸囊")
	_check(row_text.contains("要從怪物身上取得") and row_text.contains("器官") and not row_text.contains("$0"),
		"the picker shows an unowned organ as 器官, not buyable (%s)" % row_text)
	screen.set_part("ammo", "spitter_sac")
	_check(screen.missing_organs() == ["spitter_sac"] and screen.plan_cost() == 0, "the plan lists the organ as missing, not as a price")
	_check(not screen.equip_plan(), "equipping a plan with a missing organ fails")
	_check(screen._cost_title.text.contains("器官") and screen._equip.text == "缺器官", "the cost panel says an organ is missing")
	GameState.stash["spitter_sac"] = 1
	screen.close_picker()
	screen.open_slot("ammo")
	await _frames(1)
	_check(_picker_text(screen, "噴吐者的酸囊").contains("擁有 1"), "an owned organ shows 擁有 1")
	_check(screen.equip_plan() and GameState.equipped.build.parts.get("ammo", "") == "spitter_sac", "an owned organ equips")
	screen.queue_free()
	await _frames(2)
	GameState.reset()


func _picker_text(screen: LoadoutScreen, part_name: String) -> String:
	for row in screen._picker_list.get_children():
		var texts := []
		for label in row.find_children("*", "Label", true, false):
			texts.append((label as Label).text)
		var joined := " ".join(texts)
		if joined.contains(part_name):
			return joined
	return ""


func _organ_loot(part_id := "") -> Array:
	var result := []
	for item in tree.get_nodes_in_group("loot"):
		if item is LootItem and Organs.is_organ(item.data) and not item.is_queued_for_deletion() \
				and (part_id == "" or item.data.organ == part_id):
			result.append(item)
	return result


func _test_drops() -> void:
	Run.forced_monsters = ["colossus"]
	var main = await _new_run()
	var run: Run = main.run
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 6:
		run.host_spawn_monster("hounds", main.player.global_position + Vector3(2.0 + i, 0.2, -6.0))
	await _frames(5)
	var hounds := run.live_monsters().filter(func(m: Node3D) -> bool: return m.get_meta("kind", "") == "hounds")
	for hound in hounds:
		hound.process_mode = Node.PROCESS_MODE_DISABLED
		run.host_damage_monster(hound, 9999.0, {"bullet": true}, main.player.global_position)
	await _frames(5)
	var fangs := _organ_loot("hound_fang").size()
	_check(fangs >= 2 and fangs < hounds.size() + 1, "killed hounds drop their organ about 70%% of the time (%d of %d)" % [fangs, hounds.size()])
	var fang: LootItem = _organ_loot("hound_fang")[0] if fangs > 0 else null
	_check(fang != null and LootTable.has_tag(fang.data, "organ") and fang.get_node_or_null("Organ") != null,
		"the organ lies at the body as loot with its own model")
	# Large monsters: the first break drops the organ, later breaks don't.
	main.colossus.state = BoilerColossus.State.VENT
	run.host_damage_monster(main.colossus, 99999.0, {"explode": 0.0}, main.colossus.global_position + Vector3(0, 0, 5))
	await _frames(3)
	_check(_organ_loot("colossus_heart").size() == 1, "breaking the colossus drops its heart")
	main.colossus.set_meta("hp", 1.0)
	run.host_damage_monster(main.colossus, 99999.0, {"explode": 0.0}, main.colossus.global_position + Vector3(0, 0, 5))
	await _frames(3)
	_check(_organ_loot("colossus_heart").size() == 1, "a second break doesn't drop another")
	# A living organ twitches: noise, and the map wakes a little.
	var ear := Ear.new()
	run.add_child(ear)
	var mask := run.host_spawn_loot(Organs.loot_data("screamer_mask"), main.player.global_position + Vector3(0, 0.3, -2.0))
	await _frames(2)
	mask._twitch()
	_check(ear.heard_near(mask.global_position, GameNoise.Kind.ITEM, Organs.TWITCH_NOISE - 0.1), "a living organ twitches and makes noise")
	# Picking it up shows in the backpack like other loot.
	var player: Player = main.player
	_check(player.pickup(mask.to_data()) and main.hud._inventory.text.contains("器官 1"), "carrying an organ shows in the HUD backpack (%s)" % main.hud._inventory.text)
	_check(LootTable.prompt(Organs.loot_data("colossus_heart")).contains("器官") and not LootTable.prompt(Organs.loot_data("colossus_heart")).contains("$"),
		"the pick-up prompt calls it an organ, not a price")
	await _end_run(main)


func _test_extract() -> void:
	GameState.reset()
	GameState.stash["watcher_eye"] = 1
	GameState.equip_build({"frame": "revolver", "parts": {"sight": "watcher_eye"}})
	var main = await _new_run(GameState.consume_equipped())
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	_check("watcher_eye" in player.remaining_gear(), "an organ on the gun counts as gear you carry back")
	player.pickup(Organs.loot_data("spitter_sac"))
	player.pickup(LootTable.make(1))
	var money_before := GameState.money
	main.run.local_extracted()
	await _frames(5)
	_check(GameState.owned("spitter_sac") == 1, "an organ carried out goes into the stash as its part id")
	_check(GameState.owned("watcher_eye") == 1, "the organ on the gun comes back too")
	_check(GameState.money == money_before + LootTable.find(1).value, "organs are never paid out as money")
	var result: Dictionary = main.last_result
	_check(result.get("organs", []) == ["spitter_sac"] and result.items.size() == 1, "the result lists the organ separately (帶回器官)")
	var screen := ResultScreen.new()
	screen.survived = true
	screen.items = result.items
	screen.payout = result.payout
	screen.organs = result.organs
	tree.root.add_child(screen)
	await _frames(1)
	var found := false
	for label in screen.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("帶回器官：噴吐者的酸囊"):
			found = true
	_check(found, "the result screen says 帶回器官：…")
	screen.queue_free()
	await _end_run(main)
	# Lost on death like everything else.
	GameState.reset()
	main = await _new_run()
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.player.pickup(Organs.loot_data("hound_fang"))
	main.player.die("test")
	await _frames(5)
	_check(GameState.owned("hound_fang") == 0, "an organ is lost when you die")
	await _end_run(main)
	GameState.reset()


func _test_effects() -> void:
	var main = await _new_run()
	var run: Run = main.run
	var player: Player = main.player
	main.colossus.process_mode = Node.PROCESS_MODE_DISABLED
	main.colossus.global_position = Vector3(0, 0, -100)
	var ear := Ear.new()
	run.add_child(ear)
	var origin := player.global_position + Vector3.UP * 1.5
	var aim := Vector3(0, -0.3, -1).normalized()
	var stats := Arsenal.stats({"frame": "revolver", "parts": {"barrel": "threaded_barrel", "muzzle": "screamer_mask"}})
	run.host_fire(stats, origin, [aim], player)
	var landing := run._wall_point(origin, aim, float(stats.range))
	_check(ear.heard_near(landing, GameNoise.Kind.VOICE, Organs.SCREAM_RADIUS - 0.1), "the screamer's mask makes the hit spot scream")
	var muzzle_loud := 0.0
	for entry: Array in ear.heard:
		if (entry[0] as Vector3).distance_to(origin) < 0.1:
			muzzle_loud = maxf(muzzle_loud, entry[1])
	_check(muzzle_loud < Arsenal.frame("revolver").noise * 0.5, "while the gun itself stays quiet (%.1f m)" % muzzle_loud)
	var quiet := Arsenal.stats({"frame": "revolver", "parts": {"barrel": "threaded_barrel", "muzzle": "stalker_shadow"}})
	_check(quiet.noise < 3.0, "the stalker's shadow makes shots almost silent")
	run.host_fire(Arsenal.stats({"frame": "revolver", "parts": {"ammo": "spitter_sac"}}), origin, [aim], player)
	await _frames(2)
	var pools := run.get_children().filter(func(n: Node) -> bool: return n is Organs.AcidPool)
	_check(pools.size() == 1, "the spitter's sac leaves an acid puddle where it hits")
	# The puddle eats a monster standing in it.
	run.host_spawn_monster("hounds", (pools[0] as Node3D).global_position if not pools.is_empty() else origin)
	await _frames(3)
	var hound: Node3D = null
	for monster in run.live_monsters():
		if monster.get_meta("kind", "") == "hounds":
			hound = monster
	if hound != null and not pools.is_empty():
		hound.process_mode = Node.PROCESS_MODE_DISABLED
		hound.global_position = (pools[0] as Node3D).global_position
		await _frames(70)
		_check(float(hound.get_meta("hp", 999.0)) < float(MonsterRoster.MONSTERS.hounds.health), "acid hurts monsters standing in it")
	ear.heard.clear()
	run.host_fire(Arsenal.stats({"frame": "revolver", "parts": {"gadget": "mother_musicbox"}}), origin, [aim], player)
	_check(ear.heard_near(landing, GameNoise.Kind.MUSIC, 10.0), "the mother's music box plays where the shot lands")
	# The knight's door halves damage while aiming.
	player.equip({"build": {"frame": "smg", "parts": {"stock": "knight_door"}}})
	player.force_aim = true
	await _frames(3)
	var before := player.health
	player.take_damage(20.0, "test")
	_check(absf(before - player.health - 10.0) < 0.01, "aiming behind the knight's door halves damage")
	player.force_aim = false
	await _frames(3)
	before = player.health
	player.take_damage(20.0, "test")
	_check(absf(before - player.health - 20.0) < 0.01, "but not when you aren't aiming")
	await _end_run(main)


func _test_bestiary() -> void:
	var screen := LoadoutScreen.new()
	tree.root.add_child(screen)
	await _frames(2)
	var book := screen.open_bestiary()
	await _frames(2)
	var kinds := Bestiary.kinds()
	_check(kinds.size() == book._grid.get_child_count() and kinds.size() >= 22, "the bestiary has a card for every monster (%d)" % kinds.size())
	var text := ""
	for label in book.find_children("*", "RichTextLabel", true, false):
		text += (label as RichTextLabel).get_parsed_text() + "\n"
	_check(text.contains("長頸觀察者的眼") and text.contains("弱點"), "cards show the weakness and the organ")
	_check(Bestiary.pips(2) == "●●○" and Bestiary.pips(null) == "？", "senses show as 0-3 pips")
	screen.queue_free()
	await _frames(2)


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
