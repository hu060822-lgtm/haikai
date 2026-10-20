class_name Gear
## Carry-in boosts (up to MAX_BOOSTS per run). Weapons are Arsenal builds now (see
## scripts/weapons/arsenal.gd); info() also answers for frame and part ids so menus and
## the result screen can name anything a loadout holds.

const MAX_BOOSTS := 3

const ITEMS := {
	"adrenaline": {
		"name": "腎上腺素針", "slot": "boost", "price": 120, "weight": 0.2, "consumable": true,
		"desc": "按 Q 使用：體力回滿，10 秒內衝刺不耗體力。藥效退了以後 10 秒走得很慢。",
	},
	"spring_boots": {
		"name": "彈簧鞋", "slot": "boost", "price": 160, "weight": 1.0,
		"desc": "跳躍高度兩倍，從高處落下不會受傷，但落地聲音很大。",
	},
	"iron_lung": {
		"name": "鐵肺", "slot": "boost", "price": 200, "weight": 0.5,
		"desc": "體力上限多 50%。代價是衝刺時喘得很大聲。",
	},
	"night_goggles": {
		"name": "夜視護目鏡", "slot": "boost", "price": 250, "weight": 0.5,
		"desc": "關掉提燈時，黑暗裡也看得清楚。開著提燈會反光，沒有作用。夢核地圖裡沒用。",
	},
	"exoskeleton": {
		"name": "外骨骼背架", "slot": "boost", "price": 300, "weight": 3.0,
		"desc": "負重上限 +15kg，一個人就能搬重物。代價是不能蹲下。",
	},
	"heart_detector": {
		"name": "心跳偵測器", "slot": "boost", "price": 220, "weight": 0.5,
		"desc": "顯示 15 公尺內有幾個活物、在哪個方向。偵測不到擬態蟲和假人。",
	},
	"feather_cloak": {
		"name": "羽毛斗篷", "slot": "boost", "price": 140, "weight": 0.5,
		"desc": "在空中按住空白鍵可以緩緩滑翔下來。",
	},
	"rabbit_foot": {
		"name": "兔腳幸運符", "slot": "boost", "price": 180, "weight": 0.1,
		"desc": "這局會多出幾件稀有和傳說物品。但怪物也會多一隻。",
	},
	"second_life": {
		"name": "第二條命懷錶", "slot": "boost", "price": 500, "weight": 0.2,
		"desc": "死掉的瞬間自動倒轉 5 秒，回到 5 秒前的位置（一次）。用掉就碎了。",
	},
	"cat_eye": {
		"name": "貓眼藥水", "slot": "boost", "price": 100, "weight": 0.1, "consumable": true,
		"desc": "按 Q 使用：30 秒內看得到隱形的怪物（霧行者、躲起來的孩子）。之後畫面黑白 30 秒。",
	},
}

## Prices of the carry-in weapons from before builds, so old saves get refunded.
const LEGACY_WEAPONS := {
	"crowbar": 60, "slingshot": 40, "boomerang": 120, "nail_gun": 150, "shock_glove": 180,
	"megaphone": 200, "flamethrower": 260, "shotgun": 300, "rubber_duck": 90, "railgun": 800,
}


static func info(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	return Arsenal.FRAMES.get(id, Arsenal.PARTS.get(id, {}))


static func loadout_weight(loadout: Dictionary) -> float:
	var total := 0.0
	for id in loadout_ids(loadout):
		total += float(info(id).get("weight", 0.0))
	return total


## Every id a loadout ({"build", "boosts"}) is made of: the weapon's pieces, then boosts.
static func loadout_ids(loadout: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if typeof(loadout.get("build")) == TYPE_DICTIONARY:
		ids.append_array(Arsenal.ids(loadout.build))
	for id in loadout.get("boosts", []):
		ids.append(id)
	return ids
