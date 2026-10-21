class_name ResultScreen
extends Control
## End-of-run summary: what you got out (or lost), and the money you have now.

signal continue_requested()

var survived := false
var cause := ""
var items: Array = []
var payout := {}
var lost_gear: Array = []
## Organ part ids carried out this run (they went into the stash, not into money).
var organs: Array = []
## From the session: {extracted, scavengers, squads, squad_totals}.
var summary := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.8)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grime := UiKit.add_backdrop(self, 0.5, 0.4)
	grime.modulate.a = 0.75

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(660, 0)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH

	var headline := ""
	var color := UiKit.TEXT
	if survived:
		headline = "撤離成功"
		color = UiKit.ACCENT
	else:
		headline = "你死了"
		color = UiKit.DANGER
	column.add_child(_stamp(headline, color))
	var strip := UiKit.hazard_strip(6.0, color, UiKit.INK)
	column.add_child(strip)

	var card := UiKit.panel(18)
	column.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)

	if survived:
		if items.is_empty():
			body.add_child(UiKit.label("空手而回。至少你還活著。" if organs.is_empty() else "沒帶出能賣錢的東西。", 20))
		else:
			body.add_child(UiKit.heading("帶出來的東西", "%d 件" % items.size()))
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(0, mini(items.size(), 8) * 26)
			var list := VBoxContainer.new()
			list.add_theme_constant_override("separation", 2)
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(list)
			for item in items:
				list.add_child(_row(item.name, "$%d" % item.value, UiKit.TEXT, 17))
			body.add_child(scroll)
			if payout.bonus > 0:
				body.add_child(_row("湊成一組的獎勵", "+$%d" % payout.bonus, UiKit.HOT, 18))
			body.add_child(_rule())
			body.add_child(_row("這次賺到", "$%d" % payout.total, UiKit.ACCENT, 30))
		if not organs.is_empty():
			var names := []
			for id in organs:
				names.append(Arsenal.name_of(str(id)))
			var brought := UiKit.label("帶回器官：" + "、".join(names) + "（已放進倉庫，可以裝到槍上）", 17, Bestiary.ORGAN)
			brought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(brought)
	else:
		body.add_child(UiKit.label(cause, 22))
		var dropped := UiKit.label("背包裡的 %d 件物品都掉在你倒下的地方了。" % items.size(), 17, UiKit.DIM)
		body.add_child(dropped)
		if not lost_gear.is_empty():
			var names := []
			for id in lost_gear:
				names.append(Gear.info(id).name)
			var lost := UiKit.label("失去的裝備：" + "、".join(names), 17, UiKit.DANGER)
			lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(lost)

	if not summary.is_empty() and summary.get("scavengers", 1) > 1:
		var team := UiKit.label("所有人一共撤出 $%d" % summary.get("extracted", 0), 16, UiKit.DIM)
		team.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(team)
	var squads: Array = summary.get("squads", [])
	if squads.size() > 1:
		column.add_child(_squad_ranking(squads, summary.get("squad_totals", {})))
	column.add_child(_row("現在的錢", "$%d" % GameState.money, UiKit.TEXT, 22))
	var online := Session.instance != null and Session.instance.is_online()
	var button := UiKit.primary_button("回到房間" if online else "回到倉庫", func() -> void: continue_requested.emit())
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_override("font", UiKit.display_font())
	button.add_theme_font_size_override("font_size", 24)
	column.add_child(button)
	UiKit.add_crt(self, 0.0, 0.12, 0.8)
	button.grab_focus.call_deferred()

	# Slam in.
	column.modulate.a = 0.0
	column.scale = Vector2(1.08, 1.08)
	var tween := create_tween()
	tween.tween_property(column, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(column, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	column.resized.connect(func() -> void: column.pivot_offset = column.size * 0.5)


func _stamp(text: String, color: Color) -> Control:
	var holder := CenterContainer.new()
	var stamp := UiKit.title(text, 64, color)
	stamp.rotation_degrees = -2.5
	holder.add_child(stamp)
	return holder


func _row(left: String, right: String, color := UiKit.TEXT, size := 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	var a := UiKit.label(left, size, UiKit.DIM if size < 22 else UiKit.TEXT)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(a)
	var b := UiKit.label(right, size, color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_override("font", UiKit.bold_font())
	row.add_child(b)
	return row


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1.0, 1.0, 1.0, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	return line


## Several squads: who got the most out, and where yours placed.
func _squad_ranking(squads: Array, totals: Dictionary) -> Label:
	var ranked := squads.duplicate()
	ranked.sort_custom(func(a: int, b: int) -> bool: return totals.get(a, 0) > totals.get(b, 0))
	var mine := Session.instance.squad_of(Session.instance.local_id()) if Session.instance != null else -1
	var parts := []
	for i in ranked.size():
		var squad: int = ranked[i]
		var you := "（你們）" if squad == mine else ""
		parts.append("%d. %s%s $%d" % [i + 1, Session.SQUAD_NAMES[squad], you, totals.get(squad, 0)])
	return UiKit.label("小隊排名　" + "　".join(parts), 18, UiKit.ACCENT)
