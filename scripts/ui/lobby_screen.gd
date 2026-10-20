class_name LobbyScreen
extends Control
## Waiting room for an online run: who's here, and (for the host) the start button.

signal start_requested()
signal leave_requested()

var _list: Label
var _hint: Label
var _start: Button


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
	column.position -= Vector2(280, 220)

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
	column.add_child(UiKit.button("離開房間", func() -> void: leave_requested.emit()))

	Session.instance.roster_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var session := Session.instance
	var lines := []
	var ids := session.roster.keys()
	ids.sort()
	for id in ids:
		var tag := "（主機）" if id == 1 else ""
		var you := "　← 你" if id == session.local_id() else ""
		lines.append("%s%s%s" % [session.roster[id].name, tag, you])
	_list.text = "\n".join(lines) if not lines.is_empty() else "連線中…"
	_start.visible = session.is_host()
	_start.disabled = session.roster.size() < 1
	if session.is_host():
		_hint.text = "朋友在「加入房間」輸入你的 IP 就能進來（埠 %d，最多 %d 人）。人到齊了按開始。" % [Session.PORT, Session.MAX_PLAYERS]
	else:
		_hint.text = "等主機按開始。"
