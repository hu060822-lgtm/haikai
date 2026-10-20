class_name LobbyScreen
extends Control
## Waiting room for an online run: who's here, and (for the host) the start button.

signal start_requested()
signal leave_requested()

var _list: Label
var _hint: Label
var _start: Button
var _role: Button
var _squad: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.04, 0.035, 0.03)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(560, 0)
	column.position -= Vector2(280, 300)

	column.add_child(UiKit.label("房間", 44, UiKit.ACCENT))
	_hint = UiKit.label("", 16, UiKit.DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_list = UiKit.label("", 22)
	column.add_child(_list)
	_start = UiKit.button("開始（全員進場）", func() -> void: start_requested.emit())
	_start.custom_minimum_size = Vector2(0, 54)
	_start.add_theme_font_size_override("font_size", 22)
	column.add_child(_start)
	_squad = UiKit.button("", func() -> void: Session.instance.request_next_squad())
	column.add_child(_squad)
	_role = UiKit.button("", _toggle_role)
	column.add_child(_role)
	column.add_child(UiKit.button("離開房間", func() -> void: leave_requested.emit()))

	Session.instance.roster_changed.connect(_refresh)
	_refresh()


func _toggle_role() -> void:
	var session := Session.instance
	var me_guardian := session.role_of(session.local_id()) == "guardian"
	session.request_role("scavenger" if me_guardian else "guardian")


func _refresh() -> void:
	var session := Session.instance
	var lines := []
	var ids := session.roster.keys()
	ids.sort()
	for id in ids:
		var tag := "（主機）" if id == 1 else ""
		if session.role_of(id) == "guardian":
			tag += "【守墓者】"
		else:
			tag = "［%s］" % Session.SQUAD_NAMES[session.squad_of(id)] + tag
		var you := "　← 你" if id == session.local_id() else ""
		lines.append("%s%s%s" % [session.roster[id].name, tag, you])
	_list.text = "\n".join(lines) if not lines.is_empty() else "連線中…"
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
		_hint.text = "朋友在「加入房間」輸入你的 IP 就能進來（埠 %d，最多 %d 人）。人到齊了按開始。沒人當守墓者時由 AI 代打。分成不同小隊的話，各隊從不同地方出發，而且可以互相攻擊、搶對方的東西。" % [Session.PORT, Session.MAX_PLAYERS]
	else:
		_hint.text = "等主機按開始。分成不同小隊的話，各隊從不同地方出發，而且可以互相攻擊。"
