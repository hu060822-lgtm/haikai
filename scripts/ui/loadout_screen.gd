class_name LoadoutScreen
extends Control
## The stash (倉庫) as a gunsmith bench, Tarkov style.
##   left:   tabs for weapon frames (槍身), saved plans (方案) and boosts (強化)
##   centre: the build turning on the bench (drag to rotate) with its slot buttons around
##           it; a slot opens a picker of the parts that fit, with what each one changes
##   right:  every number of the build, its effects, and what equipping it costs
##   bottom: name, back, multiplayer, and 單人出發
## Planning is free: the build on the bench is only a plan until 裝備 pays for the
## missing pieces (GameState.equip_build). Plans can be saved and loaded (GameState.builds).

signal solo_requested()
signal host_requested()
signal join_requested(address: String)
signal back_requested()

## Remembered across visits to the screen.
static var last_address := "127.0.0.1"

## Where each slot's button sits around the preview, as fractions of its rect.
const SLOT_SPOTS := {
	"sight": Vector2(0.5, 0.075), "muzzle": Vector2(0.86, 0.3), "barrel": Vector2(0.86, 0.52),
	"stock": Vector2(0.14, 0.3), "ammo": Vector2(0.86, 0.74),
	"magazine": Vector2(0.38, 0.915), "underbarrel": Vector2(0.62, 0.915), "gadget": Vector2(0.14, 0.915),
}
const SLOT_SIZE := Vector2(150, 50)
## Stats panel rows: stat, label, which way is better (1 higher, -1 lower, 0 neither).
const STAT_ROWS := [
	["damage", "傷害", 1], ["rate", "射速", 1], ["mag", "彈匣", 1], ["reserve", "備彈", 1],
	["reload", "換彈", -1], ["spread", "散佈", -1], ["range", "射程", 1], ["noise", "槍聲", -1],
	["recoil", "後座", -1], ["zoom", "瞄準倍率", 0], ["weight", "重量", -1],
]
const KIND_NAMES := {
	"hitscan": "直射", "cone": "近距離噴射", "arc": "電弧（會跳）", "lob": "拋射（會爆）",
	"bounce": "反彈飛刃", "charge": "按住充能",
}

## The build on the bench (a plan until it is equipped).
var plan: Dictionary = Arsenal.STARTER.duplicate(true)

var _loadout: Dictionary:
	get: return GameState.equipped
var _tab := "frames"
var _open_slot := ""
var _hover := {}  # a candidate build being hovered (stats show it against the plan)

var _money_label: Label
var _stats_label: Label
var _tab_buttons := {}
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _gun_name: Label
var _gun_desc: Label
var _preview: Control
var _view_container: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _yaw := -90.0
var _pitch := 14.0
var _dragged := false
var _spin_time := 0.0
var _slot_buttons := {}
var _lines: Control
var _picker: PanelContainer
var _picker_list: VBoxContainer
var _picker_title: Label
var _info: Label
var _stat_values := {}
var _stat_deltas := {}
var _effects: RichTextLabel
var _cost_title: Label
var _cost_detail: RichTextLabel
var _equip: Button
var _equipped_label: Label
var _carry_label: Label
var _name_edit: LineEdit
var _address_edit: LineEdit
var _plan_name_edit: LineEdit
var _status: Label
var _solo: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan = Arsenal.clean(_loadout.build)
	UiKit.add_backdrop(self, 0.55, 0.5)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	# Top bar: logo, screen name, money.
	var bar := UiKit.top_bar("倉庫・改槍台")
	var money_box := VBoxContainer.new()
	money_box.add_theme_constant_override("separation", -6)
	_money_label = UiKit.title("", 34, UiKit.ACCENT)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(_money_label)
	_stats_label = UiKit.label("", 13, UiKit.DIM)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_box.add_child(_stats_label)
	bar.add_child(money_box)
	page.add_child(bar)
	page.add_child(UiKit.hazard_strip(4.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_left(body)
	_build_centre(body)
	_build_right(body)
	_build_bottom(page)

	UiKit.add_crt(self, 0.0, 0.1, 0.6)
	_rebuild_model()
	_refresh()
	_solo.grab_focus.call_deferred()


# --- Layout -----------------------------------------------------------------------------

func _build_left(body: HBoxContainer) -> void:
	var panel := UiKit.panel(10)
	panel.custom_minimum_size = Vector2(250, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for tab: Array in [["frames", "槍身"], ["plans", "方案"], ["boosts", "強化"]]:
		var id: String = tab[0]
		var button := UiKit.button(tab[1], func() -> void: _set_tab(id))
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.focus_mode = Control.FOCUS_NONE
		_tab_buttons[id] = button
		tabs.add_child(button)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)


func _build_centre(body: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	_gun_name = UiKit.title("", 28, UiKit.TEXT)
	head.add_child(_gun_name)
	_gun_desc = UiKit.label("", 14, UiKit.DIM)
	_gun_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_gun_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gun_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gun_desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_gun_desc)

	var frame := UiKit.panel(0, Color(UiKit.ACCENT, 0.25))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(frame)
	_preview = Control.new()
	_preview.clip_contents = true
	frame.add_child(_preview)
	_build_viewport()
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	_preview.add_child(_lines)
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := UiKit.label("拖曳旋轉", 13, Color(UiKit.DIM, 0.8))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -90
	hint.offset_top = 6
	hint.offset_right = -10
	for slot: String in Arsenal.SLOTS:
		_slot_buttons[slot] = _make_slot_button(slot)
	_build_picker()

	var info_panel := UiKit.panel(8)
	info_panel.custom_minimum_size = Vector2(0, 52)
	column.add_child(info_panel)
	_info = UiKit.label("", 14, UiKit.TEXT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(_info)


func _build_viewport() -> void:
	_view_container = SubViewportContainer.new()
	_view_container.stretch = true
	_view_container.stretch_shrink = 2
	_view_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_view_container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_view_container.gui_input.connect(_on_preview_input)
	_preview.add_child(_view_container)
	_view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_view_container.add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.58, 0.62)
	env.environment.ambient_light_energy = 0.9
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 40, 0)
	key.light_energy = 1.25
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -150, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.8, 1.0, 0.5)
	_viewport.add_child(rim)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.position = Vector3(0, 0, 2.0)
	_viewport.add_child(_camera)
	_camera.make_current()


func _make_slot_button(slot: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	UiKit.style_button(button, "normal")
	button.anchor_left = SLOT_SPOTS[slot].x
	button.anchor_right = SLOT_SPOTS[slot].x
	button.anchor_top = SLOT_SPOTS[slot].y
	button.anchor_bottom = SLOT_SPOTS[slot].y
	button.offset_left = -SLOT_SIZE.x / 2.0
	button.offset_right = SLOT_SIZE.x / 2.0
	button.offset_top = -SLOT_SIZE.y / 2.0
	button.offset_bottom = SLOT_SIZE.y / 2.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 3
	box.offset_right = -6
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var slot_label := UiKit.label(Arsenal.SLOT_NAMES[slot], 13, UiKit.DIM)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(slot_label)
	var tag := UiKit.label("", 13, UiKit.GOOD)
	tag.name = "Tag"
	top.add_child(tag)
	var part_label := UiKit.label("", 16, UiKit.TEXT)
	part_label.name = "Part"
	part_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	part_label.clip_text = true
	part_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(part_label)
	for node: Control in [top, slot_label, tag, part_label]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(func() -> void: open_slot(slot))
	button.mouse_entered.connect(func() -> void: _describe_slot(slot))
	_preview.add_child(button)
	return button


func _build_picker() -> void:
	_picker = UiKit.panel(10, UiKit.ACCENT)
	(_picker.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.03, 0.03, 0.035, 0.97)
	_picker.visible = false
	_preview.add_child(_picker)
	_picker.anchor_left = 0.2
	_picker.anchor_right = 0.8
	_picker.anchor_top = 0.15
	_picker.anchor_bottom = 0.15
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_picker.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_picker_title = UiKit.label("", 17, UiKit.ACCENT)
	_picker_title.add_theme_font_override("font", UiKit.bold_font())
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_picker_title)
	var close := UiKit.button("✕ 關閉", close_picker)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 14)
	close.custom_minimum_size = Vector2(70, 28)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 4)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_picker_list)


func _build_right(body: HBoxContainer) -> void:
	var panel := UiKit.panel(12, Color(UiKit.ACCENT, 0.35))
	panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(UiKit.heading("數據"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", -3)
	column.add_child(grid)
	for row: Array in STAT_ROWS:
		var name_label := UiKit.label(row[1], 14, UiKit.DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(name_label)
		var value := UiKit.label("", 14, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
		var delta := UiKit.label("", 14, UiKit.GOOD)
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		delta.custom_minimum_size = Vector2(66, 0)
		grid.add_child(delta)
		_stat_values[row[0]] = value
		_stat_deltas[row[0]] = delta
	_effects = _rich(14)
	column.add_child(_effects)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	column.add_child(UiKit.hazard_strip(3.0, UiKit.HOT))
	_cost_title = UiKit.label("", 17, UiKit.TEXT)
	_cost_title.add_theme_font_override("font", UiKit.bold_font())
	_cost_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_cost_title)
	_cost_detail = _rich(14)
	column.add_child(_cost_detail)
	_equip = UiKit.primary_button("", equip_plan)
	_equip.custom_minimum_size = Vector2(0, 46)
	_equip.add_theme_font_size_override("font_size", 20)
	column.add_child(_equip)
	_equipped_label = UiKit.label("", 13, UiKit.DIM)
	_equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_equipped_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_equipped_label)


func _build_bottom(page: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	page.add_child(bar)
	var back := UiKit.button("← 回標題", func() -> void: back_requested.emit())
	back.add_theme_font_size_override("font_size", 15)
	back.custom_minimum_size = Vector2(96, 44)
	bar.add_child(back)
	bar.add_child(UiKit.label("名字", 15, UiKit.DIM))
	_name_edit = UiKit.line_edit(Session.instance.local_name if Session.instance else "拾荒者", 16)
	_name_edit.custom_minimum_size = Vector2(120, 40)
	bar.add_child(_name_edit)
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", -4)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(middle)
	_status = UiKit.label("", 15, UiKit.DANGER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(_status)
	_carry_label = UiKit.label("", 14, UiKit.DIM)
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_carry_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(_carry_label)
	var host := UiKit.button("建立房間", func() -> void: _commit_name(); host_requested.emit())
	host.custom_minimum_size = Vector2(104, 44)
	host.add_theme_font_size_override("font_size", 16)
	bar.add_child(host)
	_address_edit = UiKit.line_edit(last_address, 64)
	_address_edit.placeholder_text = "主機的 IP"
	_address_edit.custom_minimum_size = Vector2(140, 40)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _join())
	bar.add_child(_address_edit)
	var join := UiKit.button("加入房間", _join)
	join.custom_minimum_size = Vector2(104, 44)
	join.add_theme_font_size_override("font_size", 16)
	bar.add_child(join)
	_solo = UiKit.primary_button("單人出發", func() -> void: _commit_name(); solo_requested.emit())
	_solo.custom_minimum_size = Vector2(170, 48)
	_solo.add_theme_font_override("font", UiKit.display_font())
	_solo.add_theme_font_size_override("font_size", 24)
	bar.add_child(_solo)


static func _rich(size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("default_color", UiKit.TEXT)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


# --- Public actions (also what the smoke test drives) -------------------------------------

## Puts another frame on the bench, keeping every part that still fits.
func select_frame(frame_id: String) -> void:
	if not Arsenal.FRAMES.has(frame_id):
		return
	plan = Arsenal.clean({"frame": frame_id, "parts": plan.parts})
	close_picker()
	_dragged = false
	_rebuild_model()
	_refresh()


## Puts a part in a slot of the plan ("" takes the slot's part off). Free: it's a plan.
func set_part(slot: String, part_id: String) -> void:
	var parts: Dictionary = plan.parts.duplicate()
	if part_id == "":
		parts.erase(slot)
	else:
		parts[slot] = part_id
	plan = Arsenal.clean({"frame": plan.frame, "parts": parts})
	_hover = {}
	_rebuild_model()
	_refresh()


## Pays for the missing pieces and makes the plan the gun you carry in.
func equip_plan() -> bool:
	if _is_equipped_plan():
		show_status("")
		return true
	var cost := plan_cost()
	if not GameState.equip_build(plan):
		show_status("錢不夠：裝備這把還差 $%d" % (cost - GameState.money))
		return false
	show_status("")
	_flash(_equip)
	_refresh()
	return true


## Saves the bench build as a named plan (same name overwrites).
func save_current_plan(plan_name: String) -> void:
	plan_name = plan_name.strip_edges().substr(0, 14)
	if plan_name == "":
		plan_name = "方案 %d" % (GameState.builds.size() + 1)
	GameState.save_plan(plan_name, plan)
	show_status("")
	_refresh()


func load_plan(index: int) -> void:
	if index < 0 or index >= GameState.builds.size():
		return
	plan = Arsenal.clean(GameState.builds[index].build)
	close_picker()
	_dragged = false
	_rebuild_model()
	_refresh()


func delete_plan(index: int) -> void:
	if index < 0 or index >= GameState.builds.size():
		return
	GameState.builds.remove_at(index)
	GameState.save_game()
	_refresh()


## Opens the parts picker for one slot of the plan's frame.
func open_slot(slot: String) -> void:
	if not slot in Arsenal.frame(plan.frame).slots:
		return
	if _open_slot == slot and _picker.visible:
		close_picker()
		return
	_open_slot = slot
	_picker.visible = true
	_fill_picker()
	_refresh_slots()


func close_picker() -> void:
	_open_slot = ""
	_hover = {}
	if _info != null:
		_info.text = "點槍身周圍的槍位換零件。改裝是免費試的，按「裝備」才會花錢。"
	if _picker != null:
		_picker.visible = false
		_refresh_slots()
		_refresh_stats()


## Money still needed to equip the plan. Pieces on the equipped gun count as owned,
## since equipping hands them back to the stash first.
func plan_cost() -> int:
	var cost := 0
	for item: Array in _plan_pieces():
		if item[1] == "buy":
			cost += GameState.price_of(item[0])
	return cost


func show_status(text: String) -> void:
	_status.text = text
	if text != "" and is_inside_tree():
		_status.modulate.a = 0.0
		create_tween().tween_property(_status, "modulate:a", 1.0, 0.2)


## From the title screen's 多人連線: put the cursor in the address box.
func focus_multiplayer() -> void:
	if _address_edit == null:
		return
	_address_edit.grab_focus.call_deferred()
	_address_edit.select_all.call_deferred()


## For tools/loadout_shot.gd: puts the bench in a named state for a screenshot.
func shot_state(state: String) -> void:
	match state:
		"modded_smg":
			plan = {"frame": "smg", "parts": {"muzzle": "suppressor", "sight": "red_dot", "magazine": "drum_mag",
				"stock": "light_stock", "underbarrel": "flashlight", "ammo": "hollow_point", "gadget": "vampire_charm"}}
			GameState.stash["suppressor"] = 1
			GameState.stash["drum_mag"] = 1
			select_frame("smg")
			_set_tab("frames")
		"picker":
			open_slot("muzzle")
			_hover_part("compensator")
		"plans":
			close_picker()
			if GameState.builds.is_empty():
				GameState.save_plan("安靜清道夫", plan)
				GameState.save_plan("鴨鴨大砲", {"frame": "duck_launcher", "parts": {"sight": "red_dot", "magazine": "extended_mag", "gadget": "lucky_cat"}})
				GameState.save_plan("窮人左輪", {"frame": "revolver", "parts": {"underbarrel": "flashlight"}})
			_set_tab("plans")
		"frames":
			select_frame("railgun")
			_set_tab("frames")
		"boosts":
			_set_tab("boosts")


# --- Bench logic --------------------------------------------------------------------------

## Each piece of the plan: [id, "equipped" | "stash" | "buy"].
func _plan_pieces() -> Array:
	var available := {}
	var on_gun := {}
	for id in Arsenal.ids(_loadout.build):
		on_gun[id] = on_gun.get(id, 0) + 1
	var result := []
	for id in Arsenal.ids(plan):
		if on_gun.get(id, 0) > 0:
			on_gun[id] -= 1
			result.append([id, "equipped"])
			continue
		available[id] = available.get(id, 0) + 1
		if Arsenal.price_of(id) == 0 or available[id] <= GameState.owned(id):
			result.append([id, "stash"])
		else:
			result.append([id, "buy"])
	return result


## How many of a piece you have to build with: in the stash plus on the equipped gun.
func _have(id: String) -> int:
	var count := GameState.owned(id)
	for piece in Arsenal.ids(_loadout.build):
		if piece == id:
			count += 1
	return count


func _is_equipped_plan() -> bool:
	return Arsenal.clean(_loadout.build) == Arsenal.clean(plan)


func _set_tab(tab: String) -> void:
	_tab = tab
	_refresh_list()


func _hover_part(part_id: String) -> void:
	if _open_slot == "":
		return
	var parts: Dictionary = plan.parts.duplicate()
	if part_id == "":
		parts.erase(_open_slot)
	else:
		parts[_open_slot] = part_id
	_hover = {"frame": plan.frame, "parts": parts}
	_refresh_stats()
	if part_id == "":
		_info.text = "把%s的零件拆掉（放回倉庫）。" % Arsenal.SLOT_NAMES[_open_slot]
	else:
		var p := Arsenal.part(part_id)
		_info.text = "%s　%s" % [p.name, p.desc]


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragged = true
		if _picker.visible:
			close_picker()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged = true
		_yaw += event.relative.x * 0.6
		_pitch = clampf(_pitch + event.relative.y * 0.4, -60.0, 70.0)


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_spin_time += delta
	var yaw := _yaw
	if not _dragged:
		yaw = -90.0 + sin(_spin_time * 0.45) * 38.0
		_yaw = yaw
	_pivot.rotation_degrees = Vector3(_pitch, yaw, 0)
	_lines.queue_redraw()


## Leader lines from each slot button to where its part sits on the turning gun.
func _draw_lines() -> void:
	if _model == null or not is_instance_valid(_model) or not _model.is_inside_tree():
		return
	var spots: Dictionary = _model.get_meta("slots", {})
	var shrink := float(_view_container.stretch_shrink)
	for slot: String in _slot_buttons:
		var button: Button = _slot_buttons[slot]
		if not button.visible or not spots.has(slot) or (_picker.visible and slot != _open_slot):
			continue
		var world: Vector3 = _model.global_transform * (spots[slot] as Vector3)
		if _camera.is_position_behind(world):
			continue
		var target := _camera.unproject_position(world) * shrink
		var rect := Rect2(button.position, button.size)
		var start := Vector2(clampf(target.x, rect.position.x, rect.end.x), clampf(target.y, rect.position.y, rect.end.y))
		var filled: bool = plan.parts.has(slot)
		var color := Color(UiKit.HOT, 0.9) if slot == _open_slot else (Color(UiKit.ACCENT, 0.55) if filled else Color(UiKit.DIM, 0.35))
		_lines.draw_line(start, target, color, 2.0 if filled else 1.0)
		_lines.draw_rect(Rect2(target - Vector2(3, 3), Vector2(6, 6)), color)


func _rebuild_model() -> void:
	if _pivot == null:
		return
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = GunModels.build(plan)
	var box := AABB()
	var first := true
	for child in _model.get_children():
		if child is MeshInstance3D:
			var mesh_box: AABB = child.transform * (child as MeshInstance3D).get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
	_model.position = -box.get_center()
	_pivot.add_child(_model)
	# Fit the longest side, a little smaller than the frame so the slot buttons have room.
	var longest := maxf(box.size.z, maxf(box.size.y * 1.6, 0.28))
	_camera.position = Vector3(0, 0.0, longest * 1.75 + 0.1)


# --- Refresh ------------------------------------------------------------------------------

func _refresh() -> void:
	_money_label.text = "$%d" % GameState.money
	_stats_label.text = "撤離 %d 次　死亡 %d 次　最高收穫 $%d" % [GameState.extractions, GameState.deaths, GameState.best_haul]
	var f := Arsenal.frame(plan.frame)
	_gun_name.text = f.name
	_gun_desc.text = f.desc
	if _info.text == "":
		_info.text = "點槍身周圍的槍位換零件。改裝是免費試的，按「裝備」才會花錢。"
	_refresh_list()
	_refresh_slots()
	_refresh_stats()
	_refresh_cost()
	if _picker.visible:
		_fill_picker()


func _refresh_list() -> void:
	for id in _tab_buttons:
		UiKit.style_button(_tab_buttons[id], "selected" if id == _tab else "normal")
	(_tab_buttons.plans as Button).text = "方案 %d/%d" % [GameState.builds.size(), GameState.MAX_BUILDS]
	(_tab_buttons.boosts as Button).text = "強化 %d/%d" % [_loadout.boosts.size(), Gear.MAX_BOOSTS]
	for child in _list.get_children():
		child.queue_free()
	match _tab:
		"frames": _fill_frames()
		"plans": _fill_plans()
		"boosts": _fill_boosts()


func _fill_frames() -> void:
	for id: String in Arsenal.FRAMES:
		var f := Arsenal.frame(id)
		var tag := ""
		var tag_color := UiKit.GOOD
		if f.price == 0:
			tag = "免費"
		elif _have(id) > 0:
			tag = "擁有 %d" % _have(id)
		else:
			tag = "$%d" % f.price
			tag_color = UiKit.WARN if f.price <= GameState.money else UiKit.DANGER
		var row := _row_button(f.name, tag, tag_color, func() -> void: select_frame(id))
		if id == plan.frame:
			UiKit.style_button(row, "selected")
		row.mouse_entered.connect(func() -> void: _info.text = "%s　%s" % [f.name, f.desc])
		_list.add_child(row)


func _fill_plans() -> void:
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 4)
	_plan_name_edit = UiKit.line_edit("", 14)
	_plan_name_edit.placeholder_text = "方案名稱"
	_plan_name_edit.custom_minimum_size = Vector2(0, 36)
	_plan_name_edit.add_theme_font_size_override("font_size", 15)
	_plan_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan_name_edit.text_submitted.connect(func(text: String) -> void: save_current_plan(text))
	save_row.add_child(_plan_name_edit)
	var save := UiKit.button("存目前的槍", func() -> void: save_current_plan(_plan_name_edit.text))
	save.add_theme_font_size_override("font_size", 14)
	save.focus_mode = Control.FOCUS_NONE
	save_row.add_child(save)
	_list.add_child(save_row)
	var note := "規劃不花錢。存滿 %d 個會蓋掉最舊的。" % GameState.MAX_BUILDS
	var note_label := UiKit.label(note, 13, UiKit.DIM)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note_label)
	if GameState.builds.is_empty():
		var empty := UiKit.label("還沒有方案。先在中間改好一把槍，再按「存目前的槍」。", 14, UiKit.TEXT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	for i in GameState.builds.size():
		var saved: Dictionary = GameState.builds[i]
		var build: Dictionary = saved.build
		var index := i
		var missing := _missing_cost(build)
		var tag := "全部都有" if missing == 0 else "缺 $%d" % missing
		var color := UiKit.GOOD if missing == 0 else (UiKit.WARN if missing <= GameState.money else UiKit.DANGER)
		var line := "%s\n%s +%d 件" % [saved.name, Arsenal.name_of(build.frame), build.parts.size()]
		var row := _row_button(line, tag, color, func() -> void: load_plan(index), 50)
		if Arsenal.clean(build) == Arsenal.clean(plan):
			UiKit.style_button(row, "selected")
		row.mouse_entered.connect(func() -> void: _info.text = _plan_summary(build))
		var holder := HBoxContainer.new()
		holder.add_theme_constant_override("separation", 2)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(row)
		var remove := UiKit.button("✕", func() -> void: delete_plan(index))
		remove.focus_mode = Control.FOCUS_NONE
		remove.custom_minimum_size = Vector2(28, 0)
		remove.add_theme_font_size_override("font_size", 14)
		remove.tooltip_text = "刪除這個方案"
		holder.add_child(remove)
		_list.add_child(holder)


func _fill_boosts() -> void:
	var note := UiKit.label("強化每局最多帶 %d 個，和槍一樣死掉就沒了。" % Gear.MAX_BOOSTS, 13, UiKit.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)
	for id: String in Gear.ITEMS:
		var info := Gear.info(id)
		if info.slot != "boost":
			continue
		var tag := ""
		var color := UiKit.GOOD
		var equipped: bool = id in _loadout.boosts
		if equipped:
			tag = "✓ 帶著"
		elif GameState.owned(id) > 0:
			tag = "擁有 %d" % GameState.owned(id)
		else:
			tag = "$%d" % info.price
			color = UiKit.WARN if info.price <= GameState.money else UiKit.DANGER
		var row := _row_button(info.name, tag, color, func() -> void: _toggle_boost(id))
		if equipped:
			UiKit.style_button(row, "selected")
		row.mouse_entered.connect(func() -> void: _info.text = "%s　$%d・%.1fkg　%s" % [info.name, info.price, info.weight, info.desc])
		_list.add_child(row)


## A list row: text on the left, a coloured tag (owned / price) on the right.
func _row_button(text: String, tag: String, tag_color: Color, on_pressed: Callable, height := 34) -> Button:
	var row := UiKit.button("", on_pressed)
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, height)
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -8
	var main := UiKit.label(text, 15, UiKit.TEXT)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if "\n" in text:
		main.add_theme_font_size_override("font_size", 14)
		main.add_theme_constant_override("line_spacing", -4)
	box.add_child(main)
	var tag_label := UiKit.label(tag, 14, tag_color)
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag_label)
	return row


func _refresh_slots() -> void:
	var f := Arsenal.frame(plan.frame)
	var pieces := {}
	for item: Array in _plan_pieces():
		pieces[item[0]] = item[1]
	for slot: String in Arsenal.SLOTS:
		var button: Button = _slot_buttons[slot]
		button.visible = slot in f.slots
		if not button.visible:
			continue
		var part_id: String = plan.parts.get(slot, "")
		var part_label: Label = button.find_child("Part", true, false)
		var tag: Label = button.find_child("Tag", true, false)
		if part_id == "":
			part_label.text = "＋ 空"
			part_label.add_theme_color_override("font_color", UiKit.DIM)
			tag.text = "%d 種" % Arsenal.parts_for(plan.frame, slot).size()
			tag.add_theme_color_override("font_color", UiKit.DIM)
		else:
			part_label.text = Arsenal.name_of(part_id)
			part_label.add_theme_color_override("font_color", UiKit.TEXT)
			match pieces.get(part_id, "stash"):
				"buy":
					tag.text = "$%d" % Arsenal.price_of(part_id)
					tag.add_theme_color_override("font_color", UiKit.WARN)
				"equipped":
					tag.text = "裝著"
					tag.add_theme_color_override("font_color", UiKit.GOOD)
				_:
					tag.text = "擁有"
					tag.add_theme_color_override("font_color", UiKit.GOOD)
		var state := "normal"
		if slot == _open_slot:
			state = "loud"
		elif part_id != "":
			state = "selected"
		UiKit.style_button(button, state)
		if slot == _open_slot:
			(button.get_theme_stylebox("normal") as StyleBoxFlat).border_color = UiKit.HOT
			(button.get_theme_stylebox("normal") as StyleBoxFlat).border_width_left = 6


func _fill_picker() -> void:
	for child in _picker_list.get_children():
		child.queue_free()
	var slot := _open_slot
	_picker_title.text = "%s：選一個零件" % Arsenal.SLOT_NAMES[slot]
	var current: String = plan.parts.get(slot, "")
	var options: Array[String] = [""]
	options.append_array(Arsenal.parts_for(plan.frame, slot))
	var scroll: ScrollContainer = _picker.find_child("Scroll", true, false)
	scroll.custom_minimum_size.y = minf(36 + 50 * (options.size() - 1), _preview.size.y * 0.78 - 50)
	_picker.size.y = 0
	for part_id: String in options:
		var id := part_id
		var row := UiKit.button("", func() -> void: set_part(slot, id); close_picker())
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 46 if id != "" else 32)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_right = -8
		box.offset_top = 2
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
		var label_text := "（拆掉，留空）" if id == "" else Arsenal.name_of(id)
		if id == current:
			label_text = "✓ " + label_text
		var name_label := UiKit.label(label_text, 16, UiKit.ACCENT if id == current else UiKit.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(name_label)
		if id != "":
			var have := _have(id)
			var tag_text := "擁有 %d" % have if have > 0 else "$%d" % Arsenal.price_of(id)
			var tag_color := UiKit.GOOD if have > 0 else (UiKit.WARN if Arsenal.price_of(id) <= GameState.money else UiKit.DANGER)
			var tag := UiKit.label(tag_text, 14, tag_color)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(tag)
			var parts: Dictionary = plan.parts.duplicate()
			parts[slot] = id
			var changes := _rich(13)
			changes.text = _change_line(plan, {"frame": plan.frame, "parts": parts})
			changes.autowrap_mode = TextServer.AUTOWRAP_OFF
			box.add_child(changes)
		if id == current:
			UiKit.style_button(row, "selected")
		row.mouse_entered.connect(func() -> void: _hover_part(id))
		row.mouse_exited.connect(func() -> void:
			_hover = {}
			_refresh_stats())
		_picker_list.add_child(row)


func _refresh_stats() -> void:
	var shown: Dictionary = _hover if not _hover.is_empty() else plan
	var base: Dictionary = plan if not _hover.is_empty() else _loadout.build
	var s := Arsenal.stats(shown)
	var b := Arsenal.stats(base)
	for row: Array in STAT_ROWS:
		var stat: String = row[0]
		(_stat_values[stat] as Label).text = _format(stat, s)
		var delta: Label = _stat_deltas[stat]
		var diff: float = float(s[stat]) - float(b[stat])
		if stat == "damage":
			diff = float(s.damage) * s.pellets - float(b.damage) * b.pellets
		if absf(diff) < 0.05:
			delta.text = ""
			continue
		delta.text = _format_delta(stat, diff)
		var better: int = row[2]
		var good := (diff > 0.0) == (better > 0)
		delta.add_theme_color_override("font_color", UiKit.DIM if better == 0 else (UiKit.GOOD if good else UiKit.DANGER))
	var lines := ["[color=#%s]%s・%s[/color]" % [UiKit.DIM.to_html(false), KIND_NAMES.get(s.kind, s.kind), "全自動" if s.auto else "半自動"]]
	var effects := _effect_names(s.effects)
	var old := _effect_names(b.effects)
	var shown_effects := []
	for e: String in effects:
		shown_effects.append(e if e in old else "[color=#%s]+%s[/color]" % [UiKit.GOOD.to_html(false), e])
	for e: String in old:
		if not e in effects:
			shown_effects.append("[color=#%s][s]%s[/s][/color]" % [UiKit.DANGER.to_html(false), e])
	if not shown_effects.is_empty():
		lines.append("[color=#%s]效果[/color]　" % UiKit.ACCENT.to_html(false) + "、".join(shown_effects))
	_effects.text = "\n".join(lines)
	var compare := "綠／紅＝換上這個零件後的變化" if not _hover.is_empty() else "綠／紅＝跟目前裝備的槍比"
	_effects.text += "\n[color=#%s][font_size=12]%s[/font_size][/color]" % [UiKit.DIM.to_html(false), compare]


func _refresh_cost() -> void:
	var pieces := _plan_pieces()
	var cost := plan_cost()
	var lines := []
	var owned_names := []
	var buy_names := []
	for item: Array in pieces:
		var id: String = item[0]
		if item[1] == "buy":
			buy_names.append("%s [color=#%s]$%d[/color]" % [Arsenal.name_of(id), UiKit.WARN.to_html(false), Arsenal.price_of(id)])
		else:
			owned_names.append(Arsenal.name_of(id))
	if not owned_names.is_empty():
		lines.append("[color=#%s]已有：[/color]%s" % [UiKit.GOOD.to_html(false), "、".join(owned_names)])
	if not buy_names.is_empty():
		lines.append("[color=#%s]要買：[/color]%s" % [UiKit.WARN.to_html(false), "、".join(buy_names)])
	_cost_detail.text = "\n".join(lines)
	if _is_equipped_plan():
		_cost_title.text = "這把就是目前裝備的槍"
		_cost_title.add_theme_color_override("font_color", UiKit.GOOD)
		_equip.text = "✓ 已裝備"
		_equip.disabled = true
	else:
		_equip.disabled = false
		if cost == 0:
			_cost_title.text = "零件都有，不用花錢"
			_cost_title.add_theme_color_override("font_color", UiKit.GOOD)
			_equip.text = "裝備（免費）"
		else:
			_cost_title.text = "裝備要花 $%d" % cost
			_cost_title.add_theme_color_override("font_color", UiKit.WARN if cost <= GameState.money else UiKit.DANGER)
			_equip.text = "買齊並裝備（$%d）" % cost if cost <= GameState.money else "錢不夠（差 $%d）" % (cost - GameState.money)
		UiKit.style_button(_equip, "primary" if cost <= GameState.money else "locked")
	var equipped_build: Dictionary = _loadout.build
	_equipped_label.text = "目前裝備：%s%s" % [Arsenal.name_of(equipped_build.frame),
			"" if equipped_build.parts.is_empty() else " +%d 件" % equipped_build.parts.size()]
	var boost_names := []
	for id in _loadout.boosts:
		boost_names.append(Gear.info(id).name)
	_carry_label.text = "這次帶：%s%s　強化：%s" % [Arsenal.name_of(equipped_build.frame),
			"" if equipped_build.parts.is_empty() else " +%d 件" % equipped_build.parts.size(),
			"無" if boost_names.is_empty() else "、".join(boost_names)]


# --- Formatting ---------------------------------------------------------------------------

static func _format(stat: String, s: Dictionary) -> String:
	match stat:
		"damage": return "%d" % roundi(s.damage) + ("×%d" % s.pellets if s.pellets > 1 else "")
		"rate": return "%.1f 發/秒" % s.rate
		"mag", "reserve": return "%d" % s[stat]
		"reload": return "%.1f 秒" % s.reload
		"spread": return "%.1f°" % s.spread
		"range", "noise": return "%d m" % roundi(s[stat])
		"recoil": return "%.1f" % s.recoil
		"zoom": return "×%.1f" % s.zoom
		"weight": return "%.1f kg" % s.weight
	return str(s.get(stat, ""))


static func _format_delta(stat: String, diff: float) -> String:
	var sign := "+" if diff > 0.0 else "−"
	var v := absf(diff)
	match stat:
		"mag", "reserve", "range", "noise", "damage": return "%s%d" % [sign, roundi(v)]
		"zoom": return "%s%.1f" % [sign, v]
	return "%s%.1f" % [sign, v]


## A one-line summary of what changes from build a to build b, in percent.
static func _change_line(a: Dictionary, b: Dictionary) -> String:
	var sa := Arsenal.stats(a)
	var sb := Arsenal.stats(b)
	var parts := []
	for row: Array in STAT_ROWS:
		var stat: String = row[0]
		var va := float(sa[stat])
		var vb := float(sb[stat])
		if absf(va - vb) < 0.001 or row[2] == 0 and stat != "zoom":
			continue
		var text := ""
		if stat == "zoom":
			text = "倍率×%.1f" % vb
		elif stat == "weight":
			text = "重量%+.1fkg" % (vb - va)
		else:
			text = "%s%+d%%" % [row[1], roundi((vb - va) / maxf(absf(va), 0.001) * 100.0)]
		var good: bool = (vb > va) == (row[2] > 0)
		var color := UiKit.DIM if row[2] == 0 else (UiKit.GOOD if good else UiKit.DANGER)
		parts.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	var old := _effect_names(sa.effects)
	for e: String in _effect_names(sb.effects):
		if not e in old:
			parts.append("[color=#%s]+%s[/color]" % [UiKit.COLD.to_html(false), e])
	if parts.is_empty():
		return "[color=#%s]數據不變[/color]" % UiKit.DIM.to_html(false)
	return "  ".join(parts)


## Effects in Chinese, for the stats panel.
static func _effect_names(effects: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for effect: String in effects:
		var v = effects[effect]
		match effect:
			"stun": names.append("麻痺 %.1f 秒" % v)
			"slow": names.append("減速 %.1f 秒" % v)
			"burn": names.append("燃燒 %.1f 秒" % v)
			"pierce": names.append("貫穿")
			"knock": names.append(("擊退 %.1fm" if v > 0 else "往你拖 %.1fm") % absf(v))
			"explode": names.append("爆炸 %.1fm" % v)
			"chain": names.append("連鎖 +%d" % v)
			"lure": names.append("引怪")
			"reveal": names.append("逼出隱形")
			"bubble": names.append("泡泡 %d 秒" % roundi(v))
			"thermal": names.append("熱成像")
			"light": names.append("槍燈")
			"bayonet": names.append("刺刀")
			"soft": names.append("空尖（小怪痛）")
			"armor": names.append("穿甲（大怪痛）")
			"leech": names.append("吸血 %d%%" % roundi(v * 100.0))
			"ghost": names.append("每 %d 發免彈" % v)
			"bounty": names.append("殺怪掉寶")
			_: names.append(effect)
	return names


func _missing_cost(build: Dictionary) -> int:
	var cost := 0
	for id: String in _missing_pieces(build):
		cost += Arsenal.price_of(id)
	return cost


## The pieces of a build you would have to buy to equip it.
func _missing_pieces(build: Dictionary) -> Array[String]:
	var saved_plan := plan
	plan = Arsenal.clean(build)
	var result: Array[String] = []
	for item: Array in _plan_pieces():
		if item[1] == "buy":
			result.append(item[0])
	plan = saved_plan
	return result


func _plan_summary(build: Dictionary) -> String:
	var names := []
	for slot: String in Arsenal.SLOTS:
		if build.parts.has(slot):
			names.append(Arsenal.name_of(build.parts[slot]))
	var text := "%s：%s" % [Arsenal.name_of(build.frame), "沒有改裝" if names.is_empty() else "、".join(names)]
	var missing := []
	for id: String in _missing_pieces(build):
		missing.append("%s $%d" % [Arsenal.name_of(id), Arsenal.price_of(id)])
	text += "\n" + ("零件全部都有，點一下載入。" if missing.is_empty() else "缺：" + "、".join(missing) + "（點一下載入）")
	return text


func _describe_slot(slot: String) -> void:
	var part_id: String = plan.parts.get(slot, "")
	if part_id == "":
		_info.text = "%s：空的。點一下看能裝什麼（%d 種）。" % [Arsenal.SLOT_NAMES[slot], Arsenal.parts_for(plan.frame, slot).size()]
	else:
		_info.text = "%s：%s。%s" % [Arsenal.SLOT_NAMES[slot], Arsenal.name_of(part_id), Arsenal.part(part_id).desc]


# --- Boosts, names, joining ---------------------------------------------------------------

func _toggle_boost(id: String) -> void:
	var info := Gear.info(id)
	if id in _loadout.boosts:
		_loadout.boosts.erase(id)
		GameState.give_back(id)
	else:
		if _loadout.boosts.size() >= Gear.MAX_BOOSTS:
			show_status("強化最多帶 %d 個" % Gear.MAX_BOOSTS)
			return
		if not GameState.take(id):
			show_status("錢不夠買「%s」" % info.name)
			return
		_loadout.boosts.append(id)
	show_status("")
	GameState.save_game()
	_refresh()


func _join() -> void:
	_commit_name()
	last_address = _address_edit.text.strip_edges()
	join_requested.emit(last_address)


func _commit_name() -> void:
	var entered := _name_edit.text.strip_edges()
	if Session.instance != null and entered != "":
		Session.instance.local_name = entered.substr(0, 16)


func _flash(target: Control) -> void:
	if not is_inside_tree():
		return
	target.modulate = Color(2, 2, 2)
	create_tween().tween_property(target, "modulate", Color.WHITE, 0.35)
