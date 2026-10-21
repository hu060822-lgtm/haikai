class_name AwakeningMeter
extends Control
## The HUD's eye under the timer: how awake the ruin is. Three segments (沉睡 / 驚醒 /
## 暴走) fill as the level rises, coloured by stage, and the eye opens wider each stage.
## A shot makes the eye flinch so players learn that shooting wakes it. On a stage change
## it throws a big banner across the screen with a deep groan.
## Reads Run.instance.awakening every frame; works on any peer.

const SIZE := Vector2(236.0, 34.0)
const EYE_W := 40.0
const SEG_GAP := 4.0
const BANNER_TIME := 4.5
const BANNERS := [
	["", ""],
	["廢墟驚醒了…", "怪物聽得更遠、看得更遠，也更快了。有新的東西醒過來了。"],
	["廢墟暴走了！", "所有怪物都在找你。撤離電梯要等兩倍久。"],
]

var level := 0.0
var stage := 0
## Seconds left on the shot flinch.
var flinch := 0.0
var _flinch_amount := 1.0
var _clock := 0.0
var _bound: Awakening
var _name: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_time := 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 15)
	_name.add_theme_font_override("font", UiKit.bold_font())
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name.add_theme_constant_override("outline_size", 4)
	_name.position = Vector2(SIZE.x - 36.0, 5.0)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)


## The big stage-change banner lives in the HUD's full-screen root.
func attach_banner(root: Control) -> void:
	_banner = VBoxContainer.new()
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_top = -170.0
	_banner.offset_bottom = -60.0
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_override("font", UiKit.display_font())
	_banner_title.add_theme_font_size_override("font_size", 64)
	_banner_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_banner_title.add_theme_constant_override("outline_size", 10)
	_banner.add_child(_banner_title)
	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 20)
	_banner_sub.add_theme_color_override("font_color", UiKit.TEXT)
	_banner_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_banner_sub.add_theme_constant_override("outline_size", 6)
	_banner.add_child(_banner_sub)
	_banner.visible = false


## A stage was just reached: the banner and the groan.
func show_stage(new_stage: int) -> void:
	stage = maxi(stage, new_stage)
	if _banner == null or new_stage <= 0 or new_stage >= BANNERS.size():
		return
	_banner_title.text = BANNERS[new_stage][0]
	_banner_sub.text = BANNERS[new_stage][1]
	_banner_title.add_theme_color_override("font_color", Awakening.STAGE_COLORS[new_stage])
	_banner_time = BANNER_TIME
	_banner.visible = true
	_banner.modulate.a = 1.0
	if is_inside_tree():
		Sfx.play_2d(self, "awaken", 2.0 if new_stage == 2 else 0.0, 0.8 if new_stage == 2 else 1.0)


## The local player fired: the eye flinches open (bigger for loud guns).
func flinch_at(amount: float) -> void:
	flinch = 0.6
	_flinch_amount = amount


func _process(delta: float) -> void:
	_clock += delta
	flinch = maxf(flinch - delta, 0.0)
	var awake: Awakening = Run.instance.awakening if Run.instance != null and is_instance_valid(Run.instance) else null
	if awake != _bound:
		_bound = awake
		if awake != null:
			stage = awake.stage
			awake.stage_changed.connect(show_stage)
			awake.shot_woke.connect(flinch_at)
	if awake != null:
		level = awake.level
		stage = maxi(stage, awake.stage)
	_name.text = Awakening.STAGE_NAMES[stage]
	_name.add_theme_color_override("font_color", Awakening.STAGE_COLORS[stage])
	if _banner != null and _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.8, 0.0, 1.0)
		var shake := clampf(_banner_time - (BANNER_TIME - 0.6), 0.0, 0.6) * 10.0
		var jitter := randf_range(-shake, shake)
		_banner.offset_left = -500.0 + jitter
		_banner.offset_right = 500.0 + jitter
		if _banner_time <= 0.0:
			_banner.visible = false
	queue_redraw()


func _draw() -> void:
	var color: Color = Awakening.STAGE_COLORS[stage]
	var centre := Vector2(EYE_W * 0.5, SIZE.y * 0.5)
	# The eye: lids open wider each stage, and wide open for a moment after a shot.
	var open := [0.25, 0.6, 1.0][stage] as float
	var pulse := 0.0
	if flinch > 0.0:
		pulse = sin(flinch / 0.6 * PI) * clampf(_flinch_amount, 0.3, 1.0)
		open = minf(open + pulse * 0.8, 1.15)
	if stage == 2:
		open *= 0.9 + 0.1 * sin(_clock * 7.0)
	var half_w := EYE_W * 0.5 - 1.0
	var half_h := 10.0 * open + 1.0
	var outline := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		var x := lerpf(-half_w, half_w, t)
		outline.append(centre + Vector2(x, -half_h * sin(t * PI)))
	for i in range(15, 0, -1):
		var t := float(i) / 16.0
		var x := lerpf(-half_w, half_w, t)
		outline.append(centre + Vector2(x, half_h * sin(t * PI)))
	draw_colored_polygon(outline, Color(0.05, 0.03, 0.03, 0.85))
	var iris := minf(half_h, 8.0)
	if iris > 1.5:
		draw_circle(centre, iris, color.darkened(0.15))
		draw_circle(centre, iris * (0.35 if stage < 2 else 0.22), Color(0.02, 0.0, 0.0))
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, color.lerp(Color.WHITE, pulse * 0.6), 2.0, true)
	if pulse > 0.05:
		draw_arc(centre, half_w + 4.0 * pulse, 0.0, TAU, 20, Color(color, pulse * 0.7), 2.0, true)

	# Three segments, each the span of one stage.
	var x0 := EYE_W + 8.0
	var width := SIZE.x - x0 - 40.0
	var seg_w := (width - SEG_GAP * 2.0) / 3.0
	for i in 3:
		var low: float = Awakening.FLOORS[i]
		var high: float = Awakening.FLOORS[i + 1] if i < 2 else Awakening.MAX_LEVEL
		var fill := clampf((level - low) / (high - low), 0.0, 1.0)
		var rect := Rect2(Vector2(x0 + i * (seg_w + SEG_GAP), SIZE.y * 0.5 - 5.0), Vector2(seg_w, 10.0))
		draw_rect(rect, Color(1, 1, 1, 0.12))
		if fill > 0.0:
			var seg_color: Color = Awakening.STAGE_COLORS[i]
			if i == stage and stage == 2:
				seg_color = seg_color.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_clock * 7.0)))
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), seg_color)
		draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
