class_name Gear
## Carry-in gear definitions. "slot" is weapon (one per run) or boost (up to MAX_BOOSTS).
## Weapons only stun or slow big monsters, can knock medium ones down for a while, and
## can kill small ones, so monsters always stay on top (see Run._weapon).

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
	"boomerang": {
		"name": "迴力扳手", "slot": "weapon", "price": 120, "weight": 1.5,
		"desc": "丟出去會飛回來：打暈怪物一下，打到的地方會發出聲響。有時候沒接住就飛走了。",
	},
	"nail_gun": {
		"name": "釘槍", "slot": "weapon", "price": 150, "weight": 2.5, "ammo": 20,
		"desc": "連射釘子（20 發），能把小型怪釘死，中型怪會頓一下。噪音中等。",
	},
	"shock_glove": {
		"name": "電擊手套", "slot": "weapon", "price": 180, "weight": 1.0,
		"desc": "近戰電擊，讓中小型怪麻痺 3 秒（大型怪 1 秒）。用完要充電 15 秒。",
	},
	"megaphone": {
		"name": "擴音器「退散！」", "slot": "weapon", "price": 200, "weight": 1.5,
		"desc": "對前方大吼，震暈前方所有怪物 2 秒。超級大聲，整張地圖都聽得到。",
	},
	"flamethrower": {
		"name": "火焰噴射罐", "slot": "weapon", "price": 260, "weight": 4.0, "ammo": 6,
		"desc": "噴火逼退所有怪物、燒死鼠群和撲燈蛾（6 次）。會燒掉地上的物品。",
	},
	"shotgun": {
		"name": "獵槍", "slot": "weapon", "price": 300, "weight": 3.5, "ammo": 2,
		"desc": "只有 2 發：擊倒中型怪一陣子、讓大型怪踉蹌。槍聲會引來全圖的怪物。",
	},
	"rubber_duck": {
		"name": "爆炸橡皮鴨", "slot": "weapon", "price": 90, "weight": 0.6, "ammo": 2,
		"desc": "丟出去「嘎、嘎、嘎」把怪物引過去，然後爆炸（2 隻）。也會炸到隊友。",
	},
	"railgun": {
		"name": "磁軌加農炮", "slot": "weapon", "price": 800, "weight": 12.0, "ammo": 1,
		"desc": "按下充能 3 秒，一發貫穿直線上的一切，大型怪也會倒地 10 秒。只有 1 發，超重。",
	},
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

## What each weapon does when it connects, by monster size: "kill" or seconds of stun.
## range in metres; "cone" weapons hit everything in front (cos of the half angle).
const WEAPON_HITS := {
	"boomerang": {"range": 18.0, "small": 1.5, "medium": 1.5, "large": 0.5, "noise": 14.0},
	"nail_gun": {"range": 25.0, "small": "kill", "medium": 0.8, "large": 0.0, "noise": 10.0},
	"shock_glove": {"range": 2.6, "small": 3.0, "medium": 3.0, "large": 1.0, "noise": 5.0},
	"megaphone": {"range": 10.0, "cone": 0.5, "small": 2.0, "medium": 2.0, "large": 2.0, "noise": 50.0},
	"flamethrower": {"range": 5.0, "cone": 0.75, "small": "kill", "medium": 1.5, "large": 1.5, "noise": 12.0},
	"shotgun": {"range": 30.0, "small": "kill", "medium": 12.0, "large": 3.0, "noise": 60.0},
	"railgun": {"range": 60.0, "pierce": true, "small": "kill", "medium": 15.0, "large": 10.0, "noise": 40.0},
	"rubber_duck": {"range": 4.5, "small": "kill", "medium": 4.0, "large": 4.0, "noise": 30.0},
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
