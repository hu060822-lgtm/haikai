class_name LootTable
## Item definitions for the boiler factory. "rarity" is a relative roll weight.

const ITEMS := [
	{"name": "黃銅齒輪", "value": 35, "weight": 1.5, "rarity": 10, "size": Vector3(0.3, 0.3, 0.08), "texture": "brass", "color": Color(1.0, 0.9, 0.6)},
	{"name": "煤精石", "value": 25, "weight": 2.5, "rarity": 10, "size": Vector3(0.25, 0.2, 0.25), "texture": "concrete", "color": Color(0.35, 0.33, 0.38)},
	{"name": "銅線捲", "value": 45, "weight": 4.0, "rarity": 8, "size": Vector3(0.35, 0.2, 0.35), "texture": "pipe", "color": Color(1.0, 0.7, 0.5)},
	{"name": "壓力計", "value": 60, "weight": 1.0, "rarity": 6, "size": Vector3(0.22, 0.22, 0.1), "texture": "brass", "color": Color(0.9, 0.9, 0.85)},
	{"name": "蒸氣閥門", "value": 80, "weight": 6.0, "rarity": 5, "size": Vector3(0.4, 0.3, 0.4), "texture": "rust_metal", "color": Color(1.0, 1.0, 1.0)},
	{"name": "懷錶", "value": 120, "weight": 0.3, "rarity": 3, "size": Vector3(0.12, 0.12, 0.04), "texture": "brass", "color": Color(1.0, 0.95, 0.7)},
	{"name": "發條核心", "value": 180, "weight": 3.0, "rarity": 1, "size": Vector3(0.25, 0.25, 0.25), "texture": "brass", "color": Color(0.7, 1.0, 0.9)},
]


static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for item in ITEMS:
		total += item.rarity
	var pick := rng.randi_range(1, total)
	for item in ITEMS:
		pick -= item.rarity
		if pick <= 0:
			return item.duplicate()
	return ITEMS[0].duplicate()
