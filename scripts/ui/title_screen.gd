class_name TitleScreen
extends Control
## First screen: a loud, glitchy punk title card with the three ways in.
## 開始遊戲 -> stash (solo / host / join live there), 多人連線 -> stash with the
## join box focused, 結束遊戲 -> quit.

signal start_requested()
signal multiplayer_requested()
signal quit_requested()

const LOGO_SIZE := 176
const LOGO_BOX := Vector2(760, 230)

var _logo: Control
var _logo_main: Label
var _logo_hot: Label
var _logo_acid: Label
var _slices: Array[Control] = []
var _menu: VBoxContainer
var _desc: Label
var _hint: Label
var _flash: ColorRect
var _crt: ShaderMaterial
var _buttons: Array[Button] = []
var _time := 0.0
var _next_glitch := 1.2
var _glitch_left := 0.0
var _rng := RandomNumberGenerator.new()

const ENTRIES := [
	["01", "開始遊戲", "進倉庫挑裝備，一個人出發，或從那裡開房間。"],
	["02", "多人連線", "建立房間或輸入主機 IP 加入（最多 8 人，可以分隊互搶）。"],
	["03", "結束遊戲", "回到安全的地方。暫時。"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	UiKit.add_backdrop(self, 1.6, 1.2)
	_add_graffiti()
	_add_logo()
	_add_menu()
	_add_footer()

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt = UiKit.add_crt(self, 1.0, 0.26, 1.6).material
	_intro()


func _add_graffiti() -> void:
	# A huge spray-painted 撤 bleeding off the right edge.
	var big := UiKit.title("撤", 520, Color(0.0, 0.0, 0.0, 0.0))
	big.add_theme_color_override("font_outline_color", Color(UiKit.HOT, 0.22))
	big.add_theme_constant_override("outline_size", 14)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(big)
	big.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	big.position += Vector2(-120.0, -190.0)
	big.rotation_degrees = 9.0

	# Vertical stencil slogan down the right side.
	var slogan := UiKit.label("活\n著\n出\n來\n・\n才\n算\n你\n的", 22, Color(UiKit.ACCENT, 0.75))
	slogan.add_theme_font_override("font", UiKit.bold_font())
	slogan.add_theme_constant_override("line_spacing", -2)
	slogan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slogan)
	slogan.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	slogan.position += Vector2(-56.0, -150.0)


func _add_logo() -> void:
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.size = LOGO_BOX
	_logo.position = Vector2(84.0, 52.0)
	_logo.pivot_offset = LOGO_BOX * 0.5
	add_child(_logo)
	var shadow := _logo_label(Color(0.0, 0.0, 0.0, 0.75))
	shadow.position = Vector2(10.0, 10.0)
	_logo_hot = _logo_label(Color(UiKit.HOT, 0.9))
	_logo_acid = _logo_label(Color(UiKit.ACCENT, 0.9))
	_logo_main = _logo_label(UiKit.TEXT)
	_logo_main.add_theme_constant_override("outline_size", 22)
	for i in 3:
		var clip := Control.new()
		clip.clip_contents = true
		clip.visible = false
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.add_child(clip)
		var copy := _logo_label(UiKit.ACCENT if i == 1 else UiKit.TEXT)
		copy.add_theme_constant_override("outline_size", 22)
		copy.reparent(clip)
		_slices.append(clip)

	var tape := UiKit.sticker("PS1 恐怖・搜打撤", UiKit.ACCENT, UiKit.INK, 20, -7.0)
	_logo.add_child(tape)
	tape.position = Vector2(470.0, 8.0)
	var tag := UiKit.sticker("最多 8 人連線", UiKit.HOT, UiKit.INK, 16, 5.0)
	_logo.add_child(tag)
	tag.position = Vector2(560.0, 190.0)

	var sub := UiKit.label("搜　刮　／　撤　離　／　活　下　來", 22, UiKit.TEXT)
	sub.add_theme_font_override("font", UiKit.bold_font())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(sub)
	sub.position = Vector2(100.0, 270.0)
	var strip := UiKit.hazard_strip(8.0)
	add_child(strip)
	strip.position = Vector2(96.0, 310.0)
	strip.size = Vector2(540.0, 8.0)


func _logo_label(color: Color) -> Label:
	var label := UiKit.title("HAIKAI", LOGO_SIZE, color)
	label.add_theme_font_override("font", UiKit.logo_font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_constant_override("outline_size", 0 if color != UiKit.TEXT else 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.add_child(label)
	label.position = Vector2.ZERO
	label.size = LOGO_BOX
	return label


func _add_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	_menu.position = Vector2(96.0, 350.0)
	_menu.custom_minimum_size = Vector2(400.0, 0.0)
	var actions := [start_requested, multiplayer_requested, quit_requested]
	for i in ENTRIES.size():
		var entry: Array = ENTRIES[i]
		var signal_to_emit: Signal = actions[i]
		var button := UiKit.button("%s　%s" % [entry[0], entry[1]], func() -> void: _press(signal_to_emit))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(400.0, 62.0)
		button.add_theme_font_override("font", UiKit.display_font())
		button.add_theme_font_size_override("font_size", 32)
		UiKit.style_button(button, "loud")
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(func() -> void: _desc.text = entry[2])
		_menu.add_child(button)
		_buttons.append(button)
	_desc = UiKit.label("", 16, UiKit.DIM)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc.custom_minimum_size = Vector2(560.0, 0.0)
	_menu.add_child(_desc)


func _add_footer() -> void:
	_hint = UiKit.label("↑↓ 選擇　Enter 確定", 15, UiKit.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_hint.position += Vector2(98.0, -52.0)

	var stats := UiKit.label("倉庫 $%d　撤離 %d 次　死亡 %d 次" % [GameState.money, GameState.extractions, GameState.deaths], 15, UiKit.DIM)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(stats)
	stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	stats.position += Vector2(-40.0, -52.0)

	var strip := UiKit.hazard_strip(10.0, UiKit.HOT, UiKit.INK)
	add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -10.0


func _intro() -> void:
	_logo.scale = Vector2(1.35, 1.35)
	_logo.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_menu.position.x -= 60.0
	_flash.color.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.05)
	tween.parallel().tween_property(_logo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_flash, "color:a", 0.0, 0.5).from(0.85)
	tween.parallel().tween_callback(func() -> void: _glitch_left = 0.25)
	tween.tween_property(_menu, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_menu, "position:x", _menu.position.x + 60.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if not _buttons.is_empty() and is_inside_tree():
			_buttons[0].grab_focus())


func _press(which: Signal) -> void:
	_glitch_left = 0.2
	_flash.color.a = 0.35
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.15)
	tween.tween_callback(func() -> void: which.emit())


func _process(delta: float) -> void:
	_time += delta
	_hint.modulate.a = 0.45 + 0.55 * float(int(_time * 1.6) % 2)
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_next_glitch = _rng.randf_range(1.4, 4.0)
		_glitch_left = _rng.randf_range(0.08, 0.28)

	var bursting := _glitch_left > 0.0
	_glitch_left -= delta
	if bursting:
		var jump := _rng.randf_range(5.0, 18.0)
		_logo_hot.position = Vector2(-jump, _rng.randf_range(-3.0, 3.0))
		_logo_acid.position = Vector2(jump * 0.8, _rng.randf_range(-3.0, 3.0))
		for clip in _slices:
			clip.visible = _rng.randf() < 0.8
			var y := _rng.randf_range(20.0, LOGO_BOX.y - 40.0)
			var h := _rng.randf_range(6.0, 34.0)
			var dx := _rng.randf_range(-40.0, 40.0)
			clip.position = Vector2(dx, y)
			clip.size = Vector2(LOGO_BOX.x, h)
			(clip.get_child(0) as Control).position = Vector2(0.0, -y)
	else:
		var wobble := 3.0 + sin(_time * 2.3) * 1.5
		_logo_hot.position = Vector2(-wobble, 0.0)
		_logo_acid.position = Vector2(wobble, 0.0)
		for clip in _slices:
			clip.visible = false
	# Neon buzz: the acid layer drops out now and then.
	_logo_acid.modulate.a = 0.25 if fmod(_time * 7.3, 5.0) < 0.18 else 1.0
	if _crt != null:
		_crt.set_shader_parameter("burst", 0.7 if bursting else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	# Any key wakes up keyboard focus if the mouse took it away.
	if event is InputEventKey and event.pressed and get_viewport().gui_get_focus_owner() == null and not _buttons.is_empty():
		_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()
