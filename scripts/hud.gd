class_name HUD
extends CanvasLayer
## Full-resolution overlay drawn on top of the low-res game view.
## Layout: objective + map status top-left, timer and toasts top-centre, prompt and
## extraction progress under the crosshair, backpack + vitals bottom-left, gear and
## usable item (with their keys) bottom-right. Controls show for the first seconds
## of a run and while F1 is held.

const TEXT_COLOR := UiKit.TEXT
const VIGNETTE_SHADER := preload("res://shaders/ui_vignette.gdshader")
const HELP_SECONDS := 10.0
const CONTROLS := [
	["WASD", "移動"], ["滑鼠", "看"], ["Shift", "衝刺"], ["Ctrl", "蹲下"],
	["空白", "跳"], ["E", "撿起／互動"], ["G", "丟下"], ["F", "提燈"],
	["左鍵", "武器"], ["Q", "強化"], ["R", "用物品"], ["M", "麥克風"],
]

var _root: Control
var _crosshair: Control
var _prompt: Label
var _prompt_key: PanelContainer
var _prompt_key_label: Label
var _prompt_detail: Label
var _prompt_row: HBoxContainer
var _inventory: Label
var _weight_bar: ProgressBar
var _gear: VBoxContainer
var _timer: Label
var _timer_panel: PanelContainer
var _objective: Label
var _status: Label
var _health: ProgressBar
var _stamina: ProgressBar
var _extract: ProgressBar
var _extract_label: Label
var _extract_panel: PanelContainer
var _message: Label
var _toast: PanelContainer
var _help: PanelContainer
var _help_hint: Label
var _voice: Label
var _readout: Label
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _message_timer := 0.0
var _help_timer := HELP_SECONDS
var _flash := 0.0
var _health_ratio := 1.0
var _time_left := 999.0
var _clock := 0.0
var _usable := ""
var _player: Player


func _ready() -> void:
	layer = 10
	_vignette = ColorRect.new()
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = VIGNETTE_SHADER
	_vignette.material = _vignette_material
	_vignette.color = Color(0.6, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_top_left()
	_build_top_centre()
	_build_centre()
	_build_bottom_left()
	_build_bottom_right()
	_build_help()
	_ignore_mouse(_root)


# --- Layout ---------------------------------------------------------------------------

func _build_top_left() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_root.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stack.position = Vector2(20.0, 18.0)
	stack.custom_minimum_size = Vector2(380.0, 0.0)
	var panel := _panel(UiKit.ACCENT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stack.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var tag := _text("目標", 12, UiKit.ACCENT, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(tag)
	_objective = _text("", 17)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_objective)
	_status = _text("", 17, UiKit.COLD, true)
	_status.visible = false
	var status_panel := _panel(UiKit.COLD)
	status_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status_panel.add_child(_status)
	stack.add_child(status_panel)
	status_panel.visible = false


func _build_top_centre() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_root.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stack.offset_top = 14.0
	_timer_panel = _panel(Color(1.0, 1.0, 1.0, 0.25), 4)
	_timer_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	(_timer_panel.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(1)
	_timer = _text("", 26, UiKit.TEXT, true)
	_timer.custom_minimum_size = Vector2(84.0, 0.0)
	_timer_panel.add_child(_timer)
	stack.add_child(_timer_panel)
	_toast = _panel(UiKit.TEXT)
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_message = _text("", 19)
	_toast.add_child(_message)
	_toast.visible = false
	stack.add_child(_toast)


func _build_centre() -> void:
	_crosshair = Control.new()
	_root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var dot := ColorRect.new()
	dot.color = Color(0.0, 0.0, 0.0, 0.6)
	dot.size = Vector2(6.0, 6.0)
	dot.position = Vector2(-3.0, -3.0)
	_crosshair.add_child(dot)
	var core := ColorRect.new()
	core.color = UiKit.TEXT
	core.size = Vector2(2.0, 2.0)
	core.position = Vector2(-1.0, -1.0)
	_crosshair.add_child(core)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_root.add_child(stack)
	stack.anchor_left = 0.0
	stack.anchor_right = 1.0
	stack.anchor_top = 0.5
	stack.anchor_bottom = 0.5
	stack.offset_top = 34.0
	stack.offset_bottom = 34.0
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 8)
	_prompt_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_key = UiKit.key_chip("E", 16)
	_prompt_key_label = _prompt_key.get_child(0) as Label
	_prompt_row.add_child(_prompt_key)
	_prompt = _text("", 20)
	_prompt_row.add_child(_prompt)
	_prompt_row.visible = false
	stack.add_child(_prompt_row)
	_prompt_detail = _text("", 15, UiKit.DIM)
	_prompt_detail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_detail.visible = false
	stack.add_child(_prompt_detail)

	_extract_panel = _panel(UiKit.GOOD)
	_extract_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_extract_panel.add_child(box)
	_extract_label = _text("撤離中…", 17, UiKit.GOOD, true)
	box.add_child(_extract_label)
	_extract = _bar(UiKit.GOOD, Vector2(260.0, 10.0))
	box.add_child(_extract)
	_extract_panel.visible = false
	_extract_label.visible = false
	_extract.visible = false
	stack.add_child(_extract_panel)


func _build_bottom_left() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(stack)
	stack.anchor_top = 0.4
	stack.anchor_bottom = 1.0
	stack.offset_left = 20.0
	stack.offset_right = 380.0
	stack.offset_bottom = -20.0
	_voice = _text("", 14, UiKit.TEXT)
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(_voice)

	var pack := _panel(Color(1.0, 1.0, 1.0, 0.25))
	pack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pack_box := VBoxContainer.new()
	pack_box.add_theme_constant_override("separation", 4)
	pack.add_child(pack_box)
	_inventory = _text("", 16)
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pack_box.add_child(_inventory)
	_weight_bar = _bar(UiKit.TEXT, Vector2(240.0, 4.0))
	pack_box.add_child(_weight_bar)
	stack.add_child(pack)

	var vitals := _panel(UiKit.DANGER)
	vitals.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	vitals.add_child(grid)
	grid.add_child(_text("生命", 13, UiKit.DIM, true))
	_health = _bar(UiKit.DANGER, Vector2(200.0, 10.0))
	_health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(_health)
	grid.add_child(_text("體力", 13, UiKit.DIM, true))
	_stamina = _bar(UiKit.WARN, Vector2(200.0, 6.0))
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(_stamina)
	stack.add_child(vitals)


func _build_bottom_right() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(stack)
	stack.anchor_left = 1.0
	stack.anchor_right = 1.0
	stack.anchor_top = 0.3
	stack.anchor_bottom = 1.0
	stack.offset_left = -420.0
	stack.offset_right = -20.0
	stack.offset_bottom = -20.0
	_readout = _text("", 16, UiKit.GOOD)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.size_flags_horizontal = Control.SIZE_SHRINK_END
	stack.add_child(_readout)
	var panel := _panel(UiKit.ACCENT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_gear = VBoxContainer.new()
	_gear.add_theme_constant_override("separation", 5)
	panel.add_child(_gear)
	panel.visible = false
	stack.add_child(panel)
	_help_hint = _text("按住 F1：操作說明", 12, UiKit.DIM)
	_help_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	_help_hint.modulate.a = 0.0
	stack.add_child(_help_hint)


func _build_help() -> void:
	_help = _panel(UiKit.ACCENT, 14)
	_root.add_child(_help)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	_help.add_child(grid)
	for pair in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UiKit.key_chip(pair[0], 13))
		row.add_child(_text(pair[1], 15))
		grid.add_child(row)
	_help.anchor_left = 0.5
	_help.anchor_right = 0.5
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_bottom = -24.0
	_help.offset_top = -24.0


# --- Public API -----------------------------------------------------------------------

func bind_player(player: Player) -> void:
	_player = player
	player.prompt_changed.connect(_set_prompt)
	player.stamina_changed.connect(func(ratio: float) -> void: _stamina.value = ratio)
	player.health_changed.connect(_on_health_changed)
	player.inventory_changed.connect(_on_inventory_changed)
	player.gear_changed.connect(_on_gear_changed)
	player.message.connect(show_message)
	player.readout_changed.connect(func(text: String) -> void: _readout.text = text)
	_on_inventory_changed(player.items, player.carried_weight, player.carried_value)
	_on_gear_changed()


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_timer = seconds
	_toast.visible = text != ""
	_fit(_message, 640.0)
	_toast.modulate.a = 1.0


func set_extract_progress(ratio: float) -> void:
	var on := ratio > 0.0
	_extract_panel.visible = on
	_extract.visible = on
	_extract_label.visible = on
	_extract.value = ratio
	_extract_label.text = "撤離中…　%d%%" % int(ratio * 100.0)


func set_time_left(seconds: float) -> void:
	_time_left = seconds
	var s := maxi(int(ceil(seconds)), 0)
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	var urgent := seconds < 120.0
	_timer.add_theme_color_override("font_color", UiKit.DANGER if urgent else UiKit.TEXT)
	(_timer_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UiKit.DANGER if urgent else Color(1.0, 1.0, 1.0, 0.25)


## Mic indicator for online runs. state: "" (hidden), "on", "speaking" or "muted".
func set_voice(state: String) -> void:
	match state:
		"speaking":
			_voice.text = "● 說話中　M 靜音"
			_voice.add_theme_color_override("font_color", UiKit.GOOD)
		"muted":
			_voice.text = "✕ 麥克風靜音　M 打開"
			_voice.add_theme_color_override("font_color", UiKit.DANGER)
		"on":
			_voice.text = "○ 麥克風開（附近的人和怪物都聽得到）"
			_voice.add_theme_color_override("font_color", UiKit.DIM)
		_:
			_voice.text = ""
	_voice.visible = _voice.text != ""


## A map-specific line under the objective (body heat on the ice station).
func set_status(text: String) -> void:
	if text == _status.text:
		return
	_status.text = text
	_status.visible = text != ""
	_status.get_parent().visible = text != ""
	# Colour by the first percentage in it: fine / getting bad / critical.
	var color := UiKit.COLD
	var regex := RegEx.create_from_string("(\\d+)%")
	var found := regex.search(text)
	if found != null:
		var value := found.get_string(1).to_int()
		color = UiKit.DANGER if value <= 25 else (UiKit.WARN if value <= 55 else UiKit.COLD)
	_status.add_theme_color_override("font_color", color)
	var box := _status.get_parent().get_theme_stylebox("panel") as StyleBoxFlat
	box.border_color = color


func set_objective(text: String) -> void:
	_objective.text = text
	_fit(_objective, 340.0)


# --- Per frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if _message_timer > 0.0:
		_message_timer -= delta
		_toast.modulate.a = clampf(_message_timer / 0.4, 0.0, 1.0)
		if _message_timer <= 0.0:
			_message.text = ""
			_toast.visible = false

	_flash = maxf(_flash - delta * 0.6, 0.0)
	var low := 0.0
	if _health_ratio > 0.0 and _health_ratio < 0.35:
		low = (0.35 - _health_ratio) * (0.9 + 0.5 * sin(_clock * 5.0))
	_vignette.color.a = maxf(_flash, low)
	_vignette_material.set_shader_parameter("amount", clampf(_vignette.color.a * 2.2, 0.0, 1.0))

	if _time_left < 120.0:
		_timer_panel.modulate.a = 0.75 + 0.25 * sin(_clock * 6.0)
	else:
		_timer_panel.modulate.a = 1.0

	var held := Input.is_key_pressed(KEY_F1) and DisplayServer.get_name() != "headless"
	_help_timer = maxf(_help_timer - delta, 0.0)
	var target := 1.0 if held or _help_timer > 0.0 else 0.0
	_help.modulate.a = move_toward(_help.modulate.a, target * (1.0 if held else minf(_help_timer, 1.0)), delta * 4.0)
	_help.visible = _help.modulate.a > 0.01
	_help_hint.modulate.a = 0.0 if _help.visible else 0.55


func _on_health_changed(ratio: float) -> void:
	if ratio < _health_ratio or ratio <= 0.0:
		_flash = 0.35 if ratio > 0.0 else 0.55
	_health_ratio = ratio
	_health.value = ratio


func _on_inventory_changed(items: Array, weight: float, value: int) -> void:
	var limit := Player.max_carry(_player)
	_inventory.text = "背包 %d 件　%.1f / %.0f kg　$%d" % [items.size(), weight, limit, value]
	var ratio := weight / limit if limit > 0.0 else 0.0
	_weight_bar.value = ratio
	_set_bar_color(_weight_bar, UiKit.DANGER if ratio > 0.85 else (UiKit.WARN if ratio > 0.6 else UiKit.TEXT))
	_usable = ""
	for i in range(items.size() - 1, -1, -1):
		if items[i].has("use"):
			_usable = "%s（%s）" % [items[i].name, LootTable.USE_NAMES.get(items[i].use, "使用")]
			break
	_rebuild_gear()


func _on_gear_changed() -> void:
	_rebuild_gear()


func _rebuild_gear() -> void:
	if _gear == null:
		return
	for child in _gear.get_children():
		_gear.remove_child(child)
		child.queue_free()
	var passive := []
	if _player != null:
		if _player.weapon_id != "":
			var weapon := Gear.info(_player.weapon_id)
			var line: String = weapon.name
			if weapon.has("ammo"):
				line += "　×%d" % _player.weapon_ammo
			_gear.add_child(_key_row("左鍵", line, UiKit.TEXT))
		for id in _player.boosts:
			var boost := Gear.info(id)
			if boost.get("consumable", false):
				_gear.add_child(_key_row("Q", boost.name, UiKit.TEXT))
			else:
				passive.append(boost.name)
	if _usable != "":
		_gear.add_child(_key_row("R", _usable, UiKit.ACCENT))
	if not passive.is_empty():
		var label := _text("・".join(passive), 13, UiKit.DIM)
		label.size_flags_horizontal = Control.SIZE_SHRINK_END
		_gear.add_child(label)
	_gear.get_parent().visible = _gear.get_child_count() > 0
	_ignore_mouse(_gear)


## "[E] 撿起 罐頭　$12　0.4kg　易碎" -> key chip E, "撿起 罐頭", details underneath.
func _set_prompt(text: String) -> void:
	_prompt_row.visible = text != ""
	var body := text
	var key := ""
	if body.begins_with("["):
		var close := body.find("]")
		if close > 0:
			key = body.substr(1, close - 1).strip_edges()
			body = body.substr(close + 1).strip_edges()
	_prompt_key.visible = key != ""
	_prompt_key_label.text = key
	var parts := body.split("　", false)
	if key != "" and parts.size() > 1:
		_prompt.text = parts[0]
		parts.remove_at(0)
		_prompt_detail.text = "　".join(parts)
		_prompt_detail.visible = true
	else:
		_prompt.text = body
		_prompt_detail.text = ""
		_prompt_detail.visible = false
	_prompt.add_theme_color_override("font_color", UiKit.TEXT if key != "" else UiKit.DIM)


# --- Builders -------------------------------------------------------------------------

## Wraps a label at max_width only when its longest line is wider than that, so
## short text keeps a tight panel (autowrap with no width would stack every glyph).
func _fit(label: Label, max_width: float) -> void:
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for line in label.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if widest > max_width:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = max_width
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0.0
	label.reset_size()

func _text(text: String, size: int, color := UiKit.TEXT, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	if bold:
		label.add_theme_font_override("font", UiKit.bold_font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Thin translucent panel with a coloured left edge.
func _panel(edge: Color, margin := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.02, 0.025, 0.55)
	box.border_color = edge
	box.border_width_left = 2
	box.content_margin_left = margin + 2
	box.content_margin_right = margin
	box.content_margin_top = maxi(margin - 4, 3)
	box.content_margin_bottom = maxi(margin - 4, 3)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _key_row(key: String, text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(UiKit.key_chip(key, 13))
	row.add_child(_text(text, 16, color))
	return row


func _bar(color: Color, bar_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = bar_size
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	bar.add_theme_stylebox_override("background", back)
	_set_bar_color(bar, color)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
