class_name UiKit
## Shared look for every menu and the HUD: a small punk palette (bone text, acid
## green and hot pink on black grime), chunky display font, thin translucent panels,
## and the animated backdrop / CRT overlay shaders.

const INK := Color(0.03, 0.028, 0.034)
const TEXT := Color(0.93, 0.9, 0.82)
const DIM := Color(0.6, 0.58, 0.55)
const ACCENT := Color(0.78, 1.0, 0.16)
const HOT := Color(1.0, 0.18, 0.44)
const DANGER := Color(1.0, 0.3, 0.26)
const GOOD := Color(0.45, 1.0, 0.6)
const COLD := Color(0.5, 0.85, 1.0)
const WARN := Color(1.0, 0.72, 0.25)

const BACKDROP_SHADER := preload("res://shaders/ui_backdrop.gdshader")
const CRT_SHADER := preload("res://shaders/ui_crt.gdshader")
const HAZARD_SHADER := preload("res://shaders/ui_hazard.gdshader")

static var _display_font: FontVariation
static var _logo_font: FontVariation
static var _bold_font: FontVariation


## Slanted, heavier variant of the default font for big headings and buttons.
## Kept moderate so dense Chinese glyphs don't clog up.
static func display_font() -> Font:
	if _display_font == null:
		_display_font = FontVariation.new()
		_display_font.base_font = ThemeDB.fallback_font
		_display_font.variation_embolden = 0.55
		_display_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2.ZERO)
		_display_font.spacing_glyph = 1
	return _display_font


## Extra-chunky slanted face for the Latin HAIKAI logo.
static func logo_font() -> Font:
	if _logo_font == null:
		_logo_font = FontVariation.new()
		_logo_font.base_font = ThemeDB.fallback_font
		_logo_font.variation_embolden = 1.15
		_logo_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
		_logo_font.spacing_glyph = 2
	return _logo_font


## Slightly heavier default font for buttons and HUD numbers.
static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = ThemeDB.fallback_font
		_bold_font.variation_embolden = 0.6
	return _bold_font


static func label(text: String, size := 18, color := TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	result.add_theme_constant_override("outline_size", maxi(2, size / 6))
	return result


## Big slanted heading in the display font.
static func title(text: String, size := 48, color := ACCENT) -> Label:
	var result := label(text, size, color)
	result.add_theme_font_override("font", display_font())
	result.add_theme_constant_override("outline_size", maxi(4, size / 5))
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	return result


## Small section heading: an acid block, then the text.
static func heading(text: String, note := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var block := ColorRect.new()
	block.color = ACCENT
	block.custom_minimum_size = Vector2(10, 10)
	block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(block)
	var main := label(text, 17, ACCENT)
	main.add_theme_font_override("font", bold_font())
	row.add_child(main)
	if note != "":
		row.add_child(label(note, 14, DIM))
	return row


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_font_override("font", bold_font())
	style_button(result, "normal")
	result.pressed.connect(on_pressed)
	return result


## Primary action: filled acid, black text.
static func primary_button(text: String, on_pressed: Callable) -> Button:
	var result := button(text, on_pressed)
	style_button(result, "primary")
	return result


## Restyles a button. state: "normal", "primary", "loud" (dark, turns acid on focus),
## "selected" (equipped / toggled on), or "locked" (can't afford).
static func style_button(target: Button, state: String) -> void:
	var back := Color(0.05, 0.045, 0.055, 0.82)
	var edge := Color(1.0, 1.0, 1.0, 0.16)
	var text := TEXT
	var hover_back := Color(0.12, 0.13, 0.06, 0.92)
	var hover_edge := ACCENT
	var hover_text := ACCENT
	match state:
		"primary":
			back = ACCENT
			edge = ACCENT
			text = INK
			hover_back = Color(0.9, 1.0, 0.5)
			hover_edge = HOT
			hover_text = INK
		"loud":
			hover_back = ACCENT
			hover_edge = HOT
			hover_text = INK
		"selected":
			back = Color(0.16, 0.2, 0.04, 0.92)
			edge = ACCENT
			text = ACCENT
		"locked":
			text = Color(0.5, 0.48, 0.46)
	var normal := _box(back, edge, 1)
	normal.border_width_left = 3
	var hover := _box(hover_back, hover_edge, 1)
	hover.border_width_left = 8 if state == "loud" else 5
	var pressed := _box(HOT, HOT, 1)
	var disabled := _box(Color(0.05, 0.05, 0.05, 0.6), Color(1, 1, 1, 0.06), 1)
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("focus", hover)
	target.add_theme_stylebox_override("pressed", pressed)
	target.add_theme_stylebox_override("hover_pressed", pressed)
	target.add_theme_stylebox_override("disabled", disabled)
	target.add_theme_color_override("font_color", text)
	target.add_theme_color_override("font_hover_color", hover_text)
	target.add_theme_color_override("font_focus_color", hover_text)
	target.add_theme_color_override("font_pressed_color", INK)
	target.add_theme_color_override("font_hover_pressed_color", INK)
	target.add_theme_color_override("font_disabled_color", Color(0.4, 0.39, 0.38))


static func line_edit(text: String, max_length := 32) -> LineEdit:
	var result := LineEdit.new()
	result.text = text
	result.max_length = max_length
	result.custom_minimum_size = Vector2(0, 40)
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_placeholder_color", Color(0.5, 0.48, 0.46))
	result.add_theme_color_override("caret_color", ACCENT)
	result.add_theme_color_override("selection_color", Color(HOT, 0.5))
	var box := _box(Color(0.0, 0.0, 0.0, 0.6), Color(1.0, 1.0, 1.0, 0.18), 1)
	box.set_content_margin_all(8)
	var focus := _box(Color(0.0, 0.0, 0.0, 0.7), ACCENT, 1)
	focus.border_width_bottom = 3
	focus.set_content_margin_all(8)
	result.add_theme_stylebox_override("normal", box)
	result.add_theme_stylebox_override("focus", focus)
	return result


## Thin translucent panel.
static func panel(margin := 14, edge := Color(1.0, 1.0, 1.0, 0.1)) -> PanelContainer:
	var result := PanelContainer.new()
	var box := _box(Color(0.02, 0.02, 0.025, 0.72), edge, 1)
	box.set_content_margin_all(margin)
	result.add_theme_stylebox_override("panel", box)
	return result


## A tilted sticker / tape strip with stencil-ish text.
static func sticker(text: String, back := ACCENT, fore := INK, size := 18, angle := -4.0) -> PanelContainer:
	var result := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	result.add_theme_stylebox_override("panel", box)
	var text_label := label(text, size, fore)
	text_label.add_theme_font_override("font", bold_font())
	text_label.add_theme_constant_override("outline_size", 0)
	result.add_child(text_label)
	result.rotation_degrees = angle
	return result


## Scrolling hazard stripes.
static func hazard_strip(height := 6.0, a := ACCENT, b := INK) -> ColorRect:
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(0, height)
	var material := ShaderMaterial.new()
	material.shader = HAZARD_SHADER
	material.set_shader_parameter("color_a", a)
	material.set_shader_parameter("color_b", b)
	strip.material = material
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return strip


## Animated grime/smoke/ember background filling `parent`.
static func add_backdrop(parent: Control, glow := 1.0, embers := 1.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = INK
	var material := ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	material.set_shader_parameter("glow", glow)
	material.set_shader_parameter("embers", embers)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## CRT / glitch overlay over everything already drawn in `parent`. Add it last.
static func add_crt(parent: Control, glitch := 0.25, scanlines := 0.16, aberration := 1.0) -> ColorRect:
	var rect := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = CRT_SHADER
	material.set_shader_parameter("glitch", glitch)
	material.set_shader_parameter("scanlines", scanlines)
	material.set_shader_parameter("aberration", aberration)
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## The menus' top bar: small logo, the screen's name, and a right-hand slot.
static func top_bar(screen_name: String) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	var logo := title("HAIKAI", 40, ACCENT)
	logo.add_theme_font_override("font", logo_font())
	bar.add_child(logo)
	var tag := sticker(screen_name, HOT, INK, 18, -3.0)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	return bar


## A key cap like [E], for HUD hints and prompts.
static func key_chip(key: String, size := 14) -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(TEXT, 0.92)
	box.set_corner_radius_all(2)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", box)
	var text := label(key, size, INK)
	text.add_theme_font_override("font", bold_font())
	text.add_theme_constant_override("outline_size", 0)
	chip.add_child(text)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


static func _box(back: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = back
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_content_margin_all(8)
	return box
