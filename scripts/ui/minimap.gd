class_name Minimap
extends Control
## The round map in the HUD's top-right corner, turned so the way you face is up, with
## 北東南西 riding its rim, plus a thin compass strip for the top of the screen.
##
## The floor plan is rasterised ONCE per run from physics queries (no second camera):
## each 0.5 m cell is probed for a floor (a ray down) and for a wall at chest height (a
## small box overlap), on the ground level and again one storey up (mall upper floor,
## subway ticket hall, factory catwalks). That runs ~2.5 ms per physics frame for the
## first few seconds of the run, rows nearest you first (a big map is ~1 s of probing in
## all); after that drawing it is one shader quad, so it costs nothing per frame. Only the layout, yourself, your squad and the exit once it is
## open are shown: never monsters or other squads. It's a horror game, not a radar.
##
## In 無盡的午後 the map is never quite steady (it wobbles more the deeper the dream),
## and in the looping stretch of the white corridor it dissolves into static, so it
## can't give away the loop.
##
## M cycles small -> large -> hidden.

enum Mode { SMALL, LARGE, HIDDEN }

const CELL := 0.5
## Diameter in pixels and how many metres the rim is from you.
const DIAMETER := {Mode.SMALL: 168.0, Mode.LARGE: 300.0}
const RANGE := {Mode.SMALL: 18.0, Mode.LARGE: 34.0}
## Pixel blocks across the disc (the PS1 chunkiness).
const PIXELS := {Mode.SMALL: 84.0, Mode.LARGE: 120.0}
const LABEL_HEIGHT := 22.0
## Feet above this use the upper storey's plan.
const UPPER_SPLIT := 2.6
const UPPER_BASE := 5.0
## Milliseconds of probing per physics frame while the plan is drawn (rows nearest
## the player first, so the part you can see fills in within a few frames).
const STEP_BUDGET_MS := 2.5
const STRIP_SIZE := Vector2(380.0, 24.0)
const STRIP_SPAN := 150.0  # degrees shown across the strip

const COL_WALL := Color(0.86, 0.83, 0.74, 1.0)
const COL_FLOOR := Color(0.2, 0.21, 0.21, 1.0)
const COL_PIT := Color(0.09, 0.09, 0.1, 1.0)
const COL_HIGH := Color(0.28, 0.29, 0.27, 1.0)
const COL_BELOW := 0.4  # the ground plan, dimmed, under an upper storey
const BEARING_NAMES := ["北", "東北", "東", "東南", "南", "西南", "西", "西北"]

const SHADER := preload("res://shaders/ui_minimap.gdshader")

var mode := Mode.SMALL
var player: Player
var level: GameMap
## 0 = steady; 1 = nothing but static.
var fuzz := 0.0
## Rasterising progress, 0..1 (1 = the whole plan is drawn).
var progress := 0.0

var _map: ColorRect
var _material: ShaderMaterial
var _overlay: Control
var _strip: Control
var _clock := 0.0
## Ground and upper storey plans, x = world x, y = world z.
var _images: Array[Image] = []
var _textures: Array[ImageTexture] = []
var _origin := Vector2.ZERO
var _cells := Vector2i.ONE
## Rows of the plan still to probe, nearest the player first.
var _rows: Array[int] = []
var _rows_total := 1
var _steps := 0
var _col := 0
var _wait_frames := 2
var _box_query: PhysicsShapeQueryParameters3D
var _jitter := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_map = ColorRect.new()
	_map.material = _material
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_apply_mode()


## The compass strip goes in the HUD's full-screen root, top centre.
func attach_strip(root: Control) -> Control:
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	root.add_child(_strip)
	_strip.anchor_left = 0.5
	_strip.anchor_right = 0.5
	_strip.offset_left = -STRIP_SIZE.x / 2.0
	_strip.offset_right = STRIP_SIZE.x / 2.0
	_strip.offset_top = 8.0
	_strip.offset_bottom = 8.0 + STRIP_SIZE.y
	return _strip


## M: small -> large -> hidden -> small.
func cycle() -> void:
	set_mode((mode + 1) % 3)


func set_mode(value: int) -> void:
	mode = value as Mode
	_apply_mode()


func _apply_mode() -> void:
	if mode == Mode.HIDDEN:
		return
	var d: float = DIAMETER[mode]
	custom_minimum_size = Vector2(d, d + LABEL_HEIGHT)
	size = custom_minimum_size
	offset_left = -20.0 - d
	offset_right = -20.0
	offset_top = 18.0
	offset_bottom = 18.0 + d + LABEL_HEIGHT
	_map.position = Vector2.ZERO
	_map.size = Vector2(d, d)
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(d, d + LABEL_HEIGHT)
	_material.set_shader_parameter("pixels", PIXELS[mode])


## Whether the minimap and strip should draw this frame (the HUD adds its own rules).
func wanted() -> bool:
	return mode != Mode.HIDDEN and player != null and is_instance_valid(player) and player.is_active()


func set_shown(on: bool) -> void:
	visible = on
	if _strip != null:
		_strip.visible = on


# --- Rasterising ----------------------------------------------------------------------

## Draws the whole plan right away (tests and screenshots).
func rasterise_now() -> void:
	if not _begin():
		return
	_step(INF)


func is_ready() -> bool:
	return progress >= 1.0


func _begin() -> bool:
	if not _images.is_empty():
		return true
	if level == null and Run.instance != null:
		level = Run.instance.level
	if level == null or not is_instance_valid(level) or not level.is_inside_tree():
		return false
	var b := level.bounds
	_origin = Vector2(b.position.x, b.position.z) - Vector2(2.0, 2.0)
	_cells = Vector2i(clampi(ceili((b.size.x + 4.0) / CELL), 1, 1024), clampi(ceili((b.size.z + 4.0) / CELL), 1, 1024))
	for i in 2:
		var image := Image.create(_cells.x, _cells.y, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		_images.append(image)
		_textures.append(ImageTexture.create_from_image(image))
	_box_query = PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL * 0.9, 0.5, CELL * 0.9)
	_box_query.shape = box
	_box_query.collision_mask = Layers.WORLD | Layers.WALKWAY
	var start := 0
	if player != null and is_instance_valid(player):
		start = clampi(int((player.global_position.z - _origin.y) / CELL), 0, _cells.y - 1)
	for row in _cells.y:
		_rows.append(row)
	_rows.sort_custom(func(a: int, b: int) -> bool: return absi(a - start) > absi(b - start))
	_rows_total = _rows.size()
	_material.set_shader_parameter("map_tex", _textures[0])
	return true


func _physics_process(_delta: float) -> void:
	# Wait for your player (the plan fills in outwards from where you start).
	if progress >= 1.0 or player == null:
		return
	# Nobody sees it without a screen (tests, headless peers); rasterise_now() still works.
	if DisplayServer.get_name() == "headless":
		return
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	if not _begin():
		return
	_step(STEP_BUDGET_MS)


## Probes whole rows until the time budget runs out (rows are popped off the end).
func _step(budget_ms: float) -> void:
	var started := Time.get_ticks_usec()
	var space := level.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if Run.instance != null:
		for other in Run.instance.all_players():
			exclude.append(other.get_rid())
	_box_query.exclude = exclude
	var low := _images[0]
	var high := _images[1]
	var floor_y := level.bounds.position.y - 1.0
	while not _rows.is_empty() and (Time.get_ticks_usec() - started) / 1000.0 < budget_ms:
		# A row is done 48 cells at a time so a wide map can't blow the budget.
		var cy: int = _rows.back()
		var z := _origin.y + (cy + 0.5) * CELL
		var end := mini(_col + 48, _cells.x)
		for cx in range(_col, end):
			var x := _origin.x + (cx + 0.5) * CELL
			var ground := _probe(space, exclude, x, z, 0.0, floor_y)
			low.set_pixel(cx, cy, ground)
			var upper := _probe(space, exclude, x, z, UPPER_BASE, UPPER_SPLIT)
			if upper.a <= 0.0:
				upper = Color(ground.r * COL_BELOW, ground.g * COL_BELOW, ground.b * COL_BELOW, ground.a)
			high.set_pixel(cx, cy, upper)
		_col = end
		if _col >= _cells.x:
			_col = 0
			_rows.pop_back()
	progress = 1.0 - float(_rows.size()) / float(_rows_total)
	# Uploading is the slow part: only the storey on show, every few steps, then both.
	_steps += 1
	if progress >= 1.0:
		for i in 2:
			_textures[i].update(_images[i])
	elif _steps % 4 == 1:
		var i := 1 if player != null and is_instance_valid(player) and player.global_position.y > UPPER_SPLIT else 0
		_textures[i].update(_images[i])


## One cell of one storey: a wall at chest height, else a floor (shaded by how far it
## is below the storey's base), else nothing.
func _probe(space: PhysicsDirectSpaceState3D, exclude: Array[RID], x: float, z: float, base: float, bottom: float) -> Color:
	_box_query.transform = Transform3D(Basis.IDENTITY, Vector3(x, base + 1.35, z))
	if not space.intersect_shape(_box_query, 1).is_empty():
		return COL_WALL
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x, base + 2.4, z), Vector3(x, bottom, z), Layers.WORLD | Layers.WALKWAY, exclude)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return Color(0, 0, 0, 0)
	var h: float = hit.position.y - base
	if h < -0.45:
		return COL_PIT
	if h > 0.45:
		return COL_HIGH
	return COL_FLOOR


# --- Per frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if not visible or player == null or not is_instance_valid(player):
		return
	if _images.is_empty() and not _begin():
		return
	var pos := player.global_position
	var forward := _flat(-player.global_basis.z)
	var right := Vector2(-forward.y, forward.x)
	fuzz = _dream_fuzz(pos)
	_jitter = 0.0 if fuzz < 0.95 else sin(_clock * 23.0) * 40.0 + sin(_clock * 3.1) * 70.0
	var upper := pos.y > UPPER_SPLIT
	_material.set_shader_parameter("map_tex", _textures[1 if upper else 0])
	var span := Vector2(_cells) * CELL
	var reach: float = RANGE[mode] if mode != Mode.HIDDEN else RANGE[Mode.SMALL]
	_material.set_shader_parameter("centre_uv", (Vector2(pos.x, pos.z) - _origin) / span)
	_material.set_shader_parameter("right_uv", right * reach / span)
	_material.set_shader_parameter("down_uv", -forward * reach / span)
	_material.set_shader_parameter("fuzz", fuzz)
	_material.set_shader_parameter("clock", _clock)
	# No screen, no text to lay out every frame (headless tests and peers).
	if DisplayServer.get_name() == "headless":
		return
	_overlay.queue_redraw()
	if _strip != null:
		_strip.queue_redraw()


## Compass bearing the player faces: 0 = north (-z), 90 = east (+x).
func heading() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var f := _flat(-player.global_basis.z)
	return fposmod(rad_to_deg(atan2(f.x, -f.y)), 360.0)


static func bearing_name(degrees: float) -> String:
	return BEARING_NAMES[int(round(fposmod(degrees, 360.0) / 45.0)) % 8]


## Where world point `at` lands on the disc (centre = you), in metres before scaling.
func _to_disc(at: Vector3) -> Vector2:
	var pos := player.global_position
	var forward := _flat(-player.global_basis.z)
	var right := Vector2(-forward.y, forward.x)
	var d := Vector2(at.x - pos.x, at.z - pos.z)
	return Vector2(d.dot(right), -d.dot(forward))


func _flat(v: Vector3) -> Vector2:
	var f := Vector2(v.x, v.z)
	return f.normalized() if f.length() > 0.001 else Vector2(0, -1)


## The dream map: always a little unsteady, worse as clarity drops, pure static in the
## repeating stretch of the white corridor.
func _dream_fuzz(pos: Vector3) -> float:
	if not (level is EndlessAfternoon):
		return 0.0
	if absf(pos.z) < EndlessAfternoon.CORRIDOR_HALF + 0.4 and absf(pos.x) > EndlessAfternoon.LOOP_AT - EndlessAfternoon.LOOP_PERIOD - 1.0 \
			and pos.y < EndlessAfternoon.ROOM_H:
		return 1.0
	return clampf(0.18 + player.map_dream * 0.6 + 0.08 * sin(_clock * 0.7), 0.0, 0.9)


func _exit_point() -> Variant:
	if level == null or not is_instance_valid(level) or not level.objective_on:
		return null
	var zone := level.extraction_zone
	if zone == null or not is_instance_valid(zone) or not zone.is_inside_tree():
		return null
	return zone.global_position


func _teammates() -> Array[Player]:
	var result: Array[Player] = []
	if Run.instance == null:
		return result
	for other in Run.instance.all_players():
		if other != player and other.squad == player.squad and other.is_active():
			result.append(other)
	return result


# --- Drawing --------------------------------------------------------------------------

func _draw_overlay() -> void:
	if mode == Mode.HIDDEN or player == null or not is_instance_valid(player):
		return
	var d: float = DIAMETER[mode]
	var radius := d / 2.0
	var centre := Vector2(radius, radius)
	var reach: float = RANGE[mode]
	var scale := radius / reach
	var font := UiKit.bold_font()
	var static_on := fuzz >= 0.95

	if progress < 1.0:
		_outlined(font, centre + Vector2(0, radius * 0.62), "掃描中 %d%%" % int(progress * 100.0), 12, UiKit.DIM)

	if not static_on:
		# Squadmates: blue dots (pinned to the rim, hollow, when out of range).
		for mate in _teammates():
			var at := _to_disc(mate.global_position) * scale
			var edge := at.length() > radius - 9.0
			if edge:
				at = at.normalized() * (radius - 9.0)
			_overlay.draw_circle(centre + at, 5.0, Color(0, 0, 0, 0.9))
			if edge:
				_overlay.draw_arc(centre + at, 3.5, 0.0, TAU, 12, UiKit.COLD, 1.5)
			else:
				_overlay.draw_circle(centre + at, 3.5, UiKit.COLD)
		# The open exit: a green pad, or a chevron on the rim pointing at it.
		var exit = _exit_point()
		if exit != null:
			var at := _to_disc(exit) * scale
			var pulse := 0.75 + 0.25 * sin(_clock * 5.0)
			var green := Color(UiKit.GOOD, pulse)
			if at.length() > radius - 12.0:
				var dir := at.normalized()
				var tip := centre + dir * (radius - 4.0)
				var side := Vector2(-dir.y, dir.x)
				var tri := PackedVector2Array([tip + dir * 1.5, tip - dir * 15.0 + side * 9.5, tip - dir * 15.0 - side * 9.5])
				_overlay.draw_colored_polygon(tri, Color(0, 0, 0, 0.9))
				var inner := PackedVector2Array([tip - dir * 1.0, tip - dir * 12.5 + side * 6.5, tip - dir * 12.5 - side * 6.5])
				_overlay.draw_colored_polygon(inner, green)
			else:
				var s := maxf(2.6 * scale * 0.5, 5.0)
				_overlay.draw_rect(Rect2(centre + at - Vector2(s + 2, s + 2), Vector2(s + 2, s + 2) * 2.0), Color(0, 0, 0, 0.85))
				_overlay.draw_rect(Rect2(centre + at - Vector2(s, s), Vector2(s, s) * 2.0), green, false, 2.0)
				_outlined(font, centre + at + Vector2(0, 4), "出", 11, green)

	# North, east, south, west round the inside of the rim; 北 in hot pink.
	var turn := deg_to_rad(heading() + _jitter)
	for i in 4:
		var bearing := turn - i * PI / 2.0
		# Bearing b in the world sits at screen angle (b - heading) from up, clockwise.
		var dir := Vector2(sin(-bearing), -cos(-bearing))
		var at := centre + dir * (radius - 13.0)
		var color := UiKit.HOT if i == 0 else UiKit.TEXT
		_overlay.draw_circle(at, 9.5, Color(0, 0, 0, 0.7))
		_outlined(font, at + Vector2(0, 5), ["北", "東", "南", "西"][i], 14 if i == 0 else 12, color)

	# You: an acid arrow pointing up (the way you face).
	var arrow := PackedVector2Array([centre + Vector2(0, -9), centre + Vector2(6.5, 7), centre + Vector2(0, 3.5), centre + Vector2(-6.5, 7)])
	var shadow := PackedVector2Array([centre + Vector2(0, -12), centre + Vector2(9, 9.5), centre + Vector2(0, 5.5), centre + Vector2(-9, 9.5)])
	_overlay.draw_colored_polygon(shadow, Color(0, 0, 0, 0.9))
	_overlay.draw_colored_polygon(arrow, UiKit.ACCENT)

	# Under the disc: which way you face, and the key.
	var h := heading() + _jitter
	var caption := "%s %03d°" % [bearing_name(h), int(round(fposmod(h, 360.0))) % 360] if not static_on else "？？？"
	_overlay.draw_rect(Rect2(Vector2(radius - 64.0, d + 2.0), Vector2(128.0, 20.0)), Color(0.02, 0.02, 0.025, 0.6))
	_outlined(font, Vector2(radius - 14.0, d + 16.0), caption, 13, UiKit.TEXT if not static_on else UiKit.HOT)
	var key_x := radius + 30.0
	var key_rect := Rect2(Vector2(key_x, d + 4.0), Vector2(16, 16))
	_overlay.draw_rect(key_rect, Color(0, 0, 0, 0.7))
	_overlay.draw_rect(key_rect, UiKit.DIM, false, 1.0)
	_outlined(font, key_rect.get_center() + Vector2(0, 4.5), "M", 11, UiKit.DIM)


## Thin heading tape at the top centre: ticks every 15°, 北東南西 at the cardinals,
## a green diamond towards the open exit.
func _draw_strip() -> void:
	if player == null or not is_instance_valid(player):
		return
	var w := STRIP_SIZE.x
	var h := STRIP_SIZE.y
	var static_on := fuzz >= 0.95
	var head := heading() + _jitter
	var font := UiKit.bold_font()
	_strip.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.02, 0.02, 0.025, 0.5))
	_strip.draw_line(Vector2(0, h), Vector2(w, h), Color(1, 1, 1, 0.25), 1.0)
	var per := w / STRIP_SPAN
	var first := int(floor((head - STRIP_SPAN / 2.0) / 15.0)) * 15
	var deg := first
	while deg <= head + STRIP_SPAN / 2.0:
		var x := w / 2.0 + (deg - head) * per
		if x >= 0.0 and x <= w:
			var fade := 1.0 - absf(x - w / 2.0) / (w / 2.0) * 0.7
			var b := posmod(deg, 360)
			if b % 90 == 0:
				var color := UiKit.HOT if b == 0 else UiKit.TEXT
				_outlined(font, Vector2(x, 16.0), ["北", "東", "南", "西"][b / 90], 14, Color(color, fade), _strip)
			elif b % 45 == 0:
				_strip.draw_line(Vector2(x, h - 9.0), Vector2(x, h), Color(UiKit.TEXT, 0.8 * fade), 2.0)
			else:
				_strip.draw_line(Vector2(x, h - 5.0), Vector2(x, h), Color(UiKit.DIM, 0.7 * fade), 1.0)
		deg += 15
	if not static_on:
		var exit = _exit_point()
		if exit != null:
			var to := Vector2(exit.x - player.global_position.x, exit.z - player.global_position.z)
			var bearing := rad_to_deg(atan2(to.x, -to.y))
			var off := wrapf(bearing - head, -180.0, 180.0)
			var x := clampf(w / 2.0 + off * per, 6.0, w - 6.0)
			var diamond := PackedVector2Array([Vector2(x, 2), Vector2(x + 5, 7), Vector2(x, 12), Vector2(x - 5, 7)])
			_strip.draw_colored_polygon(diamond, UiKit.GOOD)
	# The caret: where you face.
	var caret := PackedVector2Array([Vector2(w / 2.0, h - 6.0), Vector2(w / 2.0 + 5.0, h + 2.0), Vector2(w / 2.0 - 5.0, h + 2.0)])
	_strip.draw_colored_polygon(caret, UiKit.ACCENT)


## Centred text with a black outline. `at` is the baseline centre.
func _outlined(font: Font, at: Vector2, text: String, font_size: int, color: Color, canvas: CanvasItem = null) -> void:
	var target: CanvasItem = canvas if canvas != null else _overlay
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at - Vector2(width / 2.0, 0.0)
	target.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9 * color.a))
	target.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
