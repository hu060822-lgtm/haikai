class_name Gear
## Carry-in gear definitions. "slot" is weapon (one per run) or boost (up to MAX_BOOSTS).

const MAX_BOOSTS := 3

const ITEMS := {
	"crowbar": {
		"name": "撬棍", "slot": "weapon", "price": 60, "weight": 2.5,
		"desc": "左鍵揮擊。可以撬開上鎖的櫃子，裡面有比較好的東西。揮空會發出聲音。",
	},
	"slingshot": {
		"name": "彈弓", "slot": "weapon", "price": 40, "weight": 0.5, "ammo": 12,
		"desc": "左鍵射出玻璃彈珠（12 發），落點會發出聲響，可以把怪物引開。",
	},
	"adrenaline": {
		"name": "腎上腺素針", "slot": "boost", "price": 120, "weight": 0.2, "consumable": true,
		"desc": "按 Q 使用：體力回滿，10 秒內衝刺不耗體力。藥效退了以後 10 秒走得很慢。",
	},
	"spring_boots": {
		"name": "彈簧鞋", "slot": "boost", "price": 160, "weight": 1.0,
		"desc": "跳躍高度兩倍，從高處落下不會受傷，但落地聲音很大。",
	},
}


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func loadout_weight(loadout: Dictionary) -> float:
	var total := 0.0
	for id in loadout_ids(loadout):
		total += ITEMS[id].weight
	return total


static func loadout_ids(loadout: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if loadout.get("weapon", "") != "":
		ids.append(loadout.weapon)
	for id in loadout.get("boosts", []):
		ids.append(id)
	return ids
