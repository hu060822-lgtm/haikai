class_name HUD
extends CanvasLayer
## Full-resolution overlay drawn on top of the low-res game view.

var _crosshair: Label
var _prompt: Label
var _inventory: Label
var _stamina: ProgressBar
var _extract: ProgressBar
var _extract_label: Label
var _message: Label
var _help: Label
var _message_timer := 0.0


func _ready() -> void:
	layer = 10
	_crosshair = _label("·", 28, Control.PRESET_CENTER)
	_prompt = _label("", 22, Control.PRESET_CENTER)
	_prompt.position.y += 40.0
	_message = _label("", 26, Control.PRESET_CENTER_TOP)
	_message.position.y += 60.0

	_inventory = _label("", 20, Control.PRESET_BOTTOM_LEFT)
	_inventory.position += Vector2(24.0, -90.0)

	_help = _label("WASD 移動　Shift 衝刺　Ctrl 蹲下　E 撿起　G 丟下　F 提燈　Esc 滑鼠", 16, Control.PRESET_TOP_LEFT)
	_help.position += Vector2(16.0, 12.0)
	_help.modulate.a = 0.6

	_stamina = _bar(Control.PRESET_BOTTOM_LEFT, Color(0.85, 0.75, 0.45))
	_stamina.position += Vector2(24.0, -36.0)

	_extract = _bar(Control.PRESET_CENTER, Color(0.5, 0.9, 0.6))
	_extract.position += Vector2(-110.0, 80.0)
	_extract.size.x = 220.0
	_extract.visible = false
	_extract_label = _label("撤離中…", 20, Control.PRESET_CENTER)
	_extract_label.position.y += 110.0
	_extract_label.visible = false


func bind_player(player: Player) -> void:
	player.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	player.stamina_changed.connect(func(ratio: float) -> void: _stamina.value = ratio)
	player.inventory_changed.connect(_on_inventory_changed)
	player.message.connect(show_message)
	_on_inventory_changed(player.items, player.carried_weight, player.carried_value)


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_timer = seconds


func set_extract_progress(ratio: float) -> void:
	_extract.visible = ratio > 0.0
	_extract_label.visible = ratio > 0.0
	_extract.value = ratio


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""


func _on_inventory_changed(items: Array, weight: float, value: int) -> void:
	_inventory.text = "背包 %d 件　%.1f / %.0f kg　價值 $%d" % [items.size(), weight, Player.MAX_CARRY_WEIGHT, value]


func _label(text: String, font_size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	if preset in [Control.PRESET_CENTER, Control.PRESET_CENTER_TOP]:
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	return label


func _bar(preset: Control.LayoutPreset, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180.0, 10.0)
	bar.size = bar.custom_minimum_size
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	return bar
