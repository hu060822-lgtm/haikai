class_name HUD
extends CanvasLayer
## Full-resolution overlay drawn on top of the low-res game view.

const TEXT_COLOR := Color(0.92, 0.86, 0.72)

var _crosshair: Label
var _prompt: Label
var _inventory: Label
var _gear: Label
var _timer: Label
var _objective: Label
var _health: ProgressBar
var _stamina: ProgressBar
var _extract: ProgressBar
var _extract_label: Label
var _message: Label
var _help: Label
var _voice: Label
var _vignette: ColorRect
var _message_timer := 0.0
var _player: Player


func _ready() -> void:
	layer = 10
	_vignette = ColorRect.new()
	_vignette.color = Color(0.6, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_crosshair = _label("·", 28, Control.PRESET_CENTER)
	_prompt = _label("", 22, Control.PRESET_CENTER)
	_prompt.position.y += 40.0
	_message = _label("", 26, Control.PRESET_CENTER_TOP)
	_message.position.y += 70.0

	_timer = _label("", 26, Control.PRESET_CENTER_TOP)
	_timer.position.y += 14.0
	_objective = _label("", 18, Control.PRESET_TOP_RIGHT)
	_objective.position += Vector2(-16.0, 14.0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_inventory = _label("", 20, Control.PRESET_BOTTOM_LEFT)
	_inventory.position += Vector2(24.0, -120.0)
	_gear = _label("", 18, Control.PRESET_BOTTOM_RIGHT)
	_gear.position += Vector2(-24.0, -60.0)
	_gear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	_help = _label("WASD 移動　Shift 衝刺　Ctrl 蹲下　空白 跳　E 撿起/互動　G 丟下　F 提燈　左鍵 武器　Q 強化", 15, Control.PRESET_CENTER_BOTTOM)
	_help.position.y -= 30.0
	_help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help.modulate.a = 0.5

	_voice = _label("", 16, Control.PRESET_BOTTOM_LEFT)
	_voice.position += Vector2(24.0, -150.0)
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_health = _bar(Control.PRESET_BOTTOM_LEFT, Color(0.8, 0.25, 0.2))
	_health.position += Vector2(24.0, -64.0)
	_stamina = _bar(Control.PRESET_BOTTOM_LEFT, Color(0.85, 0.75, 0.45))
	_stamina.position += Vector2(24.0, -40.0)

	_extract = _bar(Control.PRESET_CENTER, Color(0.5, 0.9, 0.6))
	_extract.position += Vector2(-110.0, 80.0)
	_extract.size.x = 220.0
	_extract.visible = false
	_extract_label = _label("撤離中…", 20, Control.PRESET_CENTER)
	_extract_label.position.y += 110.0
	_extract_label.visible = false


func bind_player(player: Player) -> void:
	_player = player
	player.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)
	player.stamina_changed.connect(func(ratio: float) -> void: _stamina.value = ratio)
	player.health_changed.connect(_on_health_changed)
	player.inventory_changed.connect(_on_inventory_changed)
	player.gear_changed.connect(_on_gear_changed)
	player.message.connect(show_message)
	_on_inventory_changed(player.items, player.carried_weight, player.carried_value)
	_on_gear_changed()


func show_message(text: String, seconds := 3.0) -> void:
	_message.text = text
	_message_timer = seconds


func set_extract_progress(ratio: float) -> void:
	_extract.visible = ratio > 0.0
	_extract_label.visible = ratio > 0.0
	_extract.value = ratio


func set_time_left(seconds: float) -> void:
	var s := maxi(int(ceil(seconds)), 0)
	_timer.text = "%d:%02d" % [s / 60, s % 60]
	_timer.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if seconds < 120.0 else TEXT_COLOR)


## Mic indicator for online runs. state: "" (hidden), "on", "speaking" or "muted".
func set_voice(state: String) -> void:
	match state:
		"speaking":
			_voice.text = "● 說話中（M 靜音）"
			_voice.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
		"muted":
			_voice.text = "麥克風靜音（M 打開）"
			_voice.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		"on":
			_voice.text = "麥克風開（附近的人和怪物都聽得到）"
			_voice.add_theme_color_override("font_color", TEXT_COLOR)
		_:
			_voice.text = ""


func set_objective(text: String) -> void:
	_objective.text = text


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""
	_vignette.color.a = maxf(_vignette.color.a - delta * 0.6, 0.0)


func _on_health_changed(ratio: float) -> void:
	_vignette.color.a = 0.35 if ratio > 0.0 else 0.55
	_health.value = ratio


func _on_inventory_changed(items: Array, weight: float, value: int) -> void:
	_inventory.text = "背包 %d 件　%.1f / %.0f kg　價值 $%d" % [items.size(), weight, Player.MAX_CARRY_WEIGHT, value]


func _on_gear_changed() -> void:
	if _player == null:
		return
	var lines := []
	if _player.weapon_id != "":
		var weapon := Gear.info(_player.weapon_id)
		var line: String = "左鍵：" + weapon.name
		if weapon.has("ammo"):
			line += "（%d）" % _player.weapon_ammo
		lines.append(line)
	for id in _player.boosts:
		var boost := Gear.info(id)
		lines.append(("Q：" if boost.get("consumable", false) else "") + boost.name)
	_gear.text = "\n".join(lines)


func _label(text: String, font_size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_KEEP_SIZE)
	if preset in [Control.PRESET_CENTER, Control.PRESET_CENTER_TOP]:
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]:
		label.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
