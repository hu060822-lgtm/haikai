extends RefCounted
## Smoke tests for the gunsmith bench UI (LoadoutScreen): the grouped frame list, the slot
## tree (child slots under the part that opened them, what more could open), parts that
## take others off with them, calibre warnings, tuning sliders, stat deltas, the same part
## twice needing two, random builds and stripping, and tune surviving saved plans.
## Called from tests/smoke_test.gd:
##   _failures += await load("res://tests/bench_tests.gd").new().run(self)

var tree: SceneTree
var failures := 0


func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	print("gunsmith bench")
	_test_groups()
	await _test_bench()
	return failures


func _test_groups() -> void:
	var counts := {}
	for id: String in Arsenal.FRAMES:
		var group := LoadoutScreen.frame_group(id)
		counts[group] = counts.get(group, 0) + 1
	var all_groups := true
	for entry: Array in LoadoutScreen.FRAME_GROUPS:
		all_groups = all_groups and counts.get(entry[0], 0) > 0
	_check(all_groups and counts.size() == LoadoutScreen.FRAME_GROUPS.size(), "every frame category has frames (%s)" % counts)
	_check(LoadoutScreen.frame_group("revolver") == "pistol" and LoadoutScreen.frame_group("pdw") == "smg"
		and LoadoutScreen.frame_group("carbine") == "rifle" and LoadoutScreen.frame_group("sawed_off") == "shotgun"
		and LoadoutScreen.frame_group("nail_gun") == "odd" and LoadoutScreen.frame_group("railgun") == "odd",
		"frames sort into 手槍 / 衝鋒槍 / 步槍 / 霰彈槍 / 怪東西")


func _test_bench() -> void:
	GameState.reset()
	GameState.money = 5000
	var screen := LoadoutScreen.new()
	tree.root.add_child(screen)
	await _frames(2)

	# The frame list: a header per category and a row per frame.
	var labels := _texts(screen._list)
	_check(labels.has("步槍") and labels.has("怪東西") and labels.has("模組化卡賓槍") and labels.has("磁軌炮"),
		"the frame list shows categories and every frame")

	# The slot tree: only open slots, children under the part that opened them.
	screen.select_frame("carbine")
	await _frames(1)
	_check(screen._slot_rows.keys().size() == Arsenal.open_slots(screen.plan).size() and not screen._slot_rows.has("rail_l"),
		"the tree shows exactly the open slots (no rails before a handguard)")
	_check(_texts(screen._tree).any(func(t: String) -> bool: return t.begins_with("還能多出") and t.contains("左導軌")),
		"the tree says which slots this frame could still get")
	screen.set_part("handguard", "quad_rail")
	screen.set_part("rail_l", "flashlight")
	screen.set_part("rail_r", "flashlight")
	screen.set_part("foregrip", "vertical_grip")
	await _frames(1)
	_check(screen._slot_rows.has("rail_r") and screen._slot_rows.rail_r.get_meta("depth") == 1
		and screen._slot_rows.handguard.get_meta("depth") == 0, "rails show indented under the handguard")
	var order: Array = screen._slot_rows.keys()
	_check(order.find("rail_l") == order.find("handguard") + 1, "child slots come right after their parent")

	# The same part twice needs two of it.
	GameState.stash["flashlight"] = 1
	screen._refresh()
	_check(screen.plan_cost() == 700 + 180 + 70 + 80, "two flashlights with one owned buys one ($%d)" % screen.plan_cost())
	screen.open_slot("rail_r")
	await _frames(1)
	var row := _picker_row(screen, "戰術燈")
	_check(row.contains("1 個都用掉了") and row.contains("$70"), "the picker knows the owned flashlight is already used (%s)" % row)
	screen.close_picker()

	# Taking a parent off takes its children too, and says so.
	screen.set_part("handguard", "")
	_check(not screen.plan.parts.has("rail_l") and screen.last_removed.has("rail_r") and screen.last_removed.has("foregrip"),
		"taking the handguard off takes the rail parts with it")
	_check(screen._status.text.contains("戰術燈") and screen._status.text.contains("垂直握把"), "the status line names what came off")

	# Calibre change: the picker warns, then the ammo drops.
	screen.set_part("ammo", "api_rounds")
	screen.open_slot("receiver")
	await _frames(1)
	var receiver_row := _picker_row(screen, "9mm 手槍彈上機匣")
	_check(receiver_row.contains("9×19mm"), "a calibre part shows its new calibre in the picker (%s)" % receiver_row)
	screen._hover_part("upper_pcc")
	var detail := screen._info.get_parsed_text()
	_check(detail.contains("口徑改成 9×19mm") and detail.contains("會拆掉") and detail.contains("穿甲燃燒彈"),
		"the detail box warns which parts the calibre change would drop")
	_check(screen._stat_rows.damage.delta.text.begins_with("−"), "hovering shows the stat change")
	screen.set_part("receiver", "upper_pcc")
	screen.close_picker()
	_check(not screen.plan.parts.has("ammo") and screen.last_removed.get("ammo") == "api_rounds"
		and Arsenal.caliber_of(screen.plan) == "9mm", "switching to 9mm drops rifle-only ammo")
	screen.set_part("receiver", "")

	# Deltas: green when lower is better.
	screen.set_part("handguard", "long_handguard")
	screen.open_slot("foregrip")
	screen._hover_part("vertical_grip")
	var recoil: Dictionary = screen._stat_rows.recoil
	_check(recoil.delta.text.begins_with("−") and recoil.delta.get_theme_color("font_color") == UiKit.GOOD,
		"less recoil shows as a green minus")
	screen._hover_part("bipod")
	var ergo: Dictionary = screen._stat_rows.ergo
	_check(ergo.delta.text.begins_with("−") and ergo.delta.get_theme_color("font_color") == UiKit.DANGER,
		"less ergonomics shows as a red minus")
	screen.close_picker()

	# Tuning: a slider under the part, 9 steps, live stats.
	screen.set_part("gas", "adjustable_gas")
	await _frames(1)
	var slider: HSlider = screen._tune_sliders.get("gas")
	_check(slider != null and slider.tick_count == 9 and is_equal_approx(slider.step, 0.25), "a tunable part gets a 9-step slider")
	var rate_mid: float = Arsenal.stats(screen.plan).rate
	slider.value = 1.0
	_check(is_equal_approx(screen.plan.tune.get("gas", 0.0), 1.0) and Arsenal.stats(screen.plan).rate > rate_mid,
		"moving the slider tunes the plan (more gas, faster)")
	_check(screen._stat_rows.rate.value.text == LoadoutScreen._format("rate", Arsenal.stats(screen.plan)), "the stats follow the slider")
	screen.set_tune("gas", -0.6)
	_check(is_equal_approx(screen.plan.tune.gas, -0.5) and is_equal_approx(slider.value, -0.5), "tuning snaps to the 9 steps")
	screen.save_current_plan("調過的")
	screen.strip_all()
	_check(screen.plan.parts.is_empty() and screen.plan.tune.is_empty(), "拆光 leaves the bare frame")
	screen.load_plan(GameState.builds.size() - 1)
	_check(is_equal_approx(Arsenal.tune_of(screen.plan, "gas"), -0.5), "tuning is saved with the plan")

	# Random builds: fill empty slots, never knock parts off, stay affordable.
	screen.strip_all()
	GameState.money = 1500
	var added := screen.random_mod(11)
	var plan_ok: bool = Arsenal.clean(screen.plan) == screen.plan
	_check(added >= 5 and plan_ok and screen.plan_cost() <= GameState.money and screen.missing_organs().is_empty(),
		"隨機改裝 fills slots with parts you can afford (%d parts, $%d)" % [added, screen.plan_cost()])
	var before: Dictionary = screen.plan.parts.duplicate()
	screen.random_mod(12)
	var kept := true
	for slot: String in before:
		kept = kept and screen.plan.parts.get(slot, "") == before[slot]
	_check(kept, "a second roll keeps what was already on")

	# Switching frames says what didn't fit.
	screen.strip_all()
	screen.set_part("receiver", "upper_300")
	screen.select_frame("ak")
	_check(screen.last_removed.get("receiver") == "upper_300" and screen._status.text.contains(".300 BLK 上機匣"),
		"switching frames names the parts that didn't fit")

	# Equipping the two-flashlight build buys only what is missing.
	GameState.money = 5000
	GameState.stash["flashlight"] = 1
	screen.select_frame("carbine")
	screen.strip_all()
	screen.set_part("handguard", "quad_rail")
	screen.set_part("rail_l", "flashlight")
	screen.set_part("rail_r", "flashlight")
	var cost := screen.plan_cost()
	_check(screen.equip_plan() and GameState.money == 5000 - cost and GameState.owned("flashlight") == 0
		and GameState.equipped.build.parts.get("rail_r") == "flashlight", "equipping two flashlights uses the owned one and buys one")
	screen.queue_free()
	await _frames(2)
	GameState.reset()


func _picker_row(screen: LoadoutScreen, part_name: String) -> String:
	for row in screen._picker_list.get_children():
		var joined := " ".join(_texts(row))
		if joined.contains(part_name):
			return joined
	return ""


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	for label in node.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	return result


func _frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		failures += 1
		print("  FAIL ", label)
