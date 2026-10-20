class_name LoadoutScreen
extends Control
## Pre-run screen: shows money and stats, lets the player pick carry-in gear, then start.
## Picking gear takes it from the stash or buys it; un-picking puts it back in the stash.

signal solo_requested()
signal host_requested()
signal join_requested(address: String)

## Remembered across visits to the screen.
static var last_address := "127.0.0.1"

var _loadout: Dictionary:
	get: return GameState.equipped
var _money_label: Label
var _stats_label: Label
var _loadout_label: Label
var _buttons := {}
var _name_edit: LineEdit
var _address_edit: LineEdit
var _status: Label


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
	column.position -= Vector2(380, 340)

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

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	name_row.add_child(UiKit.label("名字", 18))
	_name_edit = UiKit.line_edit(Session.instance.local_name if Session.instance else "拾荒者", 16)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	column.add_child(name_row)

	var go_row := HBoxContainer.new()
	go_row.add_theme_constant_override("separation", 12)
	var solo := UiKit.button("單人出發", func() -> void: _commit_name(); solo_requested.emit())
	var host := UiKit.button("建立房間", func() -> void: _commit_name(); host_requested.emit())
	for button in [solo, host]:
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		go_row.add_child(button)
	column.add_child(go_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	_address_edit = UiKit.line_edit(last_address, 64)
	_address_edit.placeholder_text = "主機的 IP"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address_edit)
	var join := UiKit.button("加入房間", func() -> void:
		_commit_name()
		last_address = _address_edit.text.strip_edges()
		join_requested.emit(last_address))
	join.custom_minimum_size = Vector2(200, 44)
	join_row.add_child(join)
	column.add_child(join_row)
	_status = UiKit.label("", 16, Color(1.0, 0.5, 0.4))
	column.add_child(_status)
	_refresh()


func show_status(text: String) -> void:
	_status.text = text


func _commit_name() -> void:
	var entered := _name_edit.text.strip_edges()
	if Session.instance != null and entered != "":
		Session.instance.local_name = entered.substr(0, 16)


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
