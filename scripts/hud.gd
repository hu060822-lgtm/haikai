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
	["左鍵", "開槍"], ["右鍵", "瞄準"], ["R", "換彈"], ["V", "小刀"],
	["Q", "強化"], ["X", "用物品"], ["Tab", "背包"], ["M", "麥克風"],
]
const HIT_TIME := 0.28

var _root: Control
var _crosshair: Control
var _ticks: Array[ColorRect] = []
var _hit_marker: Control
var _hit_lines: Array[ColorRect] = []
var _hit_number: Label
var _hit_timer := 0.0
var _weapon_panel: PanelContainer
var _weapon_name: Label
var _ammo: Label
var _reserve: Label
var _reload_bar: ProgressBar
var _weapon_hint: Label
var _prompt: Label
var _prompt_key: PanelContainer
var _prompt_key_label: Label
var _prompt_detail: Label
var _prompt_row: HBoxContainer
var _inventory: Label
var _weight_bar: ProgressBar
var _pack_panel: PanelContainer
var _pack_flash := 0.0
## The backpack grid screen (Tab).
var bag: BagScreen
## What's in your arms when hauling a bulky item (name, weight, value, how to put it down).
var _haul_panel: PanelContainer
var _haul: Label
var _haul_bar: ProgressBar
var _gear: VBoxContainer
var _timer: Label
var _timer_panel: PanelContainer
## 會醒來的廢墟: the eye under the timer (and its stage banner).
var awakening_meter: AwakeningMeter
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
	bag = BagScreen.new()
	add_child(bag)


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
	awakening_meter = AwakeningMeter.new()
	awakening_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(awakening_meter)
	awakening_meter.attach_banner(_root)
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
	# Four ticks that spread apart with the gun's spread (see _update_crosshair).
	for i in 4:
		var shadow := ColorRect.new()
		shadow.color = Color(0.0, 0.0, 0.0, 0.55)
		_crosshair.add_child(shadow)
		var tick := ColorRect.new()
		tick.color = Color(UiKit.TEXT, 0.85)
		shadow.add_child(tick)
		tick.position = Vector2(1.0, 1.0)
		_ticks.append(shadow)
	# The hit marker: an X round the crosshair, and the damage under it.
	_hit_marker = Control.new()
	_crosshair.add_child(_hit_marker)
	for i in 4:
		var line := ColorRect.new()
		line.size = Vector2(9.0, 2.0)
		line.pivot_offset = Vector2(0.0, 1.0)
		line.rotation = PI / 4.0 + PI / 2.0 * i
		line.position = Vector2.from_angle(line.rotation) * 7.0 - Vector2(0.0, 1.0)
		_hit_marker.add_child(line)
		_hit_lines.append(line)
	_hit_number = _text("", 14, UiKit.TEXT, true)
	_hit_number.position = Vector2(12.0, 6.0)
	_hit_marker.add_child(_hit_number)
	_hit_marker.visible = false

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

	_haul_panel = _panel(UiKit.WARN)
	_haul_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var haul_box := VBoxContainer.new()
	haul_box.add_theme_constant_override("separation", 4)
	_haul_panel.add_child(haul_box)
	_haul = _text("", 16, UiKit.TEXT)
	_haul.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	haul_box.add_child(_haul)
	_haul_bar = _bar(UiKit.WARN, Vector2(240.0, 4.0))
	haul_box.add_child(_haul_bar)
	_haul_panel.visible = false
	stack.add_child(_haul_panel)

	var pack := _panel(Color(1.0, 1.0, 1.0, 0.25))
	_pack_panel = pack
	pack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pack_box := VBoxContainer.new()
	pack_box.add_theme_constant_override("separation", 4)
	pack.add_child(pack_box)
	var pack_row := HBoxContainer.new()
	pack_row.add_theme_constant_override("separation", 8)
	pack_box.add_child(pack_row)
	_inventory = _text("", 16)
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pack_row.add_child(_inventory)
	pack_row.add_child(UiKit.key_chip("Tab", 12))
	# How full the grid is.
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
	_weapon_panel = _panel(UiKit.HOT)
	_weapon_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	var weapon_box := VBoxContainer.new()
	weapon_box.add_theme_constant_override("separation", 2)
	_weapon_panel.add_child(weapon_box)
	_weapon_name = _text("", 13, UiKit.HOT, true)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_name.size_flags_horizontal = Control.SIZE_SHRINK_END
	weapon_box.add_child(_weapon_name)
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 6)
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ammo = _text("", 34, UiKit.TEXT, true)
	_ammo.add_theme_font_override("font", UiKit.display_font())
	ammo_row.add_child(_ammo)
	_reserve = _text("", 18, UiKit.DIM, true)
	_reserve.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(_reserve)
	weapon_box.add_child(ammo_row)
	_reload_bar = _bar(UiKit.WARN, Vector2(170.0, 5.0))
	_reload_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_reload_bar.modulate.a = 0.0
	weapon_box.add_child(_reload_bar)
	_weapon_hint = _text("R 換彈　V 小刀　右鍵 瞄準", 12, UiKit.DIM)
	_weapon_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	weapon_box.add_child(_weapon_hint)
	_weapon_panel.visible = false
	stack.add_child(_weapon_panel)
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
	player.hit_confirmed.connect(show_hit)
	bag.bind(player)
	_on_inventory_changed(player.items, player.carried_weight, player.carried_value)
	_on_gear_changed()


func show_message(text: String, seconds := 3.0) -> void:
	var full := text.begins_with(Player.BAG_FULL_MESSAGE)
	if full:
		_pack_flash = 1.2
	# 「包包塞不下」 shouts in red; everything else is the usual bone white.
	(_toast.get_theme_stylebox("panel") as StyleBoxFlat).border_color = UiKit.DANGER if full else UiKit.TEXT
	(_toast.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left = 4 if full else 2
	_message.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55) if full else UiKit.TEXT)
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


## A map-specific line under the objective (the last train warning on the subway).
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
	_update_weapon(delta)
	_update_haul()
	_pack_flash = maxf(_pack_flash - delta, 0.0)
	var pack_box := _pack_panel.get_theme_stylebox("panel") as StyleBoxFlat
	pack_box.border_color = UiKit.DANGER if fmod(_pack_flash, 0.3) > 0.15 else Color(1.0, 1.0, 1.0, 0.25)
	pack_box.border_width_left = 4 if _pack_flash > 0.0 else 2


## Tab: open or close the backpack grid. The game doesn't pause.
func toggle_bag(open: bool) -> void:
	if open:
		bag.open()
	else:
		bag.close()
	if _player != null and is_instance_valid(_player):
		_player.bag_open = open
	_crosshair.visible = not open
	_prompt_row.visible = _prompt_row.visible and not open


var bag_open: bool:
	get: return bag != null and bag.visible


func _update_haul() -> void:
	var held: LootItem = _player.held_bulky if _player != null and is_instance_valid(_player) else null
	_haul_panel.visible = held != null and is_instance_valid(held)
	if not _haul_panel.visible:
		return
	var shared := held.carry != null and held.carry.holders.size() >= 2
	var felt := _player.bulky_load()
	_haul.text = "雙手：%s　%.0f kg　$%d\n%s　E 放下" % [held.item_name, held.weight, held.value,
		"兩個人抬：你扛 %.0f kg" % felt if shared else "一個人扛（找隊友抬另一邊）"]
	_haul_bar.value = clampf(felt / 120.0, 0.0, 1.0)
	_set_bar_color(_haul_bar, UiKit.DANGER if felt > 60.0 else UiKit.WARN)


## A shot or stab landed: flash the X (red on a kill, orange when a big one breaks).
func show_hit(damage: float, result: String) -> void:
	_hit_timer = HIT_TIME
	var color := UiKit.TEXT
	match result:
		"kill":
			color = UiKit.DANGER
		"break":
			color = UiKit.WARN
		"blocked":
			color = UiKit.DIM
		"player":
			color = UiKit.HOT
	for line in _hit_lines:
		line.color = color
	_hit_number.add_theme_color_override("font_color", color)
	match result:
		"kill":
			_hit_number.text = "%d　擊殺" % roundi(damage)
		"break":
			_hit_number.text = "%d　打倒了！" % roundi(damage)
		"blocked":
			_hit_number.text = "擋下了"
		_:
			_hit_number.text = "%d" % maxi(roundi(damage), 1)
	_hit_number.reset_size()
	_hit_marker.visible = true


func _update_weapon(delta: float) -> void:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_hit_marker.visible = _hit_timer > 0.0
	if _hit_marker.visible:
		var t := _hit_timer / HIT_TIME
		_hit_marker.modulate.a = clampf(t * 1.6, 0.0, 1.0)
		_hit_marker.scale = Vector2.ONE * (1.0 + (t - 0.6) * 0.5 if t > 0.6 else 1.0)
		_hit_number.position.y = 6.0 + (1.0 - t) * 10.0
	var player := _player
	if player == null or not is_instance_valid(player) or player.weapon.is_empty():
		_weapon_panel.visible = false
		_update_crosshair(0.0)
		return
	_weapon_panel.visible = true
	var stats: Dictionary = player.weapon
	_weapon_name.text = Arsenal.name_of(player.build.frame)
	_ammo.text = str(player.mag_ammo)
	_reserve.text = "/ %d" % player.reserve_ammo
	var empty := player.mag_ammo <= 0
	_ammo.add_theme_color_override("font_color", UiKit.DANGER if empty else (UiKit.WARN if player.mag_ammo <= maxi(int(stats.mag) / 4, 1) else UiKit.TEXT))
	var bar := 0.0
	if player.reloading > 0.0:
		bar = 1.0 - player.reloading / maxf(float(stats.reload), 0.01)
		_set_bar_color(_reload_bar, UiKit.WARN)
		_weapon_hint.text = "換彈中…"
	elif player.charge > 0.0:
		bar = player.charge
		_set_bar_color(_reload_bar, UiKit.COLD)
		_weapon_hint.text = "充能中…放開就取消"
	elif empty and player.reserve_ammo > 0:
		_weapon_hint.text = "沒子彈了！按 R 換彈"
	elif empty:
		_weapon_hint.text = "子彈打光了。只剩小刀（V）"
	else:
		_weapon_hint.text = "R 換彈　V 小刀　右鍵 瞄準" if stats.kind != "charge" else "按住左鍵充能　V 小刀"
	_weapon_hint.add_theme_color_override("font_color", UiKit.DANGER if empty and player.reloading <= 0.0 else UiKit.DIM)
	_reload_bar.value = bar
	_reload_bar.modulate.a = 1.0 if bar > 0.0 else 0.0
	_update_crosshair(player.current_spread(), player.view_fov(), player.aiming)


## Crosshair ticks sit as far out as the shot's random cone reaches on screen.
func _update_crosshair(spread: float, fov := 70.0, aiming := false) -> void:
	var height := _root.size.y if _root.size.y > 0.0 else 720.0
	var gap := 4.0 + tan(deg_to_rad(spread)) / tan(deg_to_rad(fov) * 0.5) * height * 0.5
	gap = clampf(gap, 4.0, 120.0)
	var length := 5.0 if aiming else 7.0
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for i in 4:
		var shadow := _ticks[i]
		var dir: Vector2 = dirs[i]
		var size := Vector2(2.0, length) if dir.x == 0.0 else Vector2(length, 2.0)
		shadow.size = size + Vector2(2.0, 2.0)
		(shadow.get_child(0) as ColorRect).size = size
		var centre := dir * (gap + length * 0.5)
		shadow.position = centre - shadow.size * 0.5
		shadow.visible = spread > 0.01 or aiming


func _on_health_changed(ratio: float) -> void:
	if ratio < _health_ratio or ratio <= 0.0:
		_flash = 0.35 if ratio > 0.0 else 0.55
	_health_ratio = ratio
	_health.value = ratio


func _on_inventory_changed(items: Array, weight: float, value: int) -> void:
	var cells := _player.bag_cells.size() if _player != null else GridBag.CELLS
	var used := cells - (GridBag.free_cells(_player.bag_cells, items) if _player != null else cells)
	_inventory.text = "背包 %d / %d 格　%.1f kg　$%d" % [used, cells, weight, value]
	var organs := items.filter(func(item: Dictionary) -> bool: return item.has("organ")).size()
	if organs > 0:
		_inventory.text += "　器官 %d" % organs
	var ratio := float(used) / cells if cells > 0 else 0.0
	_weight_bar.value = ratio
	# Heavier means slower: the bar goes orange, then red, as the weight piles on.
	var heft := weight / Player.full_load(_player)
	_set_bar_color(_weight_bar, UiKit.DANGER if heft > 0.85 else (UiKit.WARN if heft > 0.6 else UiKit.TEXT))
	if bag != null:
		bag.refresh()
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
		for id in _player.boosts:
			var boost := Gear.info(id)
			if boost.get("consumable", false):
				_gear.add_child(_key_row("Q", boost.name, UiKit.TEXT))
			else:
				passive.append(boost.name)
	if _usable != "":
		_gear.add_child(_key_row("X", _usable, UiKit.ACCENT))
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
