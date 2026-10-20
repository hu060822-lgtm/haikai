class_name Arsenal
## Every weapon a scavenger can carry, and every part that bolts onto one.
## A weapon is a frame (the gun itself) plus up to one part per slot the frame has; the
## stash screen is where players put builds together, like modding a gun in Tarkov.
##   build = {"frame": "smg", "parts": {"muzzle": "suppressor", "magazine": "drum"}}
## Arsenal.stats(build) gives the finished numbers the game uses.
##
## Frames and parts are bought into the stash (GameState.stash, by id) and go into a run
## with the build: lost on death, back in the stash on extraction. The starter revolver
## is free and always there, and every scavenger also carries a knife (Player handles it),
## so nobody goes in unable to fight back.

const SLOTS := ["muzzle", "barrel", "sight", "magazine", "stock", "underbarrel", "ammo", "gadget"]
const SLOT_NAMES := {
	"muzzle": "槍口", "barrel": "槍管", "sight": "瞄具", "magazine": "彈匣", "stock": "槍托",
	"underbarrel": "下掛", "ammo": "彈藥", "gadget": "怪東西",
}

## Stats every frame defines:
##   damage    per projectile (monster health is in MonsterRoster; players have 100)
##   pellets   projectiles per shot
##   rate      shots per second (held trigger repeats when "auto")
##   mag       rounds before reloading; reserve = spare rounds carried in
##   reload    seconds
##   spread    degrees of random cone when hip-firing (aiming halves it)
##   range     metres
##   noise     radius in metres monsters hear the shot from
##   recoil    camera kick per shot, degrees
##   zoom      field-of-view divisor while aiming
##   weight    kg; price in $
##   kind      how a shot travels: hitscan, cone (flame), arc (chain lightning), lob
##             (grenade), bounce (saw blade), charge (hold to charge, then hitscan)
##   tags      which parts fit: gun, pellet, bolt, fuel, energy, launcher
##   effects   what a hit does besides damage: stun, slow, burn (seconds), pierce
##             (true: goes through everything), knock (metres), explode (radius), chain (extra
##             targets), lure (the hit spot is noisy), reveal (shows hidden monsters), bubble
const FRAMES := {
	"revolver": {
		"name": "舊警用左輪", "price": 0, "weight": 1.0, "tags": ["gun"], "kind": "hitscan",
		"damage": 16.0, "pellets": 1, "rate": 2.2, "auto": false, "mag": 6, "reserve": 24, "reload": 2.2,
		"spread": 2.5, "range": 40.0, "noise": 30.0, "recoil": 3.0, "zoom": 1.2,
		"slots": ["muzzle", "barrel", "sight", "underbarrel", "ammo", "gadget"], "effects": {},
		"desc": "免費的，永遠拿得到。六發，準頭普通，聲音不小。",
	},
	"smg": {
		"name": "拼裝衝鋒槍", "price": 350, "weight": 2.6, "tags": ["gun"], "kind": "hitscan",
		"damage": 9.0, "pellets": 1, "rate": 9.0, "auto": true, "mag": 30, "reserve": 90, "reload": 2.4,
		"spread": 4.5, "range": 35.0, "noise": 35.0, "recoil": 1.2, "zoom": 1.25,
		"slots": SLOTS, "effects": {},
		"desc": "水管和縫紉機零件焊成的全自動槍。彈幕壓制，但很散。",
	},
	"shotgun": {
		"name": "泵動獵槍", "price": 420, "weight": 3.4, "tags": ["gun", "pellet"], "kind": "hitscan",
		"damage": 10.0, "pellets": 8, "rate": 1.1, "auto": false, "mag": 5, "reserve": 20, "reload": 3.0,
		"spread": 7.0, "range": 25.0, "noise": 60.0, "recoil": 7.0, "zoom": 1.15,
		"slots": ["muzzle", "barrel", "sight", "magazine", "stock", "underbarrel", "ammo", "gadget"], "effects": {"knock": 1.2},
		"desc": "近距離一發轟退中型怪。槍聲會引來半張地圖的東西。",
	},
	"rifle": {
		"name": "栓動步槍", "price": 560, "weight": 3.8, "tags": ["gun"], "kind": "hitscan",
		"damage": 65.0, "pellets": 1, "rate": 0.8, "auto": false, "mag": 5, "reserve": 20, "reload": 3.2,
		"spread": 0.4, "range": 100.0, "noise": 55.0, "recoil": 6.0, "zoom": 1.6,
		"slots": SLOTS, "effects": {},
		"desc": "一槍一個洞。遠距離最準，近身很難用。",
	},
	"nail_gun": {
		"name": "工業釘槍", "price": 220, "weight": 2.4, "tags": ["gun"], "kind": "hitscan",
		"damage": 7.0, "pellets": 1, "rate": 6.0, "auto": true, "mag": 40, "reserve": 120, "reload": 2.0,
		"spread": 3.0, "range": 28.0, "noise": 12.0, "recoil": 0.8, "zoom": 1.2,
		"slots": ["barrel", "sight", "magazine", "underbarrel", "ammo", "gadget"], "effects": {"slow": 0.3},
		"desc": "安靜的連射，釘子會讓目標慢下來一點。",
	},
	"crossbow": {
		"name": "鋼弩", "price": 300, "weight": 2.2, "tags": ["bolt"], "kind": "hitscan",
		"damage": 48.0, "pellets": 1, "rate": 0.7, "auto": false, "mag": 1, "reserve": 15, "reload": 1.3,
		"spread": 0.5, "range": 60.0, "noise": 4.0, "recoil": 2.0, "zoom": 1.5,
		"slots": ["sight", "stock", "underbarrel", "ammo", "gadget"], "effects": {},
		"desc": "幾乎沒有聲音。一次一發，換箭頭可以變出各種花樣。",
	},
	"flamethrower": {
		"name": "火焰噴射器", "price": 500, "weight": 5.0, "tags": ["fuel"], "kind": "cone",
		"damage": 5.0, "pellets": 1, "rate": 10.0, "auto": true, "mag": 80, "reserve": 80, "reload": 3.5,
		"spread": 0.0, "range": 7.0, "noise": 15.0, "recoil": 0.0, "zoom": 1.0,
		"slots": ["muzzle", "magazine", "gadget"], "effects": {"burn": 3.0},
		"desc": "噴出一片火，燒到的東西會繼續燒。對鼠群和撲燈蛾特別有效。",
	},
	"tesla": {
		"name": "特斯拉線圈槍", "price": 650, "weight": 4.0, "tags": ["energy"], "kind": "arc",
		"damage": 14.0, "pellets": 1, "rate": 3.0, "auto": true, "mag": 24, "reserve": 48, "reload": 3.0,
		"spread": 0.0, "range": 14.0, "noise": 25.0, "recoil": 0.5, "zoom": 1.0,
		"slots": ["barrel", "magazine", "stock", "gadget"], "effects": {"stun": 0.5, "chain": 2},
		"desc": "電弧會跳到旁邊的目標上，每一下都讓它們麻一下。",
	},
	"harpoon": {
		"name": "捕鯨魚叉槍", "price": 450, "weight": 4.5, "tags": ["bolt"], "kind": "hitscan",
		"damage": 80.0, "pellets": 1, "rate": 0.5, "auto": false, "mag": 1, "reserve": 8, "reload": 2.4,
		"spread": 0.6, "range": 40.0, "noise": 20.0, "recoil": 5.0, "zoom": 1.3,
		"slots": ["sight", "stock", "ammo", "gadget"], "effects": {"pierce": true, "knock": -2.5},
		"desc": "一叉穿過一整排，還會把目標往你這邊拖。",
	},
	"railgun": {
		"name": "磁軌炮", "price": 1200, "weight": 11.0, "tags": ["energy"], "kind": "charge",
		"damage": 260.0, "pellets": 1, "rate": 0.4, "auto": false, "mag": 1, "reserve": 3, "reload": 4.0,
		"spread": 0.0, "range": 120.0, "noise": 45.0, "recoil": 10.0, "zoom": 2.0,
		"slots": ["barrel", "sight", "magazine", "stock", "gadget"], "effects": {"pierce": true, "stun": 2.0},
		"desc": "按住充能 2 秒，一發貫穿直線上的一切。超重，子彈很少。",
	},
	"duck_launcher": {
		"name": "爆炸鴨發射器", "price": 700, "weight": 4.2, "tags": ["launcher"], "kind": "lob",
		"damage": 90.0, "pellets": 1, "rate": 0.8, "auto": false, "mag": 3, "reserve": 6, "reload": 3.5,
		"spread": 1.0, "range": 35.0, "noise": 60.0, "recoil": 6.0, "zoom": 1.1,
		"slots": ["sight", "magazine", "stock", "gadget"], "effects": {"explode": 4.0, "lure": true},
		"desc": "拋出一隻嘎嘎叫的橡皮鴨，把怪物引過去再炸開。也炸得到隊友。",
	},
	"saw_launcher": {
		"name": "圓鋸片發射器", "price": 480, "weight": 3.6, "tags": ["launcher"], "kind": "bounce",
		"damage": 38.0, "pellets": 1, "rate": 1.4, "auto": false, "mag": 8, "reserve": 16, "reload": 2.8,
		"spread": 0.8, "range": 35.0, "noise": 22.0, "recoil": 3.0, "zoom": 1.2,
		"slots": ["sight", "magazine", "stock", "underbarrel", "gadget"], "effects": {"chain": 1},
		"desc": "鋸片打中牆會反彈，打中一個還會彈去下一個。",
	},
	"bubble_gun": {
		"name": "泡泡槍", "price": 260, "weight": 1.2, "tags": ["energy"], "kind": "hitscan",
		"damage": 2.0, "pellets": 1, "rate": 4.0, "auto": true, "mag": 50, "reserve": 100, "reload": 2.0,
		"spread": 2.0, "range": 20.0, "noise": 6.0, "recoil": 0.2, "zoom": 1.0,
		"slots": ["magazine", "gadget"], "effects": {"bubble": 4.0},
		"desc": "幾乎不痛，但小怪會被包進泡泡裡飄 4 秒，中型怪要連中好幾發。",
	},
}

## Parts: slot, fits (frame tags, or "all"), and mods applied in order:
##   "x" multiplies a stat, "+" adds to it, "=" sets it; "effects" merges into the frame's.
const PARTS := {
	# Muzzle
	"suppressor": {"name": "消音器", "slot": "muzzle", "price": 180, "weight": 0.4, "fits": ["gun"],
		"x": {"noise": 0.3, "damage": 0.9}, "desc": "槍聲小很多，傷害少一點。"},
	"compensator": {"name": "制退器", "slot": "muzzle", "price": 120, "weight": 0.2, "fits": ["gun"],
		"x": {"recoil": 0.55, "spread": 0.85}, "desc": "槍口不跳，連射更穩。"},
	"choke": {"name": "收束器", "slot": "muzzle", "price": 100, "weight": 0.2, "fits": ["pellet"],
		"x": {"spread": 0.55, "range": 1.2}, "desc": "霰彈打得更集中、更遠。"},
	"wide_nozzle": {"name": "寬口噴嘴", "slot": "muzzle", "price": 140, "weight": 0.3, "fits": ["fuel"],
		"x": {"range": 0.75, "damage": 1.3}, "desc": "火噴得近，但更猛。"},
	# Barrel
	"long_barrel": {"name": "長槍管", "slot": "barrel", "price": 160, "weight": 0.8, "fits": ["gun"],
		"x": {"range": 1.4, "spread": 0.7, "damage": 1.1}, "desc": "更遠更準，比較重。"},
	"short_barrel": {"name": "短槍管", "slot": "barrel", "price": 90, "weight": -0.3, "fits": ["gun"],
		"x": {"spread": 1.3, "rate": 1.15, "range": 0.8}, "desc": "射得快，但散。"},
	"coil_barrel": {"name": "加速線圈", "slot": "barrel", "price": 260, "weight": 1.0, "fits": ["energy"],
		"x": {"damage": 1.35, "noise": 1.3, "range": 1.2}, "desc": "電力加大：更痛、更吵。"},
	# Sight
	"red_dot": {"name": "紅點瞄具", "slot": "sight", "price": 110, "weight": 0.2, "fits": ["gun", "bolt", "launcher", "energy"],
		"x": {"spread": 0.8}, "=": {"zoom": 1.35}, "desc": "瞄準時更準。"},
	"scope": {"name": "4 倍狙擊鏡", "slot": "sight", "price": 240, "weight": 0.5, "fits": ["gun", "bolt", "energy"],
		"x": {"spread": 0.6}, "=": {"zoom": 3.0}, "desc": "看得很遠。近距離反而難用。"},
	"thermal": {"name": "熱成像鏡", "slot": "sight", "price": 420, "weight": 0.6, "fits": ["gun", "bolt", "energy", "launcher"],
		"=": {"zoom": 1.6}, "effects": {"thermal": true}, "desc": "瞄準時看得到黑暗裡和隱形的怪物。"},
	# Magazine
	"extended_mag": {"name": "擴充彈匣", "slot": "magazine", "price": 130, "weight": 0.4, "fits": ["gun", "launcher"],
		"x": {"mag": 1.6, "reload": 1.1}, "desc": "子彈多一半。"},
	"drum_mag": {"name": "彈鼓", "slot": "magazine", "price": 230, "weight": 1.2, "fits": ["gun"],
		"x": {"mag": 2.5, "reload": 1.4}, "desc": "子彈多兩倍半，換彈很慢。"},
	"quick_mag": {"name": "快拔彈匣", "slot": "magazine", "price": 150, "weight": 0.1, "fits": ["gun", "launcher"],
		"x": {"reload": 0.55}, "desc": "換彈快一倍。"},
	"big_tank": {"name": "大油罐", "slot": "magazine", "price": 160, "weight": 1.5, "fits": ["fuel"],
		"x": {"mag": 2.0, "reserve": 1.5}, "desc": "燃料多一倍。"},
	"capacitor": {"name": "大電容", "slot": "magazine", "price": 200, "weight": 0.8, "fits": ["energy"],
		"x": {"mag": 1.8, "reload": 0.8}, "desc": "電多、充得快。"},
	# Stock
	"heavy_stock": {"name": "重槍托", "slot": "stock", "price": 100, "weight": 1.0, "fits": ["gun", "bolt", "energy", "launcher"],
		"x": {"recoil": 0.6, "spread": 0.85}, "desc": "穩，但重。"},
	"light_stock": {"name": "輕槍托", "slot": "stock", "price": 80, "weight": -0.5, "fits": ["gun", "bolt", "energy", "launcher"],
		"x": {"recoil": 1.2}, "desc": "減重，後座大一點。"},
	# Underbarrel
	"flashlight": {"name": "戰術燈", "slot": "underbarrel", "price": 70, "weight": 0.2, "fits": "all",
		"effects": {"light": true}, "desc": "槍上的燈，跟著準心照。"},
	"laser": {"name": "雷射指示器", "slot": "underbarrel", "price": 120, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.7}, "desc": "不瞄準也打得準。紅點別人看得到。"},
	"bayonet": {"name": "刺刀", "slot": "underbarrel", "price": 60, "weight": 0.3, "fits": "all",
		"effects": {"bayonet": true}, "desc": "近戰（V）傷害兩倍。"},
	# Ammo
	"hollow_point": {"name": "空尖彈", "slot": "ammo", "price": 90, "weight": 0.0, "fits": ["gun"],
		"effects": {"soft": true}, "desc": "對中小型怪多 40% 傷害，對大型怪少 30%。"},
	"ap_rounds": {"name": "穿甲彈", "slot": "ammo", "price": 160, "weight": 0.0, "fits": ["gun"],
		"effects": {"pierce": true, "armor": true}, "desc": "打穿一排，對大型怪多 50% 傷害。"},
	"incendiary": {"name": "燃燒彈", "slot": "ammo", "price": 150, "weight": 0.0, "fits": ["gun", "bolt"],
		"effects": {"burn": 2.5}, "desc": "打中會燒起來。"},
	"shock_rounds": {"name": "電擊彈", "slot": "ammo", "price": 170, "weight": 0.0, "fits": ["gun", "bolt"],
		"effects": {"stun": 0.4}, "x": {"damage": 0.85}, "desc": "每一發都讓目標麻一下。"},
	"rock_salt": {"name": "粗鹽彈", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["pellet"],
		"effects": {"reveal": true, "slow": 1.0}, "x": {"damage": 0.6}, "desc": "不太痛，但能逼出霧行者，打到的都會變慢。"},
	"explosive_bolt": {"name": "爆裂箭頭", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["bolt"],
		"effects": {"explode": 2.5}, "x": {"reserve": 0.6}, "desc": "命中爆炸，箭變少。"},
	"net_bolt": {"name": "網箭頭", "slot": "ammo", "price": 130, "weight": 0.0, "fits": ["bolt"],
		"effects": {"slow": 4.0}, "x": {"damage": 0.4}, "desc": "把目標纏住，慢 4 秒。"},
	# Gadget: the strange stuff
	"vampire_charm": {"name": "吸血蝙蝠吊飾", "slot": "gadget", "price": 280, "weight": 0.1, "fits": "all",
		"effects": {"leech": 0.1}, "desc": "打怪物造成的傷害，有 10% 補回你的血。"},
	"spring_bolt": {"name": "彈簧連發機", "slot": "gadget", "price": 220, "weight": 0.4, "fits": "all",
		"x": {"rate": 1.35, "recoil": 1.5}, "desc": "射速快三成多，後座也大。"},
	"ghost_chamber": {"name": "幽靈膛室", "slot": "gadget", "price": 300, "weight": 0.2, "fits": "all",
		"effects": {"ghost": 5}, "desc": "每第 5 發不耗子彈。"},
	"lucky_cat": {"name": "招財貓吊飾", "slot": "gadget", "price": 160, "weight": 0.1, "fits": "all",
		"effects": {"bounty": true}, "desc": "殺死怪物時，牠會掉下一件東西。"},
	"echo_bell": {"name": "回聲鈴鐺", "slot": "gadget", "price": 140, "weight": 0.1, "fits": "all",
		"effects": {"lure": true}, "x": {"noise": 0.6}, "desc": "槍聲變小，但子彈打到的地方會叮噹響，把怪物引過去。"},
}

const STARTER := {"frame": "revolver", "parts": {}}
## Stats that are whole numbers after mods.
const INT_STATS := ["mag", "reserve", "pellets"]


static func frame(id: String) -> Dictionary:
	return FRAMES.get(id, {})


static func part(id: String) -> Dictionary:
	return PARTS.get(id, {})


## The display name of any frame or part id.
static func name_of(id: String) -> String:
	return FRAMES.get(id, PARTS.get(id, {})).get("name", id)


static func price_of(id: String) -> int:
	return FRAMES.get(id, PARTS.get(id, {})).get("price", 0)


## Can this part go on this frame?
static func fits(frame_id: String, part_id: String) -> bool:
	var f := frame(frame_id)
	var p := part(part_id)
	if f.is_empty() or p.is_empty() or not p.slot in f.slots:
		return false
	if p.fits is String:
		return true
	for tag in p.fits:
		if tag in f.tags:
			return true
	return false


## Parts that can go in one slot of a frame.
static func parts_for(frame_id: String, slot: String) -> Array[String]:
	var result: Array[String] = []
	for id in PARTS:
		if PARTS[id].slot == slot and fits(frame_id, id):
			result.append(id)
	return result


## Drops parts that don't fit (a build loaded from an old save, or a changed frame).
static func clean(build: Dictionary) -> Dictionary:
	var frame_id: String = build.get("frame", "")
	if not FRAMES.has(frame_id):
		return STARTER.duplicate(true)
	var parts := {}
	var given: Dictionary = build.get("parts", {})
	for slot in given:
		var part_id: String = str(given[slot])
		if PARTS.has(part_id) and PARTS[part_id].slot == slot and fits(frame_id, part_id):
			parts[slot] = part_id
	return {"frame": frame_id, "parts": parts}


## Every id a build is made of (the frame first).
static func ids(build: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if FRAMES.has(build.get("frame", "")):
		result.append(build.frame)
	for slot in SLOTS:
		var part_id: String = build.get("parts", {}).get(slot, "")
		if part_id != "":
			result.append(part_id)
	return result


## The finished weapon: the frame's stats with every part's mods applied.
static func stats(build: Dictionary) -> Dictionary:
	build = clean(build)
	var f := frame(build.frame)
	var result := f.duplicate(true)
	result.frame = build.frame
	result.parts = build.parts.duplicate()
	result.effects = f.effects.duplicate()
	var price: int = f.price
	for slot in SLOTS:
		var part_id: String = build.parts.get(slot, "")
		if part_id == "":
			continue
		var p := part(part_id)
		price += p.price
		result.weight += p.weight
		for stat in p.get("x", {}):
			result[stat] = result[stat] * p.x[stat]
		for stat in p.get("+", {}):
			result[stat] = result[stat] + p["+"][stat]
		for stat in p.get("=", {}):
			result[stat] = p["="][stat]
		for effect in p.get("effects", {}):
			var value = p.effects[effect]
			if result.effects.has(effect) and value is float:
				result.effects[effect] = maxf(result.effects[effect], value)
			else:
				result.effects[effect] = value
	for stat in INT_STATS:
		result[stat] = maxi(1, roundi(result[stat]))
	result.weight = maxf(result.weight, 0.3)
	result.price = price
	return result


## A short Chinese summary line of a build's numbers, for menus.
static func summary(build: Dictionary) -> String:
	var s := stats(build)
	var pellets := "×%d" % s.pellets if s.pellets > 1 else ""
	return "傷害 %d%s　射速 %.1f/秒　彈匣 %d（備彈 %d）　射程 %dm　聲音 %dm　%.1fkg" % [
		roundi(s.damage), pellets, s.rate, s.mag, s.reserve, roundi(s.range), roundi(s.noise), s.weight]
