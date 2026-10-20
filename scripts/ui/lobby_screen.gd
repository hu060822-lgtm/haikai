class_name LobbyScreen
extends Control
## Waiting room for an online run: who's here, and (for the host) the start button.

signal start_requested()
signal leave_requested()

var _list: VBoxContainer
var _count: Label
var _hint: Label
var _start: Button
var _role: Button
var _squad: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.add_backdrop(self, 0.7, 0.6)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)
	var bar := UiKit.top_bar("房間")
	_count = UiKit.title("", 34, UiKit.ACCENT)
	bar.add_child(_count)
	page.add_child(bar)
	page.add_child(UiKit.hazard_strip(5.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# Left: the roster.
	var roster := UiKit.panel(18)
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(roster)
	var roster_box := VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 10)
	roster.add_child(roster_box)
	roster_box.add_child(UiKit.heading("玩家", "最多 %d 人" % Session.MAX_PLAYERS))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	roster_box.add_child(_list)

	# Right: actions.
	var side := UiKit.panel(18, Color(UiKit.ACCENT, 0.35))
	side.custom_minimum_size = Vector2(400, 0)
	body.add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	side.add_child(column)
	_hint = UiKit.label("", 15, UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	_squad = UiKit.button("", func() -> void: Session.instance.request_next_squad())
	_squad.custom_minimum_size = Vector2(0, 44)
	column.add_child(_squad)
	_role = UiKit.button("", _toggle_role)
	_role.custom_minimum_size = Vector2(0, 44)
	_role.add_theme_font_size_override("font_size", 16)
	column.add_child(_role)
	_start = UiKit.primary_button("開始（全員進場）", func() -> void: start_requested.emit())
	_start.custom_minimum_size = Vector2(0, 58)
	_start.add_theme_font_override("font", UiKit.display_font())
	_start.add_theme_font_size_override("font_size", 26)
	column.add_child(_start)
	var leave := UiKit.button("← 離開房間", func() -> void: leave_requested.emit())
	leave.custom_minimum_size = Vector2(0, 38)
	leave.add_theme_font_size_override("font_size", 16)
	column.add_child(leave)

	UiKit.add_crt(self, 0.0, 0.12, 0.8)
	Session.instance.roster_changed.connect(_refresh)
	_refresh()


func _toggle_role() -> void:
	var session := Session.instance
	var me_guardian := session.role_of(session.local_id()) == "guardian"
	session.request_role("scavenger" if me_guardian else "guardian")


func _refresh() -> void:
	var session := Session.instance
	for child in _list.get_children():
		child.queue_free()
	var ids := session.roster.keys()
	ids.sort()
	for id in ids:
		_list.add_child(_player_row(session, id))
	if ids.is_empty():
		_list.add_child(UiKit.label("連線中…", 20, UiKit.DIM))
	_count.text = "%d / %d" % [ids.size(), Session.MAX_PLAYERS]
	_start.visible = session.is_host()
	_start.disabled = session.scavenger_ids().is_empty()
	var me_guardian := session.role_of(session.local_id()) == "guardian"
	var taken := session.guardian_id() != 0 and not me_guardian
	_role.text = "改當搜刮者" if me_guardian else ("已經有人當守墓者了" if taken else "我要當守墓者（在機房操控整座工廠）")
	_role.disabled = taken
	_squad.visible = not me_guardian
	var squads := session.active_squads()
	_squad.text = "換小隊（現在：%s）" % Session.SQUAD_NAMES[session.squad_of(session.local_id())]
	if squads.size() > 1:
		_squad.text += "　· %d 隊互相競爭" % squads.size()
	if session.is_host():
		_hint.text = "朋友在「加入房間」輸入你的 IP 就能進來（埠 %d，最多 %d 人）。人到齊了按開始。\n\n沒人當守墓者時由 AI 代打。分成不同小隊的話，各隊從不同地方出發，而且可以互相攻擊、搶對方的東西。" % [Session.PORT, Session.MAX_PLAYERS]
	else:
		_hint.text = "等主機按開始。\n\n分成不同小隊的話，各隊從不同地方出發，而且可以互相攻擊。"


func _player_row(session: Session, id: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var guardian := session.role_of(id) == "guardian"
	var color: Color = UiKit.COLD if guardian else Session.SQUAD_COLORS[session.squad_of(id)]
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(6, 30)
	row.add_child(swatch)
	var you := id == session.local_id()
	var name_label := UiKit.label(session.roster[id].name, 22, UiKit.ACCENT if you else UiKit.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var tag: String = "守墓者" if guardian else Session.SQUAD_NAMES[session.squad_of(id)]
	row.add_child(UiKit.sticker(tag, color, UiKit.INK, 14, 0.0))
	if id == 1:
		row.add_child(UiKit.sticker("主機", UiKit.TEXT, UiKit.INK, 14, 0.0))
	if you:
		row.add_child(UiKit.label("← 你", 16, UiKit.ACCENT))
	for child in row.get_children():
		if child is Control:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row
