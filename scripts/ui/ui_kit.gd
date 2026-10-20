class_name UiKit
## Small helpers so every menu shares the same look.

const TEXT := Color(0.92, 0.86, 0.72)
const DIM := Color(0.7, 0.66, 0.58)
const ACCENT := Color(1.0, 0.72, 0.3)


static func label(text: String, size := 18, color := TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.12, 0.09)
	normal.border_color = Color(0.45, 0.32, 0.18)
	normal.set_border_width_all(2)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.18, 0.1)
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", hover)
	result.add_theme_stylebox_override("focus", normal)
	result.pressed.connect(on_pressed)
	return result
