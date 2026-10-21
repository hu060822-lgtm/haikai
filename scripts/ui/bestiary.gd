class_name Bestiary
extends Control
## 怪物圖鑑: every monster in the roster on its own card: name and size, how keenly it
## senses sound / light / motion (0-3 pips, MonsterRoster "senses"), its weakness in one
## line, and the organ it drops (an Arsenal part, see Organs) with what that organ does.
## Opened from the stash screen as a full-screen panel.

signal closed()

## The colour organs wear everywhere in the UI.
const ORGAN := Color(1.0, 0.5, 0.42)
const ORGAN_BACK := Color(0.42, 0.05, 0.05)
const SIZE_NAMES := {"small": "小型", "medium": "中型", "large": "大型"}
const SIZE_COLORS := {"small": UiKit.GOOD, "medium": UiKit.WARN, "large": UiKit.DANGER}
const SENSES := [["sound", "聲音"], ["light", "光"], ["motion", "動作"]]
## How to beat each monster, in one line.
const WEAKNESS := {
	"colossus": "每 40 秒要排氣 5 秒，這時看不見也聽不到；進不了通風管和小門。",
	"watcher": "只看得到會動的東西：停下來別動，或躲到屋頂、走道底下。",
	"centipede": "路線永遠一樣；聽到地板在震就躲進旁邊的房間。",
	"mother": "附近有音樂她就停下來聽；別在她面前跑。",
	"fog_walker": "粗鹽彈或灑粉讓它現形，現形時才打得痛；它不靠近帶冰的人。",
	"tuner": "任何聲音都能把它引走，音樂讓它錯亂；先和隊友約好暗號。",
	"child": "用提燈照到它就算你贏，還會留下禮物。",
	"greeter": "千萬別跑；按 E 回答它、拿東西給它看，它就會鞠躬離開。",
	"collector": "被追時丟一件東西在它旁邊，它會收下然後放過你。",
	"rats": "在牠們旁邊跳一下就嚇跑；怕爆炸和電弧。",
	"mannequin": "盯著它就不能動；多人時輪流盯。",
	"mimic": "會輕輕滴答響；開一槍或用小刀戳一下就死。",
	"hounds": "把背上長骨刺的頭犬打到重傷，整群就逃；背靠牆。",
	"weaver": "網在提燈下會反光；用火打牠連網一起燒，傷害加倍。",
	"shield_knight": "打沒有護甲的背；引牠衝去撞牆，牠會暈頭、盾牌垂下。",
	"stalker": "一被燈照到就定住變成實體；倒退走，用燈照著牠。",
	"eyes": "很脆弱；電擊、暈眩讓牠掉下來；等牠俯衝時再打。",
	"spitter": "打中發綠光的喉囊傷害三倍（蓄力時最大最好打）。",
	"burrower": "只聽得到一樓地面的聲音：爬高或蹲著走。只有立起來的肚子打得痛。",
	"splitter": "用火或爆炸打死它，就不會裂成小爬蟲。",
	"dropper": "提燈亮著它就不敢下來；被抓住時重新點燈或用火燒。",
	"screamer": "槍口對著它就叫不出來；趁它吸氣時一槍打掉。",
}

var _scroll: ScrollContainer
var _grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.018, 0.022, 0.97)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	page.add_child(head)
	head.add_child(UiKit.title("怪物圖鑑", 40, ORGAN))
	var note := UiKit.label("每隻怪物都比你強，但都有弱點。殺死（大型的打到崩潰）會掉出牠的器官：帶出去就是槍上的零件。", 15, UiKit.DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(note)
	var close := UiKit.button("✕ 關閉", func() -> void: closed.emit(); queue_free())
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(96, 40)
	close.add_theme_font_size_override("font_size", 16)
	head.add_child(close)
	page.add_child(UiKit.hazard_strip(4.0, ORGAN, UiKit.INK))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	for kind in kinds():
		_grid.add_child(_card(kind))


## Roster kinds shown: everything that can be drawn into a run, large ones first.
static func kinds() -> Array[String]:
	var result: Array[String] = []
	for size in ["large", "medium", "small"]:
		for kind: String in MonsterRoster.MONSTERS:
			var entry: Dictionary = MonsterRoster.MONSTERS[kind]
			if entry.get("size", "") == size and not entry.get("spawned_only", false):
				result.append(kind)
	return result


## Scrolls to a fraction of the list (0 top, 1 bottom); the screenshot tool uses it.
func scroll_to(fraction: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll.scroll_vertical = int((bar.max_value - bar.page) * clampf(fraction, 0.0, 1.0))


## "●●○" pips for a 0-3 sense value; "？" while the roster doesn't say.
static func pips(value) -> String:
	if value == null:
		return "？"
	var n := clampi(int(value), 0, 3)
	return "●".repeat(n) + "○".repeat(3 - n)


func _card(kind: String) -> Control:
	var entry: Dictionary = MonsterRoster.MONSTERS[kind]
	var size: String = entry.get("size", "medium")
	var card := UiKit.panel(10, Color(SIZE_COLORS.get(size, UiKit.DIM), 0.35))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var name_label := UiKit.title(str(entry.get("name", kind)), 24, UiKit.TEXT)
	top.add_child(name_label)
	top.add_child(UiKit.sticker(SIZE_NAMES.get(size, size), SIZE_COLORS.get(size, UiKit.DIM), UiKit.INK, 13, -3.0))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(filler)
	var senses: Dictionary = entry.get("senses", {})
	for sense: Array in SENSES:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.add_child(UiKit.label(sense[1], 13, UiKit.DIM))
		var value = senses.get(sense[0])
		var pip := UiKit.label(pips(value), 14, UiKit.ACCENT if value != null and int(value) >= 2 else UiKit.TEXT)
		box.add_child(pip)
		top.add_child(box)

	var weak := _rich(14)
	weak.text = "[color=#%s]弱點[/color]　%s" % [UiKit.GOOD.to_html(false), WEAKNESS.get(kind, "還沒有人活著回來說。")]
	column.add_child(weak)

	var organ_id := str(entry.get("organ", ""))
	var organ := Arsenal.part(organ_id)
	var line := _rich(14)
	if organ.is_empty():
		line.text = "[color=#%s]器官[/color]　沒有" % UiKit.DIM.to_html(false)
	else:
		var owned := GameState.owned(organ_id)
		var where := "大型：第一次打到崩潰時掉落" if size == "large" else "殺死時 %d%% 掉落" % roundi(Organs.DROP_CHANCE * 100.0)
		line.text = "[color=#%s]器官[/color]　[color=#%s]%s[/color]（%s）　[color=#%s]%s・%s[/color]\n%s" % [
			ORGAN.to_html(false), ORGAN.to_html(false), organ.name, Arsenal.SLOT_NAMES.get(organ.slot, ""),
			(UiKit.GOOD if owned > 0 else UiKit.DIM).to_html(false), "擁有 %d" % owned if owned > 0 else "還沒有", where,
			organ.get("desc", "")]
	column.add_child(line)
	return card


static func _rich(size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", UiKit.TEXT)
	label.add_theme_constant_override("line_separation", -2)
	return label
