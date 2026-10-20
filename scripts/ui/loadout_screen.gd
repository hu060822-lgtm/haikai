class_name LoadoutScreen
extends Control
## Pre-run screen (倉庫): money and stats, carry-in gear on the left, how to go in on
## the right (solo, host, join). Picking gear takes it from the stash or buys it;
## un-picking puts it back in the stash.

signal solo_requested()
signal host_requested()
signal join_requested(address: String)
signal back_requested()

## Remembered across visits to the screen.
static var last_address := "127.0.0.1"

var _loadout: Dictionary:
	get: return GameState.equipped
var _money_label: Label
var _stats_label: Label
var _loadout_label: Label
var _weight_label: Label
var _buttons := {}
var _name_edit: LineEdit
var _address_edit: LineEdit
var _status: Label
var _desc_title: Label
var _desc: Label
var _solo: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.add_backdrop(self, 0.55, 0.5)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	# Top bar: logo, screen name, money.
	var bar := UiKit.top_bar("倉庫")
	var money_box := VBoxContainer.new()
	money_box.add_theme_constant_override("separation", -4)
	_money_label = UiKit.title("", 38, UiKit.ACCENT)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(_money_label)
	_stats_label = UiKit.label("", 14, UiKit.DIM)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(_stats_label)
	bar.add_child(money_box)
	page.add_child(bar)
	page.add_child(UiKit.hazard_strip(5.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# Left: gear.
	var gear := VBoxContainer.new()
	gear.add_theme_constant_override("separation", 8)
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(gear)
	gear.add_child(UiKit.label("選好進場要帶的東西。死掉會全部失去，活著撤離就能帶回來。", 15, UiKit.DIM))
	(gear.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for slot in ["weapon", "boost"]:
		if slot == "weapon":
			gear.add_child(UiKit.heading("武器", "選一把"))
		else:
			gear.add_child(UiKit.heading("強化", "最多 %d 個" % Gear.MAX_BOOSTS))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for id in Gear.ITEMS:
			if Gear.ITEMS[id].slot != slot:
				continue
			var button := UiKit.button("", func() -> void: _toggle(id))
			button.custom_minimum_size = Vector2(146, 62)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 15)
			button.clip_text = true
			button.mouse_entered.connect(func() -> void: _describe(id))
			button.focus_entered.connect(func() -> void: _describe(id))
			_buttons[id] = button
			grid.add_child(button)
		gear.add_child(grid)
	var desc_panel := UiKit.panel(12)
	desc_panel.custom_minimum_size = Vector2(0, 100)
	var desc_box := VBoxContainer.new()
	desc_box.add_theme_constant_override("separation", 2)
	desc_panel.add_child(desc_box)
	_desc_title = UiKit.label("說明", 17, UiKit.ACCENT)
	_desc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_box.add_child(_desc_title)
	_desc = UiKit.label("把滑鼠移到裝備上看說明。", 15, UiKit.TEXT)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_box.add_child(_desc)
	gear.add_child(desc_panel)

	# Right: this run's kit and the ways in.
	var side := UiKit.panel(18, Color(UiKit.ACCENT, 0.35))
	side.custom_minimum_size = Vector2(380, 0)
	body.add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	side.add_child(column)
	column.add_child(UiKit.heading("這次帶"))
	_loadout_label = UiKit.label("", 16)
	_loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_loadout_label)
	_weight_label = UiKit.label("", 14, UiKit.DIM)
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_weight_label)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UiKit.label("名字", 16, UiKit.DIM))
	_name_edit = UiKit.line_edit(Session.instance.local_name if Session.instance else "拾荒者", 16)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)
	column.add_child(name_row)

	_solo = UiKit.primary_button("單人出發", func() -> void: _commit_name(); solo_requested.emit())
	_solo.custom_minimum_size = Vector2(0, 58)
	_solo.add_theme_font_override("font", UiKit.display_font())
	_solo.add_theme_font_size_override("font_size", 28)
	column.add_child(_solo)

	column.add_child(UiKit.heading("多人連線", "最多 %d 人" % Session.MAX_PLAYERS))
	var host := UiKit.button("建立房間", func() -> void: _commit_name(); host_requested.emit())
	host.custom_minimum_size = Vector2(0, 46)
	host.add_theme_font_size_override("font_size", 20)
	column.add_child(host)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_address_edit = UiKit.line_edit(last_address, 64)
	_address_edit.placeholder_text = "主機的 IP"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_edit.text_submitted.connect(func(_text: String) -> void: _join())
	join_row.add_child(_address_edit)
	var join := UiKit.button("加入房間", _join)
	join.custom_minimum_size = Vector2(120, 44)
	join_row.add_child(join)
	column.add_child(join_row)
	_status = UiKit.label("", 15, UiKit.DANGER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var back := UiKit.button("← 回標題", func() -> void: back_requested.emit())
	back.add_theme_font_size_override("font_size", 15)
	back.custom_minimum_size = Vector2(0, 34)
	column.add_child(back)

	UiKit.add_crt(self, 0.0, 0.12, 0.8)
	_refresh()
	_solo.grab_focus.call_deferred()


func _join() -> void:
	_commit_name()
	last_address = _address_edit.text.strip_edges()
	join_requested.emit(last_address)


## From the title screen's 多人連線: put the cursor in the address box.
func focus_multiplayer() -> void:
	if _address_edit == null:
		return
	_address_edit.grab_focus.call_deferred()
	_address_edit.select_all.call_deferred()


func _describe(id: String) -> void:
	var info := Gear.info(id)
	_desc_title.text = "%s　$%d・%.1fkg" % [info.name, info.price, info.weight]
	_desc.text = info.desc


func show_status(text: String) -> void:
	_status.text = text
	if text != "" and is_inside_tree():
		_status.modulate.a = 0.0
		create_tween().tween_property(_status, "modulate:a", 1.0, 0.2)


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
			show_status("強化最多帶 %d 個" % Gear.MAX_BOOSTS)
			return
		if not GameState.take(id):
			show_status("錢不夠買「%s」" % info.name)
			return
		if info.slot == "weapon":
			if _loadout.weapon != "":
				GameState.give_back(_loadout.weapon)
			_loadout.weapon = id
		else:
			_loadout.boosts.append(id)
	show_status("")
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
		var state := "normal"
		if _is_equipped(id):
			text = "✓ " + text + "\n已裝備"
			state = "selected"
		elif owned > 0:
			text += "\n擁有 %d" % owned
		else:
			text += "\n$%d" % info.price
			if info.price > GameState.money:
				state = "locked"
		_buttons[id].text = text
		UiKit.style_button(_buttons[id], state)
	var lines := ["・煤油提燈"]
	for id in Gear.loadout_ids(_loadout):
		lines.append("・" + Gear.info(id).name)
	_loadout_label.text = "\n".join(lines)
	_weight_label.text = "裝備重量 %.1f kg" % Gear.loadout_weight(_loadout)
