class_name LoadoutScreen
extends Control
## The stash (倉庫) as a gunsmith bench, Tarkov style, in four columns:
##   frames:  tabs for weapon frames (槍身, grouped 手槍 / 衝鋒槍 / 步槍 / 霰彈槍 / 怪東西),
##            saved plans (方案) and boosts (強化)
##   slots:   the build's slot tree (槍位) in the four SLOT_GROUPS, child slots indented under
##            the part that opened them, tuning sliders under tunable parts, and what more
##            slots the frame could still get; 隨機改裝 and 拆光 below
##   bench:   the build turning on the bench (drag to rotate), then the part picker for the
##            chosen slot (every fitting part, owned / price, what it changes) and a detail
##            box (the hovered part's description, slots it opens or blocks, calibre change
##            and which parts would come off)
##   numbers: every stat as a bar with its number and the change (green better / red worse),
##            the effects as tags, what equipping costs and the equip button
##   bottom:  name, back, multiplayer, and 單人出發
## Planning is free: the build on the bench is only a plan until 裝備 pays for the
## missing pieces (GameState.equip_build). Plans can be saved and loaded (GameState.builds).

signal solo_requested()
signal host_requested()
signal join_requested(address: String)
signal back_requested()

## Remembered across visits to the screen.
static var last_address := "127.0.0.1"

## Frame categories in the frame list, see frame_group().
const FRAME_GROUPS := [["pistol", "手槍"], ["smg", "衝鋒槍"], ["rifle", "步槍"], ["shotgun", "霰彈槍"], ["odd", "怪東西"]]
## Stats panel rows: stat, label, bar full at (0 = a text row without a bar).
## "damage" compares the whole shot (damage × pellets).
const STAT_ROWS := [
	["damage", "傷害", 150.0], ["pellets", "彈丸", 18.0], ["rate", "射速", 16.0], ["modes", "射擊模式", 0.0],
	["mag", "彈匣/備彈", 100.0], ["reload", "換彈", 6.0], ["spread", "腰射散佈", 10.0], ["moa", "瞄準精度", 10.0],
	["recoil", "垂直後座", 10.0], ["recoil_h", "水平後座", 3.0], ["ergo", "人體工學", 100.0], ["aim_time", "舉槍時間", 0.8],
	["sway", "晃動", 1.2], ["velocity", "初速", 1200.0], ["pen", "穿透", 100.0], ["range", "射程/衰減", 150.0],
	["noise", "噪音", 90.0], ["flash", "火光", 100.0], ["reliability", "可靠度/卡彈", 100.0], ["heat", "發熱/散熱", 0.6],
	["zoom", "瞄準倍率", 3.6], ["weight", "重量", 14.0], ["length", "長度", 150.0], ["caliber", "口徑", 0.0],
	["sound", "消音/音速", 0.0],
]
## Stats where less is better (everything else numeric: more is better).
const LOWER_BETTER := ["spread", "aim_spread", "moa", "recoil", "recoil_h", "noise", "flash", "reload", "aim_time",
	"sway", "jam", "weight", "heat", "length"]
## Stats that are neither better nor worse.
const NEUTRAL := ["zoom", "pellets"]
## Decimals a stat's change is shown (and judged) with.
const DECIMALS := {
	"damage": 0, "pellets": 0, "rate": 1, "mag": 0, "reserve": 0, "reload": 2, "spread": 2, "moa": 1, "recoil": 1,
	"recoil_h": 2, "ergo": 0, "aim_time": 2, "sway": 2, "velocity": 0, "pen": 0, "range": 0, "falloff": 0,
	"noise": 0, "flash": 0, "reliability": 0, "jam": 4, "heat": 3, "cooling": 2, "zoom": 2, "weight": 2, "length": 0,
}
## Second numbers shown in a row next to the first (彈匣/備彈...), compared when the first doesn't change.
const SECOND := {"mag": "reserve", "range": "falloff", "reliability": "jam", "heat": "cooling"}
## Short names of stats for the picker's one-line change summary.
const SHORT := {
	"damage": "傷害", "rate": "射速", "mag": "彈匣", "reserve": "備彈", "reload": "換彈", "spread": "腰射散佈",
	"moa": "MOA", "recoil": "垂直後座", "recoil_h": "水平後座", "ergo": "人體工學", "aim_time": "舉槍",
	"sway": "晃動", "velocity": "初速", "pen": "穿透", "range": "射程", "noise": "噪音", "flash": "火光",
	"reliability": "可靠度", "heat": "發熱", "cooling": "散熱", "weight": "重量", "length": "長度",
}
const KIND_NAMES := {
	"hitscan": "直射", "cone": "近距離噴射", "arc": "電弧（會跳）", "lob": "拋射（會爆）",
	"bounce": "反彈飛刃", "charge": "按住充能",
}
## Where on the model (GunModels "slots" meta) a slot's marker points.
const MODEL_SPOT := {
	"muzzle": "muzzle", "silencer": "muzzle", "barrel": "barrel", "gas": "barrel", "sight": "sight", "mount": "sight",
	"magazine": "magazine", "stock": "stock", "buttpad": "stock", "underbarrel": "underbarrel", "foregrip": "underbarrel",
	"handguard": "underbarrel", "rail_l": "underbarrel", "rail_r": "underbarrel", "ammo": "ammo", "gadget": "gadget",
}
const DEFAULT_INFO := "點中間的槍位換零件，滑過零件看數據變化。改裝是免費試的，按「裝備」才會花錢。"

## Per-frame caches (the frame data never changes while the game runs).
static var _possible_cache := {}
static var _openers_cache := {}

## The build on the bench (a plan until it is equipped). Always kept clean.
var plan: Dictionary = Arsenal.STARTER.duplicate(true):
	set(value):
		plan = Arsenal.clean(value)
## Parts the last change took off besides the one swapped: {slot: part id}. For the tests.
var last_removed := {}

var _loadout: Dictionary:
	get: return GameState.equipped
var _tab := "frames"
var _open_slot := ""
var _hover_slot := ""
var _hover := {}  # a candidate build being hovered (stats show it against the plan)

var _money_label: Label
var _stats_label: Label
var _tab_buttons := {}
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _tree: VBoxContainer
var _tree_scroll: ScrollContainer
var _tree_count: Label
var _slot_rows := {}
var _tune_sliders := {}
var _gun_name: Label
var _gun_sub: Label
var _preview: Control
var _preview_frame: PanelContainer
var _view_container: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _yaw := -90.0
var _pitch := 14.0
var _dragged := false
var _spin_time := 0.0
var _lines: Control
var _picker: PanelContainer
var _picker_list: VBoxContainer
var _picker_scroll: ScrollContainer
var _picker_title: Label
var _info: RichTextLabel
var _compare_note: Label
var _stat_rows := {}
var _effects_flow: HFlowContainer
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


## A stat bar: the shown value filled in acid, and when something is being compared the
## stretch between it and the old value in green (better) or red (worse).
class StatBar extends Control:
	var fill := 0.0
	var other := -1.0
	var better := 0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.08))
		if other < 0.0 or absf(fill - other) < 0.002:
			draw_rect(Rect2(0, 0, w * fill, h), Color(UiKit.ACCENT, 0.7))
			return
		var lo := minf(fill, other)
		var hi := maxf(fill, other)
		draw_rect(Rect2(0, 0, w * lo, h), Color(UiKit.ACCENT, 0.7))
		var color := UiKit.DIM if better == 0 else (UiKit.GOOD if better > 0 else UiKit.DANGER)
		draw_rect(Rect2(w * lo, 0, maxf(w * (hi - lo), 2.0), h), Color(color, 0.95 if fill > other else 0.45))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plan = _loadout.build
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
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	_build_left(body)
	_build_tree(body)
	_build_centre(body)
	_build_right(body)
	_build_bottom(page)

	UiKit.add_crt(self, 0.0, 0.1, 0.6)
	_rebuild_model()
	_refresh()
	_solo.grab_focus.call_deferred()


# --- Layout -----------------------------------------------------------------------------

func _build_left(body: HBoxContainer) -> void:
	var panel := UiKit.panel(8)
	panel.custom_minimum_size = Vector2(232, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	column.add_child(tabs)
	for tab: Array in [["frames", "槍身"], ["plans", "方案"], ["boosts", "強化"]]:
		var id: String = tab[0]
		var button := UiKit.button(tab[1], func() -> void: _set_tab(id))
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		_tab_buttons[id] = button
		tabs.add_child(button)
	_list_scroll = _scroll()
	column.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)


func _build_tree(body: HBoxContainer) -> void:
	var panel := UiKit.panel(8, Color(UiKit.ACCENT, 0.2))
	panel.custom_minimum_size = Vector2(268, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var head := UiKit.heading("槍位", " ")
	_tree_count = head.get_child(2) as Label
	column.add_child(head)
	_tree_scroll = _scroll()
	column.add_child(_tree_scroll)
	_tree = VBoxContainer.new()
	_tree.add_theme_constant_override("separation", 2)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_scroll.add_child(_tree)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	column.add_child(buttons)
	var dice := UiKit.button("隨機改裝", func() -> void: random_mod())
	dice.tooltip_text = "把空著的槍位隨便裝滿（只挑你有的、或買得起的零件）"
	var strip := UiKit.button("拆光", func() -> void: strip_all())
	strip.tooltip_text = "把所有零件拆下來，只剩槍身"
	for button: Button in [dice, strip]:
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		buttons.add_child(button)
	dice.size_flags_stretch_ratio = 1.6


func _build_centre(body: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	_gun_name = UiKit.title("", 26, UiKit.TEXT)
	head.add_child(_gun_name)
	_gun_sub = UiKit.label("", 13, UiKit.DIM)
	_gun_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_gun_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gun_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gun_sub.clip_text = true
	_gun_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_gun_sub)

	_preview_frame = UiKit.panel(0, Color(UiKit.ACCENT, 0.25))
	_preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_frame.custom_minimum_size = Vector2(0, 150)
	column.add_child(_preview_frame)
	_preview = Control.new()
	_preview.clip_contents = true
	_preview_frame.add_child(_preview)
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

	_build_picker(column)

	var info_panel := UiKit.panel(8)
	info_panel.custom_minimum_size = Vector2(0, 84)
	column.add_child(info_panel)
	_info = _rich(13)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _build_picker(column: VBoxContainer) -> void:
	_picker = UiKit.panel(8, UiKit.ACCENT)
	(_picker.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.03, 0.03, 0.035, 0.94)
	_picker.visible = false
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.size_flags_stretch_ratio = 2.4
	column.add_child(_picker)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	_picker.add_child(inner)
	var head := HBoxContainer.new()
	inner.add_child(head)
	_picker_title = UiKit.label("", 16, UiKit.ACCENT)
	_picker_title.add_theme_font_override("font", UiKit.bold_font())
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_title.clip_text = true
	head.add_child(_picker_title)
	var close := UiKit.button("✕ 關閉", close_picker)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 13)
	close.custom_minimum_size = Vector2(64, 26)
	head.add_child(close)
	_picker_scroll = _scroll()
	_picker_scroll.name = "Scroll"
	inner.add_child(_picker_scroll)
	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 3)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_scroll.add_child(_picker_list)


func _build_right(body: HBoxContainer) -> void:
	var panel := UiKit.panel(10, Color(UiKit.ACCENT, 0.35))
	panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var head := UiKit.heading("數據", " ")
	_compare_note = head.get_child(2) as Label
	_compare_note.add_theme_font_size_override("font_size", 12)
	_compare_note.clip_text = true
	_compare_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(head)
	var scroll := _scroll()
	column.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_effects_flow = HFlowContainer.new()
	_effects_flow.add_theme_constant_override("h_separation", 4)
	_effects_flow.add_theme_constant_override("v_separation", 3)
	inner.add_child(_effects_flow)
	for row: Array in STAT_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		inner.add_child(line)
		var name_label := UiKit.label(row[1], 13, UiKit.DIM)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_label.custom_minimum_size = Vector2(76, 0)
		line.add_child(name_label)
		var bar := StatBar.new()
		bar.custom_minimum_size = Vector2(30, 7)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = row[2] > 0.0
		line.add_child(bar)
		var value := UiKit.label("", 13, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(78, 0)
		if row[2] <= 0.0:
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(value)
		var delta := UiKit.label("", 12, UiKit.GOOD)
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		delta.custom_minimum_size = Vector2(44, 0)
		line.add_child(delta)
		_stat_rows[row[0]] = {"line": line, "bar": bar, "value": value, "delta": delta}

	column.add_child(UiKit.hazard_strip(3.0, UiKit.HOT))
	_cost_title = UiKit.label("", 16, UiKit.TEXT)
	_cost_title.add_theme_font_override("font", UiKit.bold_font())
	_cost_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_cost_title)
	_cost_detail = _rich(13)
	column.add_child(_cost_detail)
	_equip = UiKit.primary_button("", equip_plan)
	_equip.custom_minimum_size = Vector2(0, 42)
	_equip.add_theme_font_size_override("font_size", 18)
	column.add_child(_equip)
	_equipped_label = UiKit.label("", 12, UiKit.DIM)
	_equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_equipped_label.clip_text = true
	_equipped_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_equipped_label)


func _build_bottom(page: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	page.add_child(bar)
	var back := UiKit.button("← 回標題", func() -> void: back_requested.emit())
	back.add_theme_font_size_override("font_size", 15)
	back.custom_minimum_size = Vector2(96, 44)
	bar.add_child(back)
	var book := UiKit.button("怪物圖鑑", func() -> void: open_bestiary())
	book.add_theme_font_size_override("font_size", 15)
	book.add_theme_color_override("font_color", Bestiary.ORGAN)
	book.custom_minimum_size = Vector2(96, 44)
	bar.add_child(book)
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
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	middle.add_child(_status)
	_carry_label = UiKit.label("", 14, UiKit.DIM)
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_carry_label.clip_text = true
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
	label.add_theme_font_override("bold_font", UiKit.bold_font())
	label.add_theme_color_override("default_color", UiKit.TEXT)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return label


static func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


static func _left_label(text: String, size: int, color: Color) -> Label:
	var label := UiKit.label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Public actions (also what the smoke test drives) -------------------------------------

## Puts another frame on the bench, keeping every part that still fits.
func select_frame(frame_id: String) -> void:
	if not Arsenal.FRAMES.has(frame_id):
		return
	var before: Dictionary = plan.parts.duplicate()
	plan = {"frame": frame_id, "parts": plan.parts, "tune": plan.get("tune", {})}
	last_removed = _dropped(before, plan.parts, "")
	close_picker()
	_dragged = false
	_rebuild_model()
	_refresh()
	if not last_removed.is_empty():
		_tell_removed("換成%s後裝不上，先拿下來：" % Arsenal.name_of(frame_id))


## Puts a part in a slot of the plan ("" takes the slot's part off). Free: it's a plan.
## Parts that only hung on the old part (its child slots) or that no longer fit the new
## calibre come off too; last_removed says which, and the status line tells the player.
func set_part(slot: String, part_id: String) -> void:
	var parts: Dictionary = plan.parts.duplicate()
	var before := parts.duplicate()
	var old: String = parts.get(slot, "")
	if part_id == "":
		parts.erase(slot)
	else:
		parts[slot] = part_id
	plan = {"frame": plan.frame, "parts": parts, "tune": plan.tune}
	last_removed = _dropped(before, plan.parts, slot)
	_hover = {}
	_rebuild_model()
	_refresh()
	if not last_removed.is_empty():
		var what := "拆下「%s」" % Arsenal.name_of(old) if part_id == "" else "換上「%s」" % Arsenal.name_of(part_id)
		_tell_removed(what + "，連帶拿下：")
	elif part_id != "" and Arsenal.part(part_id).has("adds"):
		var opened: Array = Arsenal.part(part_id).adds.filter(func(s: String) -> bool: return s in Arsenal.open_slots(plan))
		if not opened.is_empty():
			show_status("多出槍位：" + "、".join(opened.map(func(s: String) -> String: return Arsenal.slot_name(s))), UiKit.COLD)


## Sets a tunable part's slider (-1..1, snapped to 9 steps). Free, like every plan change.
func set_tune(slot: String, value: float) -> void:
	if not Arsenal.part(plan.parts.get(slot, "")).has("tune"):
		return
	var tune: Dictionary = plan.tune.duplicate()
	tune[slot] = snappedf(clampf(value, -1.0, 1.0), 0.25)
	plan = {"frame": plan.frame, "parts": plan.parts, "tune": tune}
	var slider: HSlider = _tune_sliders.get(slot)
	if slider != null and is_instance_valid(slider) and not is_equal_approx(slider.value, tune[slot]):
		slider.set_value_no_signal(tune[slot])
	if slider != null and is_instance_valid(slider):
		(slider.get_meta("value_label") as Label).text = _tune_text(tune[slot])
	_refresh_stats()
	_refresh_cost()
	if _tab == "plans":
		_refresh_list()


## Fills every empty open slot with a random part you own (free) or can afford, never one
## that would knock another part off. Tunable parts get a random setting. Returns how many
## parts went on. `seed_value` >= 0 makes it repeatable (tests).
func random_mod(seed_value := -1) -> int:
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var build: Dictionary = plan.duplicate(true)
	var added := 0
	for _pass in 5:
		var changed := false
		for slot: String in Arsenal.open_slots(build):
			if build.parts.has(slot):
				continue
			var options: Array[String] = []
			for id: String in Arsenal.parts_for(build, slot):
				var trial: Dictionary = build.duplicate(true)
				trial.parts[slot] = id
				trial = Arsenal.clean(trial)
				if trial.parts.size() != build.parts.size() + 1:
					continue  # it would knock something off (a calibre change)
				var pieces := _pieces_of(trial)
				if pieces.any(func(item: Array) -> bool: return item[1] == "missing"):
					continue
				if _cost_of(trial) > GameState.money:
					continue
				options.append(id)
			if options.is_empty():
				continue
			var pick: String = options[rng.randi() % options.size()]
			build.parts[slot] = pick
			if Arsenal.part(pick).has("tune"):
				build.tune[slot] = rng.randi_range(-4, 4) * 0.25
			build = Arsenal.clean(build)
			added += 1
			changed = true
		if not changed:
			break
	plan = build
	last_removed = {}
	close_picker()
	_rebuild_model()
	_refresh()
	if added == 0:
		show_status("沒有空槍位能裝了（或是錢不夠）", UiKit.WARN)
	else:
		var cost := plan_cost()
		show_status("隨機裝上 %d 件零件%s" % [added, "，全部都是你有的" if cost == 0 else "，裝備要花 $%d" % cost], UiKit.COLD)
	return added


## Takes every part off the plan, leaving the bare frame.
func strip_all() -> void:
	var count: int = plan.parts.size()
	plan = {"frame": plan.frame, "parts": {}, "tune": {}}
	last_removed = {}
	close_picker()
	_rebuild_model()
	_refresh()
	show_status("拆下 %d 件零件，只剩槍身" % count if count > 0 else "已經是光禿禿的槍身了", UiKit.COLD)


## Pays for the missing pieces and makes the plan the gun you carry in.
func equip_plan() -> bool:
	if _is_equipped_plan():
		show_status("")
		return true
	var cost := plan_cost()
	var lacking := missing_organs()
	if not lacking.is_empty():
		show_status("缺器官：%s（要從怪物身上取得）" % "、".join(lacking.map(func(id: String) -> String: return Arsenal.name_of(id))))
		return false
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
	plan = GameState.builds[index].build
	last_removed = {}
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


## Opens the parts picker for one open slot of the plan (again: closes it).
func open_slot(slot: String) -> void:
	if not slot in Arsenal.open_slots(plan):
		return
	if _open_slot == slot and _picker.visible:
		close_picker()
		return
	_open_slot = slot
	_hover = {}
	_picker.visible = true
	_fill_picker()
	_refresh_tree_styles()
	_describe_slot(slot)
	_refresh_stats()


func close_picker() -> void:
	_open_slot = ""
	_hover = {}
	if _info != null:
		_info.text = _default_info()
	if _picker != null:
		_picker.visible = false
		_refresh_tree_styles()
		_refresh_stats()


## Money still needed to equip the plan. Pieces on the equipped gun count as owned,
## since equipping hands them back to the stash first. A part used twice needs two.
func plan_cost() -> int:
	return _cost_of(plan)


func show_status(text: String, color := UiKit.DANGER) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_status.tooltip_text = text
	if text != "" and is_inside_tree():
		_status.modulate.a = 0.0
		create_tween().tween_property(_status, "modulate:a", 1.0, 0.2)


## From the title screen's 多人連線: put the cursor in the address box.
func focus_multiplayer() -> void:
	if _address_edit == null:
		return
	_address_edit.grab_focus.call_deferred()
	_address_edit.select_all.call_deferred()


## The deep carbine the screenshots and tests use: tuned gas, stock and scope, two rail
## accessories (two flashlights: needs two owned), a quick-detach can on a flash hider.
const DEEP_CARBINE := {"frame": "carbine", "parts": {
	"receiver": "upper_billet", "barrel": "fluted_barrel", "muzzle": "flash_hider", "silencer": "can_light",
	"gas": "adjustable_gas", "handguard": "quad_rail", "rail_l": "flashlight", "rail_r": "flashlight",
	"foregrip": "angled_grip", "underbarrel": "bayonet", "mount": "canted_dot", "sight": "variable_scope",
	"grip": "stippled_grip", "trigger": "match_trigger", "bolt": "nickel_bolt", "charging": "ambi_charging",
	"magazine": "polymer_mag", "ammo": "api_rounds", "stock": "adjustable_stock", "buttpad": "cheek_riser",
	"gadget": "oil_can"}, "tune": {"gas": -0.5, "sight": 0.75, "stock": 0.25, "trigger": -0.25}}


## For tools/loadout_shot.gd and tools/bench_shots.gd: puts the bench in a named state.
func shot_state(state: String) -> void:
	match state:
		"modded_smg":
			plan = {"frame": "smg", "parts": {"muzzle": "suppressor", "sight": "red_dot", "magazine": "drum_mag",
				"stock": "light_stock", "rail_l": "flashlight", "ammo": "hollow_point", "gadget": "vampire_charm"}}
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
				GameState.save_plan("窮人左輪", {"frame": "revolver", "parts": {"rail_l": "flashlight"}})
				GameState.save_plan("滿配卡賓", DEEP_CARBINE)
			_set_tab("plans")
		"frames":
			select_frame("railgun")
			_set_tab("frames")
		"frame_list":
			close_picker()
			_set_tab("frames")
			select_frame("carbine")
			_hover_frame("pdw")
		"deep_carbine":
			GameState.stash["flashlight"] = 1
			GameState.stash["carbine"] = 1
			GameState.stash["quad_rail"] = 1
			plan = DEEP_CARBINE
			select_frame("carbine")
			_set_tab("frames")
			scroll_tree_to("gas")
		"deep_tuned":
			set_tune("gas", 0.75)
			scroll_tree_to("stock")
		"receiver_picker":
			open_slot("receiver")
			_hover_part("upper_pcc")
		"handguard_picker":
			open_slot("handguard")
			_hover_part("short_handguard")
			scroll_tree_to("handguard")
		"rail_picker":
			open_slot("rail_r")
			_hover_part("combo_light")
		"boosts":
			_set_tab("boosts")


## Scrolls the slot tree so this slot's row is in view.
func scroll_tree_to(slot: String) -> void:
	var row: Control = _slot_rows.get(slot)
	if row == null:
		return
	# After the tree has been laid out (it was probably just rebuilt).
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(row) and is_instance_valid(_tree_scroll):
			_tree_scroll.scroll_vertical = maxi(0, int(row.position.y) - 30))


# --- Bench logic --------------------------------------------------------------------------

## Organs the plan uses that you don't have (they only come out of monsters).
func missing_organs() -> Array[String]:
	var result: Array[String] = []
	for item: Array in _plan_pieces():
		if item[1] == "missing":
			result.append(item[0])
	return result


## Opens the 怪物圖鑑 over the bench.
func open_bestiary() -> Bestiary:
	close_picker()
	var book := Bestiary.new()
	book.name = "Bestiary"
	add_child(book)
	return book


## For the screenshot tool: scroll the open bestiary (0 top, 1 bottom).
func bestiary_scroll(fraction: float) -> void:
	var book := get_node_or_null("Bestiary") as Bestiary
	if book != null:
		book.scroll_to(fraction)


## Which category a frame is listed under: pistol, smg, rifle, shotgun or odd.
static func frame_group(frame_id: String) -> String:
	var f := Arsenal.frame(frame_id)
	var tags: Array = f.get("tags", [])
	var family: String = Arsenal.CALIBERS.get(f.get("cal", Arsenal.DEFAULTS.cal), {}).get("family", "odd")
	if not "gun" in tags or family == "odd":
		return "odd"
	if "pellet" in tags or family == "shell":
		return "shotgun"
	if "pistol_frame" in tags or "revolver" in tags:
		return "pistol"
	if family == "pistol":
		return "smg"
	return "rifle"


static func possible_slots(frame_id: String) -> Array[String]:
	if not _possible_cache.has(frame_id):
		_possible_cache[frame_id] = Arsenal.possible_slots(frame_id)
	return _possible_cache[frame_id]


## For each slot of this frame that only a part opens: the names of the slots whose
## parts open it ({"silencer": ["槍口"], "rail_l": ["護木"]}).
static func slot_openers(frame_id: String) -> Dictionary:
	if _openers_cache.has(frame_id):
		return _openers_cache[frame_id]
	var result := {}
	var possible := possible_slots(frame_id)
	for id: String in Arsenal.PARTS:
		var p := Arsenal.part(id)
		if not p.has("adds") or not Arsenal.fits(frame_id, id) or (p.has("frames") and not frame_id in p.frames):
			continue
		var holder := Arsenal.slot_name(p.slot)
		var holder_open := false
		for slot: String in possible:
			if Arsenal.slot_type(slot) == p.slot:
				holder_open = true
		if not holder_open:
			continue
		for added: String in p.adds:
			if not result.has(added):
				result[added] = []
			if not holder in result[added]:
				result[added].append(holder)
	_openers_cache[frame_id] = result
	return result


## Each piece of the plan: [id, "equipped" | "stash" | "buy" | "missing" (an organ you lack), slot].
func _plan_pieces() -> Array:
	return _pieces_of(plan)


## The same for any build. The same part twice needs two of it: the second one counts
## against what is left after the first.
func _pieces_of(build: Dictionary) -> Array:
	var available := {}
	var on_gun := {}
	for id in Arsenal.ids(_loadout.build):
		on_gun[id] = on_gun.get(id, 0) + 1
	var entries := [[build.frame, ""]]
	for slot: String in Arsenal.SLOTS:
		if build.parts.has(slot):
			entries.append([build.parts[slot], slot])
	var result := []
	for entry: Array in entries:
		var id: String = entry[0]
		if on_gun.get(id, 0) > 0:
			on_gun[id] -= 1
			result.append([id, "equipped", entry[1]])
			continue
		available[id] = available.get(id, 0) + 1
		if Arsenal.is_organ(id):
			result.append([id, "stash" if available[id] <= GameState.owned(id) else "missing", entry[1]])
		elif Arsenal.price_of(id) == 0 or available[id] <= GameState.owned(id):
			result.append([id, "stash", entry[1]])
		else:
			result.append([id, "buy", entry[1]])
	return result


func _cost_of(build: Dictionary) -> int:
	var cost := 0
	for item: Array in _pieces_of(build):
		if item[1] == "buy":
			cost += GameState.price_of(item[0])
	return cost


## How many of a piece you have to build with: in the stash plus on the equipped gun.
func _have(id: String) -> int:
	var count := GameState.owned(id)
	for piece in Arsenal.ids(_loadout.build):
		if piece == id:
			count += 1
	return count


## How many of a part are still free for this slot (owned minus what other slots of the plan use).
func _free_count(id: String, slot: String) -> int:
	var used := 0
	for other: String in plan.parts:
		if other != slot and plan.parts[other] == id:
			used += 1
	return _have(id) - used


## Parts in `before` that are gone (or changed) in `after`, other than in `except`.
static func _dropped(before: Dictionary, after: Dictionary, except: String) -> Dictionary:
	var result := {}
	for slot: String in Arsenal.SLOTS:
		if slot != except and before.has(slot) and after.get(slot, "") != before[slot]:
			result[slot] = before[slot]
	return result


func _tell_removed(lead: String) -> void:
	var names := []
	for slot: String in last_removed:
		names.append("%s「%s」" % [Arsenal.slot_name(slot), Arsenal.name_of(last_removed[slot])])
	var text: String = lead + "、".join(names)
	show_status(text, UiKit.WARN)
	_info.text = "[color=#%s]%s[/color]" % [UiKit.WARN.to_html(false), text]


func _is_equipped_plan() -> bool:
	return Arsenal.clean(_loadout.build) == Arsenal.clean(plan)


func _set_tab(tab: String) -> void:
	_tab = tab
	_refresh_list()


## The plan with one slot swapped (what hovering a part in the picker shows).
func _with_part(slot: String, part_id: String) -> Dictionary:
	var parts: Dictionary = plan.parts.duplicate()
	if part_id == "":
		parts.erase(slot)
	else:
		parts[slot] = part_id
	return Arsenal.clean({"frame": plan.frame, "parts": parts, "tune": plan.tune})


func _hover_part(part_id: String) -> void:
	if _open_slot == "":
		return
	var slot := _open_slot
	_hover = _with_part(slot, part_id)
	_refresh_stats()
	_info.text = _part_detail(slot, part_id)


func _hover_frame(frame_id: String) -> void:
	_hover = Arsenal.clean({"frame": frame_id, "parts": plan.parts, "tune": plan.tune})
	_refresh_stats()
	var f := Arsenal.frame(frame_id)
	var text := "[b]%s[/b]　[color=#%s]%s・%s・最多 %d 個槍位[/color]\n%s" % [f.name, UiKit.DIM.to_html(false),
		Arsenal.caliber_name(f.get("cal", "9mm")), KIND_NAMES.get(f.get("kind", "hitscan"), ""),
		possible_slots(frame_id).size(), f.desc]
	if frame_id != plan.frame:
		var lost := _dropped(plan.parts, _hover.parts, "")
		if not lost.is_empty():
			text += "\n[color=#%s]換過去裝不上：%s[/color]" % [UiKit.WARN.to_html(false), _slot_part_list(lost)]
	_info.text = text


func _unhover() -> void:
	_hover = {}
	_refresh_stats()


## What the detail box says about a part in the picker: price, what it is, what slots it
## opens or blocks, a calibre change and what would come off.
func _part_detail(slot: String, part_id: String) -> String:
	var candidate := _with_part(slot, part_id)
	var lost := _dropped(plan.parts, candidate.parts, slot)
	var lines := []
	if part_id == "":
		lines.append("把%s的零件拆掉（規劃而已，不花錢）。" % Arsenal.slot_name(slot))
	else:
		var p := Arsenal.part(part_id)
		var head := "[b]%s[/b]" % p.name
		var bits := []
		if Arsenal.is_organ(part_id):
			bits.append("器官")
		else:
			bits.append("$%d" % p.price)
		bits.append("%+.2f kg" % p.get("weight", 0.0))
		lines.append("%s　[color=#%s]%s[/color]" % [head, UiKit.DIM.to_html(false), "・".join(bits)])
		lines.append(p.desc)
		var extra := []
		if p.has("set_cal"):
			extra.append("[color=#%s]口徑改成 %s[/color]" % [UiKit.HOT.to_html(false), Arsenal.caliber_name(p.set_cal)])
		if p.has("adds"):
			extra.append("[color=#%s]多出槍位：%s[/color]" % [UiKit.COLD.to_html(false),
				"、".join(p.adds.map(func(s: String) -> String: return Arsenal.slot_name(s)))])
		if p.has("blocks"):
			extra.append("[color=#%s]擋住槍位：%s[/color]" % [UiKit.WARN.to_html(false),
				"、".join(p.blocks.map(func(s: String) -> String: return Arsenal.slot_name(s)))])
		if p.has("tune"):
			extra.append("[color=#%s]可微調：%s（%s ↔ %s）[/color]" % [UiKit.ACCENT.to_html(false), p.tune.name, p.tune.lo, p.tune.hi])
		if not extra.is_empty():
			lines.append("　".join(extra))
	if not lost.is_empty():
		lines.append("[color=#%s]會拆掉：%s[/color]" % [UiKit.DANGER.to_html(false), _slot_part_list(lost)])
	return "\n".join(lines)


static func _slot_part_list(parts: Dictionary) -> String:
	var names := []
	for slot: String in parts:
		names.append("%s「%s」" % [Arsenal.slot_name(slot), Arsenal.name_of(parts[slot])])
	return "、".join(names)


func _default_info() -> String:
	var f := Arsenal.frame(plan.frame)
	return "[b]%s[/b]　%s\n[color=#%s]%s[/color]" % [f.get("name", ""), f.get("desc", ""), UiKit.DIM.to_html(false), DEFAULT_INFO]


func _describe_slot(slot: String) -> void:
	var part_id: String = plan.parts.get(slot, "")
	var count := Arsenal.parts_for(plan, slot).size()
	var parent := Arsenal.opened_by(plan, slot)
	var origin := "" if parent == "" else "（%s「%s」開出來的）" % [Arsenal.slot_name(parent), Arsenal.name_of(plan.parts.get(parent, ""))]
	if part_id == "":
		_info.text = "[b]%s[/b]%s：空的，有 %d 種零件能裝。點一下打開清單。" % [Arsenal.slot_name(slot), origin, count]
	else:
		_info.text = "[b]%s[/b]%s：%s。%s" % [Arsenal.slot_name(slot), origin, Arsenal.name_of(part_id), Arsenal.part(part_id).desc]


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragged = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged = true
		_yaw += event.relative.x * 0.6
		_pitch = clampf(_pitch + event.relative.y * 0.4, -60.0, 70.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _picker != null and _picker.visible:
		close_picker()
		get_viewport().set_input_as_handled()


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


## A marker on the turning gun where the open (or hovered) slot's part sits.
func _draw_lines() -> void:
	if _model == null or not is_instance_valid(_model) or not _model.is_inside_tree():
		return
	var slot := _open_slot if _open_slot != "" else _hover_slot
	var spots: Dictionary = _model.get_meta("slots", {})
	var spot: String = MODEL_SPOT.get(slot, "")
	if spot == "" or not spots.has(spot):
		return
	var world: Vector3 = _model.global_transform * (spots[spot] as Vector3)
	if _camera.is_position_behind(world):
		return
	var target := _camera.unproject_position(world) * float(_view_container.stretch_shrink)
	var color := Color(UiKit.HOT, 0.95)
	var corner := Vector2(14, 22)
	_lines.draw_line(corner + Vector2(0, 6), target, Color(color, 0.6), 1.5)
	_lines.draw_rect(Rect2(target - Vector2(4, 4), Vector2(8, 8)), color, false, 2.0)
	var font := ThemeDB.fallback_font
	_lines.draw_string_outline(font, corner, Arsenal.slot_name(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	_lines.draw_string(font, corner, Arsenal.slot_name(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _rebuild_model() -> void:
	if _pivot == null:
		return
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = GunModels.build(plan)
	if _model == null:
		return
	var box := AABB()
	var first := true
	for child in _model.get_children():
		if child is MeshInstance3D:
			var mesh_box: AABB = child.transform * (child as MeshInstance3D).get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
	_model.position = -box.get_center()
	_pivot.add_child(_model)
	var longest := maxf(box.size.z, maxf(box.size.y * 1.8, 0.28))
	_camera.position = Vector3(0, 0.0, longest * 1.55 + 0.1)


# --- Refresh ------------------------------------------------------------------------------

func _refresh() -> void:
	_money_label.text = "$%d" % GameState.money
	_stats_label.text = "撤離 %d 次　死亡 %d 次　最高收穫 $%d" % [GameState.extractions, GameState.deaths, GameState.best_haul]
	var f := Arsenal.frame(plan.frame)
	_gun_name.text = f.name
	_gun_sub.text = "%s・%s・%s" % [Arsenal.caliber_name(Arsenal.caliber_of(plan)), KIND_NAMES.get(f.get("kind", "hitscan"), ""),
		frame_group_name(plan.frame)]
	if _info.text == "":
		_info.text = _default_info()
	_refresh_list()
	_fill_tree()
	_refresh_stats()
	_refresh_cost()
	if _picker.visible:
		if _open_slot in Arsenal.open_slots(plan):
			_fill_picker()
		else:
			close_picker()


static func frame_group_name(frame_id: String) -> String:
	var group := frame_group(frame_id)
	for entry: Array in FRAME_GROUPS:
		if entry[0] == group:
			return entry[1]
	return ""


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _refresh_list() -> void:
	for id in _tab_buttons:
		UiKit.style_button(_tab_buttons[id], "selected" if id == _tab else "normal")
	(_tab_buttons.plans as Button).text = "方案 %d/%d" % [GameState.builds.size(), GameState.MAX_BUILDS]
	(_tab_buttons.boosts as Button).text = "強化 %d/%d" % [_loadout.boosts.size(), Gear.MAX_BOOSTS]
	var keep := _list_scroll.scroll_vertical
	_clear(_list)
	match _tab:
		"frames": _fill_frames()
		"plans": _fill_plans()
		"boosts": _fill_boosts()
	_list_scroll.set_deferred("scroll_vertical", keep)


func _fill_frames() -> void:
	for group: Array in FRAME_GROUPS:
		var ids := []
		for id: String in Arsenal.FRAMES:
			if frame_group(id) == group[0]:
				ids.append(id)
		if ids.is_empty():
			continue
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		var bar := ColorRect.new()
		bar.color = Color(UiKit.ACCENT, 0.8)
		bar.custom_minimum_size = Vector2(4, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(bar)
		var title := _left_label(group[1], 14, UiKit.ACCENT)
		title.add_theme_font_override("font", UiKit.bold_font())
		header.add_child(title)
		header.add_child(_left_label("%d" % ids.size(), 12, UiKit.DIM))
		if not _list.get_children().is_empty():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 2)
			_list.add_child(gap)
		_list.add_child(header)
		for id: String in ids:
			_list.add_child(_frame_row(id))


func _frame_row(id: String) -> Button:
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
	var sub := "%s・%d 槍位・%.1fkg" % [Arsenal.caliber_name(f.get("cal", "9mm")), possible_slots(id).size(), f.weight]
	var row := _two_line_row(f.name, tag, tag_color, sub, func() -> void: select_frame(id))
	if id == plan.frame:
		(row.find_child("Main", true, false) as Label).add_theme_color_override("font_color", UiKit.ACCENT)
		UiKit.style_button(row, "selected")
	row.mouse_entered.connect(func() -> void: _hover_frame(id))
	row.mouse_exited.connect(_unhover)
	return row


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
	var note_label := _left_label(note, 13, UiKit.DIM)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note_label)
	if GameState.builds.is_empty():
		var empty := _left_label("還沒有方案。先在中間改好一把槍，再按「存目前的槍」。", 14, UiKit.TEXT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	for i in GameState.builds.size():
		var saved: Dictionary = GameState.builds[i]
		var build: Dictionary = Arsenal.clean(saved.build)
		var index := i
		var missing := _missing_cost(build)
		var tag := "全部都有" if missing == 0 else "缺 $%d" % missing
		var color := UiKit.GOOD if missing == 0 else (UiKit.WARN if missing <= GameState.money else UiKit.DANGER)
		if not _missing_pieces(build, "missing").is_empty():
			tag = "缺器官"
			color = UiKit.DANGER
		var sub := "%s・%s・%d 件" % [Arsenal.name_of(build.frame), Arsenal.caliber_name(Arsenal.caliber_of(build)), build.parts.size()]
		var row := _two_line_row(saved.name, tag, color, sub, func() -> void: load_plan(index))
		if build == plan:
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
	var note := _left_label("強化每局最多帶 %d 個，和槍一樣死掉就沒了。" % Gear.MAX_BOOSTS, 13, UiKit.DIM)
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
		row.mouse_entered.connect(func() -> void: _info.text = "[b]%s[/b]　$%d・%.1fkg\n%s" % [info.name, info.price, info.weight, info.desc])
		_list.add_child(row)


## A two-line list row: a name and a coloured tag (owned / price), and a dim line under them.
func _two_line_row(text: String, tag: String, tag_color: Color, sub: String, on_pressed: Callable) -> Button:
	var row := UiKit.button("", on_pressed)
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 40)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 9
	box.offset_right = -7
	box.offset_top = 2
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var name_label := _left_label(text, 15, UiKit.TEXT)
	name_label.name = "Main"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	top.add_child(_left_label(tag, 13, tag_color))
	var sub_label := _left_label(sub, 12, UiKit.DIM)
	sub_label.clip_text = true
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(sub_label)
	return row


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
	var main := _left_label(text, 15, UiKit.TEXT)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.clip_text = true
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if "\n" in text:
		main.add_theme_font_size_override("font_size", 14)
		main.add_theme_constant_override("line_spacing", -4)
	box.add_child(main)
	var tag_label := UiKit.label(tag, 14, tag_color)
	tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag_label)
	return row


# --- Slot tree ------------------------------------------------------------------------------

func _fill_tree() -> void:
	var keep := _tree_scroll.scroll_vertical
	_clear(_tree)
	_slot_rows = {}
	_tune_sliders = {}
	var open := Arsenal.open_slots(plan)
	var parent := {}
	for slot: String in open:
		parent[slot] = Arsenal.opened_by(plan, slot)
	var states := {}
	for item: Array in _plan_pieces():
		states[item[2]] = item[1]
	var shown := {}
	for group: Array in Arsenal.SLOT_GROUPS:
		var roots: Array = (group[1] as Array).filter(func(s: String) -> bool: return s in open and parent[s] == "")
		if roots.is_empty():
			continue
		var header := _left_label(group[0], 13, UiKit.ACCENT)
		header.add_theme_font_override("font", UiKit.bold_font())
		_tree.add_child(header)
		for slot: String in Arsenal.SLOTS:
			if slot in roots:
				_add_slot_row(slot, 0, open, parent, states, shown)
	for slot: String in open:  # anything the walk above missed (should be nothing)
		if not shown.has(slot):
			_add_slot_row(slot, 0, open, parent, states, shown)
	# What more this frame could have.
	var possible := possible_slots(plan.frame)
	_tree_count.text = "%d 個開著・最多 %d" % [open.size(), possible.size()]
	var locked := []
	var openers := slot_openers(plan.frame)
	for slot: String in possible:
		if slot in open:
			continue
		if slot in Arsenal.frame(plan.frame).slots:
			locked.append("%s（被擋住）" % Arsenal.slot_name(slot))
		elif openers.has(slot):
			locked.append("%s（裝%s）" % [Arsenal.slot_name(slot), "或".join(openers[slot])])
		else:
			locked.append(Arsenal.slot_name(slot))
	if not locked.is_empty():
		var hint := _left_label("還能多出 %d 個槍位：%s" % [locked.size(), "、".join(locked)], 12, Color(UiKit.DIM, 0.85))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(200, 0)
		_tree.add_child(hint)
	_refresh_tree_styles()
	_tree_scroll.set_deferred("scroll_vertical", keep)


func _add_slot_row(slot: String, depth: int, open: Array, parent: Dictionary, states: Dictionary, shown: Dictionary) -> void:
	shown[slot] = true
	var part_id: String = plan.parts.get(slot, "")
	var row := UiKit.button("", func() -> void: open_slot(slot))
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 30)
	row.set_meta("depth", depth)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 7 + depth * 14
	box.offset_right = -6
	if depth > 0:
		box.add_child(_left_label("└", 13, Color(UiKit.ACCENT, 0.6)))
	var slot_label := _left_label(Arsenal.slot_name(slot), 12, UiKit.DIM)
	slot_label.custom_minimum_size = Vector2(40, 0)
	box.add_child(slot_label)
	var part_label := _left_label("", 14, UiKit.TEXT)
	part_label.name = "Part"
	part_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	part_label.clip_text = true
	part_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(part_label)
	var tag := _left_label("", 12, UiKit.GOOD)
	tag.name = "Tag"
	box.add_child(tag)
	if part_id == "":
		part_label.text = "＋ 空"
		part_label.add_theme_color_override("font_color", UiKit.DIM)
		tag.text = "%d 種" % Arsenal.parts_for(plan, slot).size()
		tag.add_theme_color_override("font_color", UiKit.DIM)
	else:
		part_label.text = Arsenal.name_of(part_id)
		row.tooltip_text = Arsenal.name_of(part_id)
		part_label.add_theme_color_override("font_color", Bestiary.ORGAN if Arsenal.is_organ(part_id) else UiKit.TEXT)
		match states.get(slot, "stash"):
			"missing":
				tag.text = "沒有"
				tag.add_theme_color_override("font_color", UiKit.DANGER)
			"buy":
				tag.text = "$%d" % Arsenal.price_of(part_id)
				tag.add_theme_color_override("font_color", UiKit.WARN)
			"equipped":
				tag.text = "裝著"
			_:
				tag.text = "擁有"
	row.mouse_entered.connect(func() -> void:
		_hover_slot = slot
		if _open_slot == "":
			_describe_slot(slot))
	row.mouse_exited.connect(func() -> void: _hover_slot = "")
	_tree.add_child(row)
	_slot_rows[slot] = row
	if part_id != "" and Arsenal.part(part_id).has("tune"):
		_tree.add_child(_tune_row(slot, Arsenal.part(part_id).tune, depth))
	for child: String in Arsenal.SLOTS:
		if child in open and parent.get(child, "") == slot and not shown.has(child):
			_add_slot_row(child, depth + 1, open, parent, states, shown)


## The slider under a tunable part: its name, the low end, 9 steps, the high end.
func _tune_row(slot: String, tune: Dictionary, depth: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(14 + depth * 14, 0)
	line.add_child(indent)
	var name_label := _left_label(tune.name, 12, UiKit.ACCENT)
	line.add_child(name_label)
	line.add_child(_left_label(tune.lo, 11, UiKit.DIM))
	var slider := HSlider.new()
	slider.min_value = -1.0
	slider.max_value = 1.0
	slider.step = 0.25
	slider.tick_count = 9
	slider.ticks_on_borders = true
	slider.value = Arsenal.tune_of(plan, slot)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(60, 18)
	slider.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = Color(UiKit.ACCENT, 0.7)
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	slider.tooltip_text = "%s：%s ↔ %s" % [tune.name, tune.lo, tune.hi]
	line.add_child(slider)
	line.add_child(_left_label(tune.hi, 11, UiKit.DIM))
	var value_label := _left_label(_tune_text(slider.value), 12, UiKit.TEXT)
	value_label.custom_minimum_size = Vector2(32, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(value_label)
	slider.set_meta("value_label", value_label)
	slider.value_changed.connect(func(value: float) -> void: set_tune(slot, value))
	_tune_sliders[slot] = slider
	return line


static func _tune_text(value: float) -> String:
	if absf(value) < 0.01:
		return "0"
	return "%+d" % roundi(value * 4.0)


func _refresh_tree_styles() -> void:
	for slot: String in _slot_rows:
		var row: Button = _slot_rows[slot]
		if not is_instance_valid(row):
			continue
		var state := "normal"
		if slot == _open_slot:
			state = "loud"
		elif plan.parts.has(slot):
			state = "selected"
		UiKit.style_button(row, state)
		var box := row.get_theme_stylebox("normal") as StyleBoxFlat
		if slot == _open_slot:
			box.border_color = UiKit.HOT
			box.border_width_left = 6
		if row.get_meta("depth", 0) > 0:
			box.bg_color = box.bg_color.darkened(0.15)
		box.content_margin_left = 0
		var label := row.find_child("Part", true, false) as Label
		if label != null and plan.parts.has(slot) and not Arsenal.is_organ(plan.parts[slot]):
			label.add_theme_color_override("font_color", UiKit.HOT if slot == _open_slot else UiKit.ACCENT)


# --- Part picker ------------------------------------------------------------------------------

func _fill_picker() -> void:
	_clear(_picker_list)
	var slot := _open_slot
	var current: String = plan.parts.get(slot, "")
	var options: Array[String] = [""]
	options.append_array(Arsenal.parts_for(plan, slot))
	_picker_title.text = "%s：%d 種零件能裝" % [Arsenal.slot_name(slot), options.size() - 1]
	var budget := GameState.money - plan_cost()
	for item: Array in _plan_pieces():
		if item[2] == slot and item[1] == "buy":
			budget += Arsenal.price_of(item[0])
	var base := Arsenal.stats(plan)
	for part_id: String in options:
		var id := part_id
		var row := UiKit.button("", func() -> void: set_part(slot, id); close_picker())
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(0, 44 if id != "" else 28)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 9
		box.offset_right = -7
		box.offset_top = 2
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 5)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(top)
		var label_text := "（拆掉，留空）" if id == "" else Arsenal.name_of(id)
		if id == current:
			label_text = "✓ " + label_text
		var organ := id != "" and Arsenal.is_organ(id)
		var name_label := _left_label(label_text, 15, UiKit.ACCENT if id == current else (Bestiary.ORGAN if organ else UiKit.TEXT))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if organ:
			var badge := UiKit.sticker("器官", Bestiary.ORGAN_BACK, Bestiary.ORGAN, 11, 0.0)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(badge)
		top.add_child(name_label)
		if id != "":
			var p := Arsenal.part(id)
			if p.has("set_cal"):
				top.add_child(_chip("→ " + Arsenal.caliber_name(p.set_cal), UiKit.HOT))
			if p.has("tune"):
				top.add_child(_chip("可調", UiKit.ACCENT))
			var free := _free_count(id, slot)
			var tag_text := "擁有 %d" % free if free > 0 else "$%d" % Arsenal.price_of(id)
			var tag_color := UiKit.GOOD if free > 0 else (UiKit.WARN if Arsenal.price_of(id) <= budget else UiKit.DANGER)
			if organ and free <= 0:
				tag_text = "要從怪物身上取得"
				tag_color = UiKit.DANGER
			elif free <= 0 and _have(id) > 0:
				tag_text = "$%d（%d 個都用掉了）" % [Arsenal.price_of(id), _have(id)]
			var tag := UiKit.label(tag_text, 13, tag_color)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(tag)
			var changes := _rich(12)
			changes.text = _change_line(base, _with_part(slot, id), plan.parts, slot)
			changes.autowrap_mode = TextServer.AUTOWRAP_OFF
			changes.clip_contents = true
			box.add_child(changes)
		if id == current:
			UiKit.style_button(row, "selected")
		row.mouse_entered.connect(func() -> void: _hover_part(id))
		row.mouse_exited.connect(_unhover)
		_picker_list.add_child(row)


static func _chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.13)
	box.border_color = Color(color, 0.75)
	box.set_border_width_all(1)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", box)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := UiKit.label(text, 12, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


## The biggest few changes from stats `sa` to build `b`, in percent, plus a calibre change,
## new slots, new effects and parts that would come off.
static func _change_line(sa: Dictionary, b: Dictionary, old_parts: Dictionary, slot: String) -> String:
	var sb := Arsenal.stats(b)
	var found := []
	for stat: String in SHORT:
		var va := _num(sa, stat)
		var vb := _num(sb, stat)
		var dec: int = DECIMALS.get(stat, 1)
		if absf(va - vb) < 0.5 * pow(10.0, -dec):
			continue
		var pct := (vb - va) / maxf(absf(va), 0.001) * 100.0
		var text := ""
		if stat == "weight":
			text = "重量%+.2fkg" % (vb - va)
		elif stat == "length":
			text = "長度%+dcm" % roundi(vb - va)
		elif absf(va) < 0.001:
			text = "%s+%s" % [SHORT[stat], _number(vb, dec)]
		else:
			text = "%s%+d%%" % [SHORT[stat], roundi(pct)]
		var dir := _better_dir(stat)
		var color := UiKit.DIM if dir == 0 else (UiKit.GOOD if (vb - va) * dir > 0.0 else UiKit.DANGER)
		var weight := absf(pct) if stat != "weight" and stat != "length" else 1.0
		found.append([weight, "[color=#%s]%s[/color]" % [color.to_html(false), text]])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var parts := []  # (a calibre change shows as a chip on the row itself)
	var lost := _dropped(old_parts, b.parts, slot)
	if not lost.is_empty():
		parts.append("[color=#%s]拆掉 %d 件[/color]" % [UiKit.DANGER.to_html(false), lost.size()])
	var gained := Arsenal.open_slots(b).size() - Arsenal.open_slots(Arsenal.clean({"frame": sa.frame, "parts": sa.parts, "tune": sa.tune})).size()
	if gained > 0:
		parts.append("[color=#%s]+%d 槍位[/color]" % [UiKit.COLD.to_html(false), gained])
	if absf(float(sa.zoom) - float(sb.zoom)) > 0.01:
		parts.append("[color=#%s]倍率×%.1f[/color]" % [UiKit.DIM.to_html(false), sb.zoom])
	for i in mini(found.size(), 4):
		parts.append(found[i][1])
	var old := _effect_names(sa.effects)
	var added := 0
	for e: String in _effect_names(sb.effects):
		if not e in old and added < 2:
			parts.append("[color=#%s]+%s[/color]" % [UiKit.COLD.to_html(false), e])
			added += 1
	for m: String in sb.modes:
		if not m in sa.modes:
			parts.append("[color=#%s]+%s[/color]" % [UiKit.COLD.to_html(false), Arsenal.MODE_NAMES.get(m, m)])
	if parts.is_empty():
		return "[color=#%s]數據不變[/color]" % UiKit.DIM.to_html(false)
	return "  ".join(parts)


# --- Stats ------------------------------------------------------------------------------------

## 1 when more of a stat is better, -1 when less is, 0 when neither.
static func _better_dir(stat: String) -> int:
	if stat in NEUTRAL:
		return 0
	return -1 if stat in LOWER_BETTER else 1


## A stat as a number for comparing ("damage" is the whole shot: damage × pellets).
static func _num(s: Dictionary, stat: String) -> float:
	if stat == "damage":
		return float(s.damage) * float(s.pellets)
	return float(s.get(stat, 0.0))


static func _number(value: float, decimals: int) -> String:
	return ("%." + str(decimals) + "f") % value


static func _signed(diff: float, decimals: int) -> String:
	return ("+" if diff > 0.0 else "−") + _number(absf(diff), decimals)


func _refresh_stats() -> void:
	if _stat_rows.is_empty():
		return
	var shown: Dictionary = _hover if not _hover.is_empty() else plan
	var base: Dictionary = plan if not _hover.is_empty() else _loadout.build
	var s := Arsenal.stats(shown)
	var b := Arsenal.stats(base)
	if not _hover.is_empty():
		_compare_note.text = "綠/紅＝換上後的變化"
	elif _is_equipped_plan():
		_compare_note.text = "目前裝備的槍"
	else:
		_compare_note.text = "綠/紅＝跟目前裝備的比"
	for row: Array in STAT_ROWS:
		var stat: String = row[0]
		var widgets: Dictionary = _stat_rows[stat]
		var visible := true
		match stat:
			"pellets": visible = s.pellets > 1 or b.pellets > 1
			"heat": visible = s.heat > 0.0 or b.heat > 0.0
		(widgets.line as Control).visible = visible
		if not visible:
			continue
		var value: Label = widgets.value
		var delta: Label = widgets.delta
		var bar: StatBar = widgets.bar
		value.text = _format(stat, s)
		delta.text = ""
		var full: float = row[2]
		if full <= 0.0:
			var changed := _format(stat, b) != value.text
			value.add_theme_color_override("font_color", UiKit.HOT if changed else UiKit.TEXT)
			delta.text = "改" if changed else ""
			delta.add_theme_color_override("font_color", UiKit.HOT)
			continue
		var v := _num(s, stat)
		var o := _num(b, stat)
		bar.fill = clampf(v / full, 0.0, 1.0)
		bar.other = clampf(o / full, 0.0, 1.0)
		bar.better = 0
		var dec: int = DECIMALS.get(stat, 1)
		var key := stat
		var diff := v - o
		if absf(diff) < 0.5 * pow(10.0, -dec) and SECOND.has(stat):
			key = SECOND[stat]
			dec = DECIMALS.get(key, 1)
			diff = _num(s, key) - _num(b, key)
		value.add_theme_color_override("font_color", UiKit.TEXT)
		if absf(diff) >= 0.5 * pow(10.0, -dec):
			var dir := _better_dir(key)
			var good := diff * dir > 0.0
			var color := UiKit.DIM if dir == 0 else (UiKit.GOOD if good else UiKit.DANGER)
			delta.text = _signed(diff * (100.0 if key == "jam" else 1.0), 2 if key == "jam" else dec)
			delta.add_theme_color_override("font_color", color)
			value.add_theme_color_override("font_color", color.lerp(UiKit.TEXT, 0.35))
			if key == stat:
				bar.better = 0 if dir == 0 else (1 if good else -1)
		else:
			bar.other = -1.0
		bar.queue_redraw()
	# Effects as tags: new ones green, lost ones red.
	_clear(_effects_flow)
	var effects := _effect_names(s.effects)
	var old := _effect_names(b.effects)
	_effects_flow.add_child(_chip(KIND_NAMES.get(s.kind, s.kind), UiKit.DIM))
	for e: String in effects:
		_effects_flow.add_child(_chip(e if e in old else "+" + e, UiKit.COLD if e in old else UiKit.GOOD))
	for e: String in old:
		if not e in effects:
			_effects_flow.add_child(_chip("−" + e, UiKit.DANGER))


static func _format(stat: String, s: Dictionary) -> String:
	match stat:
		"damage": return "%d×%d" % [roundi(s.damage), s.pellets] if s.pellets > 1 else "%d" % roundi(s.damage)
		"pellets": return "%d 顆" % s.pellets
		"rate": return "%.1f 發/秒" % s.rate
		"modes": return "、".join((s.modes as Array).map(func(m: String) -> String: return Arsenal.MODE_NAMES.get(m, m)))
		"mag": return "%d / %d" % [s.mag, s.reserve]
		"reload": return "%.2f 秒" % s.reload
		"spread": return "%.2f°" % s.spread
		"moa": return "%.1f MOA" % s.moa
		"recoil": return "%.1f" % s.recoil
		"recoil_h": return "%.2f" % s.recoil_h
		"ergo": return "%d" % roundi(s.ergo)
		"aim_time": return "%.2f 秒" % s.aim_time
		"sway": return "%.2f°" % s.sway
		"velocity": return "%d m/s" % roundi(s.velocity)
		"pen": return "%d" % roundi(s.pen)
		"range": return "%d / %d m" % [roundi(s.range), roundi(s.falloff)]
		"noise": return "%d m" % roundi(s.noise)
		"flash": return "%d" % roundi(s.flash)
		"reliability": return "%d / %.2f%%" % [roundi(s.reliability), s.jam * 100.0]
		"heat": return "%.3f / %.2f" % [s.heat, s.cooling]
		"zoom": return "×%.2f" % s.zoom
		"weight": return "%.2f kg" % s.weight
		"length": return "%d cm" % roundi(s.length)
		"caliber": return s.caliber
		"sound":
			var quiet := "已消音" if s.suppressed else "未消音"
			if s.kind != "hitscan":
				return quiet
			return quiet + "・" + ("超音速" if s.supersonic else "亞音速")
	return str(s.get(stat, ""))


func _refresh_cost() -> void:
	var pieces := _plan_pieces()
	var cost := plan_cost()
	var owned_count := 0
	var buy_names := []
	var lacking := []
	for item: Array in pieces:
		var id: String = item[0]
		if item[1] == "missing":
			lacking.append(Arsenal.name_of(id))
		elif item[1] == "buy":
			buy_names.append("%s [color=#%s]$%d[/color]" % [Arsenal.name_of(id), UiKit.WARN.to_html(false), Arsenal.price_of(id)])
		else:
			owned_count += 1
	var lines := []
	var head := "[color=#%s]已有 %d 件[/color]" % [UiKit.GOOD.to_html(false), owned_count]
	if not buy_names.is_empty():
		var shown := buy_names.slice(0, 3)
		var more := "" if buy_names.size() <= 3 else " 等 %d 件" % buy_names.size()
		head += "　[color=#%s]要買：[/color]%s%s" % [UiKit.WARN.to_html(false), "、".join(shown), more]
	lines.append(head)
	if not lacking.is_empty():
		lines.append("[color=#%s]缺器官（要從怪物身上取得）：[/color]%s" % [UiKit.DANGER.to_html(false), "、".join(lacking)])
	_cost_detail.text = "\n".join(lines)
	if not lacking.is_empty() and not _is_equipped_plan():
		_equip.disabled = false
		_cost_title.text = "缺 %d 個器官，裝不起來" % lacking.size()
		_cost_title.add_theme_color_override("font_color", UiKit.DANGER)
		_equip.text = "缺器官"
		UiKit.style_button(_equip, "locked")
	elif _is_equipped_plan():
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
	var carried := "%s%s" % [Arsenal.name_of(equipped_build.frame),
			"" if equipped_build.parts.is_empty() else " +%d 件" % equipped_build.parts.size()]
	_equipped_label.text = "目前裝備：" + carried
	var boost_names := []
	for id in _loadout.boosts:
		boost_names.append(Gear.info(id).name)
	_carry_label.text = "這次帶：%s　強化：%s" % [carried, "無" if boost_names.is_empty() else "、".join(boost_names)]


## Effects in Chinese, for the stats panel's tags.
static func _effect_names(effects: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for effect: String in effects:
		var v = effects[effect]
		match effect:
			"stun": names.append("麻痺 %.1f 秒" % v)
			"slow": names.append("減速 %.1f 秒" % v)
			"burn": names.append("燃燒 %.1f 秒" % v)
			"bleed": names.append("流血 %.1f 秒" % v)
			"pierce": names.append("貫穿")
			"knock": names.append(("擊退 %.1fm" if v > 0 else "往你拖 %.1fm") % absf(v))
			"explode": names.append("爆炸 %.1fm" % v)
			"chain": names.append("連鎖 +%d" % v)
			"lure": names.append("引怪")
			"reveal": names.append("逼出隱形")
			"bubble": names.append("泡泡 %d 秒" % roundi(v))
			"thermal": names.append("熱成像")
			"night": names.append("夜視")
			"light": names.append("槍燈")
			"laser": names.append("雷射")
			"laser_ir": names.append("紅外線雷射")
			"strobe": names.append("爆閃")
			"bipod": names.append("腳架")
			"canted": names.append("偏置瞄具")
			"suppressed": names.append("消音")
			"tracer": names.append("曳光")
			"quick_clear": names.append("快速排除卡彈")
			"bayonet": names.append("刺刀")
			"soft": names.append("空尖（小怪痛）")
			"armor": names.append("穿甲（大怪痛）")
			"leech": names.append("吸血 %d%%" % roundi(v * 100.0))
			"ghost": names.append("每 %d 發免彈" % v)
			"bounty": names.append("殺怪掉寶" if not v is float or v <= 1.0 else "殺怪掉好寶")
			"scream": names.append("命中處尖叫引怪")
			"hush": names.append("幾乎無聲")
			"acid": names.append("酸液水窪")
			"lullaby": names.append("搖籃曲安撫")
			"web": names.append("黏網")
			"motion_sight": names.append("看穿牆後動靜")
			"squeal": names.append("瞄準時尖叫")
			"guard": names.append("瞄準時傷害 −%d%%" % roundi(v * 100.0))
			"fang": names.append("獸牙（近戰×3）")
			_: names.append(effect)
	return names


func _missing_cost(build: Dictionary) -> int:
	var cost := 0
	for id: String in _missing_pieces(build):
		cost += Arsenal.price_of(id)
	return cost


## The pieces of a build you would have to buy (or, with "missing", organs you lack).
func _missing_pieces(build: Dictionary, state := "buy") -> Array[String]:
	var result: Array[String] = []
	for item: Array in _pieces_of(Arsenal.clean(build)):
		if item[1] == state:
			result.append(item[0])
	return result


func _plan_summary(build: Dictionary) -> String:
	var names := []
	for slot: String in Arsenal.SLOTS:
		if build.parts.has(slot):
			names.append(Arsenal.name_of(build.parts[slot]))
	var text := "[b]%s[/b]（%s）：%s" % [Arsenal.name_of(build.frame), Arsenal.caliber_name(Arsenal.caliber_of(build)),
		"沒有改裝" if names.is_empty() else "、".join(names)]
	var missing := []
	for id: String in _missing_pieces(build):
		missing.append("%s $%d" % [Arsenal.name_of(id), Arsenal.price_of(id)])
	for id: String in _missing_pieces(build, "missing"):
		missing.append("%s（器官，買不到）" % Arsenal.name_of(id))
	text += "\n" + ("零件全部都有，點一下載入。" if missing.is_empty() else "缺：" + "、".join(missing) + "（點一下載入）")
	return text


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
