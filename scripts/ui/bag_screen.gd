class_name BagScreen
extends Control
## The backpack screen (Tab): the run's random grid with everything packed in it.
## The game keeps running behind it. Drag an item to move it, R or right click turns it
## while dragging (R on a hovered item turns it in place), drop it outside the grid to
## throw it on the floor, G drops the item under the mouse. Hover shows what it is.

const CELL := 54.0
const PAD := 10.0
const INFO_WIDTH := 300.0
const SLOT := Color(0.09, 0.09, 0.1, 0.92)
const SLOT_EDGE := Color(1.0, 1.0, 1.0, 0.1)

var player: Player
## Index into player.items of the item being dragged (-1: none), and the dragged item
## itself (so a rat stealing it mid-drag cancels the drag).
var drag := -1
var drag_turns := 0
var _drag_data: Dictionary = {}
## Which footprint cell (by index) is under the mouse while dragging.
var _drag_cell := 0
var hovered := -1
## Where the mouse is, in grid cells (tests and tools can set it through point_at).
var _mouse := Vector2.ZERO

var _panel: PanelContainer
var _grid: Control
var _drag_layer: Control
var _stats: Label
var _size_tag: Label
var _info_name: Label
var _info_body: Label
var _info_hint: Label
var _hands: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = 150.0  # the timer and messages above stay clear

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Leave the top of the screen to the timer and the HUD's messages (「包包塞不下」).
	center.offset_top = 150.0
	center.offset_bottom = -8.0
	_panel = UiKit.panel(18, Color(UiKit.ACCENT, 0.5))
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.02, 0.02, 0.025, 0.88)
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left = 4
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	column.add_child(top)
	top.add_child(UiKit.title("背包", 34))
	var tag := UiKit.sticker("", UiKit.HOT, UiKit.INK, 15, -3.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size_tag = tag.get_child(0) as Label
	top.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_stats = UiKit.label("", 17, UiKit.TEXT)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_stats)
	column.add_child(UiKit.hazard_strip(5.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_grid)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(INFO_WIDTH, 0.0)
	info.add_theme_constant_override("separation", 6)
	body.add_child(info)
	info.add_child(UiKit.heading("查看"))
	_info_name = UiKit.label("", 21, UiKit.TEXT)
	_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_name.custom_minimum_size.x = INFO_WIDTH
	info.add_child(_info_name)
	_info_body = UiKit.label("", 16, UiKit.TEXT)
	_info_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size.x = INFO_WIDTH
	info.add_child(_info_body)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(fill)
	_hands = UiKit.label("", 15, UiKit.WARN)
	_hands.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hands.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hands.custom_minimum_size.x = INFO_WIDTH
	info.add_child(_hands)
	_info_hint = UiKit.label("撤離時，包包裡的東西和雙手搬的大件都帶得走。", 14, UiKit.DIM)
	_info_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_hint.custom_minimum_size.x = INFO_WIDTH
	info.add_child(_info_hint)

	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 8)
	column.add_child(keys)
	for pair: Array in [["拖曳", "移動"], ["R／右鍵", "轉向"], ["拖到外面", "丟在地上"], ["G", "丟下指著的"], ["Tab", "關上"]]:
		keys.add_child(UiKit.key_chip(pair[0], 13))
		var text := UiKit.label(pair[1], 15, UiKit.DIM)
		keys.add_child(text)
		var gap := Control.new()
		gap.custom_minimum_size.x = 6.0
		keys.add_child(gap)

	_drag_layer = Control.new()
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.draw.connect(_draw_drag)
	add_child(_drag_layer)
	_drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for node in [_panel, column, top, body, info, keys, center]:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(target: Player) -> void:
	player = target
	refresh()


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	if drag >= 0:
		_cancel_drag()
	visible = false
	hovered = -1


## Redraw after the backpack changed.
func refresh() -> void:
	if player == null or not is_instance_valid(player):
		return
	if drag >= 0 and (drag >= player.items.size() or not is_same(player.items[drag], _drag_data)):
		# It isn't where it was any more (stolen, escaped, used): find it or let go.
		drag = -1
		for i in player.items.size():
			if is_same(player.items[i], _drag_data):
				drag = i
		if drag < 0:
			_drag_data = {}
	var size := GridBag.extent(player.bag_cells)
	_grid.custom_minimum_size = Vector2(size) * CELL + Vector2(PAD, PAD) * 2.0
	var used := player.bag_cells.size() - GridBag.free_cells(player.bag_cells, player.items)
	_size_tag.text = "%d 格" % player.bag_cells.size()
	var organs := 0
	for item in player.items:
		if item.has("organ"):
			organs += 1
	_stats.text = "已用 %d / %d 格　%.1f kg　總值 $%d%s" % [used, player.bag_cells.size(), player.carried_weight,
		player.carried_value, "　器官 %d" % organs if organs > 0 else ""]
	var held := player.held_bulky
	_hands.text = "雙手：%s　$%d　%.0f kg（大件不進包包）" % [held.item_name, held.value, held.weight] \
		if held != null and is_instance_valid(held) else ""
	_hands.visible = _hands.text != ""
	if hovered >= player.items.size():
		hovered = -1
	_show_info()
	_grid.queue_redraw()
	_drag_layer.queue_redraw()


# --- Input --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or player == null:
		return
	if event is InputEventMouseMotion:
		point_at(_grid.get_global_transform().affine_inverse() * (event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		point_at(_grid.get_global_transform().affine_inverse() * button.position)
		if button.button_index == MOUSE_BUTTON_LEFT:
			begin_drag()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			turn()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and drag >= 0:
			end_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_R:
			turn()
			get_viewport().set_input_as_handled()
		elif event.is_action("drop"):
			drop_hovered()
			get_viewport().set_input_as_handled()


## Moves the pointer to a spot in the grid control's local pixels.
func point_at(local: Vector2) -> void:
	_mouse = (local - Vector2(PAD, PAD)) / CELL
	var cell := Vector2i(floori(_mouse.x), floori(_mouse.y))
	var taken := GridBag.occupancy(player.items)
	var before := hovered
	hovered = taken.get(cell, -1) if drag < 0 else drag
	if hovered != before:
		_show_info()
	_grid.queue_redraw()
	_drag_layer.queue_redraw()


## Same, in grid cells (tests, screenshots).
func point_at_cell(cell: Vector2) -> void:
	point_at(Vector2(PAD, PAD) + cell * CELL)


func begin_drag() -> bool:
	var cell := _mouse_cell()
	var index: int = GridBag.occupancy(player.items).get(cell, -1)
	if index < 0:
		return false
	drag = index
	_drag_data = player.items[index]
	var at: Vector3i = _drag_data.bag
	drag_turns = at.z
	var cells := GridBag.rotated(GridBag.footprint(_drag_data), drag_turns)
	_drag_cell = maxi(cells.find(cell - Vector2i(at.x, at.y)), 0)
	hovered = drag
	_show_info()
	_grid.queue_redraw()
	_drag_layer.queue_redraw()
	return true


## R / right click: turn the dragged item (or the hovered one, in place if it fits).
func turn() -> void:
	if drag >= 0:
		drag_turns = posmod(drag_turns + 1, 4)
	elif hovered >= 0:
		var data: Dictionary = player.items[hovered]
		var at: Vector3i = data.bag
		var size := GridBag.footprint_size(data, at.z)
		var turned := GridBag.footprint_size(data, at.z + 1)
		# Turn about the middle, then nudge around to find room.
		var base := Vector2i(at.x, at.y) + (size - turned) / 2
		for nudge: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(-2, 0), Vector2i(0, -2)]:
			if player.bag_move(hovered, base + nudge, at.z + 1):
				break
	_grid.queue_redraw()
	_drag_layer.queue_redraw()


## Where the dragged item's corner would land.
func drag_origin() -> Vector2i:
	var cells := GridBag.rotated(GridBag.footprint(_drag_data), drag_turns)
	return _mouse_cell() - cells[mini(_drag_cell, cells.size() - 1)]


func drag_fits() -> bool:
	var cells := GridBag.rotated(GridBag.footprint(_drag_data), drag_turns)
	return GridBag.fits(player.bag_cells, GridBag.occupancy(player.items, drag), cells, drag_origin())


## Let go: into the grid if it fits there, on the floor if outside the grid, else back.
## Returns "moved", "dropped" or "back".
func end_drag() -> String:
	if drag < 0:
		return "back"
	var index := drag
	var result := "back"
	if not _over_grid():
		player.drop_item(index)
		result = "dropped"
	elif player.bag_move(index, drag_origin(), drag_turns):
		result = "moved"
	else:
		player.message.emit("那裡放不下")
	drag = -1
	_drag_data = {}
	hovered = -1
	point_at(Vector2(PAD, PAD) + _mouse * CELL)
	refresh()
	return result


func drop_hovered() -> void:
	if drag >= 0:
		return
	player.drop_item(hovered if hovered >= 0 else player.items.size() - 1)
	hovered = -1
	refresh()


func _cancel_drag() -> void:
	drag = -1
	_drag_data = {}
	_grid.queue_redraw()
	_drag_layer.queue_redraw()


func _mouse_cell() -> Vector2i:
	return Vector2i(floori(_mouse.x), floori(_mouse.y))


## Inside the grid's box (with its padding), even over a gap in the bag's shape.
func _over_grid() -> bool:
	var size := Vector2(GridBag.extent(player.bag_cells))
	var margin := PAD / CELL
	return _mouse.x >= -margin and _mouse.y >= -margin and _mouse.x < size.x + margin and _mouse.y < size.y + margin


# --- Info -------------------------------------------------------------------------------

func _show_info() -> void:
	if player == null:
		return
	if hovered < 0 or hovered >= player.items.size():
		_info_name.text = "（把滑鼠移到物品上）"
		_info_name.add_theme_color_override("font_color", UiKit.DIM)
		_info_body.text = "撿東西會自動塞進第一個放得下的位置。\n塞不下就留在地上：整理一下，或丟掉便宜的。"
		_info_body.add_theme_color_override("font_color", UiKit.DIM)
		return
	var data: Dictionary = player.items[hovered]
	_info_name.text = str(data.get("name", "?"))
	var rarity := clampi(int(data.get("rarity", 0)), 0, 3)
	_info_name.add_theme_color_override("font_color", LootTable.RARITY_COLORS[rarity])
	var lines: Array[String] = []
	if data.has("organ"):
		lines.append("器官（%s）：帶出去變成槍零件" % Arsenal.SLOT_NAMES.get(Arsenal.part(str(data.organ)).get("slot", ""), "零件"))
	elif LootTable.has_tag(data, "scratch"):
		lines.append("價值：撤離後才知道")
	else:
		lines.append("價值 $%d　%s" % [int(data.get("value", 0)), LootTable.RARITY_NAMES[rarity]])
	var size := GridBag.footprint_size(data)
	lines.append("%.1f kg　%d 格（%d×%d）" % [float(data.get("weight", 0.0)), GridBag.footprint(data).size(), size.x, size.y])
	var tags: Array[String] = []
	for tag in data.get("tags", []):
		if LootTable.TAG_NAMES.has(tag):
			tags.append(LootTable.TAG_NAMES[tag])
	if not tags.is_empty():
		lines.append("・".join(tags))
	if LootTable.USE_NAMES.has(data.get("use", "")):
		lines.append("X：%s" % LootTable.USE_NAMES[data.use])
	_info_body.text = "\n".join(lines)
	_info_body.add_theme_color_override("font_color", UiKit.TEXT)


# --- Drawing ----------------------------------------------------------------------------

func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(PAD, PAD) + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _draw_grid() -> void:
	if player == null:
		return
	var shape := player.bag_cells
	var lookup := {}
	for cell in shape:
		lookup[cell] = true
	# The bag: dark slots, the outline of its shape in acid.
	for cell in shape:
		var rect := _cell_rect(cell)
		_grid.draw_rect(rect.grow(-1.0), SLOT)
		_grid.draw_rect(rect.grow(-1.0), SLOT_EDGE, false, 1.0)
	_outline(_grid, shape, Vector2.ZERO, Color(UiKit.ACCENT, 0.75), 2.0, lookup)
	for i in player.items.size():
		if i == drag:
			continue
		_draw_item(_grid, player.items[i], GridBag.placed_cells(player.items[i]), Vector2.ZERO, i == hovered)
	# Where the dragged item would land: green if it fits, red over loot or off the bag.
	if drag >= 0 and _over_grid():
		var color := UiKit.GOOD if drag_fits() else UiKit.DANGER
		var ghost: Array[Vector2i] = []
		var origin := drag_origin()
		for cell in GridBag.rotated(GridBag.footprint(_drag_data), drag_turns):
			ghost.append(origin + cell)
		var ghost_lookup := {}
		for cell in ghost:
			ghost_lookup[cell] = true
		for cell in ghost:
			_grid.draw_rect(_cell_rect(cell).grow(-3.0), Color(color, 0.3))
		_outline(_grid, ghost, Vector2.ZERO, color, 3.0, ghost_lookup, 2.0)


func _draw_drag() -> void:
	if drag < 0 or player == null or _drag_data.is_empty():
		return
	var cells := GridBag.rotated(GridBag.footprint(_drag_data), drag_turns)
	# Follow the mouse smoothly (not cell-snapped) so it feels picked up.
	var grab: Vector2i = cells[mini(_drag_cell, cells.size() - 1)]
	var origin_px := _grid.get_global_transform() * (Vector2(PAD, PAD) + _mouse * CELL) - get_global_transform().origin
	var offset := origin_px - (Vector2(grab) + Vector2(0.5, 0.5)) * CELL - Vector2(PAD, PAD)
	_draw_item(_drag_layer, _drag_data, cells, offset, true, 0.72)
	# What letting go would do.
	var note := "放開：丟在地上" if not _over_grid() else ("放開：放進這裡" if drag_fits() else "這裡放不下")
	var color := UiKit.WARN if not _over_grid() else (UiKit.GOOD if drag_fits() else UiKit.DANGER)
	var size := Vector2(GridBag.extent(cells)) * CELL
	var at := offset + Vector2(PAD, PAD) + Vector2(0.0, size.y + 20.0)
	var font := UiKit.bold_font()
	_drag_layer.draw_string_outline(font, at, note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.9))
	_drag_layer.draw_string(font, at, note, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _draw_item(canvas: Control, data: Dictionary, cells: Array[Vector2i], offset: Vector2, lit: bool, alpha := 1.0) -> void:
	if cells.is_empty():
		return
	var lookup := {}
	for cell in cells:
		lookup[cell] = true
	var rarity := clampi(int(data.get("rarity", 0)), 0, 3)
	var tint: Color = data.get("color", Color.WHITE)
	if data.has("organ"):
		tint = Color(0.85, 0.2, 0.18)
	var fill := UiKit.INK.lerp(tint, 0.42 if lit else 0.3)
	fill.a = alpha
	var edge: Color = LootTable.RARITY_COLORS[rarity] if not data.has("organ") else UiKit.DANGER
	if lit:
		edge = edge.lightened(0.3)
	edge.a = alpha
	for cell in cells:
		var rect := _cell_rect(cell)
		rect.position += offset
		var inner := rect.grow(-4.0)
		canvas.draw_rect(inner, fill)
		# Bridge to neighbours of the same item so it reads as one piece.
		var right := lookup.has(cell + Vector2i.RIGHT)
		var down := lookup.has(cell + Vector2i.DOWN)
		if right:
			canvas.draw_rect(Rect2(Vector2(inner.end.x, inner.position.y), Vector2(8.0, inner.size.y)), fill)
		if down:
			canvas.draw_rect(Rect2(Vector2(inner.position.x, inner.end.y), Vector2(inner.size.x, 8.0)), fill)
		if right and down and lookup.has(cell + Vector2i.ONE):
			canvas.draw_rect(Rect2(inner.end, Vector2(8.0, 8.0)), fill)
	_outline(canvas, cells, offset, edge, 2.0 if lit else 1.5, lookup, 4.0)
	# Name in the first row's run of cells, value in the last cell.
	var font := UiKit.bold_font()
	var first := cells[0]
	for cell in cells:
		if cell.y < first.y or (cell.y == first.y and cell.x < first.x):
			first = cell
	var run := 1
	while lookup.has(first + Vector2i(run, 0)):
		run += 1
	var top_left := _cell_rect(first).position + offset + Vector2(7.0, 19.0)
	var full_name := str(data.get("name", "?"))
	var width := run * CELL - 12.0
	var text_color := Color(UiKit.TEXT, alpha)
	var shown := _clip(font, full_name, 13, width)
	if shown != full_name:
		# Too long: drop the bracketed part first (罐頭（沒標籤） -> 罐頭).
		full_name = full_name.get_slice("（", 0).get_slice("「", 0)
		shown = _clip(font, full_name, 13, width)
	canvas.draw_string_outline(font, top_left, shown, HORIZONTAL_ALIGNMENT_LEFT, width, 13, 3, Color(0, 0, 0, 0.8 * alpha))
	canvas.draw_string(font, top_left, shown, HORIZONTAL_ALIGNMENT_LEFT, width, 13, text_color)
	if run < 2 and shown != full_name and lookup.has(first + Vector2i.DOWN):
		# A tall narrow piece: carry on down the column.
		var rest := _clip(font, full_name.substr(shown.length()), 13, width)
		canvas.draw_string_outline(font, top_left + Vector2(0, 16.0), rest, HORIZONTAL_ALIGNMENT_LEFT, width, 13, 3, Color(0, 0, 0, 0.8 * alpha))
		canvas.draw_string(font, top_left + Vector2(0, 16.0), rest, HORIZONTAL_ALIGNMENT_LEFT, width, 13, text_color)
	var last := cells[0]
	for cell in cells:
		if cell.y > last.y or (cell.y == last.y and cell.x > last.x):
			last = cell
	var corner := _cell_rect(last).end + offset - Vector2(7.0, 8.0)
	var tagline := "器官" if data.has("organ") else ("$?" if LootTable.has_tag(data, "scratch") else "$%d" % int(data.get("value", 0)))
	var value_color := Color(UiKit.DANGER if data.has("organ") else UiKit.ACCENT, alpha)
	canvas.draw_string_outline(font, corner - Vector2(CELL - 14.0, 0.0), tagline, HORIZONTAL_ALIGNMENT_RIGHT, CELL - 14.0, 12, 3, Color(0, 0, 0, 0.8 * alpha))
	canvas.draw_string(font, corner - Vector2(CELL - 14.0, 0.0), tagline, HORIZONTAL_ALIGNMENT_RIGHT, CELL - 14.0, 12, value_color)
	if data.has("use"):
		var dot := _cell_rect(first).position + offset + Vector2(CELL - 10.0, 9.0)
		canvas.draw_circle(dot, 3.5, Color(UiKit.ACCENT, alpha))


## Draws the outer edge of a set of cells (edges with no neighbour in the set).
func _outline(canvas: Control, cells: Array[Vector2i], offset: Vector2, color: Color, width: float, lookup: Dictionary, inset := 0.0) -> void:
	for cell in cells:
		var rect := _cell_rect(cell)
		rect.position += offset
		var a := rect.position + Vector2(inset, inset)
		var b := rect.end - Vector2(inset, inset)
		var left := lookup.has(cell + Vector2i.LEFT)
		var right := lookup.has(cell + Vector2i.RIGHT)
		var up := lookup.has(cell + Vector2i.UP)
		var down := lookup.has(cell + Vector2i.DOWN)
		var x0 := rect.position.x if left else a.x
		var x1 := rect.end.x if right else b.x
		var y0 := rect.position.y if up else a.y
		var y1 := rect.end.y if down else b.y
		if not up:
			canvas.draw_line(Vector2(x0, a.y), Vector2(x1, a.y), color, width)
		if not down:
			canvas.draw_line(Vector2(x0, b.y), Vector2(x1, b.y), color, width)
		if not left:
			canvas.draw_line(Vector2(a.x, y0), Vector2(a.x, y1), color, width)
		if not right:
			canvas.draw_line(Vector2(b.x, y0), Vector2(b.x, y1), color, width)


static func _clip(font: Font, text: String, size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		return text
	var cut := text.length()
	while cut > 1 and font.get_string_size(text.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		cut -= 1
	return text.substr(0, cut)
