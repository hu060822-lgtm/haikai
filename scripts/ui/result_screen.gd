class_name ResultScreen
extends Control
## End-of-run summary: what you got out (or lost), and the money you have now.

signal continue_requested()

var survived := false
var cause := ""
var items: Array = []
var payout := {}
var lost_gear: Array = []
## From the session: {extracted, threshold, guardian_won, guardian}.
var summary := {}
var as_guardian := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.85)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(640, 0)
	column.position -= Vector2(320, 260)

	if as_guardian:
		var won: bool = summary.get("guardian_won", false)
		column.add_child(UiKit.label("守墓者勝利" if won else "他們逃掉了", 52, Color(0.55, 0.8, 1.0) if won else Color(0.9, 0.4, 0.3)))
		column.add_child(UiKit.label("搜刮者撤出 $%d，門檻 $%d" % [summary.get("extracted", 0), summary.get("threshold", 0)], 24))
		column.add_child(UiKit.label("守墓者報酬 +$%d" % (GameState.GUARDIAN_WIN_REWARD if won else GameState.GUARDIAN_LOSS_REWARD), 22, UiKit.ACCENT))
	elif survived:
		column.add_child(UiKit.label("撤離成功", 52, Color(0.55, 0.95, 0.6)))
		if items.is_empty():
			column.add_child(UiKit.label("空手而回。至少你還活著。", 20))
		else:
			var lines := []
			for item in items:
				lines.append("%s　$%d" % [item.name, item.value])
			var list := UiKit.label("\n".join(lines), 17, UiKit.DIM)
			column.add_child(list)
			if payout.bonus > 0:
				column.add_child(UiKit.label("湊成一組的獎勵　+$%d" % payout.bonus, 18, UiKit.ACCENT))
			column.add_child(UiKit.label("這次賺到 $%d" % payout.total, 30, UiKit.ACCENT))
	else:
		column.add_child(UiKit.label("你死了", 56, Color(0.9, 0.25, 0.2)))
		column.add_child(UiKit.label(cause, 22))
		column.add_child(UiKit.label("背包裡的 %d 件物品都留在工廠裡了。" % items.size(), 18, UiKit.DIM))
		if not lost_gear.is_empty():
			var names := []
			for id in lost_gear:
				names.append(Gear.info(id).name)
			column.add_child(UiKit.label("失去的裝備：" + "、".join(names), 18, UiKit.DIM))

	if not as_guardian and not summary.is_empty():
		var keeper: String = summary.get("guardian", "")
		var who := "守墓者「%s」" % keeper if keeper != "" else "AI 守墓者"
		var line := "全隊撤出 $%d／門檻 $%d：%s" % [summary.get("extracted", 0), summary.get("threshold", 0),
			who + "贏了" if summary.get("guardian_won", false) else "你們贏過了" + who]
		column.add_child(UiKit.label(line, 18, UiKit.DIM))
	column.add_child(UiKit.label("現在的錢：$%d" % GameState.money, 22))
	var button := UiKit.button("回到倉庫", func() -> void: continue_requested.emit())
	button.custom_minimum_size = Vector2(0, 52)
	column.add_child(button)
