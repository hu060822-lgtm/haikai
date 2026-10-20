class_name LootTable
## Item definitions (see design/HAIKAI-內容清單.md for the full 100).
## "rarity": 0 common, 1 uncommon, 2 rare, 3 legendary.
## "tags": fragile = loses value on hard landings, noisy = makes noise while carried,
## collect = worth more as a set (see SET_BONUSES), hot = hurts while carried,
## scratch = its real value is only revealed at extraction.
## "shape" (box if missing): see LootShapes.

const RARITY_WEIGHT := [60, 25, 10, 3]
const RARITY_NAMES := ["普通", "少見", "稀有", "傳說"]
const RARITY_COLORS := [Color(0.85, 0.82, 0.75), Color(0.5, 0.9, 0.5), Color(0.45, 0.7, 1.0), Color(1.0, 0.8, 0.3)]

const ITEMS := [
	{"id": 1, "name": "黃銅齒輪", "rarity": 0, "weight": 1.5, "value": 35, "size": Vector3(0.3, 0.3, 0.08), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.9, 0.6), "tags": []},
	{"id": 2, "name": "煤精石", "rarity": 0, "weight": 2.5, "value": 25, "size": Vector3(0.25, 0.2, 0.25), "shape": "sphere", "texture": "concrete", "color": Color(0.35, 0.33, 0.38), "tags": []},
	{"id": 3, "name": "銅線捲", "rarity": 0, "weight": 4.0, "value": 45, "size": Vector3(0.35, 0.2, 0.35), "shape": "cylinder", "texture": "pipe", "color": Color(1.0, 0.7, 0.5), "tags": []},
	{"id": 4, "name": "生鏽的扳手", "rarity": 0, "weight": 2.0, "value": 20, "size": Vector3(0.45, 0.06, 0.12), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 5, "name": "一隻襪子", "rarity": 0, "weight": 0.1, "value": 3, "size": Vector3(0.12, 0.3, 0.05), "texture": "concrete", "color": Color(0.9, 0.85, 0.95), "tags": ["collect"]},
	{"id": 6, "name": "半個三明治", "rarity": 0, "weight": 0.2, "value": 1, "size": Vector3(0.15, 0.06, 0.1), "texture": "brass", "color": Color(1.0, 0.95, 0.8), "tags": []},
	{"id": 7, "name": "過期的保險單", "rarity": 0, "weight": 0.1, "value": 5, "size": Vector3(0.2, 0.02, 0.28), "texture": "concrete", "color": Color(1.0, 1.0, 0.9), "tags": []},
	{"id": 8, "name": "貓的照片", "rarity": 0, "weight": 0.1, "value": 15, "size": Vector3(0.15, 0.02, 0.1), "texture": "concrete", "color": Color(1.0, 0.9, 0.8), "tags": []},
	{"id": 9, "name": "工人的便當盒", "rarity": 0, "weight": 1.0, "value": 12, "size": Vector3(0.25, 0.12, 0.15), "texture": "rust_metal", "color": Color(0.7, 0.8, 0.9), "tags": []},
	{"id": 10, "name": "安全守則手冊", "rarity": 0, "weight": 0.5, "value": 8, "size": Vector3(0.2, 0.04, 0.28), "texture": "brick", "color": Color(1.0, 0.9, 0.5), "tags": []},
	{"id": 11, "name": "發條鑰匙", "rarity": 0, "weight": 0.2, "value": 25, "size": Vector3(0.15, 0.04, 0.08), "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 20, "name": "電池", "rarity": 0, "weight": 0.3, "value": 18, "size": Vector3(0.08, 0.15, 0.08), "shape": "cylinder", "texture": "pipe", "color": Color(0.6, 0.8, 0.6), "tags": []},
	{"id": 22, "name": "罐頭（沒標籤）", "rarity": 0, "weight": 0.5, "value": 12, "size": Vector3(0.1, 0.14, 0.1), "shape": "cylinder", "texture": "rust_metal", "color": Color(0.9, 0.9, 0.9), "tags": []},
	{"id": 27, "name": "「世界最棒的老闆」馬克杯", "rarity": 0, "weight": 0.4, "value": 18, "size": Vector3(0.1, 0.12, 0.1), "shape": "cylinder", "texture": "concrete", "color": Color(1.0, 1.0, 1.0), "tags": ["fragile"]},
	{"id": 28, "name": "鐵桶", "rarity": 0, "weight": 3.0, "value": 22, "size": Vector3(0.35, 0.4, 0.35), "shape": "cylinder", "texture": "rust_metal", "color": Color.WHITE, "tags": ["noisy"]},
	{"id": 30, "name": "糖果罐", "rarity": 0, "weight": 1.0, "value": 28, "size": Vector3(0.15, 0.2, 0.15), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.6, 0.8), "tags": ["noisy"]},
	{"id": 36, "name": "餐具組", "rarity": 0, "weight": 1.0, "value": 26, "size": Vector3(0.3, 0.05, 0.2), "texture": "brass", "color": Color(0.85, 0.85, 0.9), "tags": ["noisy"]},
	{"id": 37, "name": "舊報紙", "rarity": 0, "weight": 0.2, "value": 6, "size": Vector3(0.3, 0.02, 0.4), "texture": "concrete", "color": Color(0.95, 0.92, 0.8), "tags": []},
	{"id": 42, "name": "燈泡", "rarity": 0, "weight": 0.2, "value": 16, "size": Vector3(0.08, 0.12, 0.08), "shape": "sphere", "texture": "concrete", "color": Color(1.0, 1.0, 0.8), "tags": ["fragile"]},
	{"id": 44, "name": "工會徽章", "rarity": 0, "weight": 0.2, "value": 40, "size": Vector3(0.08, 0.08, 0.02), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.8, 0.4), "tags": []},
	{"id": 46, "name": "壓力計", "rarity": 1, "weight": 1.0, "value": 60, "size": Vector3(0.22, 0.22, 0.1), "shape": "cylinder", "texture": "brass", "color": Color(0.9, 0.9, 0.85), "tags": ["fragile"]},
	{"id": 47, "name": "蒸氣閥門", "rarity": 1, "weight": 6.0, "value": 80, "size": Vector3(0.4, 0.3, 0.4), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 48, "name": "會叫的黃銅鴨", "rarity": 1, "weight": 0.5, "value": 55, "size": Vector3(0.18, 0.16, 0.22), "texture": "brass", "color": Color(1.0, 0.95, 0.4), "tags": ["noisy"]},
	{"id": 49, "name": "很大的螺絲", "rarity": 1, "weight": 25.0, "value": 150, "size": Vector3(0.35, 1.2, 0.35), "shape": "cylinder", "texture": "rust_metal", "color": Color(0.8, 0.8, 0.85), "tags": []},
	{"id": 50, "name": "茶壺（還是熱的）", "rarity": 1, "weight": 2.0, "value": 70, "size": Vector3(0.25, 0.22, 0.2), "shape": "sphere", "texture": "brass", "color": Color(0.8, 0.9, 1.0), "tags": ["fragile"]},
	{"id": 52, "name": "工頭的哨子", "rarity": 1, "weight": 0.2, "value": 45, "size": Vector3(0.1, 0.04, 0.04), "shape": "capsule", "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 54, "name": "打卡機", "rarity": 1, "weight": 12.0, "value": 110, "size": Vector3(0.5, 0.6, 0.35), "texture": "rust_metal", "color": Color(0.8, 0.7, 0.6), "tags": ["noisy"]},
	{"id": 76, "name": "懷錶", "rarity": 2, "weight": 0.3, "value": 120, "size": Vector3(0.12, 0.12, 0.04), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.95, 0.7), "tags": ["fragile"]},
	{"id": 79, "name": "「年度最安全工廠」獎盃", "rarity": 2, "weight": 5.0, "value": 160, "size": Vector3(0.25, 0.5, 0.25), "shape": "cone", "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": ["fragile"]},
	{"id": 93, "name": "發條核心", "rarity": 3, "weight": 3.0, "value": 380, "size": Vector3(0.25, 0.25, 0.25), "shape": "sphere", "texture": "brass", "color": Color(0.7, 1.0, 0.9), "tags": []},
	{"id": 12, "name": "瓶中信", "rarity": 0, "weight": 0.5, "value": 15, "size": Vector3(0.08, 0.26, 0.08), "shape": "cylinder", "texture": "concrete", "color": Color(0.6, 0.85, 0.7), "tags": ["fragile"]},
	{"id": 13, "name": "濕掉的鈔票", "rarity": 0, "weight": 0.1, "value": 40, "size": Vector3(0.16, 0.01, 0.07), "texture": "concrete", "color": Color(0.55, 0.75, 0.5), "tags": []},
	{"id": 15, "name": "生日蛋糕（一片）", "rarity": 0, "weight": 0.5, "value": 30, "size": Vector3(0.12, 0.1, 0.16), "texture": "concrete", "color": Color(1.0, 0.85, 0.9), "tags": []},
	{"id": 16, "name": "蠟筆畫（畫了五個人）", "rarity": 0, "weight": 0.1, "value": 20, "size": Vector3(0.3, 0.01, 0.22), "texture": "concrete", "color": Color(1.0, 0.95, 0.85), "tags": []},
	{"id": 18, "name": "錄音帶", "rarity": 0, "weight": 0.3, "value": 30, "size": Vector3(0.1, 0.02, 0.065), "texture": "rust_metal", "color": Color(0.3, 0.3, 0.32), "tags": []},
	{"id": 19, "name": "塑膠恐龍", "rarity": 0, "weight": 0.3, "value": 10, "size": Vector3(0.08, 0.1, 0.16), "shape": "capsule", "texture": "concrete", "color": Color(0.4, 0.85, 0.35), "tags": ["collect"]},
	{"id": 21, "name": "舊手機（沒訊號）", "rarity": 0, "weight": 0.4, "value": 35, "size": Vector3(0.06, 0.14, 0.03), "texture": "rust_metal", "color": Color(0.25, 0.25, 0.28), "tags": []},
	{"id": 23, "name": "牙刷（用過的）", "rarity": 0, "weight": 0.05, "value": 2, "size": Vector3(0.02, 0.02, 0.18), "texture": "concrete", "color": Color(0.4, 0.7, 1.0), "tags": []},
	{"id": 25, "name": "撲克牌（少一張）", "rarity": 0, "weight": 0.1, "value": 10, "size": Vector3(0.065, 0.02, 0.09), "texture": "brick", "color": Color(0.9, 0.3, 0.3), "tags": []},
	{"id": 29, "name": "拖把", "rarity": 0, "weight": 1.5, "value": 6, "size": Vector3(0.05, 1.2, 0.05), "shape": "cylinder", "texture": "concrete", "color": Color(0.75, 0.65, 0.5), "tags": []},
	{"id": 33, "name": "收據一疊（全是泡麵）", "rarity": 0, "weight": 0.1, "value": 4, "size": Vector3(0.08, 0.04, 0.15), "texture": "concrete", "color": Color(1.0, 1.0, 0.95), "tags": []},
	{"id": 34, "name": "安全帽", "rarity": 0, "weight": 0.8, "value": 30, "size": Vector3(0.28, 0.18, 0.3), "shape": "sphere", "texture": "concrete", "color": Color(1.0, 0.8, 0.1), "tags": []},
	{"id": 35, "name": "迴紋針鏈", "rarity": 0, "weight": 0.05, "value": 5, "size": Vector3(0.4, 0.01, 0.03), "texture": "pipe", "color": Color(0.85, 0.85, 0.9), "tags": []},
	{"id": 40, "name": "毛線球", "rarity": 0, "weight": 0.3, "value": 9, "size": Vector3(0.14, 0.14, 0.14), "shape": "sphere", "texture": "brick", "color": Color(0.9, 0.4, 0.5), "tags": []},
	{"id": 45, "name": "搖搖晃晃的椅子腳", "rarity": 0, "weight": 1.0, "value": 7, "size": Vector3(0.05, 0.45, 0.05), "shape": "cylinder", "texture": "brick", "color": Color(0.6, 0.45, 0.3), "tags": []},
	{"id": 51, "name": "單片眼鏡", "rarity": 1, "weight": 0.1, "value": 65, "size": Vector3(0.05, 0.05, 0.01), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.9, 0.6), "tags": ["fragile"]},
	{"id": 53, "name": "滾燙的煤塊", "rarity": 1, "weight": 2.0, "value": 90, "size": Vector3(0.2, 0.16, 0.2), "texture": "concrete", "color": Color(1.0, 0.45, 0.2), "tags": ["hot"]},
	{"id": 55, "name": "布穀鳥鐘", "rarity": 1, "weight": 3.0, "value": 75, "size": Vector3(0.28, 0.4, 0.15), "texture": "brick", "color": Color(0.7, 0.5, 0.35), "tags": ["noisy"]},
	{"id": 57, "name": "永遠慢五分鐘的鐘", "rarity": 1, "weight": 3.0, "value": 85, "size": Vector3(0.35, 0.35, 0.08), "shape": "cylinder", "texture": "brass", "color": Color(0.95, 0.9, 0.8), "tags": []},
	{"id": 58, "name": "迷你船錨", "rarity": 1, "weight": 10.0, "value": 80, "size": Vector3(0.35, 0.5, 0.1), "texture": "rust_metal", "color": Color(0.6, 0.6, 0.65), "tags": []},
	{"id": 60, "name": "生鏽的船鐘", "rarity": 1, "weight": 6.0, "value": 95, "size": Vector3(0.3, 0.32, 0.3), "shape": "cone", "texture": "brass", "color": Color(0.8, 0.6, 0.4), "tags": ["noisy"]},
	{"id": 65, "name": "假人的手（手指會動）", "rarity": 1, "weight": 1.5, "value": 65, "size": Vector3(0.1, 0.05, 0.22), "texture": "concrete", "color": Color(0.92, 0.88, 0.82), "tags": []},
	{"id": 69, "name": "雪景球（小人在動）", "rarity": 1, "weight": 0.7, "value": 70, "size": Vector3(0.14, 0.16, 0.14), "shape": "sphere", "texture": "concrete", "color": Color(0.75, 0.9, 1.0), "tags": ["fragile"]},
	{"id": 72, "name": "黃金招財貓", "rarity": 1, "weight": 2.0, "value": 110, "size": Vector3(0.18, 0.26, 0.15), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": []},
	{"id": 74, "name": "一箱過期泡麵", "rarity": 1, "weight": 5.0, "value": 60, "size": Vector3(0.45, 0.3, 0.3), "texture": "brick", "color": Color(0.95, 0.75, 0.45), "tags": []},
	{"id": 78, "name": "金牙（不要問）", "rarity": 2, "weight": 0.05, "value": 140, "size": Vector3(0.03, 0.04, 0.03), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": []},
	{"id": 84, "name": "下水道鱷魚的牙", "rarity": 2, "weight": 0.3, "value": 150, "size": Vector3(0.05, 0.14, 0.05), "shape": "cone", "texture": "concrete", "color": Color(0.95, 0.92, 0.8), "tags": []},
	{"id": 90, "name": "鑽石戒指", "rarity": 2, "weight": 0.05, "value": 280, "size": Vector3(0.04, 0.04, 0.02), "shape": "cylinder", "texture": "brass", "color": Color(0.9, 0.95, 1.0), "tags": []},
	{"id": 91, "name": "一千塊的刮刮樂（沒刮）", "rarity": 2, "weight": 0.05, "value": 1, "size": Vector3(0.1, 0.01, 0.15), "texture": "brick", "color": Color(1.0, 0.9, 0.4), "tags": ["scratch"]},
	{"id": 98, "name": "黃金馬桶", "rarity": 3, "weight": 30.0, "value": 800, "size": Vector3(0.5, 0.75, 0.7), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": []},
]

## Bonus paid at extraction for complete sets: item id -> [set size, bonus per set].
const SET_BONUSES := {5: [2, 200], 19: [3, 150]}

const TAG_NAMES := {"fragile": "易碎", "noisy": "吵鬧", "hot": "燙手", "collect": "收集", "scratch": "特殊"}


## Rolls one item. luck shifts weight toward rarer items (0 = normal).
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var weights := []
	var total := 0.0
	for item in ITEMS:
		var w: float = RARITY_WEIGHT[item.rarity] * (1.0 + luck * item.rarity)
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in ITEMS.size():
		pick -= weights[i]
		if pick <= 0.0:
			return ITEMS[i].duplicate(true)
	return ITEMS[0].duplicate(true)


static func has_tag(data: Dictionary, tag: String) -> bool:
	return tag in data.get("tags", [])


## What the interaction prompt says about an item (real or a mimic pretending).
static func prompt(data: Dictionary) -> String:
	var tags := ""
	for tag in data.get("tags", []):
		if TAG_NAMES.has(tag):
			tags += "　" + TAG_NAMES[tag]
	return "[E] 撿起 %s　$%d　%.1fkg%s" % [data.get("name", "?"), data.get("value", 0), data.get("weight", 0.0), tags]


## A scratch card's prize: usually pocket change, sometimes a fortune.
static func scratch_prize(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	if roll < 0.5:
		return rng.randi_range(1, 20)
	if roll < 0.85:
		return rng.randi_range(20, 200)
	if roll < 0.98:
		return rng.randi_range(200, 1000)
	return rng.randi_range(1000, 5000)


## Total payout for a list of extracted items, including set bonuses.
## "items_list" is the items with scratch cards resolved to what they paid.
static func payout(items: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var total := 0
	var counts := {}
	var resolved := []
	for source in items:
		var item: Dictionary = source.duplicate(true)
		if has_tag(item, "scratch"):
			item.value = scratch_prize(rng)
			item.name += "→ 刮中 $%d" % item.value
		resolved.append(item)
		total += item.value
		counts[item.id] = counts.get(item.id, 0) + 1
	var bonus := 0
	for id in SET_BONUSES:
		var rule: Array = SET_BONUSES[id]
		bonus += (counts.get(id, 0) / rule[0]) * rule[1]
	return {"items": total, "bonus": bonus, "total": total + bonus, "items_list": resolved}
