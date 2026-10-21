class_name Arsenal
## Every weapon a scavenger can carry, and every part that bolts onto one.
## A weapon is a frame (the gun itself) plus a tree of parts, modded like a real gun on
## a gunsmith bench (Tarkov-style): the frame has root slots, and parts open more slots
## of their own (a handguard opens rails, a foregrip spot and an underbarrel spot; a
## flash hider opens a spot for a quick-detach suppressor; a threaded barrel opens a
## muzzle). Some parts block a slot (an integrally suppressed barrel has no muzzle) and
## some change the calibre (an AR upper in .300 BLK), which decides the ammo and the
## magazines that fit. A few parts can be tuned on a slider (gas, stock length, zoom).
##   build = {"frame": "carbine", "parts": {"handguard": "quad_rail", "rail_l": "flashlight"},
##            "tune": {"gas": 0.5}}
## Arsenal.stats(build) gives the finished numbers the game uses.
##
## Frames and parts are bought into the stash (GameState.stash, by id) and go into a run
## with the build: lost on death, back in the stash on extraction. The starter revolver
## is free and always there, and every scavenger also carries a knife (Player handles it),
## so nobody goes in unable to fight back.

## Every slot a build can have, parents before the slots they open (clean() walks this
## once, in order). A slot's type (SLOT_TYPE) is what parts name in "slot".
const SLOTS := ["receiver", "barrel", "muzzle", "silencer", "gas", "handguard", "rail_l", "rail_r",
	"foregrip", "underbarrel", "mount", "sight", "grip", "trigger", "bolt", "charging", "magazine",
	"ammo", "stock", "buttpad", "gadget"]
## Slots that share a type with another (both rails take rail accessories).
const SLOT_TYPE := {"rail_l": "rail", "rail_r": "rail"}
## Names of slot types (and of the two rail slots).
const SLOT_NAMES := {
	"receiver": "機匣", "barrel": "槍管", "muzzle": "槍口", "silencer": "消音器", "gas": "導氣",
	"handguard": "護木", "rail": "導軌配件", "rail_l": "左導軌", "rail_r": "右導軌", "foregrip": "前握把",
	"underbarrel": "下掛", "mount": "副瞄座", "sight": "瞄具", "grip": "握把", "trigger": "扳機組",
	"bolt": "槍機", "charging": "拉機柄", "magazine": "彈匣", "ammo": "彈藥", "stock": "槍托",
	"buttpad": "托底", "gadget": "怪東西",
}
## The four groups the bench shows slots in.
const SLOT_GROUPS := [
	["前段", ["barrel", "muzzle", "silencer", "gas", "handguard", "rail_l", "rail_r", "foregrip", "underbarrel"]],
	["上方", ["mount", "sight"]],
	["機匣", ["receiver", "grip", "trigger", "bolt", "charging", "magazine", "ammo"]],
	["後段", ["stock", "buttpad", "gadget"]],
]

## Calibres. "family" is what ammo and some parts fit by (it works like a frame tag).
const CALIBERS := {
	"9mm": {"name": "9×19mm", "family": "pistol"},
	".45": {"name": ".45 ACP", "family": "pistol"},
	".357": {"name": ".357 麥格農", "family": "pistol"},
	"5.7": {"name": "5.7×28mm", "family": "pistol"},
	"5.56": {"name": "5.56×45mm", "family": "rifle"},
	".300": {"name": ".300 BLK", "family": "rifle"},
	"7.62x39": {"name": "7.62×39mm", "family": "rifle"},
	"7.62": {"name": "7.62×51mm", "family": "rifle"},
	".338": {"name": ".338 拉普麥格農", "family": "rifle"},
	".45-70": {"name": ".45-70 政府型", "family": "rifle"},
	".50": {"name": ".50 BMG", "family": "rifle"},
	"12g": {"name": "12 號霰彈", "family": "shell"},
	"nail": {"name": "工業釘", "family": "odd"},
	"bolt": {"name": "弩箭", "family": "odd"},
	"fuel": {"name": "燃料", "family": "odd"},
	"cell": {"name": "電池", "family": "odd"},
	"duck": {"name": "橡皮鴨", "family": "odd"},
	"saw": {"name": "鋸片", "family": "odd"},
	"soap": {"name": "肥皂水", "family": "odd"},
}

## Fire modes a frame can have; the player cycles them (B).
const MODE_NAMES := {"semi": "半自動", "burst": "三連發", "auto": "全自動", "double": "雙管齊發"}

## Stats every frame defines (missing ones come from DEFAULTS):
##   damage      per projectile (monster health is in MonsterRoster; players have 100)
##   pellets     projectiles per shot
##   rate        shots per second (cyclic rate for auto and burst)
##   modes       fire modes, first is the default: semi, burst (3), auto, double (two at once)
##   mag         rounds before reloading; reserve = spare rounds carried in
##   reload      seconds (an empty gun takes EMPTY_RELOAD times longer: rack the action)
##   spread      degrees of random cone when hip-firing
##   moa         precision when aiming (minutes of angle; aimed cone = moa * MOA_DEGREES)
##   recoil      vertical camera kick per shot, degrees; recoil_h = sideways wobble
##   ergo        ergonomics 0-100: how fast you aim, how much the gun sways, recoil recovery
##   velocity    muzzle velocity m/s: over 340 the bullet cracks (a suppressor can't hide it),
##               faster keeps damage further out and adds penetration
##   pen         penetration 0-100: how much a hit counts against large, armoured monsters
##   range       metres; damage falls off over the last part of it (falloff)
##   noise       radius in metres monsters hear the shot from
##   flash       muzzle flash 0-100: lights the shooter up (light-sensing monsters see it)
##   zoom        field-of-view divisor while aiming
##   reliability 0-100: chance per shot of a jam is (100 - reliability) * JAM_PER_POINT
##   heat        heat added per shot (1.0 = overheated); cooling = heat lost per second
##   length      cm; weight kg; price $
##   cal         calibre (CALIBERS)
##   kind        how a shot travels: hitscan, cone (flame), arc (chain lightning), lob
##               (grenade), bounce (saw blade), charge (hold to charge, then hitscan)
##   tags        which parts fit: gun, pellet, bolt, fuel, energy, launcher, plus a few
##               frame families (ar, ak, pistol_frame, revolver, bolt_action)
##   slots       root slots; parts open more ("adds") or close some ("blocks")
##   effects     what a hit does besides damage: stun, slow, burn, bleed (seconds), pierce
##               (true: goes through everything), knock (metres), explode (radius), chain (extra
##               targets), lure (the hit spot is noisy), reveal (shows hidden monsters), bubble
##   shooter effects: light, thermal, night (night vision), laser / laser_ir, strobe,
##               bipod (still + aiming = much less recoil), canted (hip-fire through an offset
##               sight), suppressed, tracer, bayonet, ghost (every Nth shot is free)
##   organ effects (see Organs): scream, hush, acid, lullaby, web, motion_sight / squeal,
##               guard (aiming halves damage taken), fang (a knife three times as strong)
const DEFAULTS := {
	"pellets": 1, "modes": ["semi"], "moa": 6.0, "recoil_h": 1.0, "ergo": 60.0, "velocity": 400.0,
	"pen": 20.0, "flash": 50.0, "zoom": 1.2, "reliability": 92.0, "heat": 0.0, "cooling": 0.5,
	"length": 80.0, "effects": {}, "kind": "hitscan", "cal": "9mm",
}

const FRAMES := {
	# --- Handguns
	"revolver": {
		"name": "舊警用左輪", "price": 0, "weight": 1.0, "length": 28.0, "tags": ["gun", "revolver"], "cal": ".357",
		"damage": 16.0, "rate": 2.2, "mag": 6, "reserve": 24, "reload": 2.2,
		"spread": 2.5, "moa": 6.0, "range": 40.0, "noise": 30.0, "recoil": 3.0, "recoil_h": 0.8, "zoom": 1.2,
		"ergo": 70.0, "velocity": 430.0, "pen": 25.0, "flash": 60.0, "reliability": 98.0,
		"slots": ["receiver", "barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "underbarrel", "gadget"],
		"desc": "免費的，永遠拿得到。六發，準頭普通，聲音不小。轉輪槍幾乎不會卡彈。",
	},
	"service_pistol": {
		"name": "警用半自動手槍", "price": 150, "weight": 0.8, "length": 20.0, "tags": ["gun", "pistol_frame"], "cal": "9mm",
		"damage": 13.0, "rate": 4.0, "mag": 15, "reserve": 45, "reload": 1.6,
		"spread": 2.2, "moa": 7.0, "range": 35.0, "noise": 28.0, "recoil": 2.0, "recoil_h": 0.7, "zoom": 1.15,
		"ergo": 80.0, "velocity": 360.0, "pen": 20.0, "flash": 45.0, "reliability": 95.0,
		"slots": ["barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "十五發的聚合物手槍。輕、快、好上手，改裝空間比你想的大。",
	},
	"heavy_pistol": {
		"name": "點四五大口徑手槍", "price": 260, "weight": 1.1, "length": 22.0, "tags": ["gun", "pistol_frame"], "cal": ".45",
		"damage": 22.0, "rate": 2.8, "mag": 7, "reserve": 28, "reload": 1.7,
		"spread": 2.4, "moa": 6.0, "range": 35.0, "noise": 32.0, "recoil": 3.6, "recoil_h": 0.9, "zoom": 1.15,
		"ergo": 72.0, "velocity": 260.0, "pen": 22.0, "flash": 40.0, "reliability": 93.0,
		"slots": ["barrel", "rail_l", "sight", "grip", "trigger", "magazine", "ammo", "stock", "gadget"],
		"desc": "一百年前的設計，一發一個大洞。子彈本來就是亞音速，配消音器非常安靜。",
	},
	"machine_pistol": {
		"name": "全自動衝鋒手槍", "price": 320, "weight": 1.1, "length": 25.0, "tags": ["gun", "pistol_frame"], "cal": "9mm",
		"damage": 10.0, "rate": 14.0, "modes": ["semi", "auto"], "mag": 20, "reserve": 60, "reload": 1.8,
		"spread": 4.5, "moa": 9.0, "range": 25.0, "noise": 30.0, "recoil": 1.6, "recoil_h": 1.6, "zoom": 1.1,
		"ergo": 75.0, "velocity": 350.0, "pen": 18.0, "flash": 50.0, "reliability": 88.0, "heat": 0.03, "cooling": 0.5,
		"slots": ["barrel", "muzzle", "rail_l", "sight", "grip", "trigger", "bolt", "magazine", "ammo", "stock", "gadget"],
		"desc": "一秒十四發，槍口亂跳。近距離把一整個彈匣倒進去。",
	},
	# --- Submachine guns
	"smg": {
		"name": "拼裝衝鋒槍", "price": 350, "weight": 2.6, "length": 60.0, "tags": ["gun"], "cal": "9mm",
		"damage": 9.0, "rate": 9.0, "modes": ["auto", "semi"], "mag": 30, "reserve": 90, "reload": 2.4,
		"spread": 4.5, "moa": 10.0, "range": 35.0, "noise": 35.0, "recoil": 1.2, "recoil_h": 1.4, "zoom": 1.25,
		"ergo": 68.0, "velocity": 380.0, "pen": 18.0, "flash": 55.0, "reliability": 82.0, "heat": 0.025, "cooling": 0.4,
		"slots": ["barrel", "muzzle", "rail_l", "rail_r", "foregrip", "underbarrel", "sight", "grip", "trigger",
			"bolt", "charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "水管和縫紉機零件焊成的全自動槍。彈幕壓制，但很散，偶爾卡彈。",
	},
	"pdw": {
		"name": "個人防衛武器", "price": 600, "weight": 2.7, "length": 50.0, "tags": ["gun"], "cal": "5.7",
		"damage": 11.0, "rate": 13.0, "modes": ["auto", "semi"], "mag": 50, "reserve": 100, "reload": 2.6,
		"spread": 3.2, "moa": 6.0, "range": 45.0, "noise": 34.0, "recoil": 0.9, "recoil_h": 0.8, "zoom": 1.25,
		"ergo": 74.0, "velocity": 700.0, "pen": 45.0, "flash": 40.0, "reliability": 90.0, "heat": 0.02, "cooling": 0.5,
		"slots": ["muzzle", "rail_l", "rail_r", "foregrip", "mount", "sight", "trigger", "bolt", "magazine", "ammo", "gadget"],
		"desc": "五十發的頂裝彈匣、幾乎沒有後座。小口徑高速彈，穿透比手槍彈好得多。",
	},
	# --- Rifles
	"carbine": {
		"name": "模組化卡賓槍", "price": 700, "weight": 3.0, "length": 85.0, "tags": ["gun", "ar"], "cal": "5.56",
		"damage": 20.0, "rate": 11.0, "modes": ["semi", "auto"], "mag": 30, "reserve": 90, "reload": 2.5,
		"spread": 3.0, "moa": 3.5, "range": 70.0, "noise": 50.0, "recoil": 1.6, "recoil_h": 1.0, "zoom": 1.25,
		"ergo": 60.0, "velocity": 900.0, "pen": 40.0, "flash": 55.0, "reliability": 85.0, "heat": 0.02, "cooling": 0.45,
		"slots": ["receiver", "barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt",
			"charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "什麼都裝得上的步槍。換上機匣就能改口徑，是槍匠台上最好玩的東西。",
	},
	"ak": {
		"name": "老式突擊步槍", "price": 620, "weight": 3.6, "length": 88.0, "tags": ["gun", "ak"], "cal": "7.62x39",
		"damage": 26.0, "rate": 10.0, "modes": ["auto", "semi"], "mag": 30, "reserve": 90, "reload": 2.7,
		"spread": 3.6, "moa": 5.0, "range": 60.0, "noise": 55.0, "recoil": 2.6, "recoil_h": 1.6, "zoom": 1.2,
		"ergo": 52.0, "velocity": 715.0, "pen": 45.0, "flash": 70.0, "reliability": 98.0, "heat": 0.02, "cooling": 0.4,
		"slots": ["receiver", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "泡過水、埋過土都還能打。後座大、準頭普通，但幾乎從來不卡。",
	},
	"bullpup": {
		"name": "犢牛式步槍", "price": 780, "weight": 3.4, "length": 70.0, "tags": ["gun"], "cal": "5.56",
		"damage": 19.0, "rate": 12.0, "modes": ["semi", "auto"], "mag": 30, "reserve": 90, "reload": 3.1,
		"spread": 2.8, "moa": 3.5, "range": 70.0, "noise": 50.0, "recoil": 1.5, "recoil_h": 1.1, "zoom": 1.3,
		"ergo": 66.0, "velocity": 920.0, "pen": 40.0, "flash": 50.0, "reliability": 84.0, "heat": 0.02, "cooling": 0.45,
		"slots": ["barrel", "muzzle", "gas", "rail_l", "rail_r", "foregrip", "underbarrel", "mount", "sight", "trigger",
			"bolt", "magazine", "ammo", "gadget"],
		"desc": "彈匣在握把後面：步槍的槍管、衝鋒槍的長度。換彈要摸到肩膀後面，很慢。",
	},
	"battle_rifle": {
		"name": "戰鬥步槍", "price": 900, "weight": 4.4, "length": 105.0, "tags": ["gun"], "cal": "7.62",
		"damage": 38.0, "rate": 7.0, "modes": ["semi", "auto"], "mag": 20, "reserve": 60, "reload": 2.9,
		"spread": 3.2, "moa": 2.5, "range": 85.0, "noise": 65.0, "recoil": 4.2, "recoil_h": 1.8, "zoom": 1.3,
		"ergo": 45.0, "velocity": 840.0, "pen": 60.0, "flash": 65.0, "reliability": 90.0, "heat": 0.03, "cooling": 0.4,
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "全威力步槍彈的全自動。每一發都很痛，連射就拉不住了。",
	},
	"dmr": {
		"name": "精確射手步槍", "price": 1000, "weight": 4.6, "length": 110.0, "tags": ["gun", "ar"], "cal": "7.62",
		"damage": 45.0, "rate": 3.5, "mag": 10, "reserve": 40, "reload": 2.8,
		"spread": 3.0, "moa": 1.4, "range": 110.0, "noise": 62.0, "recoil": 3.6, "recoil_h": 1.0, "zoom": 1.4,
		"ergo": 48.0, "velocity": 860.0, "pen": 62.0, "flash": 55.0, "reliability": 88.0, "heat": 0.02, "cooling": 0.5,
		"slots": ["receiver", "barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt",
			"charging", "magazine", "ammo", "stock", "gadget"],
		"desc": "半自動的狙擊槍。比栓動快，比卡賓槍準。",
	},
	"rifle": {
		"name": "栓動步槍", "price": 560, "weight": 3.8, "length": 112.0, "tags": ["gun", "bolt_action"], "cal": "7.62",
		"damage": 65.0, "rate": 0.8, "mag": 5, "reserve": 20, "reload": 3.2,
		"spread": 0.4, "moa": 1.0, "range": 100.0, "noise": 55.0, "recoil": 6.0, "recoil_h": 0.6, "zoom": 1.6,
		"ergo": 50.0, "velocity": 850.0, "pen": 65.0, "flash": 50.0, "reliability": 99.0,
		"slots": ["receiver", "barrel", "muzzle", "rail_l", "foregrip", "underbarrel", "mount", "sight", "trigger", "bolt",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "一槍一個洞。遠距離最準，近身很難用。換槍管可以改成 .338。",
	},
	"lever_action": {
		"name": "槓桿步槍", "price": 480, "weight": 3.2, "length": 95.0, "tags": ["gun", "lever"], "cal": ".45-70",
		"damage": 55.0, "rate": 1.4, "mag": 6, "reserve": 24, "reload": 3.6,
		"spread": 1.6, "moa": 3.0, "range": 70.0, "noise": 52.0, "recoil": 5.0, "recoil_h": 0.8, "zoom": 1.3,
		"ergo": 62.0, "velocity": 600.0, "pen": 50.0, "flash": 45.0, "reliability": 97.0,
		"slots": ["barrel", "rail_l", "underbarrel", "mount", "sight", "trigger", "bolt", "magazine", "ammo", "stock",
			"buttpad", "gadget"],
		"desc": "西部片裡的槍，打熊用的子彈。拉一下打一發，一顆一顆塞進彈倉。",
	},
	"lmg": {
		"name": "輕機槍", "price": 1300, "weight": 7.5, "length": 104.0, "tags": ["gun"], "cal": "5.56",
		"damage": 20.0, "rate": 12.0, "modes": ["auto"], "mag": 100, "reserve": 200, "reload": 5.5,
		"spread": 4.5, "moa": 4.0, "range": 75.0, "noise": 60.0, "recoil": 1.8, "recoil_h": 1.6, "zoom": 1.2,
		"ergo": 25.0, "velocity": 915.0, "pen": 42.0, "flash": 65.0, "reliability": 92.0, "heat": 0.012, "cooling": 0.35,
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "一百發彈鏈。非常重、非常吵，架上腳架就是一堵火牆。換彈要五秒半。",
	},
	"anti_materiel": {
		"name": "反器材步槍", "price": 1600, "weight": 13.0, "length": 145.0, "tags": ["gun", "bolt_action"], "cal": ".50",
		"damage": 180.0, "rate": 0.6, "mag": 5, "reserve": 10, "reload": 4.2,
		"spread": 4.0, "moa": 1.2, "range": 150.0, "noise": 90.0, "recoil": 12.0, "recoil_h": 2.0, "zoom": 2.2,
		"ergo": 20.0, "velocity": 880.0, "pen": 95.0, "flash": 90.0, "reliability": 92.0,
		"effects": {"pierce": true, "knock": 2.0},
		"slots": ["muzzle", "rail_l", "foregrip", "mount", "sight", "trigger", "magazine", "ammo", "stock", "buttpad", "gadget"],
		"desc": "打卡車引擎用的槍。一發能讓大型怪踉蹌，整張地圖都聽得到。十三公斤。",
	},
	# --- Shotguns
	"shotgun": {
		"name": "泵動獵槍", "price": 420, "weight": 3.4, "length": 100.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 10.0, "pellets": 8, "rate": 1.1, "mag": 5, "reserve": 20, "reload": 3.0,
		"spread": 7.0, "moa": 8.0, "range": 25.0, "noise": 60.0, "recoil": 7.0, "recoil_h": 1.5, "zoom": 1.15,
		"ergo": 58.0, "velocity": 400.0, "pen": 15.0, "flash": 70.0, "reliability": 96.0,
		"effects": {"knock": 1.2},
		"slots": ["barrel", "muzzle", "handguard", "underbarrel", "mount", "sight", "grip", "trigger", "magazine",
			"ammo", "stock", "gadget"],
		"desc": "近距離一發轟退中型怪。槍聲會引來半張地圖的東西。換獨頭彈就能打遠。",
	},
	"double_barrel": {
		"name": "雙管獵槍", "price": 300, "weight": 3.2, "length": 105.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 11.0, "pellets": 8, "rate": 3.0, "modes": ["semi", "double"], "mag": 2, "reserve": 20, "reload": 2.2,
		"spread": 7.5, "moa": 9.0, "range": 25.0, "noise": 62.0, "recoil": 7.5, "recoil_h": 1.2, "zoom": 1.15,
		"ergo": 60.0, "velocity": 400.0, "pen": 15.0, "flash": 75.0, "reliability": 99.0,
		"effects": {"knock": 1.4},
		"slots": ["barrel", "muzzle", "rail_l", "sight", "trigger", "ammo", "stock", "buttpad", "gadget"],
		"desc": "兩發。可以一發一發打，也可以兩管一起轟。折開來換彈很快。",
	},
	"auto_shotgun": {
		"name": "半自動霰彈槍", "price": 950, "weight": 4.2, "length": 100.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 9.0, "pellets": 8, "rate": 4.0, "mag": 8, "reserve": 32, "reload": 3.2,
		"spread": 7.5, "moa": 9.0, "range": 25.0, "noise": 60.0, "recoil": 5.5, "recoil_h": 2.0, "zoom": 1.15,
		"ergo": 50.0, "velocity": 390.0, "pen": 15.0, "flash": 70.0, "reliability": 80.0, "heat": 0.02, "cooling": 0.5,
		"effects": {"knock": 1.0},
		"slots": ["barrel", "muzzle", "gas", "handguard", "mount", "sight", "grip", "trigger", "bolt", "charging",
			"magazine", "ammo", "stock", "gadget"],
		"desc": "扣一下打一發，八發連轟。用太便宜的彈藥會卡。",
	},
	"sawed_off": {
		"name": "鋸短霰彈槍", "price": 160, "weight": 1.8, "length": 45.0, "tags": ["gun", "pellet"], "cal": "12g",
		"damage": 11.0, "pellets": 8, "rate": 3.0, "modes": ["semi", "double"], "mag": 2, "reserve": 16, "reload": 2.0,
		"spread": 11.0, "moa": 14.0, "range": 15.0, "noise": 66.0, "recoil": 8.5, "recoil_h": 2.5, "zoom": 1.05,
		"ergo": 82.0, "velocity": 360.0, "pen": 12.0, "flash": 90.0, "reliability": 99.0,
		"effects": {"knock": 1.8},
		"slots": ["rail_l", "grip", "trigger", "ammo", "gadget"],
		"desc": "把雙管獵槍鋸掉一半。散得像一面牆，火光像一顆太陽。",
	},
	# --- Strange ones
	"nail_gun": {
		"name": "工業釘槍", "price": 220, "weight": 2.4, "length": 40.0, "tags": ["gun"], "cal": "nail",
		"damage": 7.0, "rate": 6.0, "modes": ["auto", "semi"], "mag": 40, "reserve": 120, "reload": 2.0,
		"spread": 3.0, "moa": 8.0, "range": 28.0, "noise": 12.0, "recoil": 0.8, "recoil_h": 0.6, "zoom": 1.2,
		"ergo": 65.0, "velocity": 150.0, "pen": 10.0, "flash": 0.0, "reliability": 75.0, "heat": 0.01, "cooling": 0.5,
		"effects": {"slow": 0.3},
		"slots": ["barrel", "rail_l", "underbarrel", "sight", "grip", "magazine", "ammo", "gadget"],
		"desc": "安靜的連射，釘子會讓目標慢下來一點。工地用品，常常卡釘。",
	},
	"crossbow": {
		"name": "鋼弩", "price": 300, "weight": 2.2, "length": 75.0, "tags": ["bolt"], "cal": "bolt",
		"damage": 48.0, "rate": 0.7, "mag": 1, "reserve": 15, "reload": 1.3,
		"spread": 0.5, "moa": 3.0, "range": 60.0, "noise": 4.0, "recoil": 2.0, "recoil_h": 0.4, "zoom": 1.5,
		"ergo": 60.0, "velocity": 100.0, "pen": 35.0, "flash": 0.0, "reliability": 99.0,
		"slots": ["rail_l", "foregrip", "underbarrel", "mount", "sight", "trigger", "ammo", "stock", "gadget"],
		"desc": "幾乎沒有聲音。一次一發，換箭頭可以變出各種花樣。",
	},
	"flamethrower": {
		"name": "火焰噴射器", "price": 500, "weight": 5.0, "length": 90.0, "tags": ["fuel"], "cal": "fuel", "kind": "cone",
		"damage": 5.0, "rate": 10.0, "modes": ["auto"], "mag": 80, "reserve": 80, "reload": 3.5,
		"spread": 0.0, "moa": 0.0, "range": 7.0, "noise": 15.0, "recoil": 0.0, "recoil_h": 0.0, "zoom": 1.0,
		"ergo": 40.0, "velocity": 20.0, "pen": 0.0, "flash": 100.0, "reliability": 85.0,
		"effects": {"burn": 3.0},
		"slots": ["muzzle", "rail_l", "magazine", "gadget"],
		"desc": "噴出一片火，燒到的東西會繼續燒。對鼠群特別有效。噴的時候你就是一支火把。",
	},
	"tesla": {
		"name": "特斯拉線圈槍", "price": 650, "weight": 4.0, "length": 70.0, "tags": ["energy"], "cal": "cell", "kind": "arc",
		"damage": 14.0, "rate": 3.0, "modes": ["auto"], "mag": 24, "reserve": 48, "reload": 3.0,
		"spread": 0.0, "moa": 0.0, "range": 14.0, "noise": 25.0, "recoil": 0.5, "recoil_h": 0.2, "zoom": 1.0,
		"ergo": 50.0, "velocity": 0.0, "pen": 30.0, "flash": 80.0, "reliability": 90.0, "heat": 0.05, "cooling": 0.3,
		"effects": {"stun": 0.5, "chain": 2},
		"slots": ["barrel", "rail_l", "magazine", "stock", "gadget"],
		"desc": "電弧會跳到旁邊的目標上，每一下都讓它們麻一下。連發會過熱。",
	},
	"harpoon": {
		"name": "捕鯨魚叉槍", "price": 450, "weight": 4.5, "length": 110.0, "tags": ["bolt"], "cal": "bolt",
		"damage": 80.0, "rate": 0.5, "mag": 1, "reserve": 8, "reload": 2.4,
		"spread": 0.6, "moa": 4.0, "range": 40.0, "noise": 20.0, "recoil": 5.0, "recoil_h": 0.5, "zoom": 1.3,
		"ergo": 40.0, "velocity": 80.0, "pen": 70.0, "flash": 0.0, "reliability": 99.0,
		"effects": {"pierce": true, "knock": -2.5},
		"slots": ["rail_l", "mount", "sight", "ammo", "stock", "gadget"],
		"desc": "一叉穿過一整排，還會把目標往你這邊拖。",
	},
	"railgun": {
		"name": "磁軌炮", "price": 1200, "weight": 11.0, "length": 130.0, "tags": ["energy"], "cal": "cell", "kind": "charge",
		"damage": 260.0, "rate": 0.4, "mag": 1, "reserve": 3, "reload": 4.0,
		"spread": 0.0, "moa": 0.5, "range": 120.0, "noise": 45.0, "recoil": 10.0, "recoil_h": 1.0, "zoom": 2.0,
		"ergo": 22.0, "velocity": 3000.0, "pen": 100.0, "flash": 85.0, "reliability": 94.0, "heat": 0.6, "cooling": 0.12,
		"effects": {"pierce": true, "stun": 2.0},
		"slots": ["barrel", "foregrip", "mount", "sight", "magazine", "stock", "gadget"],
		"desc": "按住充能 2 秒，一發貫穿直線上的一切。超重，子彈很少，打完要等它散熱。",
	},
	"duck_launcher": {
		"name": "爆炸鴨發射器", "price": 700, "weight": 4.2, "length": 80.0, "tags": ["launcher"], "cal": "duck", "kind": "lob",
		"damage": 90.0, "rate": 0.8, "mag": 3, "reserve": 6, "reload": 3.5,
		"spread": 1.0, "moa": 6.0, "range": 35.0, "noise": 60.0, "recoil": 6.0, "recoil_h": 1.0, "zoom": 1.1,
		"ergo": 45.0, "velocity": 40.0, "pen": 0.0, "flash": 40.0, "reliability": 95.0,
		"effects": {"explode": 4.0, "lure": true},
		"slots": ["rail_l", "mount", "sight", "magazine", "stock", "gadget"],
		"desc": "拋出一隻嘎嘎叫的橡皮鴨，把怪物引過去再炸開。也炸得到隊友。",
	},
	"saw_launcher": {
		"name": "圓鋸片發射器", "price": 480, "weight": 3.6, "length": 75.0, "tags": ["launcher"], "cal": "saw", "kind": "bounce",
		"damage": 38.0, "rate": 1.4, "mag": 8, "reserve": 16, "reload": 2.8,
		"spread": 0.8, "moa": 4.0, "range": 35.0, "noise": 22.0, "recoil": 3.0, "recoil_h": 0.8, "zoom": 1.2,
		"ergo": 52.0, "velocity": 60.0, "pen": 40.0, "flash": 0.0, "reliability": 88.0,
		"effects": {"chain": 1},
		"slots": ["rail_l", "underbarrel", "sight", "magazine", "stock", "gadget"],
		"desc": "鋸片打中牆會反彈，打中一個還會彈去下一個。",
	},
	"bubble_gun": {
		"name": "泡泡槍", "price": 260, "weight": 1.2, "length": 40.0, "tags": ["energy"], "cal": "soap",
		"damage": 2.0, "rate": 4.0, "modes": ["auto"], "mag": 50, "reserve": 100, "reload": 2.0,
		"spread": 2.0, "moa": 6.0, "range": 20.0, "noise": 6.0, "recoil": 0.2, "recoil_h": 0.2, "zoom": 1.0,
		"ergo": 85.0, "velocity": 15.0, "pen": 0.0, "flash": 0.0, "reliability": 97.0,
		"effects": {"bubble": 4.0},
		"slots": ["magazine", "rail_l", "gadget"],
		"desc": "幾乎不痛，但小怪會被包進泡泡裡飄 4 秒，中型怪要連中好幾發。",
	},
}

## Parts. Keys:
##   slot     the slot type it goes in
##   fits     frame tags or calibre families it goes on ("all" for anything with that slot)
##   frames   only these frames (when given)
##   cal      only these calibres (when given; checked against the build's calibre so far)
##   adds     slots it opens; blocks = slots it closes
##   set_cal  the build's calibre becomes this
##   modes    fire modes it adds; set_modes replaces them
##   x / + / = mods applied in order ("x" multiplies a stat, "+" adds, "=" sets);
##            "effects" merges into the frame's
##   tune     a slider the player sets from -1 to 1: {"name", "lo", "hi", "x": {stat: [at -1, at +1]},
##            "+": {stat: [at -1, at +1]}, "=": {stat: [at -1, at +1]}}. At 0 an "x" is 1.0 and a "+" is 0;
##            an "=" sits halfway.
const PARTS := {
	# --- Receivers / uppers (機匣): calibre conversions and whole new backbones
	"upper_300": {"name": ".300 BLK 上機匣", "slot": "receiver", "price": 380, "weight": 0.1, "fits": ["ar"], "frames": ["carbine"],
		"set_cal": ".300", "x": {"damage": 1.25, "velocity": 0.78, "range": 0.8, "recoil": 1.15, "pen": 1.05},
		"desc": "改成 .300 BLK 口徑：更痛、射程短一點。配亞音速彈加消音器，幾乎是無聲步槍。"},
	"upper_pcc": {"name": "9mm 手槍彈上機匣", "slot": "receiver", "price": 240, "weight": -0.3, "fits": ["ar"], "frames": ["carbine"],
		"set_cal": "9mm", "x": {"damage": 0.6, "velocity": 0.42, "recoil": 0.5, "recoil_h": 0.6, "range": 0.6, "noise": 0.7,
		"pen": 0.5, "rate": 1.1, "flash": 0.7}, "+": {"reliability": 5.0, "ergo": 4.0},
		"desc": "把步槍改打手槍彈：幾乎沒有後座、比較安靜。傷害和穿透大減。"},
	"upper_light": {"name": "輕量化上機匣", "slot": "receiver", "price": 300, "weight": -0.5, "fits": ["ar"],
		"x": {"cooling": 0.8}, "+": {"ergo": 5.0}, "desc": "鏤空切削，輕半公斤。散熱差一點。"},
	"upper_billet": {"name": "整塊切削上機匣", "slot": "receiver", "price": 420, "weight": 0.2, "fits": ["ar"],
		"x": {"moa": 0.85, "recoil_h": 0.9}, "+": {"reliability": 3.0},
		"desc": "一整塊鋁錠銑出來的，零件之間沒有晃動。更準。"},
	"ak_cover": {"name": "導軌防塵蓋", "slot": "receiver", "price": 140, "weight": 0.25, "fits": ["ak"],
		"adds": ["rail_r"], "x": {"moa": 1.05}, "desc": "防塵蓋上有導軌，多一個掛配件的位置。蓋子會晃，準度略差。"},
	"ak_modern": {"name": "現代化套件", "slot": "receiver", "price": 360, "weight": 0.3, "fits": ["ak"],
		"adds": ["rail_r"], "x": {"recoil_h": 0.8, "reload": 0.9}, "+": {"ergo": 6.0},
		"desc": "大保險、新拉柄、導軌蓋一次換好。比較順手。"},
	"precision_chassis": {"name": "精準底盤", "slot": "receiver", "price": 520, "weight": 1.2, "fits": ["bolt_action"],
		"adds": ["rail_r", "buttpad"], "x": {"moa": 0.7, "recoil": 0.9}, "+": {"ergo": -4.0},
		"desc": "鋁合金底盤取代木托：非常準，多出導軌和托底的位置。"},
	"cylinder_8": {"name": "八發轉輪", "slot": "receiver", "price": 220, "weight": 0.2, "fits": ["revolver"],
		"x": {"reload": 1.1}, "+": {"mag": 2}, "desc": "加大的轉輪，八發。換彈要多塞兩顆。"},
	"cylinder_45": {"name": ".45 轉換轉輪", "slot": "receiver", "price": 200, "weight": 0.1, "fits": ["revolver"],
		"set_cal": ".45", "x": {"damage": 1.2, "velocity": 0.6, "recoil": 1.1, "pen": 0.85},
		"desc": "換成 .45 ACP 的轉輪：子彈更大顆、亞音速。配消音器很安靜。"},

	# --- Barrels (槍管)
	"long_barrel": {"name": "長槍管", "slot": "barrel", "price": 160, "weight": 0.8, "fits": ["gun"],
		"x": {"range": 1.4, "spread": 0.7, "damage": 1.1, "velocity": 1.1, "moa": 0.85, "flash": 0.8}, "+": {"length": 15.0, "ergo": -6.0},
		"desc": "更遠更準，比較重、比較長。"},
	"short_barrel": {"name": "短槍管", "slot": "barrel", "price": 90, "weight": -0.3, "fits": ["gun"],
		"x": {"spread": 1.3, "rate": 1.15, "range": 0.8, "velocity": 0.88, "flash": 1.5, "moa": 1.2}, "+": {"length": -10.0, "ergo": 6.0},
		"desc": "射得快、好轉身，但散，火光大。"},
	"threaded_barrel": {"name": "螺紋槍管", "slot": "barrel", "price": 110, "weight": 0.1, "fits": ["pistol_frame", "revolver", "lever"],
		"adds": ["muzzle"], "+": {"length": 3.0},
		"desc": "槍口車了螺紋：手槍和左輪也能裝消音器、制退器。"},
	"heavy_barrel": {"name": "重型槍管", "slot": "barrel", "price": 240, "weight": 1.2, "fits": ["gun"],
		"x": {"moa": 0.6, "cooling": 1.4, "heat": 0.75}, "+": {"ergo": -8.0},
		"desc": "管壁很厚：連射也不會飄，很耐熱。非常重。"},
	"fluted_barrel": {"name": "刻槽槍管", "slot": "barrel", "price": 260, "weight": -0.3, "fits": ["gun"],
		"x": {"moa": 0.85, "cooling": 1.3}, "+": {"ergo": 3.0}, "desc": "槍管上銑出凹槽：更輕、散熱更好、更準。"},
	"match_barrel": {"name": "比賽級槍管", "slot": "barrel", "price": 380, "weight": 0.2, "fits": ["gun"],
		"x": {"moa": 0.5, "velocity": 1.03}, "+": {"reliability": -5.0},
		"desc": "公差很小的競賽槍管，非常準。對髒污很敏感，比較容易卡。"},
	"polygonal_barrel": {"name": "多邊形膛線槍管", "slot": "barrel", "price": 200, "weight": 0.0, "fits": ["gun"],
		"x": {"velocity": 1.08, "moa": 0.9, "cooling": 1.1}, "desc": "沒有陽線的膛線：子彈更快、槍管更耐用。"},
	"integral_suppressor": {"name": "整合消音槍管", "slot": "barrel", "price": 520, "weight": 0.9, "fits": ["gun"],
		"blocks": ["muzzle"], "x": {"noise": 0.3, "velocity": 0.85, "flash": 0.1, "range": 0.85, "damage": 0.95}, "+": {"length": 12.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "消音器做在槍管裡面：很安靜、沒有火光，不能再裝槍口裝置。"},
	"bbl_338": {"name": ".338 拉普槍管", "slot": "barrel", "price": 600, "weight": 0.8, "fits": ["bolt_action"], "frames": ["rifle"],
		"set_cal": ".338", "x": {"damage": 1.45, "recoil": 1.45, "noise": 1.2, "range": 1.3, "reserve": 0.75, "velocity": 1.05, "pen": 1.25, "flash": 1.3},
		"+": {"length": 10.0, "ergo": -5.0}, "desc": "改成 .338 拉普麥格農：大型怪也打得穿。後座和聲音都更兇。"},
	"rifled_slug_barrel": {"name": "膛線霰彈槍管", "slot": "barrel", "price": 180, "weight": 0.2, "fits": ["pellet"],
		"x": {"moa": 0.45, "spread": 1.2}, "desc": "霰彈槍管裡刻了膛線：獨頭彈打得很準，霰彈反而更散。"},
	"coil_barrel": {"name": "加速線圈", "slot": "barrel", "price": 260, "weight": 1.0, "fits": ["energy"],
		"x": {"damage": 1.35, "noise": 1.3, "range": 1.2, "heat": 1.3}, "desc": "電力加大：更痛、更吵、更燙。"},
	"cooling_coil": {"name": "液冷線圈", "slot": "barrel", "price": 300, "weight": 1.2, "fits": ["energy"],
		"x": {"cooling": 2.0, "heat": 0.7}, "+": {"ergo": -5.0}, "desc": "管線裡流著冷卻液：很少過熱。"},
	"nail_guide": {"name": "加長導釘管", "slot": "barrel", "price": 90, "weight": 0.3, "fits": ["gun"], "cal": ["nail"],
		"x": {"range": 1.5, "moa": 0.7, "damage": 1.15}, "desc": "釘子在管子裡跑得更久：更遠更準。"},

	# --- Muzzle devices (槍口)
	"suppressor": {"name": "螺紋消音器", "slot": "muzzle", "price": 180, "weight": 0.4, "fits": ["gun"],
		"x": {"noise": 0.35, "damage": 0.95, "flash": 0.15, "velocity": 1.02}, "+": {"length": 15.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "直接鎖在槍口上。槍聲小很多（超音速彈還是會有破空聲），幾乎沒有火光。"},
	"compensator": {"name": "補償器", "slot": "muzzle", "price": 120, "weight": 0.2, "fits": ["gun"],
		"x": {"recoil_h": 0.55, "recoil": 0.85, "spread": 0.9, "flash": 1.1}, "desc": "把氣往上噴：槍口不左右跳，連射更穩。"},
	"muzzle_brake": {"name": "制動器", "slot": "muzzle", "price": 150, "weight": 0.25, "fits": ["gun"],
		"adds": ["silencer"], "x": {"recoil": 0.6, "noise": 1.25, "flash": 1.3}, "+": {"length": 6.0},
		"desc": "把氣往兩邊噴：後座小很多，但更吵、火光更大。可以掛快拆消音器。"},
	"flash_hider": {"name": "消焰器", "slot": "muzzle", "price": 90, "weight": 0.15, "fits": ["gun"],
		"adds": ["silencer"], "x": {"flash": 0.3}, "+": {"length": 5.0},
		"desc": "火光幾乎看不見，光感怪物比較難發現你開槍。可以掛快拆消音器。"},
	"thread_adapter": {"name": "螺紋轉接器", "slot": "muzzle", "price": 40, "weight": 0.05, "fits": ["gun"],
		"adds": ["silencer"], "+": {"length": 2.0}, "desc": "什麼都不做，只是讓你能掛快拆消音器。"},
	"linear_comp": {"name": "線性補償器", "slot": "muzzle", "price": 110, "weight": 0.2, "fits": ["gun"],
		"x": {"noise": 0.85, "recoil": 0.92, "flash": 0.8}, "+": {"length": 5.0},
		"desc": "把聲音和氣都往前送：你聽起來安靜一點，前面的東西聽得更清楚。"},
	"solvent_trap": {"name": "油濾土製消音器", "slot": "muzzle", "price": 60, "weight": 0.5, "fits": ["gun"],
		"x": {"noise": 0.5, "flash": 0.4, "moa": 1.3}, "+": {"reliability": -8.0, "length": 18.0, "ergo": -6.0},
		"effects": {"suppressed": true}, "desc": "汽車油濾鑽個洞鎖上去。有效，但會讓槍變髒、變不準。"},
	"bottle_can": {"name": "寶特瓶消音器", "slot": "muzzle", "price": 15, "weight": 0.05, "fits": ["gun"],
		"x": {"noise": 0.55, "moa": 1.7, "spread": 1.2}, "+": {"length": 22.0, "ergo": -3.0},
		"effects": {"suppressed": true}, "desc": "一個膠帶纏住的寶特瓶。十五塊。真的有用，只是子彈會亂飛。"},
	"choke": {"name": "收束器", "slot": "muzzle", "price": 100, "weight": 0.2, "fits": ["pellet"],
		"tune": {"name": "收束", "lo": "圓柱", "hi": "全收", "x": {"spread": [1.25, 0.45], "range": [0.9, 1.3]}},
		"x": {"spread": 0.8, "range": 1.1}, "desc": "可調收束：轉緊打得集中、打得遠；轉鬆近距離散得更開。"},
	"duckbill": {"name": "鴨嘴噴口", "slot": "muzzle", "price": 120, "weight": 0.2, "fits": ["pellet"],
		"+": {"pellets": 2}, "x": {"spread": 1.25, "damage": 0.9}, "desc": "把霰彈壓成一條橫線：一次掃到更多東西。"},
	"breacher": {"name": "破門齒", "slot": "muzzle", "price": 80, "weight": 0.2, "fits": ["pellet"],
		"x": {"flash": 1.2}, "effects": {"bayonet": true}, "desc": "鋸齒狀的槍口：抵著東西打，也能直接拿來砸（近戰兩倍）。"},
	"wide_nozzle": {"name": "寬口噴嘴", "slot": "muzzle", "price": 140, "weight": 0.3, "fits": ["fuel"],
		"x": {"range": 0.75, "damage": 1.3}, "desc": "火噴得近，但更猛。"},
	"long_nozzle": {"name": "長管噴嘴", "slot": "muzzle", "price": 160, "weight": 0.4, "fits": ["fuel"],
		"x": {"range": 1.4, "damage": 0.85}, "+": {"length": 20.0, "ergo": -5.0}, "desc": "火柱噴得更遠，不過散開的熱力少一點。"},

	# --- Quick-detach suppressors (消音器, on a flash hider / brake / adapter)
	"can_light": {"name": "輕型快拆消音器", "slot": "silencer", "price": 260, "weight": 0.35, "fits": ["gun"],
		"x": {"noise": 0.4, "flash": 0.15, "damage": 0.97}, "+": {"length": 14.0, "ergo": -5.0},
		"effects": {"suppressed": true}, "desc": "一秒拆裝。聲音小六成。"},
	"can_heavy": {"name": "重型快拆消音器", "slot": "silencer", "price": 420, "weight": 0.7, "fits": ["gun"],
		"x": {"noise": 0.22, "flash": 0.05, "velocity": 1.03, "recoil": 0.9}, "+": {"length": 22.0, "ergo": -11.0},
		"effects": {"suppressed": true}, "desc": "又長又重，但非常安靜，後座也小一點。"},
	"can_titanium": {"name": "鈦合金短消音器", "slot": "silencer", "price": 560, "weight": 0.2, "fits": ["gun"],
		"x": {"noise": 0.45, "flash": 0.2}, "+": {"length": 9.0, "ergo": -2.0},
		"effects": {"suppressed": true}, "desc": "短、輕、貴。幾乎不影響手感。"},
	"can_wet": {"name": "濕式消音器", "slot": "silencer", "price": 300, "weight": 0.5, "fits": ["gun"],
		"x": {"noise": 0.18, "flash": 0.05, "cooling": 0.7}, "+": {"length": 16.0, "ergo": -6.0, "reliability": -4.0},
		"effects": {"suppressed": true}, "desc": "裡面灌了水：最安靜的消音器。槍會變得濕熱、比較容易卡。"},

	# --- Gas (導氣)
	"adjustable_gas": {"name": "可調導氣塊", "slot": "gas", "price": 180, "weight": 0.05, "fits": ["gun"],
		"tune": {"name": "導氣量", "lo": "少", "hi": "多", "x": {"rate": [0.8, 1.2], "recoil": [0.8, 1.25]},
			"+": {"reliability": [-10.0, 6.0]}},
		"desc": "自己調導氣量：調少後座小、射速慢、比較容易卡；調多射速快、後座大、很可靠。配消音器時調少剛好。"},
	"low_profile_gas": {"name": "低矮導氣塊", "slot": "gas", "price": 80, "weight": -0.05, "fits": ["gun"],
		"+": {"ergo": 3.0}, "desc": "藏在護木裡面的小導氣塊。順手一點。"},
	"piston_kit": {"name": "活塞套件", "slot": "gas", "price": 260, "weight": 0.3, "fits": ["gun"],
		"x": {"recoil": 1.1, "cooling": 1.15}, "+": {"reliability": 14.0},
		"desc": "把直噴改成活塞：機匣不再積碳，幾乎不卡。後座稍大。"},

	# --- Handguards (護木): where most of the accessory slots come from
	"short_handguard": {"name": "短護木", "slot": "handguard", "price": 110, "weight": 0.2, "fits": ["gun"],
		"adds": ["rail_l", "foregrip"], "+": {"ergo": 6.0}, "desc": "短而輕，只有一條側軌和一個握把位置。"},
	"long_handguard": {"name": "長護木", "slot": "handguard", "price": 160, "weight": 0.35, "fits": ["gun"],
		"adds": ["rail_l", "rail_r", "foregrip", "underbarrel"], "x": {"recoil_h": 0.95}, "+": {"ergo": -1.0},
		"desc": "M-LOK 長護木：兩邊導軌、前握把和下掛都有位置。"},
	"quad_rail": {"name": "四面導軌護木", "slot": "handguard", "price": 180, "weight": 0.6, "fits": ["gun"],
		"adds": ["rail_l", "rail_r", "foregrip", "underbarrel"], "x": {"recoil": 0.95}, "+": {"ergo": -5.0},
		"desc": "四面都是皮卡汀尼導軌，硬、重、刮手。"},
	"wood_handguard": {"name": "木護木", "slot": "handguard", "price": 70, "weight": 0.25, "fits": ["gun"],
		"adds": ["underbarrel"], "+": {"ergo": 4.0}, "x": {"cooling": 0.9}, "desc": "老式木頭護木，握起來很舒服。沒有導軌。"},
	"heatshield": {"name": "散熱護木", "slot": "handguard", "price": 200, "weight": 0.3, "fits": ["gun"],
		"adds": ["rail_l", "foregrip"], "x": {"cooling": 1.5}, "desc": "滿滿的散熱孔：連射後很快冷下來。"},
	"pump_rail": {"name": "導軌泵動護木", "slot": "handguard", "price": 120, "weight": 0.3, "fits": ["pellet"],
		"adds": ["rail_l", "foregrip"], "x": {"rate": 1.08}, "desc": "泵動霰彈的護木換成帶導軌的，拉起來更快。"},

	# --- Rail accessories (導軌配件)
	"flashlight": {"name": "戰術燈", "slot": "rail", "price": 70, "weight": 0.2, "fits": "all",
		"effects": {"light": true}, "desc": "槍上的燈，跟著準心照。開著燈的你很好認。"},
	"laser": {"name": "雷射指示器", "slot": "rail", "price": 120, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.7}, "effects": {"laser": true}, "desc": "不瞄準也打得準。紅點別人看得到。"},
	"laser_ir": {"name": "紅外線雷射", "slot": "rail", "price": 260, "weight": 0.15, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"laser_ir": true}, "desc": "看不見的雷射：一樣讓腰射更準，但別人看不到你的點。"},
	"combo_light": {"name": "光雷二合一", "slot": "rail", "price": 220, "weight": 0.3, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"light": true, "laser": true}, "desc": "燈和雷射在一個盒子裡，只佔一條軌道。"},
	"strobe_light": {"name": "爆閃戰術燈", "slot": "rail", "price": 180, "weight": 0.25, "fits": "all",
		"effects": {"light": true, "strobe": true}, "desc": "會頻閃的強光：瞄準時照到的玩家會被閃得看不清楚。怪物也會注意到你。"},
	"rail_counter": {"name": "彈數顯示器", "slot": "rail", "price": 90, "weight": 0.05, "fits": "all",
		"x": {"reload": 0.95}, "desc": "一個小螢幕告訴你彈匣裡還剩幾發。知道什麼時候該換彈，換得快一點。"},

	# --- Foregrips (前握把)
	"vertical_grip": {"name": "垂直握把", "slot": "foregrip", "price": 80, "weight": 0.15, "fits": "all",
		"x": {"recoil": 0.85}, "+": {"ergo": 2.0}, "desc": "壓得住往上跳的槍口。"},
	"angled_grip": {"name": "斜角握把", "slot": "foregrip", "price": 90, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.95, "recoil_h": 0.9}, "+": {"ergo": 8.0}, "desc": "手腕自然的角度：舉槍瞄準快很多。"},
	"stubby_grip": {"name": "短握把", "slot": "foregrip", "price": 60, "weight": 0.08, "fits": "all",
		"x": {"recoil": 0.92}, "+": {"ergo": 4.0}, "desc": "折衷：一點點穩，一點點快。"},
	"handstop": {"name": "擋手", "slot": "foregrip", "price": 40, "weight": 0.04, "fits": "all",
		"x": {"recoil_h": 0.85}, "+": {"ergo": 3.0}, "desc": "手往前頂住：槍口不左右晃。"},
	"bipod": {"name": "兩腳架", "slot": "foregrip", "price": 160, "weight": 0.5, "fits": "all",
		"x": {"recoil": 0.95}, "+": {"ergo": -6.0}, "effects": {"bipod": true},
		"desc": "站著不動瞄準時架起來：後座只剩三成，散佈也小。走動時就只是累贅。"},
	"grip_pod": {"name": "握把腳架", "slot": "foregrip", "price": 220, "weight": 0.3, "fits": "all",
		"x": {"recoil": 0.9}, "+": {"ergo": -1.0}, "effects": {"bipod": true},
		"desc": "握把底下彈出小腳架。腳架效果沒那麼好（後座剩五成），但平常也能當握把。"},

	# --- Underbarrel (下掛)
	"bayonet": {"name": "刺刀", "slot": "underbarrel", "price": 60, "weight": 0.3, "fits": "all",
		"effects": {"bayonet": true}, "desc": "近戰（V）傷害兩倍。"},
	"spike_bayonet": {"name": "三稜刺", "slot": "underbarrel", "price": 90, "weight": 0.35, "fits": "all",
		"effects": {"bayonet": true, "bleed": 3.0}, "+": {"length": 30.0, "ergo": -2.0},
		"desc": "很長的三角刺：近戰兩倍，刺到的東西會流血 3 秒。"},
	"chainsaw_bayonet": {"name": "鏈鋸刺刀", "slot": "underbarrel", "price": 280, "weight": 1.6, "fits": "all",
		"effects": {"bayonet": true, "fang": true}, "x": {"noise": 1.1}, "+": {"ergo": -10.0},
		"desc": "槍管底下的小鏈鋸：近戰三倍。很重，而且一直在嗡嗡叫。"},
	"riot_shield": {"name": "小型防彈盾", "slot": "underbarrel", "price": 320, "weight": 2.5, "fits": "all",
		"effects": {"guard": 0.25}, "x": {"spread": 1.1}, "+": {"ergo": -12.0},
		"desc": "掛在槍下的小盾：瞄準時受到的傷害少四分之一。非常礙手。"},

	# --- Offset / backup sights (副瞄座)
	"canted_dot": {"name": "偏置紅點", "slot": "mount", "price": 140, "weight": 0.1, "fits": "all",
		"x": {"spread": 0.75}, "effects": {"canted": true}, "desc": "主鏡旁邊斜裝一個紅點：不舉鏡也能打得比較準。"},
	"backup_irons": {"name": "折疊備用照門", "slot": "mount", "price": 70, "weight": 0.05, "fits": "all",
		"+": {"ergo": 3.0}, "x": {"moa": 0.95}, "desc": "主鏡起霧時還有東西可以看。順手一點。"},
	"cantilever": {"name": "懸臂鏡座", "slot": "mount", "price": 100, "weight": 0.15, "fits": "all",
		"x": {"moa": 0.92}, "+": {"ergo": -1.0}, "desc": "把主鏡往前推到剛好的位置，眼睛不用找。"},
	"riser": {"name": "增高座", "slot": "mount", "price": 60, "weight": 0.08, "fits": "all",
		"x": {"recoil": 0.95}, "+": {"ergo": 2.0}, "desc": "鏡子架高一點，抬頭就看到，脖子比較不受後座影響。"},

	# --- Sights (瞄具)
	"peep_sight": {"name": "覘孔照門", "slot": "sight", "price": 60, "weight": 0.05, "fits": "all",
		"x": {"moa": 0.85}, "=": {"zoom": 1.2}, "desc": "簡單的小孔照門。比原廠準。"},
	"red_dot": {"name": "紅點瞄具", "slot": "sight", "price": 110, "weight": 0.2, "fits": "all",
		"x": {"spread": 0.8, "moa": 0.85}, "+": {"ergo": 2.0}, "=": {"zoom": 1.35}, "desc": "瞄準時更準、更快。"},
	"pistol_dot": {"name": "手槍紅點", "slot": "sight", "price": 120, "weight": 0.05, "fits": ["pistol_frame", "revolver"],
		"x": {"moa": 0.8}, "+": {"ergo": 3.0}, "=": {"zoom": 1.25}, "desc": "滑套上的迷你紅點。手槍也能打得準。"},
	"holo": {"name": "全息瞄具", "slot": "sight", "price": 200, "weight": 0.3, "fits": "all",
		"x": {"spread": 0.75, "moa": 0.85}, "+": {"ergo": 3.0}, "=": {"zoom": 1.3}, "desc": "大窗口、兩眼睜開，近戰瞄準最快。"},
	"acog": {"name": "固定 4 倍鏡", "slot": "sight", "price": 280, "weight": 0.45, "fits": "all",
		"x": {"moa": 0.75}, "+": {"ergo": -3.0}, "=": {"zoom": 2.4}, "desc": "短而硬的四倍鏡：中距離剛好。"},
	"scope": {"name": "8 倍狙擊鏡", "slot": "sight", "price": 240, "weight": 0.5, "fits": "all",
		"x": {"spread": 0.6, "moa": 0.7}, "+": {"ergo": -6.0}, "=": {"zoom": 3.0}, "desc": "看得很遠。近距離反而難用。"},
	"variable_scope": {"name": "1-6 倍可變鏡", "slot": "sight", "price": 450, "weight": 0.6, "fits": "all",
		"x": {"moa": 0.75}, "+": {"ergo": -4.0},
		"tune": {"name": "倍率", "lo": "1 倍", "hi": "6 倍", "=": {"zoom": [1.15, 3.6]}, "+": {"ergo": [3.0, -4.0]}},
		"desc": "自己轉倍率：1 倍近戰、6 倍遠距離。"},
	"thermal": {"name": "熱成像鏡", "slot": "sight", "price": 420, "weight": 0.6, "fits": "all",
		"=": {"zoom": 1.6}, "+": {"ergo": -4.0}, "effects": {"thermal": true}, "desc": "瞄準時看得到黑暗裡和隱形的怪物。"},
	"night_vision": {"name": "夜視瞄具", "slot": "sight", "price": 380, "weight": 0.55, "fits": "all",
		"=": {"zoom": 1.5}, "+": {"ergo": -3.0}, "effects": {"night": true},
		"desc": "瞄準時整片黑暗都變成綠色的白天。看到的是地形，不是怪物身上的熱。"},

	# --- Pistol grips (握把)
	"rubber_grip": {"name": "橡膠握把", "slot": "grip", "price": 50, "weight": 0.05, "fits": "all",
		"x": {"recoil": 0.92}, "+": {"ergo": 3.0}, "desc": "不滑手，吸收一點後座。"},
	"skeleton_grip": {"name": "鏤空握把", "slot": "grip", "price": 90, "weight": -0.05, "fits": "all",
		"+": {"ergo": 6.0}, "desc": "很輕，抓起來很快。"},
	"wood_grip": {"name": "胡桃木握把", "slot": "grip", "price": 120, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.88}, "+": {"ergo": -1.0}, "desc": "沉甸甸的木頭，把槍壓得很穩。"},
	"tape_grip": {"name": "膠帶纏繞", "slot": "grip", "price": 10, "weight": 0.0, "fits": "all",
		"+": {"ergo": 2.0}, "desc": "整卷布膠帶纏上去。十塊。"},
	"stippled_grip": {"name": "燒灼防滑握把", "slot": "grip", "price": 70, "weight": 0.0, "fits": "all",
		"x": {"recoil_h": 0.9}, "+": {"ergo": 4.0}, "desc": "用烙鐵燙出顆粒：手汗也不滑。"},

	# --- Trigger groups (扳機組)
	"match_trigger": {"name": "比賽扳機", "slot": "trigger", "price": 160, "weight": 0.0, "fits": "all",
		"x": {"moa": 0.85},
		"tune": {"name": "扳機力", "lo": "輕", "hi": "重", "x": {"rate": [1.15, 0.92], "moa": [1.1, 0.88]}},
		"desc": "乾淨俐落的擊發。可以調扳機力：輕的射得快、重的打得準。"},
	"auto_sear": {"name": "全自動阻鐵", "slot": "trigger", "price": 450, "weight": 0.05, "fits": ["gun"],
		"modes": ["auto"], "+": {"reliability": -8.0}, "x": {"heat": 1.1},
		"desc": "讓半自動槍能全自動。不太合法，也不太可靠。"},
	"burst_group": {"name": "三連發扳機組", "slot": "trigger", "price": 300, "weight": 0.05, "fits": ["gun"],
		"modes": ["burst"], "x": {"recoil": 0.95}, "desc": "扣一下打三發。比全自動好控制。"},
	"binary_trigger": {"name": "二元扳機", "slot": "trigger", "price": 380, "weight": 0.05, "fits": ["gun"],
		"x": {"rate": 1.6, "spread": 1.15}, "+": {"reliability": -4.0},
		"desc": "扣下去打一發，放開再打一發。半自動快很多。"},
	"hair_trigger": {"name": "羽毛扳機", "slot": "trigger", "price": 120, "weight": 0.0, "fits": "all",
		"x": {"rate": 1.15, "spread": 1.1}, "desc": "碰一下就擊發。快，但緊張時容易打歪。"},
	"double_set": {"name": "雙扳機（預扣）", "slot": "trigger", "price": 220, "weight": 0.05, "fits": ["bolt_action", "lever", "pellet"],
		"x": {"moa": 0.7, "rate": 0.9}, "desc": "先扣後扳機上膛，前扳機一碰就發。非常準，比較慢。"},

	# --- Bolts / springs (槍機)
	"heavy_buffer": {"name": "重型緩衝器", "slot": "bolt", "price": 90, "weight": 0.1, "fits": ["gun"],
		"x": {"recoil": 0.85, "rate": 0.88}, "+": {"reliability": 2.0}, "desc": "槍機回得慢一點：射速降、後座降。"},
	"light_spring": {"name": "輕復進簧", "slot": "bolt", "price": 60, "weight": 0.0, "fits": ["gun"],
		"x": {"rate": 1.15, "recoil": 1.05}, "+": {"reliability": -6.0}, "desc": "射得更快，彈殼偶爾拋不乾淨。"},
	"heavy_spring": {"name": "強化復進簧", "slot": "bolt", "price": 60, "weight": 0.0, "fits": ["gun"],
		"x": {"rate": 0.92}, "+": {"reliability": 9.0}, "desc": "射得慢一點，但幾乎不卡。"},
	"light_bolt": {"name": "輕量槍機", "slot": "bolt", "price": 240, "weight": -0.15, "fits": ["gun"],
		"x": {"rate": 1.2, "recoil": 1.1, "recoil_h": 1.2}, "+": {"reliability": -3.0}, "desc": "槍機減重：射速快兩成，槍口更亂。"},
	"nickel_bolt": {"name": "鍍鎳槍機", "slot": "bolt", "price": 200, "weight": 0.0, "fits": ["gun"],
		"x": {"cooling": 1.1}, "+": {"reliability": 12.0}, "desc": "滑順的鍍層，髒了也照樣動。"},
	"bolt_knob": {"name": "加大拉柄球", "slot": "bolt", "price": 50, "weight": 0.03, "fits": ["bolt_action", "lever"],
		"x": {"rate": 1.25}, "desc": "大大的拉柄球：拉槍機更快。"},
	"lever_loop": {"name": "大環槓桿", "slot": "bolt", "price": 70, "weight": 0.05, "fits": ["lever"],
		"x": {"rate": 1.35}, "+": {"ergo": -2.0}, "desc": "戴手套也能甩的大環：可以單手轉槍上膛。"},

	# --- Charging handles (拉機柄)
	"ambi_charging": {"name": "雙邊拉機柄", "slot": "charging", "price": 90, "weight": 0.02, "fits": ["gun"],
		"x": {"reload": 0.92}, "+": {"ergo": 2.0}, "effects": {"quick_clear": true}, "desc": "左右手都拉得到：換彈快一點，卡彈清得快。"},
	"extended_latch": {"name": "加長拉柄卡榫", "slot": "charging", "price": 50, "weight": 0.01, "fits": ["gun"],
		"x": {"reload": 0.95}, "effects": {"quick_clear": true}, "desc": "大一點的卡榫，摸得到。卡彈清得快。"},
	"side_charging": {"name": "側拉式拉柄", "slot": "charging", "price": 150, "weight": 0.05, "fits": ["gun"],
		"x": {"reload": 0.85}, "+": {"ergo": 1.0}, "desc": "從側面拉：不用把臉離開鏡子，換彈更快。"},

	# --- Magazines (彈匣)
	"extended_mag": {"name": "擴充彈匣", "slot": "magazine", "price": 130, "weight": 0.4, "fits": ["gun", "launcher"],
		"x": {"mag": 1.6, "reload": 1.1}, "+": {"ergo": -2.0}, "desc": "子彈多一半。"},
	"drum_mag": {"name": "彈鼓", "slot": "magazine", "price": 230, "weight": 1.2, "fits": ["gun"],
		"x": {"mag": 2.5, "reload": 1.4}, "+": {"reliability": -4.0, "ergo": -6.0}, "desc": "子彈多兩倍半，換彈很慢、比較容易卡。"},
	"twin_drum": {"name": "雙彈鼓", "slot": "magazine", "price": 380, "weight": 1.8, "fits": ["rifle"],
		"x": {"mag": 3.3, "reload": 1.8}, "+": {"reliability": -10.0, "ergo": -10.0}, "desc": "一百發的蝴蝶彈鼓。很容易卡，但卡之前很爽。"},
	"quick_mag": {"name": "快拔彈匣", "slot": "magazine", "price": 150, "weight": 0.1, "fits": ["gun", "launcher"],
		"x": {"reload": 0.55}, "desc": "底部有拉環：換彈快一倍。"},
	"coupled_mag": {"name": "並聯彈匣", "slot": "magazine", "price": 120, "weight": 0.35, "fits": ["gun"],
		"x": {"reload": 0.7}, "+": {"ergo": -3.0}, "desc": "兩個彈匣綁在一起，翻過來就是滿的。"},
	"polymer_mag": {"name": "聚合物彈匣", "slot": "magazine", "price": 70, "weight": -0.15, "fits": ["gun"],
		"+": {"reliability": 3.0, "ergo": 1.0}, "desc": "輕、不生鏽，送彈很順。"},
	"casket_mag": {"name": "四排彈匣", "slot": "magazine", "price": 260, "weight": 0.6, "fits": ["gun"],
		"x": {"mag": 2.0, "reload": 1.15}, "+": {"reliability": -8.0, "ergo": -3.0}, "desc": "跟普通彈匣一樣長，子彈多一倍。彈簧很難搞。"},
	"speedloader": {"name": "快速裝填器", "slot": "magazine", "price": 80, "weight": 0.05, "fits": ["revolver"],
		"x": {"reload": 0.45}, "desc": "六顆一次塞進轉輪。"},
	"tube_extension": {"name": "延長彈倉管", "slot": "magazine", "price": 140, "weight": 0.4, "fits": ["pellet", "lever"],
		"+": {"mag": 3, "ergo": -3.0}, "desc": "管狀彈倉加長：多三發。"},
	"side_saddle": {"name": "側鞍彈架", "slot": "magazine", "price": 70, "weight": 0.3, "fits": ["pellet"],
		"x": {"reload": 0.85}, "+": {"reserve": 8}, "desc": "機匣旁邊插一排備彈，伸手就拿得到。"},
	"box_mag_conv": {"name": "盒式彈匣轉換", "slot": "magazine", "price": 300, "weight": 0.5, "fits": ["pellet"],
		"frames": ["shotgun", "auto_shotgun"], "x": {"reload": 0.5}, "+": {"mag": 1, "reliability": -6.0},
		"desc": "把霰彈槍改成插彈匣：換彈快一倍。偶爾送彈不順。"},
	"belt_box": {"name": "兩百發彈鏈箱", "slot": "magazine", "price": 420, "weight": 2.4, "fits": ["gun"], "frames": ["lmg"],
		"x": {"mag": 2.0, "reload": 1.2}, "+": {"ergo": -6.0}, "desc": "兩百發。開火開到槍管發紅。"},
	"big_tank": {"name": "大油罐", "slot": "magazine", "price": 160, "weight": 1.5, "fits": ["fuel"],
		"x": {"mag": 2.0, "reserve": 1.5}, "desc": "燃料多一倍。"},
	"capacitor": {"name": "大電容", "slot": "magazine", "price": 200, "weight": 0.8, "fits": ["energy"],
		"x": {"mag": 1.8, "reload": 0.8}, "desc": "電多、充得快。"},
	"nail_coil": {"name": "捲釘匣", "slot": "magazine", "price": 110, "weight": 0.6, "fits": ["gun"], "cal": ["nail"],
		"x": {"mag": 2.5, "reload": 1.2}, "+": {"reliability": 5.0}, "desc": "一捲兩百根的工業釘。"},

	# --- Ammo (彈藥): by calibre family
	"fmj": {"name": "全金屬被甲彈", "slot": "ammo", "price": 30, "weight": 0.0, "fits": ["pistol", "rifle"],
		"+": {"pen": 10.0, "reliability": 2.0}, "desc": "最普通的彈：穿透好一點，送彈最順。"},
	"hollow_point": {"name": "空尖彈", "slot": "ammo", "price": 90, "weight": 0.0, "fits": ["pistol", "rifle"],
		"+": {"pen": -15.0}, "effects": {"soft": true}, "desc": "對中小型怪多 40% 傷害，對大型怪很差。"},
	"ap_rounds": {"name": "穿甲彈", "slot": "ammo", "price": 160, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"damage": 0.92, "velocity": 1.05}, "+": {"pen": 35.0}, "effects": {"pierce": true, "armor": true},
		"desc": "鎢芯：打穿一排，對大型怪多 50% 傷害。"},
	"subsonic": {"name": "亞音速彈", "slot": "ammo", "price": 70, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"velocity": 0.7, "noise": 0.75, "damage": 0.88, "flash": 0.7, "recoil": 0.85, "range": 0.8},
		"desc": "比音速慢：配消音器時沒有破空聲，真正安靜。"},
	"plus_p": {"name": "高壓彈 +P", "slot": "ammo", "price": 110, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"damage": 1.15, "velocity": 1.1, "recoil": 1.2, "flash": 1.2}, "+": {"reliability": -3.0},
		"desc": "多塞了火藥：更痛、更快，後座更大，槍磨得更兇。"},
	"tracer": {"name": "曳光彈", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"spread": 0.9, "flash": 1.3}, "effects": {"tracer": true},
		"desc": "彈頭會發光：你看得到自己打到哪，所有人也看得到子彈從哪來。"},
	"match_ammo": {"name": "比賽級彈", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["pistol", "rifle"],
		"x": {"moa": 0.7}, "desc": "每一顆都秤過重量。非常準。"},
	"incendiary": {"name": "燃燒彈", "slot": "ammo", "price": 150, "weight": 0.0, "fits": ["pistol", "rifle", "bolt"],
		"effects": {"burn": 2.5}, "x": {"flash": 1.2}, "desc": "打中會燒起來。"},
	"api_rounds": {"name": "穿甲燃燒彈", "slot": "ammo", "price": 260, "weight": 0.0, "fits": ["rifle"],
		"+": {"pen": 30.0}, "effects": {"burn": 1.5, "armor": true}, "desc": "穿甲又會燒。貴。"},
	"shock_rounds": {"name": "電擊彈", "slot": "ammo", "price": 170, "weight": 0.0, "fits": ["pistol", "rifle", "bolt"],
		"effects": {"stun": 0.4}, "x": {"damage": 0.85}, "desc": "每一發都讓目標麻一下。"},
	"handload": {"name": "自己復裝的彈", "slot": "ammo", "price": 15, "weight": 0.0, "fits": ["pistol", "rifle", "shell"],
		"x": {"damage": 1.05, "moa": 1.15}, "+": {"reliability": -12.0}, "desc": "撿彈殼回來自己壓的。便宜、稍微猛，常常卡。"},
	"buckshot_mag": {"name": "三吋馬格南鹿彈", "slot": "ammo", "price": 80, "weight": 0.0, "fits": ["shell"],
		"x": {"damage": 1.25, "recoil": 1.4, "noise": 1.1}, "desc": "更長的霰彈：每顆彈丸更痛，肩膀也更痛。"},
	"slug": {"name": "獨頭彈", "slot": "ammo", "price": 70, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 1}, "x": {"damage": 5.5, "spread": 0.25, "range": 2.4, "moa": 0.6}, "+": {"pen": 30.0},
		"effects": {"knock": 1.8}, "desc": "一整顆鉛彈頭：一槍很痛，打得遠。散佈幾乎沒了，要打得準。"},
	"birdshot": {"name": "鳥彈", "slot": "ammo", "price": 25, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 18}, "x": {"damage": 0.35, "spread": 1.3, "recoil": 0.7, "range": 0.8}, "+": {"pen": -10.0},
		"desc": "一大把小鋼珠。打鼠群很好用，打大東西像在灑沙。"},
	"flechette": {"name": "鋼鏢彈", "slot": "ammo", "price": 120, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 12}, "x": {"damage": 0.65, "spread": 0.7, "range": 1.5}, "+": {"pen": 40.0},
		"desc": "裝滿小鋼鏢：穿透很好，飛得遠。"},
	"dragon_breath": {"name": "龍息彈", "slot": "ammo", "price": 140, "weight": 0.0, "fits": ["shell"],
		"x": {"damage": 0.5, "range": 0.5, "flash": 2.0}, "effects": {"burn": 3.0, "light": true},
		"desc": "噴出一條火龍：近距離把東西點燃。整個房間都會被照亮。"},
	"rock_salt": {"name": "粗鹽彈", "slot": "ammo", "price": 60, "weight": 0.0, "fits": ["shell"],
		"effects": {"reveal": true, "slow": 1.0}, "x": {"damage": 0.6}, "desc": "不太痛，但能逼出霧行者，打到的都會變慢。"},
	"beanbag": {"name": "布袋彈", "slot": "ammo", "price": 50, "weight": 0.0, "fits": ["shell"],
		"=": {"pellets": 1}, "x": {"damage": 1.6, "spread": 0.4}, "effects": {"knock": 3.0, "stun": 0.8},
		"desc": "一包鉛砂：不太會傷人，但能把東西打退、打暈一下。"},
	"explosive_bolt": {"name": "爆裂箭頭", "slot": "ammo", "price": 200, "weight": 0.0, "fits": ["bolt"],
		"effects": {"explode": 2.5}, "x": {"reserve": 0.6}, "desc": "命中爆炸，箭變少。"},
	"net_bolt": {"name": "網箭頭", "slot": "ammo", "price": 130, "weight": 0.0, "fits": ["bolt"],
		"effects": {"slow": 4.0}, "x": {"damage": 0.4}, "desc": "把目標纏住，慢 4 秒。"},
	"broadhead": {"name": "寬刃箭頭", "slot": "ammo", "price": 100, "weight": 0.0, "fits": ["bolt"],
		"x": {"damage": 1.2}, "+": {"pen": -15.0}, "effects": {"bleed": 4.0}, "desc": "三片刀刃：傷口會一直流血。"},
	"rusty_nails": {"name": "生鏽鐵釘", "slot": "ammo", "price": 20, "weight": 0.0, "fits": ["gun"], "cal": ["nail"],
		"effects": {"bleed": 2.0}, "+": {"reliability": -5.0}, "desc": "撿來的生鏽釘：打中會流血，偶爾卡在槍裡。"},

	# --- Stocks (槍托)
	"heavy_stock": {"name": "重槍托", "slot": "stock", "price": 100, "weight": 1.0, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "x": {"recoil": 0.6, "spread": 0.85}, "+": {"ergo": -4.0}, "desc": "穩，但重。"},
	"light_stock": {"name": "輕槍托", "slot": "stock", "price": 80, "weight": -0.5, "fits": ["gun", "bolt", "energy", "launcher"],
		"x": {"recoil": 1.2}, "+": {"ergo": 5.0}, "desc": "減重，後座大一點。"},
	"folding_stock": {"name": "摺疊槍托", "slot": "stock", "price": 120, "weight": 0.3, "fits": ["gun", "bolt", "energy"],
		"x": {"recoil": 1.1}, "+": {"length": -22.0, "ergo": 7.0}, "desc": "摺起來很短，好轉身、舉槍快。"},
	"adjustable_stock": {"name": "伸縮槍托", "slot": "stock", "price": 140, "weight": 0.4, "fits": ["gun", "bolt", "energy", "launcher"],
		"adds": ["buttpad"], "x": {"recoil": 0.8},
		"tune": {"name": "長度", "lo": "最短", "hi": "最長", "x": {"recoil": [1.15, 0.85]}, "+": {"ergo": [6.0, -5.0], "length": [-10.0, 6.0]}},
		"desc": "可以調長度：收短好轉身、舉槍快；拉長頂得穩、後座小。"},
	"precision_stock": {"name": "精準槍托", "slot": "stock", "price": 260, "weight": 1.1, "fits": ["gun", "bolt"],
		"adds": ["buttpad"], "x": {"moa": 0.85, "recoil": 0.8}, "+": {"ergo": -6.0}, "desc": "可調托腮和托底：狙擊手的槍托。"},
	"wire_stock": {"name": "鋼絲槍托", "slot": "stock", "price": 40, "weight": 0.15, "fits": ["gun"],
		"x": {"recoil": 0.9}, "+": {"ergo": 3.0}, "desc": "一根彎成槍托形狀的鐵絲。比沒有好。"},
	"pistol_brace": {"name": "手槍托架", "slot": "stock", "price": 150, "weight": 0.35, "fits": ["pistol_frame"],
		"x": {"recoil": 0.65, "moa": 0.8, "recoil_h": 0.75}, "+": {"ergo": -4.0, "length": 20.0},
		"desc": "把手槍變成小卡賓：穩很多，不再那麼好藏。"},
	"hydraulic_stock": {"name": "液壓緩衝槍托", "slot": "stock", "price": 340, "weight": 1.4, "fits": ["gun", "bolt", "energy"],
		"adds": ["buttpad"], "x": {"recoil": 0.55, "recoil_h": 0.85}, "+": {"ergo": -8.0}, "desc": "裡面有一根油壓桿：後座只剩一半。"},
	"bump_stock": {"name": "托式連發器", "slot": "stock", "price": 300, "weight": 0.5, "fits": ["gun"],
		"modes": ["auto"], "x": {"spread": 1.6, "recoil_h": 1.5}, "+": {"ergo": -3.0},
		"desc": "靠後座力自己撞扳機：半自動也能全自動亂噴，但完全打不準。"},

	# --- Butt pads / cheek risers (托底)
	"rubber_pad": {"name": "橡膠托底", "slot": "buttpad", "price": 40, "weight": 0.1, "fits": "all",
		"x": {"recoil": 0.9}, "desc": "一塊軟橡膠：肩膀舒服一點。"},
	"gel_pad": {"name": "凝膠托底", "slot": "buttpad", "price": 90, "weight": 0.2, "fits": "all",
		"x": {"recoil": 0.82}, "+": {"ergo": -1.0}, "desc": "吸收很多後座的凝膠墊。"},
	"cheek_riser": {"name": "托腮板", "slot": "buttpad", "price": 70, "weight": 0.1, "fits": "all",
		"x": {"moa": 0.9}, "+": {"ergo": 3.0}, "desc": "臉一貼上去眼睛就對準了。"},
	"ammo_sleeve": {"name": "托上彈袋", "slot": "buttpad", "price": 50, "weight": 0.25, "fits": "all",
		"x": {"reserve": 1.25}, "+": {"ergo": -1.0}, "desc": "套在槍托上的彈袋：多帶一些備彈。"},

	# --- Gadget: the strange stuff
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
	"heatsink_fins": {"name": "散熱鰭片", "slot": "gadget", "price": 150, "weight": 0.3, "fits": "all",
		"x": {"cooling": 1.6}, "desc": "夾在槍上的電腦散熱片。很醜，很有用。"},
	"oil_can": {"name": "隨身油壺", "slot": "gadget", "price": 90, "weight": 0.15, "fits": "all",
		"+": {"reliability": 8.0}, "desc": "每打一個彈匣就滴兩滴：卡彈少很多。"},
	"rabbit_foot": {"name": "兔腳吊飾", "slot": "gadget", "price": 120, "weight": 0.05, "fits": "all",
		"+": {"reliability": 4.0, "ergo": 2.0}, "desc": "據說很幸運。好像真的有一點。"},

	# --- Organs (器官): never sold. They come out of monsters (see Organs) and carry that
	# monster's power, always with a catch. "monster" is the roster kind that drops it.
	# Muzzle
	"screamer_mask": {"name": "尖叫面具", "slot": "muzzle", "price": 0, "organ": true, "monster": "screamer",
		"weight": 0.5, "fits": ["gun", "fuel"], "x": {"noise": 0.35, "damage": 0.85}, "effects": {"scream": true},
		"desc": "槍口本身很安靜，但每一發打到的地方都會尖叫，把那一帶的怪物引過去（不是引向你）。傷害少一點。"},
	"stalker_shadow": {"name": "影子跟蹤者的影", "slot": "muzzle", "price": 0, "organ": true, "monster": "stalker",
		"weight": 0.1, "fits": ["gun"], "x": {"noise": 0.08, "damage": 0.7, "range": 0.75, "flash": 0.0}, "effects": {"hush": true},
		"desc": "影子吞掉槍聲和火光：幾乎沒有聲音，也幾乎吵不醒廢墟。但它也吞掉三成傷害，子彈飛不遠。"},
	"greeter_smile": {"name": "迎賓員的笑臉", "slot": "muzzle", "price": 0, "organ": true, "monster": "greeter",
		"weight": 0.6, "fits": ["gun"], "x": {"damage": 1.35, "noise": 1.5},
		"desc": "咬在槍口上的整張笑臉：傷害多三成五。每一槍它都會大聲說「歡迎光臨」。"},
	"fog_lung": {"name": "霧行者的肺", "slot": "muzzle", "price": 0, "organ": true, "monster": "fog_walker",
		"weight": 0.7, "fits": ["gun", "fuel"], "x": {"noise": 0.6, "range": 0.7, "flash": 0.2}, "effects": {"reveal": true},
		"desc": "槍口噴出冷霧：子彈會逼出隱形的東西，槍聲和火光也被霧吃掉一些。但霧讓子彈飛不遠。"},
	# Barrel
	"splitter_core": {"name": "分裂者的核", "slot": "barrel", "price": 0, "organ": true, "monster": "splitter",
		"weight": 0.9, "fits": ["gun", "energy"], "+": {"pellets": 2, "spread": 1.5}, "x": {"damage": 0.5, "spread": 1.4},
		"desc": "子彈一出膛就裂成三顆。每顆只剩一半傷害，而且散得很開。"},
	"burrower_drill": {"name": "穿山者的鑽爪", "slot": "barrel", "price": 0, "organ": true, "monster": "burrower",
		"weight": 1.8, "fits": ["gun", "energy"], "x": {"range": 0.6, "rate": 0.8}, "+": {"pen": 40.0}, "effects": {"pierce": true, "armor": true},
		"desc": "子彈會鑽：貫穿一整排，對大型怪多 50%。但鑽不遠，射得也慢。"},
	# Sight
	"watcher_eye": {"name": "長頸觀察者的眼", "slot": "sight", "price": 0, "organ": true, "monster": "watcher",
		"weight": 1.2, "fits": ["gun", "bolt", "energy", "launcher"], "=": {"zoom": 2.2}, "x": {"spread": 1.2, "moa": 1.3},
		"effects": {"motion_sight": true},
		"desc": "瞄準時，牆後所有「在動」的東西都看得到（不動的就看不到）。眼球自己會亂轉，散佈大一點。"},
	"eye_lens": {"name": "窺視眼的眼球", "slot": "sight", "price": 0, "organ": true, "monster": "eyes",
		"weight": 0.3, "fits": ["gun", "bolt", "energy", "launcher"], "=": {"zoom": 1.8}, "x": {"spread": 0.7, "moa": 0.7},
		"effects": {"thermal": true, "squeal": true},
		"desc": "瞄準時看得到黑暗裡和隱形的怪物，而且很準。但被你盯著時它會一直尖叫，附近的東西都聽得到。"},
	# Magazine
	"centipede_segment": {"name": "蜈蚣列車的節", "slot": "magazine", "price": 0, "organ": true, "monster": "centipede",
		"weight": 2.5, "fits": ["gun", "launcher", "energy"], "x": {"mag": 3.0, "rate": 1.2, "reload": 2.2},
		"desc": "像列車一樣一節接一節：子彈多三倍、射得更快。但換彈要把整節拖出來，非常慢。"},
	"mimic_shell": {"name": "擬態蟲的殼", "slot": "magazine", "price": 0, "organ": true, "monster": "mimic",
		"weight": 0.4, "fits": ["gun", "launcher"], "x": {"mag": 0.6}, "effects": {"ghost": 3},
		"desc": "它會模仿子彈：每第 3 發不耗彈。但殼裡只塞得下六成子彈。"},
	"collector_sack": {"name": "回收員的袋子", "slot": "magazine", "price": 0, "organ": true, "monster": "collector",
		"weight": 1.0, "fits": ["gun", "launcher", "energy", "fuel"], "x": {"reserve": 2.0, "reload": 1.3, "noise": 1.15},
		"desc": "它會把彈殼撿回來：備彈多一倍。換彈要在袋子裡翻，比較慢，還會吱吱叫。"},
	# Stock
	"knight_door": {"name": "盾甲騎士的門板", "slot": "stock", "price": 0, "organ": true, "monster": "shield_knight",
		"weight": 6.0, "fits": ["gun", "bolt", "energy", "launcher"], "x": {"recoil": 0.5}, "+": {"ergo": -15.0}, "effects": {"guard": 0.5},
		"desc": "瞄準時把門板頂在前面：受到的傷害減半，後座也小。但一整扇鐵門非常重。"},
	"mannequin_arm": {"name": "假人的手臂", "slot": "stock", "price": 0, "organ": true, "monster": "mannequin",
		"weight": 1.4, "fits": ["gun", "bolt", "energy", "launcher"], "x": {"recoil": 0.3, "recoil_h": 0.3, "spread": 0.65, "reload": 1.35},
		"desc": "一隻完全不會抖的手：後座和散佈都小很多。但關節很僵，換彈慢。"},
	# Underbarrel
	"hound_fang": {"name": "獵犬的牙", "slot": "underbarrel", "price": 0, "organ": true, "monster": "hounds",
		"weight": 1.1, "fits": "all", "x": {"spread": 1.15}, "effects": {"bayonet": true, "fang": true},
		"desc": "一整副獵犬的下顎：近戰（V）傷害三倍，咬到的東西會慢下來。很重，槍口會往下沉。"},
	"dropper_arm": {"name": "吊頂者的長臂", "slot": "underbarrel", "price": 0, "organ": true, "monster": "dropper",
		"weight": 1.3, "fits": "all", "x": {"rate": 0.85}, "effects": {"knock": -2.0},
		"desc": "打中的東西會被長臂往你這邊拖。手臂很長很晃，射速慢一點。"},
	# Ammo
	"colossus_heart": {"name": "鍋爐巨像的心", "slot": "ammo", "price": 0, "organ": true, "monster": "colossus",
		"weight": 1.5, "fits": ["gun", "bolt"], "x": {"noise": 1.8, "flash": 1.5}, "effects": {"burn": 3.0, "explode": 2.0},
		"desc": "子彈帶著鍋爐的火：命中會燒起來、小爆炸（隊友也炸得到）。每一槍都像鍋爐排氣一樣大聲。"},
	"spitter_sac": {"name": "噴吐者的酸囊", "slot": "ammo", "price": 0, "organ": true, "monster": "spitter",
		"weight": 0.8, "fits": ["gun", "bolt"], "x": {"damage": 0.8}, "+": {"pen": 25.0}, "effects": {"acid": 8.0},
		"desc": "打到的地方留下一灘酸，站在上面的怪物會被溶掉（你自己踩到也會）。直接傷害少一點。"},
	"weaver_gland": {"name": "蛛網腺", "slot": "ammo", "price": 0, "organ": true, "monster": "weaver",
		"weight": 0.5, "fits": ["gun", "bolt"], "x": {"damage": 0.5}, "effects": {"slow": 5.0, "stun": 0.6, "web": true},
		"desc": "子彈噴出黏網：打到的怪物被纏住，慢 5 秒。網很軟，傷害只剩一半。"},
	# Gadget
	"mother_musicbox": {"name": "母親的音盒", "slot": "gadget", "price": 0, "organ": true, "monster": "mother",
		"weight": 1.0, "fits": "all", "x": {"damage": 0.8}, "effects": {"lullaby": true},
		"desc": "打中的地方會響起搖籃曲：附近的怪物會停下來、慢慢的聽一陣子。但溫柔的曲子讓子彈軟了兩成。"},
	"rat_spring": {"name": "發條鼠的發條", "slot": "gadget", "price": 0, "organ": true, "monster": "rats",
		"weight": 0.3, "fits": "all", "x": {"rate": 1.6, "spread": 1.4, "recoil": 1.3}, "+": {"reliability": -6.0},
		"desc": "把發條上滿：射速快六成。但整把槍抖個不停，偶爾卡住。"},
	"tuner_cords": {"name": "調音師的聲帶", "slot": "gadget", "price": 0, "organ": true, "monster": "tuner",
		"weight": 0.2, "fits": "all", "x": {"damage": 0.85}, "effects": {"stun": 0.6},
		"desc": "打中的怪物會聽到不存在的聲音，錯亂一下（麻痺 0.6 秒）。傷害少一點。"},
	"child_marble": {"name": "孩子的玻璃珠", "slot": "gadget", "price": 0, "organ": true, "monster": "child",
		"weight": 0.1, "fits": "all", "x": {"spread": 1.3, "moa": 1.3}, "effects": {"bounty": 3.0},
		"desc": "殺死怪物時牠會掉下一件好東西（比招財貓好得多）。但珠子裡的眼睛一直看著你，讓你瞄不準。"},
}

const STARTER := {"frame": "revolver", "parts": {}, "tune": {}}
## Stats that are whole numbers after mods.
const INT_STATS := ["mag", "reserve", "pellets"]
## Stats kept inside 0..100.
const PERCENT_STATS := ["ergo", "pen", "flash", "reliability"]
## Aimed cone (degrees) per minute of angle. Game-scaled, not real MOA.
const MOA_DEGREES := 0.05
## Per shot chance of a jam for each point of reliability under 100.
const JAM_PER_POINT := 0.0004
## An empty gun takes this much longer to reload (rack the action).
const EMPTY_RELOAD := 1.25
## Above this muzzle velocity a bullet cracks: a suppressor only takes so much off.
const SOUND_BARRIER := 340.0
const CRACK := 1.6
## Rounds in a burst.
const BURST := 3


static func frame(id: String) -> Dictionary:
	return FRAMES.get(id, {})


static func part(id: String) -> Dictionary:
	return PARTS.get(id, {})


## The type of a slot (both rails are "rail").
static func slot_type(slot: String) -> String:
	return SLOT_TYPE.get(slot, slot)


static func slot_name(slot: String) -> String:
	return SLOT_NAMES.get(slot, slot)


## The display name of any frame or part id.
static func name_of(id: String) -> String:
	return FRAMES.get(id, PARTS.get(id, {})).get("name", id)


static func price_of(id: String) -> int:
	return FRAMES.get(id, PARTS.get(id, {})).get("price", 0)


static func caliber_name(cal: String) -> String:
	return CALIBERS.get(cal, {}).get("name", cal)


## Organs come out of monsters: they can't be bought, only owned.
static func is_organ(id: String) -> bool:
	return PARTS.get(id, {}).get("organ", false)


## Every organ part id, in the order they are listed.
static func organ_ids() -> Array[String]:
	var result: Array[String] = []
	for id in PARTS:
		if PARTS[id].get("organ", false):
			result.append(id)
	return result


## A frame stat, falling back to DEFAULTS.
static func frame_stat(frame_id: String, stat: String) -> Variant:
	return frame(frame_id).get(stat, DEFAULTS.get(stat))


## Can this part go on this frame at all (some slot of its type, tags, calibre of the bare
## frame or one a conversion part could give it)? Which slots are open depends on the
## rest of the build: use fits_in / parts_for with the build for that.
static func fits(frame_id: String, part_id: String) -> bool:
	var f := frame(frame_id)
	var p := part(part_id)
	if f.is_empty() or p.is_empty() or not _frame_ok(frame_id, p):
		return false
	return _tags_fit(frame_id, _frame_calibers(frame_id), p)


## Can this part go in this slot of this build, with the build as it is (other slots
## decide which slots are open and the calibre)?
static func fits_in(build: Dictionary, slot: String, part_id: String) -> bool:
	var tree := _walk(build, slot)
	return slot in tree.open and _fits_slot(build.get("frame", ""), tree.cal, slot, part_id)


## Parts that can go in one slot. `build_or_frame` is a build (open slots and calibre
## follow its parts) or a bare frame id.
static func parts_for(build_or_frame: Variant, slot: String) -> Array[String]:
	var build: Dictionary = build_or_frame if build_or_frame is Dictionary else {"frame": str(build_or_frame), "parts": {}}
	var result: Array[String] = []
	var tree := _walk(build, slot)
	if not slot in tree.open:
		return result
	for id in PARTS:
		if _fits_slot(build.get("frame", ""), tree.cal, slot, id):
			result.append(id)
	return result


## The slots this build has right now, in SLOTS order (root slots plus what parts open,
## minus what they block).
static func open_slots(build: Dictionary) -> Array[String]:
	var tree := _walk(clean(build), "")
	var result: Array[String] = []
	for slot in SLOTS:
		if slot in tree.open:
			result.append(slot)
	return result


## Every slot this frame could ever have with the right parts (root and openable).
static func possible_slots(frame_id: String) -> Array[String]:
	var f := frame(frame_id)
	var result: Array[String] = []
	if f.is_empty():
		return result
	var cals := _frame_calibers(frame_id)
	var open: Array = f.slots.duplicate()
	for slot in SLOTS:
		if not slot in open:
			continue
		for id in PARTS:
			var p: Dictionary = PARTS[id]
			if slot_type(slot) == p.slot and _tags_fit(frame_id, cals, p) and _frame_ok(frame_id, p):
				for added in p.get("adds", []):
					if not added in open:
						open.append(added)
	for slot in SLOTS:
		if slot in open:
			result.append(slot)
	return result


## The calibre this build fires.
static func caliber_of(build: Dictionary) -> String:
	return _walk(clean(build), "").cal


## Which part opened this slot ("" for a root slot of the frame).
static func opened_by(build: Dictionary, slot: String) -> String:
	build = clean(build)
	if slot in frame(build.frame).get("slots", []):
		return ""
	for s in SLOTS:
		var id: String = build.parts.get(s, "")
		if id != "" and slot in part(id).get("adds", []):
			return s
	return ""


## Drops parts that don't fit (a build loaded from an old save, a changed frame, or a
## part whose slot went away when its parent came off) and tune values for parts that
## can't be tuned, clamped to -1..1.
static func clean(build: Dictionary) -> Dictionary:
	var frame_id: String = str(build.get("frame", ""))
	if not FRAMES.has(frame_id):
		return STARTER.duplicate(true)
	var tree := _walk(build, "")
	var tune := {}
	var given_tune: Variant = build.get("tune", {})
	if given_tune is Dictionary:
		for slot in tree.parts:
			if part(tree.parts[slot]).has("tune") and given_tune.has(slot):
				tune[slot] = clampf(float(given_tune[slot]), -1.0, 1.0)
	return {"frame": frame_id, "parts": tree.parts, "tune": tune}


## Every id a build is made of (the frame first, then parts in slot order).
static func ids(build: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if FRAMES.has(build.get("frame", "")):
		result.append(build.frame)
	for slot in SLOTS:
		var part_id: String = build.get("parts", {}).get(slot, "")
		if part_id != "":
			result.append(part_id)
	return result


## The tune value of a slot in a build (0 when not set).
static func tune_of(build: Dictionary, slot: String) -> float:
	return float(build.get("tune", {}).get(slot, 0.0))


## The finished weapon: the frame's stats with every part's mods applied in slot order,
## then the derived numbers (aim time, sway, jam chance...).
static func stats(build: Dictionary) -> Dictionary:
	build = clean(build)
	var f := frame(build.frame)
	var result := DEFAULTS.duplicate(true)
	for key in f:
		result[key] = f[key]
	result = result.duplicate(true)
	result.frame = build.frame
	result.parts = build.parts.duplicate()
	result.tune = build.tune.duplicate()
	result.effects = (f.get("effects", {}) as Dictionary).duplicate()
	result.modes = (result.modes as Array).duplicate()
	result.base_noise = float(f.noise)
	var price: int = f.price
	for slot in SLOTS:
		var part_id: String = build.parts.get(slot, "")
		if part_id == "":
			continue
		var p := part(part_id)
		price += p.price
		result.weight += p.weight
		if p.has("set_cal"):
			result.cal = p.set_cal
		for stat in p.get("x", {}):
			result[stat] = result[stat] * p.x[stat]
		for stat in p.get("+", {}):
			result[stat] = result[stat] + p["+"][stat]
		for stat in p.get("=", {}):
			result[stat] = p["="][stat]
		if p.has("tune"):
			_apply_tune(result, p.tune, float(build.tune.get(slot, 0.0)))
		if p.has("set_modes"):
			result.modes = (p.set_modes as Array).duplicate()
		for mode in p.get("modes", []):
			if not mode in result.modes:
				result.modes.append(mode)
		for effect in p.get("effects", {}):
			var value = p.effects[effect]
			if result.effects.has(effect) and effect == "knock" and float(value) < 0.0:
				result.effects[effect] = value  # a pull (harpoon, dropper's arm) beats a shove
			elif result.effects.has(effect) and effect == "ghost":
				result.effects[effect] = mini(int(result.effects[effect]), int(value))
			elif result.effects.has(effect) and value is float:
				result.effects[effect] = maxf(result.effects[effect], value)
			else:
				result.effects[effect] = value
	for stat in INT_STATS:
		result[stat] = maxi(1, roundi(result[stat]))
	for stat in PERCENT_STATS:
		result[stat] = clampf(result[stat], 0.0, 100.0)
	result.weight = maxf(result.weight, 0.3)
	result.length = maxf(result.length, 15.0)
	result.price = price
	_derive(result)
	return result


## Numbers worked out from the finished stats.
##   aim_time   seconds to raise the sights; sway = degrees of drift while aiming
##   aim_spread aimed cone in degrees (from moa)
##   jam        chance per shot of a jam (heat makes it worse in play)
##   falloff    metres where damage starts falling (to FALLOFF_MIN at full range)
##   recovery   how fast the sights come back down after a kick (1.0 = normal)
##   auto       true when the default fire mode repeats (held trigger)
##   suppressed true when something quiets the shot; noise then gets the sonic crack
##   when the bullet is supersonic
static func _derive(s: Dictionary) -> void:
	var ergo: float = s.ergo
	s.aim_time = clampf(0.42 - ergo * 0.0028 + s.weight * 0.012 + maxf(s.length - 60.0, 0.0) * 0.0008, 0.1, 0.8)
	s.sway = clampf((100.0 - ergo) * 0.006 * (0.7 + s.weight * 0.06), 0.0, 1.2)
	s.aim_spread = maxf(float(s.moa) * MOA_DEGREES, 0.0)
	s.jam = maxf(100.0 - float(s.reliability), 0.0) * JAM_PER_POINT
	s.recovery = 0.6 + ergo / 100.0
	s.falloff = float(s.range) * clampf(float(s.velocity) / 1000.0 + 0.3, 0.5, 0.95)
	s.supersonic = float(s.velocity) > SOUND_BARRIER
	s.suppressed = s.effects.get("suppressed", false)
	if s.suppressed and s.supersonic and s.kind == "hitscan":
		s.noise = minf(float(s.noise) * CRACK, s.base_noise)
	s.auto = s.modes[0] == "auto"
	s.burst = BURST
	s.caliber = caliber_name(s.cal)


## Tune: t from -1 to 1. "x" goes from 1.0 at 0 to the listed value at each end, "+"
## from 0, and "=" sits halfway at 0.
static func _apply_tune(result: Dictionary, tune: Dictionary, t: float) -> void:
	t = clampf(t, -1.0, 1.0)
	for stat in tune.get("x", {}):
		var ends: Array = tune.x[stat]
		result[stat] = result[stat] * (lerpf(1.0, ends[0], -t) if t < 0.0 else lerpf(1.0, ends[1], t))
	for stat in tune.get("+", {}):
		var ends: Array = tune["+"][stat]
		result[stat] = result[stat] + (lerpf(0.0, ends[0], -t) if t < 0.0 else lerpf(0.0, ends[1], t))
	for stat in tune.get("=", {}):
		var ends: Array = tune["="][stat]
		result[stat] = lerpf(ends[0], ends[1], (t + 1.0) * 0.5)


## Walks the slot tree in SLOTS order: which slots are open, what is in them, and the
## calibre so far. When `stop_at` is a slot, the walk ends there (the calibre and open
## slots as that slot sees them) but keeps going for the "open" set's sake.
static func _walk(build: Dictionary, stop_at: String) -> Dictionary:
	var frame_id: String = str(build.get("frame", ""))
	var f := frame(frame_id)
	var open: Array = (f.get("slots", []) as Array).duplicate()
	var blocked: Array = []
	var parts := {}
	var cal: String = str(f.get("cal", DEFAULTS.cal))
	var cal_at_stop := ""
	var given: Variant = build.get("parts", {})
	if not given is Dictionary:
		given = {}
	for slot in SLOTS:
		if slot == stop_at:
			cal_at_stop = cal
		if not slot in open or slot in blocked:
			continue
		var part_id: String = str(given.get(slot, ""))
		if part_id == "" or not _fits_slot(frame_id, cal, slot, part_id):
			continue
		parts[slot] = part_id
		var p := part(part_id)
		for added in p.get("adds", []):
			if not added in open:
				open.append(added)
		for gone in p.get("blocks", []):
			blocked.append(gone)
		if p.has("set_cal"):
			cal = p.set_cal
	for gone in blocked:
		open.erase(gone)
	return {"open": open, "parts": parts, "cal": cal_at_stop if stop_at != "" else cal}


static func _fits_slot(frame_id: String, cal: String, slot: String, part_id: String) -> bool:
	var p := part(part_id)
	if p.is_empty() or p.slot != slot_type(slot) or not _frame_ok(frame_id, p):
		return false
	if p.has("cal") and not cal in p.cal:
		return false
	return _tags_fit(frame_id, [cal], p)


static func _frame_ok(frame_id: String, p: Dictionary) -> bool:
	return not p.has("frames") or frame_id in p.frames


## Fits by frame tag or by the calibre family of any of `cals`.
static func _tags_fit(frame_id: String, cals: Array, p: Dictionary) -> bool:
	if p.fits is String:
		return true
	var tags: Array = frame(frame_id).get("tags", [])
	for tag in p.fits:
		if tag in tags:
			return true
		for cal in cals:
			if CALIBERS.get(cal, {}).get("family", "") == tag:
				return true
	return false


## The frame's own calibre and every calibre a conversion part can give it.
static func _frame_calibers(frame_id: String) -> Array:
	var cals := [str(frame(frame_id).get("cal", DEFAULTS.cal))]
	for id in PARTS:
		var p: Dictionary = PARTS[id]
		if p.has("set_cal") and _frame_ok(frame_id, p) and _tags_fit(frame_id, [], p) and not p.set_cal in cals:
			cals.append(p.set_cal)
	return cals


## A short Chinese summary line of a build's numbers, for menus.
static func summary(build: Dictionary) -> String:
	var s := stats(build)
	var pellets := "×%d" % s.pellets if s.pellets > 1 else ""
	return "%s　傷害 %d%s　射速 %.1f/秒　彈匣 %d（備彈 %d）　射程 %dm　聲音 %dm　%.1fkg" % [
		s.caliber, roundi(s.damage), pellets, s.rate, s.mag, s.reserve, roundi(s.range), roundi(s.noise), s.weight]
