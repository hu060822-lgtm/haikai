class_name LoadoutScreen
extends Control
## Pre-run screen: shows money and stats, lets the player pick carry-in gear, then start.
## Picking gear takes it from the stash or buys it; un-picking puts it back in the stash.

signal start_requested(loadout: Dictionary)

var _loadout := {"weapon": "", "boosts": []}
var _money_label: Label
var _stats_label: Label
var _loadout_label: Label
var _buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.035, 0.03)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(760, 0)
	column.position -= Vector2(380, 300)

	column.add_child(UiKit.label("HAIKAI", 56, UiKit.ACCENT))
	column.add_child(UiKit.label("倉庫：選好進場要帶的東西。死掉會全部失去，活著撤離就能帶回來。", 18))
	_money_label = UiKit.label("", 26, UiKit.ACCENT)
	column.add_child(_money_label)
	_stats_label = UiKit.label("", 16, UiKit.DIM)
	column.add_child(_stats_label)

	for id in Gear.ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var button := UiKit.button("", func() -> void: _toggle(id))
		button.custom_minimum_size = Vector2(260, 44)
		_buttons[id] = button
		row.add_child(button)
		var desc := UiKit.label(Gear.ITEMS[id].desc, 15, UiKit.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(480, 0)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(desc)
		column.add_child(row)

	_loadout_label = UiKit.label("", 18)
	column.add_child(_loadout_label)
	var go := UiKit.button("出發：黑暗鍋爐工廠", _start)
	go.custom_minimum_size = Vector2(0, 56)
	go.add_theme_font_size_override("font_size", 24)
	column.add_child(go)
	_refresh()


func _toggle(id: String) -> void:
	var info := Gear.info(id)
	if _is_equipped(id):
		if info.slot == "weapon":
			_loadout.weapon = ""
		else:
			_loadout.boosts.erase(id)
		GameState.give_back(id)
	else:
		if info.slot == "boost" and _loadout.boosts.size() >= Gear.MAX_BOOSTS:
			return
		if not GameState.take(id):
			return
		if info.slot == "weapon":
			if _loadout.weapon != "":
				GameState.give_back(_loadout.weapon)
			_loadout.weapon = id
		else:
			_loadout.boosts.append(id)
	GameState.save_game()
	_refresh()


func _is_equipped(id: String) -> bool:
	return _loadout.weapon == id or id in _loadout.boosts


func _start() -> void:
	start_requested.emit(_loadout.duplicate(true))


func _refresh() -> void:
	_money_label.text = "$%d" % GameState.money
	_stats_label.text = "撤離成功 %d 次　死亡 %d 次　最高收穫 $%d" % [GameState.extractions, GameState.deaths, GameState.best_haul]
	for id in _buttons:
		var info := Gear.info(id)
		var owned := GameState.owned(id)
		var text: String = info.name
		if _is_equipped(id):
			text = "✓ " + text + "（已裝備）"
		elif owned > 0:
			text += "（擁有 %d）" % owned
		else:
			text += "　$%d" % info.price
		_buttons[id].text = text
	var names := []
	for id in Gear.loadout_ids(_loadout):
		names.append(Gear.info(id).name)
	_loadout_label.text = "這次帶：煤油提燈" + ("、" + "、".join(names) if not names.is_empty() else "")
