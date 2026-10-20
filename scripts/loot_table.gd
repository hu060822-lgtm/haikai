class_name LootTable
## Item definitions (see design/HAIKAI-內容清單.md for the full 100).
## "rarity": 0 common, 1 uncommon, 2 rare, 3 legendary.
## "tags": fragile = loses value on hard landings, noisy = makes noise while carried,
## collect = worth more as a set (see SET_BONUSES).

const RARITY_WEIGHT := [60, 25, 10, 3]
const RARITY_NAMES := ["普通", "少見", "稀有", "傳說"]
const RARITY_COLORS := [Color(0.85, 0.82, 0.75), Color(0.5, 0.9, 0.5), Color(0.45, 0.7, 1.0), Color(1.0, 0.8, 0.3)]

const ITEMS := [
	{"id": 1, "name": "黃銅齒輪", "rarity": 0, "weight": 1.5, "value": 35, "size": Vector3(0.3, 0.3, 0.08), "texture": "brass", "color": Color(1.0, 0.9, 0.6), "tags": []},
	{"id": 2, "name": "煤精石", "rarity": 0, "weight": 2.5, "value": 25, "size": Vector3(0.25, 0.2, 0.25), "texture": "concrete", "color": Color(0.35, 0.33, 0.38), "tags": []},
	{"id": 3, "name": "銅線捲", "rarity": 0, "weight": 4.0, "value": 45, "size": Vector3(0.35, 0.2, 0.35), "texture": "pipe", "color": Color(1.0, 0.7, 0.5), "tags": []},
	{"id": 4, "name": "生鏽的扳手", "rarity": 0, "weight": 2.0, "value": 20, "size": Vector3(0.45, 0.06, 0.12), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 5, "name": "一隻襪子", "rarity": 0, "weight": 0.1, "value": 3, "size": Vector3(0.12, 0.3, 0.05), "texture": "concrete", "color": Color(0.9, 0.85, 0.95), "tags": ["collect"]},
	{"id": 6, "name": "半個三明治", "rarity": 0, "weight": 0.2, "value": 1, "size": Vector3(0.15, 0.06, 0.1), "texture": "brass", "color": Color(1.0, 0.95, 0.8), "tags": []},
	{"id": 7, "name": "過期的保險單", "rarity": 0, "weight": 0.1, "value": 5, "size": Vector3(0.2, 0.02, 0.28), "texture": "concrete", "color": Color(1.0, 1.0, 0.9), "tags": []},
	{"id": 8, "name": "貓的照片", "rarity": 0, "weight": 0.1, "value": 15, "size": Vector3(0.15, 0.02, 0.1), "texture": "concrete", "color": Color(1.0, 0.9, 0.8), "tags": []},
	{"id": 9, "name": "工人的便當盒", "rarity": 0, "weight": 1.0, "value": 12, "size": Vector3(0.25, 0.12, 0.15), "texture": "rust_metal", "color": Color(0.7, 0.8, 0.9), "tags": []},
	{"id": 10, "name": "安全守則手冊", "rarity": 0, "weight": 0.5, "value": 8, "size": Vector3(0.2, 0.04, 0.28), "texture": "brick", "color": Color(1.0, 0.9, 0.5), "tags": []},
	{"id": 11, "name": "發條鑰匙", "rarity": 0, "weight": 0.2, "value": 25, "size": Vector3(0.15, 0.04, 0.08), "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 20, "name": "電池", "rarity": 0, "weight": 0.3, "value": 18, "size": Vector3(0.08, 0.15, 0.08), "texture": "pipe", "color": Color(0.6, 0.8, 0.6), "tags": []},
	{"id": 22, "name": "罐頭（沒標籤）", "rarity": 0, "weight": 0.5, "value": 12, "size": Vector3(0.1, 0.14, 0.1), "texture": "rust_metal", "color": Color(0.9, 0.9, 0.9), "tags": []},
	{"id": 27, "name": "「世界最棒的老闆」馬克杯", "rarity": 0, "weight": 0.4, "value": 18, "size": Vector3(0.1, 0.12, 0.1), "texture": "concrete", "color": Color(1.0, 1.0, 1.0), "tags": ["fragile"]},
	{"id": 28, "name": "鐵桶", "rarity": 0, "weight": 3.0, "value": 22, "size": Vector3(0.35, 0.4, 0.35), "texture": "rust_metal", "color": Color.WHITE, "tags": ["noisy"]},
	{"id": 30, "name": "糖果罐", "rarity": 0, "weight": 1.0, "value": 28, "size": Vector3(0.15, 0.2, 0.15), "texture": "brass", "color": Color(1.0, 0.6, 0.8), "tags": ["noisy"]},
	{"id": 36, "name": "餐具組", "rarity": 0, "weight": 1.0, "value": 26, "size": Vector3(0.3, 0.05, 0.2), "texture": "brass", "color": Color(0.85, 0.85, 0.9), "tags": ["noisy"]},
	{"id": 37, "name": "舊報紙", "rarity": 0, "weight": 0.2, "value": 6, "size": Vector3(0.3, 0.02, 0.4), "texture": "concrete", "color": Color(0.95, 0.92, 0.8), "tags": []},
	{"id": 42, "name": "燈泡", "rarity": 0, "weight": 0.2, "value": 16, "size": Vector3(0.08, 0.12, 0.08), "texture": "concrete", "color": Color(1.0, 1.0, 0.8), "tags": ["fragile"]},
	{"id": 44, "name": "工會徽章", "rarity": 0, "weight": 0.2, "value": 40, "size": Vector3(0.08, 0.08, 0.02), "texture": "brass", "color": Color(1.0, 0.8, 0.4), "tags": []},
	{"id": 46, "name": "壓力計", "rarity": 1, "weight": 1.0, "value": 60, "size": Vector3(0.22, 0.22, 0.1), "texture": "brass", "color": Color(0.9, 0.9, 0.85), "tags": ["fragile"]},
	{"id": 47, "name": "蒸氣閥門", "rarity": 1, "weight": 6.0, "value": 80, "size": Vector3(0.4, 0.3, 0.4), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 48, "name": "會叫的黃銅鴨", "rarity": 1, "weight": 0.5, "value": 55, "size": Vector3(0.18, 0.16, 0.22), "texture": "brass", "color": Color(1.0, 0.95, 0.4), "tags": ["noisy"]},
	{"id": 49, "name": "很大的螺絲", "rarity": 1, "weight": 25.0, "value": 150, "size": Vector3(0.35, 1.2, 0.35), "texture": "rust_metal", "color": Color(0.8, 0.8, 0.85), "tags": []},
	{"id": 50, "name": "茶壺（還是熱的）", "rarity": 1, "weight": 2.0, "value": 70, "size": Vector3(0.25, 0.22, 0.2), "texture": "brass", "color": Color(0.8, 0.9, 1.0), "tags": ["fragile"]},
	{"id": 52, "name": "工頭的哨子", "rarity": 1, "weight": 0.2, "value": 45, "size": Vector3(0.1, 0.04, 0.04), "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 54, "name": "打卡機", "rarity": 1, "weight": 12.0, "value": 110, "size": Vector3(0.5, 0.6, 0.35), "texture": "rust_metal", "color": Color(0.8, 0.7, 0.6), "tags": ["noisy"]},
	{"id": 76, "name": "懷錶", "rarity": 2, "weight": 0.3, "value": 120, "size": Vector3(0.12, 0.12, 0.04), "texture": "brass", "color": Color(1.0, 0.95, 0.7), "tags": ["fragile"]},
	{"id": 79, "name": "「年度最安全工廠」獎盃", "rarity": 2, "weight": 5.0, "value": 160, "size": Vector3(0.25, 0.5, 0.25), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": ["fragile"]},
	{"id": 93, "name": "發條核心", "rarity": 3, "weight": 3.0, "value": 380, "size": Vector3(0.25, 0.25, 0.25), "texture": "brass", "color": Color(0.7, 1.0, 0.9), "tags": []},
]

## Bonus paid at extraction for complete sets: item id -> [set size, bonus per set].
const SET_BONUSES := {5: [2, 200]}


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


## Total payout for a list of extracted items, including set bonuses.
static func payout(items: Array) -> Dictionary:
	var total := 0
	var counts := {}
	for item in items:
		total += item.value
		counts[item.id] = counts.get(item.id, 0) + 1
	var bonus := 0
	for id in SET_BONUSES:
		var rule: Array = SET_BONUSES[id]
		bonus += (counts.get(id, 0) / rule[0]) * rule[1]
	return {"items": total, "bonus": bonus, "total": total + bonus}
