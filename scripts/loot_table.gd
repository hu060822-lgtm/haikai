class_name LootTable
## Item definitions (see design/HAIKAI-內容清單.md): the original 100 (ids 1-100), 20 bulky
## hauls (101-120) and 10 heavy-but-cheap fillers (121-130). New items append new ids.
## "rarity": 0 common, 1 uncommon, 2 rare, 3 legendary.
## "tags": fragile = loses value on hard landings, noisy = makes noise while carried,
## collect = worth more as a set (see SET_BONUSES), hot = hurts while carried,
## scratch = its real value is only revealed at extraction, heavy = one person carries it
## slowly (stand next to a teammate to share the load), cursed = valuable but trouble,
## alive = wriggles out of your hands, music = plays a tune (some monsters stop to listen),
## cold = icy (the fog walker keeps away), bulky = a big physical object carried in both hands
## instead of the backpack (no gun, no sprint, slow; two players carrying it share the weight;
## see LootItem and Player.held_bulky). Bulky items never come out of roll(): maps place them with
## roll_bulky(), and "theme" (factory/mall/subway/dream) makes them likelier on that map.
## Every non-bulky item takes a footprint of cells in the backpack grid (see GridBag).
## "use": what pressing X does with it (see Player.use_item). "effect": a passive effect
## while carried (see Player). "note": shown when picked up. "pool": false keeps it out of
## random rolls (it is obtained some other way).
## "shape" (box if missing): see LootShapes.

const RARITY_WEIGHT := [60, 25, 10, 3]
const RARITY_NAMES := ["普通", "少見", "稀有", "傳說"]
const RARITY_COLORS := [Color(0.85, 0.82, 0.75), Color(0.5, 0.9, 0.5), Color(0.45, 0.7, 1.0), Color(1.0, 0.8, 0.3)]

const ITEMS := [
	{"id": 1, "name": "黃銅齒輪", "rarity": 0, "weight": 3.0, "value": 35, "size": Vector3(0.3, 0.3, 0.08), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.9, 0.6), "tags": []},
	{"id": 2, "name": "煤精石", "rarity": 0, "weight": 4.0, "value": 25, "size": Vector3(0.25, 0.2, 0.25), "shape": "sphere", "texture": "concrete", "color": Color(0.35, 0.33, 0.38), "tags": []},
	{"id": 3, "name": "銅線捲", "rarity": 0, "weight": 6.0, "value": 45, "size": Vector3(0.35, 0.2, 0.35), "shape": "cylinder", "texture": "pipe", "color": Color(1.0, 0.7, 0.5), "tags": []},
	{"id": 4, "name": "生鏽的扳手", "rarity": 0, "weight": 2.5, "value": 20, "size": Vector3(0.45, 0.06, 0.12), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 5, "name": "一隻襪子", "rarity": 0, "weight": 0.1, "value": 3, "size": Vector3(0.12, 0.3, 0.05), "texture": "concrete", "color": Color(0.9, 0.85, 0.95), "tags": ["collect"]},
	{"id": 6, "name": "半個三明治", "rarity": 0, "weight": 0.2, "value": 1, "size": Vector3(0.15, 0.06, 0.1), "texture": "brass", "color": Color(1.0, 0.95, 0.8), "tags": [], "use": "eat"},
	{"id": 7, "name": "過期的保險單", "rarity": 0, "weight": 0.1, "value": 5, "size": Vector3(0.2, 0.02, 0.28), "texture": "concrete", "color": Color(1.0, 1.0, 0.9), "tags": []},
	{"id": 8, "name": "貓的照片", "rarity": 0, "weight": 0.1, "value": 15, "size": Vector3(0.15, 0.02, 0.1), "texture": "concrete", "color": Color(1.0, 0.9, 0.8), "tags": []},
	{"id": 9, "name": "工人的便當盒", "rarity": 0, "weight": 1.2, "value": 12, "size": Vector3(0.25, 0.12, 0.15), "texture": "rust_metal", "color": Color(0.7, 0.8, 0.9), "tags": []},
	{"id": 10, "name": "安全守則手冊", "rarity": 0, "weight": 0.5, "value": 8, "size": Vector3(0.2, 0.04, 0.28), "texture": "brick", "color": Color(1.0, 0.9, 0.5), "tags": []},
	{"id": 11, "name": "發條鑰匙", "rarity": 0, "weight": 0.2, "value": 25, "size": Vector3(0.15, 0.04, 0.08), "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 20, "name": "電池", "rarity": 0, "weight": 0.3, "value": 18, "size": Vector3(0.08, 0.15, 0.08), "shape": "cylinder", "texture": "pipe", "color": Color(0.6, 0.8, 0.6), "tags": []},
	{"id": 22, "name": "罐頭（沒標籤）", "rarity": 0, "weight": 0.8, "value": 12, "size": Vector3(0.1, 0.14, 0.1), "shape": "cylinder", "texture": "rust_metal", "color": Color(0.9, 0.9, 0.9), "tags": []},
	{"id": 27, "name": "「世界最棒的老闆」馬克杯", "rarity": 0, "weight": 0.4, "value": 18, "size": Vector3(0.1, 0.12, 0.1), "shape": "cylinder", "texture": "concrete", "color": Color(1.0, 1.0, 1.0), "tags": ["fragile"]},
	{"id": 28, "name": "鐵桶", "rarity": 0, "weight": 8.0, "value": 22, "size": Vector3(0.35, 0.4, 0.35), "shape": "cylinder", "texture": "rust_metal", "color": Color.WHITE, "tags": ["noisy"]},
	{"id": 30, "name": "糖果罐", "rarity": 0, "weight": 1.5, "value": 28, "size": Vector3(0.15, 0.2, 0.15), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.6, 0.8), "tags": ["noisy"]},
	{"id": 36, "name": "餐具組", "rarity": 0, "weight": 2.0, "value": 26, "size": Vector3(0.3, 0.05, 0.2), "texture": "brass", "color": Color(0.85, 0.85, 0.9), "tags": ["noisy"]},
	{"id": 37, "name": "舊報紙", "rarity": 0, "weight": 0.2, "value": 6, "size": Vector3(0.3, 0.02, 0.4), "texture": "concrete", "color": Color(0.95, 0.92, 0.8), "tags": []},
	{"id": 42, "name": "燈泡", "rarity": 0, "weight": 0.2, "value": 16, "size": Vector3(0.08, 0.12, 0.08), "shape": "sphere", "texture": "concrete", "color": Color(1.0, 1.0, 0.8), "tags": ["fragile"]},
	{"id": 44, "name": "工會徽章", "rarity": 0, "weight": 0.2, "value": 40, "size": Vector3(0.08, 0.08, 0.02), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.8, 0.4), "tags": []},
	{"id": 46, "name": "壓力計", "rarity": 1, "weight": 2.5, "value": 60, "size": Vector3(0.22, 0.22, 0.1), "shape": "cylinder", "texture": "brass", "color": Color(0.9, 0.9, 0.85), "tags": ["fragile"]},
	{"id": 47, "name": "蒸氣閥門", "rarity": 1, "weight": 10.0, "value": 80, "size": Vector3(0.4, 0.3, 0.4), "texture": "rust_metal", "color": Color.WHITE, "tags": []},
	{"id": 48, "name": "會叫的黃銅鴨", "rarity": 1, "weight": 1.5, "value": 55, "size": Vector3(0.18, 0.16, 0.22), "texture": "brass", "color": Color(1.0, 0.95, 0.4), "tags": ["noisy"]},
	{"id": 49, "name": "很大的螺絲", "rarity": 1, "weight": 18.0, "value": 150, "size": Vector3(0.35, 1.2, 0.35), "shape": "cylinder", "texture": "rust_metal", "color": Color(0.8, 0.8, 0.85), "tags": ["heavy"]},
	{"id": 50, "name": "茶壺（還是熱的）", "rarity": 1, "weight": 2.5, "value": 70, "size": Vector3(0.25, 0.22, 0.2), "shape": "sphere", "texture": "brass", "color": Color(0.8, 0.9, 1.0), "tags": ["fragile"]},
	{"id": 52, "name": "工頭的哨子", "rarity": 1, "weight": 0.2, "value": 45, "size": Vector3(0.1, 0.04, 0.04), "shape": "capsule", "texture": "brass", "color": Color.WHITE, "tags": []},
	{"id": 54, "name": "打卡機", "rarity": 1, "weight": 14.0, "value": 110, "size": Vector3(0.5, 0.6, 0.35), "texture": "rust_metal", "color": Color(0.8, 0.7, 0.6), "tags": ["noisy", "heavy"]},
	{"id": 76, "name": "懷錶", "rarity": 2, "weight": 0.3, "value": 120, "size": Vector3(0.12, 0.12, 0.04), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.95, 0.7), "tags": ["fragile"]},
	{"id": 79, "name": "「年度最安全工廠」獎盃", "rarity": 2, "weight": 6.0, "value": 160, "size": Vector3(0.25, 0.5, 0.25), "shape": "cone", "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": ["fragile"]},
	{"id": 93, "name": "發條核心", "rarity": 3, "weight": 5.0, "value": 380, "size": Vector3(0.25, 0.25, 0.25), "shape": "sphere", "texture": "brass", "color": Color(0.7, 1.0, 0.9), "tags": []},
	{"id": 12, "name": "瓶中信", "rarity": 0, "weight": 0.5, "value": 15, "size": Vector3(0.08, 0.26, 0.08), "shape": "cylinder", "texture": "concrete", "color": Color(0.6, 0.85, 0.7), "tags": ["fragile"]},
	{"id": 13, "name": "濕掉的鈔票", "rarity": 0, "weight": 0.1, "value": 40, "size": Vector3(0.16, 0.01, 0.07), "texture": "concrete", "color": Color(0.55, 0.75, 0.5), "tags": []},
	{"id": 15, "name": "生日蛋糕（一片）", "rarity": 0, "weight": 0.5, "value": 30, "size": Vector3(0.12, 0.1, 0.16), "texture": "concrete", "color": Color(1.0, 0.85, 0.9), "tags": []},
	{"id": 16, "name": "蠟筆畫（畫了五個人）", "rarity": 0, "weight": 0.1, "value": 20, "size": Vector3(0.3, 0.01, 0.22), "texture": "concrete", "color": Color(1.0, 0.95, 0.85), "tags": []},
	{"id": 18, "name": "錄音帶", "rarity": 0, "weight": 0.3, "value": 30, "size": Vector3(0.1, 0.02, 0.065), "texture": "rust_metal", "color": Color(0.3, 0.3, 0.32), "tags": []},
	{"id": 19, "name": "塑膠恐龍", "rarity": 0, "weight": 0.3, "value": 10, "size": Vector3(0.08, 0.1, 0.16), "shape": "capsule", "texture": "concrete", "color": Color(0.4, 0.85, 0.35), "tags": ["collect"]},
	{"id": 21, "name": "舊手機（沒訊號）", "rarity": 0, "weight": 0.4, "value": 35, "size": Vector3(0.06, 0.14, 0.03), "texture": "rust_metal", "color": Color(0.25, 0.25, 0.28), "tags": []},
	{"id": 23, "name": "牙刷（用過的）", "rarity": 0, "weight": 0.05, "value": 2, "size": Vector3(0.02, 0.02, 0.18), "texture": "concrete", "color": Color(0.4, 0.7, 1.0), "tags": []},
	{"id": 25, "name": "撲克牌（少一張）", "rarity": 0, "weight": 0.1, "value": 10, "size": Vector3(0.065, 0.02, 0.09), "texture": "brick", "color": Color(0.9, 0.3, 0.3), "tags": []},
	{"id": 29, "name": "拖把", "rarity": 0, "weight": 2.0, "value": 6, "size": Vector3(0.05, 1.2, 0.05), "shape": "cylinder", "texture": "concrete", "color": Color(0.75, 0.65, 0.5), "tags": []},
	{"id": 33, "name": "收據一疊（全是泡麵）", "rarity": 0, "weight": 0.1, "value": 4, "size": Vector3(0.08, 0.04, 0.15), "texture": "concrete", "color": Color(1.0, 1.0, 0.95), "tags": []},
	{"id": 34, "name": "安全帽", "rarity": 0, "weight": 1.2, "value": 30, "size": Vector3(0.28, 0.18, 0.3), "shape": "sphere", "texture": "concrete", "color": Color(1.0, 0.8, 0.1), "tags": []},
	{"id": 35, "name": "迴紋針鏈", "rarity": 0, "weight": 0.05, "value": 5, "size": Vector3(0.4, 0.01, 0.03), "texture": "pipe", "color": Color(0.85, 0.85, 0.9), "tags": []},
	{"id": 40, "name": "毛線球", "rarity": 0, "weight": 0.3, "value": 9, "size": Vector3(0.14, 0.14, 0.14), "shape": "sphere", "texture": "brick", "color": Color(0.9, 0.4, 0.5), "tags": []},
	{"id": 45, "name": "搖搖晃晃的椅子腳", "rarity": 0, "weight": 1.5, "value": 7, "size": Vector3(0.05, 0.45, 0.05), "shape": "cylinder", "texture": "brick", "color": Color(0.6, 0.45, 0.3), "tags": []},
	{"id": 51, "name": "單片眼鏡", "rarity": 1, "weight": 0.1, "value": 65, "size": Vector3(0.05, 0.05, 0.01), "shape": "cylinder", "texture": "brass", "color": Color(1.0, 0.9, 0.6), "tags": ["fragile"]},
	{"id": 53, "name": "滾燙的煤塊", "rarity": 1, "weight": 3.0, "value": 90, "size": Vector3(0.2, 0.16, 0.2), "texture": "concrete", "color": Color(1.0, 0.45, 0.2), "tags": ["hot"]},
	{"id": 55, "name": "布穀鳥鐘", "rarity": 1, "weight": 4.0, "value": 75, "size": Vector3(0.28, 0.4, 0.15), "texture": "brick", "color": Color(0.7, 0.5, 0.35), "tags": ["noisy"]},
	{"id": 57, "name": "永遠慢五分鐘的鐘", "rarity": 1, "weight": 4.5, "value": 85, "size": Vector3(0.35, 0.35, 0.08), "shape": "cylinder", "texture": "brass", "color": Color(0.95, 0.9, 0.8), "tags": []},
	{"id": 58, "name": "迷你船錨", "rarity": 1, "weight": 15.0, "value": 80, "size": Vector3(0.35, 0.5, 0.1), "texture": "rust_metal", "color": Color(0.6, 0.6, 0.65), "tags": ["heavy"]},
	{"id": 60, "name": "生鏽的船鐘", "rarity": 1, "weight": 10.0, "value": 95, "size": Vector3(0.3, 0.32, 0.3), "shape": "cone", "texture": "brass", "color": Color(0.8, 0.6, 0.4), "tags": ["noisy"]},
	{"id": 65, "name": "假人的手（手指會動）", "rarity": 1, "weight": 2.0, "value": 65, "size": Vector3(0.1, 0.05, 0.22), "texture": "concrete", "color": Color(0.92, 0.88, 0.82), "tags": []},
	{"id": 69, "name": "雪景球（小人在動）", "rarity": 1, "weight": 0.7, "value": 70, "size": Vector3(0.14, 0.16, 0.14), "shape": "sphere", "texture": "concrete", "color": Color(0.75, 0.9, 1.0), "tags": ["fragile"]},
	{"id": 72, "name": "黃金招財貓", "rarity": 1, "weight": 3.5, "value": 110, "size": Vector3(0.18, 0.26, 0.15), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": []},
	{"id": 74, "name": "一箱過期泡麵", "rarity": 1, "weight": 6.0, "value": 60, "size": Vector3(0.45, 0.3, 0.3), "texture": "brick", "color": Color(0.95, 0.75, 0.45), "tags": []},
	{"id": 78, "name": "金牙（不要問）", "rarity": 2, "weight": 0.05, "value": 140, "size": Vector3(0.03, 0.04, 0.03), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": []},
	{"id": 84, "name": "下水道鱷魚的牙", "rarity": 2, "weight": 0.3, "value": 150, "size": Vector3(0.05, 0.14, 0.05), "shape": "cone", "texture": "concrete", "color": Color(0.95, 0.92, 0.8), "tags": []},
	{"id": 90, "name": "鑽石戒指", "rarity": 2, "weight": 0.05, "value": 280, "size": Vector3(0.04, 0.04, 0.02), "shape": "cylinder", "texture": "brass", "color": Color(0.9, 0.95, 1.0), "tags": []},
	{"id": 91, "name": "一千塊的刮刮樂（沒刮）", "rarity": 2, "weight": 0.05, "value": 1, "size": Vector3(0.1, 0.01, 0.15), "texture": "brick", "color": Color(1.0, 0.9, 0.4), "tags": ["scratch"]},
	{"id": 98, "name": "黃金馬桶", "rarity": 3, "weight": 45.0, "value": 900, "size": Vector3(0.5, 0.75, 0.7), "texture": "brass", "color": Color(1.0, 0.85, 0.3), "tags": ["bulky"], "theme": "mall"},
	{"id": 14, "name": "會動的魚", "rarity": 0, "weight": 1.0, "value": 20, "size": Vector3(0.1, 0.08, 0.3), "texture": "concrete", "color": Color(0.55, 0.7, 0.8), "tags": ["alive"]},
	{"id": 17, "name": "永遠溫熱的牛奶", "rarity": 0, "weight": 1.0, "value": 25, "size": Vector3(0.1, 0.22, 0.1), "shape": "cylinder", "texture": "concrete", "color": Color(1.0, 0.98, 0.92), "tags": [], "use": "milk"},
	{"id": 24, "name": "假花", "rarity": 0, "weight": 0.2, "value": 8, "size": Vector3(0.12, 0.3, 0.12), "shape": "cone", "texture": "carpet", "color": Color(1.0, 0.55, 0.7), "tags": []},
	{"id": 26, "name": "雨傘", "rarity": 0, "weight": 1.0, "value": 15, "size": Vector3(0.06, 0.9, 0.06), "shape": "cylinder", "texture": "carpet", "color": Color(0.25, 0.3, 0.55), "tags": [], "effect": "umbrella"},
	{"id": 31, "name": "遙控器", "rarity": 0, "weight": 0.2, "value": 20, "size": Vector3(0.05, 0.025, 0.17), "texture": "rust_metal", "color": Color(0.2, 0.2, 0.22), "tags": [], "use": "remote"},
	{"id": 32, "name": "玩具槍（很像真的）", "rarity": 0, "weight": 0.5, "value": 15, "size": Vector3(0.04, 0.12, 0.22), "texture": "concrete", "color": Color(0.25, 0.25, 0.25), "tags": []},
	{"id": 38, "name": "蠟燭", "rarity": 0, "weight": 0.3, "value": 10, "size": Vector3(0.05, 0.16, 0.05), "shape": "cylinder", "texture": "concrete", "color": Color(1.0, 0.95, 0.8), "tags": [], "use": "candle"},
	{"id": 39, "name": "洗衣粉", "rarity": 0, "weight": 3.0, "value": 14, "size": Vector3(0.2, 0.28, 0.12), "texture": "concrete", "color": Color(0.6, 0.8, 1.0), "tags": [], "use": "powder"},
	{"id": 41, "name": "雞毛撢子", "rarity": 0, "weight": 0.3, "value": 12, "size": Vector3(0.06, 0.6, 0.06), "shape": "cone", "texture": "carpet", "color": Color(0.7, 0.45, 0.35), "tags": []},
	{"id": 43, "name": "備用鑰匙", "rarity": 0, "weight": 0.1, "value": 20, "size": Vector3(0.03, 0.01, 0.07), "texture": "brass", "color": Color.WHITE, "tags": [], "use": "key"},
	{"id": 56, "name": "音叉", "rarity": 1, "weight": 0.3, "value": 50, "size": Vector3(0.04, 0.22, 0.02), "texture": "brass", "color": Color(0.95, 0.9, 0.7), "tags": [], "use": "fork"},
	{"id": 59, "name": "海盜義眼", "rarity": 1, "weight": 0.05, "value": 70, "size": Vector3(0.05, 0.05, 0.05), "shape": "sphere", "texture": "concrete", "color": Color(0.95, 0.95, 0.9), "tags": []},
	{"id": 61, "name": "寫著你名字的名牌", "rarity": 1, "weight": 0.1, "value": 100, "size": Vector3(0.09, 0.03, 0.01), "texture": "brass", "color": Color(0.9, 0.9, 0.85), "tags": ["cursed"], "effect": "name_tag", "note": "名牌上寫的是你的名字。字跡還沒乾。"},
	{"id": 62, "name": "錄影帶", "rarity": 1, "weight": 0.5, "value": 90, "size": Vector3(0.19, 0.025, 0.1), "texture": "rust_metal", "color": Color(0.18, 0.18, 0.2), "tags": [], "note": "標籤寫著「最後一次全家出遊」。"},
	{"id": 63, "name": "泰迪熊", "rarity": 1, "weight": 1.0, "value": 60, "size": Vector3(0.24, 0.3, 0.2), "shape": "sphere", "texture": "carpet", "color": Color(0.7, 0.5, 0.3), "tags": [], "effect": "comfort", "note": "抱著它，心裡比較踏實。"},
	{"id": 64, "name": "遊樂園門票", "rarity": 1, "weight": 0.05, "value": 75, "size": Vector3(0.12, 0.005, 0.05), "texture": "concrete", "color": Color(1.0, 0.7, 0.8), "tags": [], "note": "日期是很久以前的某一天。你好像去過。"},
	{"id": 66, "name": "霓虹招牌字母", "rarity": 1, "weight": 5.0, "value": 85, "size": Vector3(0.4, 0.5, 0.08), "texture": "concrete", "color": Color(1.0, 0.4, 0.75), "tags": ["fragile", "collect"]},
	{"id": 67, "name": "卡帶隨身聽", "rarity": 1, "weight": 0.6, "value": 80, "size": Vector3(0.12, 0.035, 0.09), "texture": "rust_metal", "color": Color(1.0, 0.85, 0.3), "tags": [], "use": "walkman"},
	{"id": 68, "name": "拍立得相機", "rarity": 1, "weight": 1.0, "value": 95, "size": Vector3(0.15, 0.12, 0.12), "texture": "concrete", "color": Color(0.95, 0.95, 0.92), "tags": [], "use": "camera"},
	{"id": 70, "name": "實驗室白袍", "rarity": 1, "weight": 1.0, "value": 55, "size": Vector3(0.4, 0.05, 0.6), "texture": "carpet", "color": Color(0.95, 0.95, 0.95), "tags": [], "note": "名牌被撕掉了。口袋裡有一張寫著「別回來」的紙條。"},
	{"id": 71, "name": "溫度計", "rarity": 1, "weight": 0.2, "value": 50, "size": Vector3(0.02, 0.18, 0.02), "shape": "cylinder", "texture": "concrete", "color": Color(0.9, 0.95, 1.0), "tags": ["fragile"], "effect": "thermometer"},
	{"id": 73, "name": "電吉他", "rarity": 1, "weight": 5.0, "value": 120, "size": Vector3(0.35, 0.08, 1.0), "texture": "wood", "color": Color(0.85, 0.2, 0.15), "tags": ["noisy"]},
	{"id": 75, "name": "瑜珈球", "rarity": 1, "weight": 2.0, "value": 45, "size": Vector3(0.6, 0.6, 0.6), "shape": "sphere", "texture": "concrete", "color": Color(0.6, 0.4, 0.85), "tags": ["alive"]},
	{"id": 77, "name": "「別按」按鈕", "rarity": 2, "weight": 1.5, "value": 99, "size": Vector3(0.2, 0.12, 0.2), "shape": "cylinder", "texture": "concrete", "color": Color(0.95, 0.15, 0.1), "tags": [], "use": "button"},
	{"id": 80, "name": "黃銅義肢手臂", "rarity": 2, "weight": 6.0, "value": 175, "size": Vector3(0.12, 0.12, 0.7), "texture": "brass", "color": Color(1.0, 0.85, 0.55), "tags": [], "note": "它剛剛…比了中指？"},
	{"id": 81, "name": "沙漏", "rarity": 2, "weight": 1.5, "value": 130, "size": Vector3(0.12, 0.25, 0.12), "shape": "cylinder", "texture": "wood", "color": Color(0.95, 0.85, 0.6), "tags": ["fragile"], "use": "hourglass"},
	{"id": 82, "name": "星象儀", "rarity": 2, "weight": 12.0, "value": 260, "size": Vector3(0.5, 0.5, 0.5), "shape": "sphere", "texture": "brass", "color": Color(0.7, 0.75, 1.0), "tags": ["fragile", "heavy"]},
	{"id": 83, "name": "黃銅潛水頭盔", "rarity": 2, "weight": 12.0, "value": 210, "size": Vector3(0.45, 0.5, 0.45), "shape": "sphere", "texture": "brass", "color": Color(1.0, 0.8, 0.5), "tags": [], "effect": "diving", "note": "戴著它，霧裡的東西好像看不見你。"},
	{"id": 85, "name": "走私的香料箱", "rarity": 2, "weight": 12.0, "value": 140, "size": Vector3(0.5, 0.35, 0.35), "texture": "wood", "color": Color(0.85, 0.6, 0.4), "tags": ["heavy"]},
	{"id": 86, "name": "會唱歌的音樂盒", "rarity": 2, "weight": 2.0, "value": 170, "size": Vector3(0.2, 0.14, 0.14), "texture": "wood", "color": Color(1.0, 0.75, 0.8), "tags": ["noisy", "music"]},
	{"id": 87, "name": "媽媽做的便當", "rarity": 2, "weight": 1.0, "value": 199, "size": Vector3(0.22, 0.08, 0.15), "texture": "carpet", "color": Color(0.9, 0.3, 0.35), "tags": [], "note": "還是溫的。怎麼會在這裡？"},
	{"id": 88, "name": "冷凍的不明生物", "rarity": 2, "weight": 10.0, "value": 230, "size": Vector3(0.5, 0.3, 0.3), "texture": "concrete", "color": Color(0.7, 0.9, 1.0), "tags": ["heavy", "cold"], "effect": "thaw"},
	{"id": 89, "name": "古董電視（還開著）", "rarity": 2, "weight": 18.0, "value": 240, "size": Vector3(0.5, 0.45, 0.45), "texture": "wood", "color": Color(0.6, 0.45, 0.35), "tags": ["heavy", "fragile"], "note": "螢幕上是你的背影。"},
	{"id": 92, "name": "機器人管家頭", "rarity": 2, "weight": 9.0, "value": 190, "size": Vector3(0.35, 0.35, 0.35), "shape": "sphere", "texture": "pipe", "color": Color(0.85, 0.85, 0.9), "tags": ["noisy"], "note": "「歡迎回家，主人。歡迎回家，主人。歡迎回家——」"},
	{"id": 94, "name": "巨像的螺栓", "rarity": 3, "weight": 8.0, "value": 400, "size": Vector3(0.14, 0.4, 0.14), "shape": "cylinder", "texture": "rust_metal", "color": Color(1.0, 0.75, 0.6), "tags": [], "pool": false},
	{"id": 95, "name": "調音師的頭", "rarity": 3, "weight": 5.0, "value": 450, "size": Vector3(0.16, 0.5, 0.06), "texture": "brass", "color": Color(1.0, 0.9, 0.55), "tags": ["cursed"], "effect": "radio"},
	{"id": 96, "name": "母親的搖籃", "rarity": 3, "weight": 20.0, "value": 600, "size": Vector3(0.8, 0.5, 0.5), "texture": "wood", "color": Color(0.95, 0.85, 0.75), "tags": ["heavy", "cursed"], "effect": "cradle", "note": "搖籃還在輕輕搖。遠處好像有人在找它。"},
	{"id": 97, "name": "假人的心臟", "rarity": 3, "weight": 2.0, "value": 420, "size": Vector3(0.16, 0.18, 0.14), "shape": "sphere", "texture": "concrete", "color": Color(0.85, 0.15, 0.2), "tags": ["alive"]},
	{"id": 99, "name": "不會融化的冰塊", "rarity": 3, "weight": 2.0, "value": 480, "size": Vector3(0.16, 0.16, 0.16), "texture": "concrete", "color": Color(0.8, 0.95, 1.0), "tags": ["cold"], "effect": "chill", "note": "冷到骨子裡，跑完很難喘過氣。"},
	{"id": 100, "name": "最後一張全家福", "rarity": 3, "weight": 0.2, "value": 500, "size": Vector3(0.15, 0.005, 0.1), "texture": "concrete", "color": Color(0.95, 0.9, 0.75), "tags": [], "note": "照片裡是一家人，站在這棟建築前面。背面寫著：「我們從來沒有離開過。」"},
	# --- Bulky hauls (tag "bulky"): carried in both hands, not in the backpack. ---
	{"id": 101, "name": "鑄鐵保險箱", "rarity": 3, "weight": 85.0, "value": 950, "size": Vector3(0.7, 0.85, 0.65), "shape": "safe", "texture": "rust_metal", "color": Color(0.5, 0.58, 0.5), "tags": ["bulky"], "theme": "factory", "note": "裡面有東西在滾。撬不開，只能整個搬走。"},
	{"id": 102, "name": "柴油發電機", "rarity": 2, "weight": 70.0, "value": 650, "size": Vector3(1.0, 0.65, 0.6), "shape": "generator", "texture": "rust_metal", "color": Color(1.0, 0.75, 0.3), "tags": ["bulky"], "theme": "factory"},
	{"id": 103, "name": "工業馬達", "rarity": 2, "weight": 55.0, "value": 480, "size": Vector3(0.85, 0.5, 0.5), "shape": "motor", "texture": "pipe", "color": Color(0.45, 0.6, 0.8), "tags": ["bulky"], "theme": "factory"},
	{"id": 104, "name": "蒸汽汽笛", "rarity": 1, "weight": 30.0, "value": 380, "size": Vector3(0.4, 1.0, 0.4), "shape": "whistle", "texture": "brass", "color": Color(1.0, 0.85, 0.5), "tags": ["bulky"], "theme": "factory"},
	{"id": 105, "name": "鐵砧", "rarity": 1, "weight": 60.0, "value": 340, "size": Vector3(0.75, 0.45, 0.3), "shape": "anvil", "texture": "rust_metal", "color": Color(0.55, 0.55, 0.6), "tags": ["bulky"], "theme": "factory"},
	{"id": 106, "name": "人形模特兒", "rarity": 1, "weight": 20.0, "value": 220, "size": Vector3(0.5, 1.75, 0.3), "shape": "mannequin", "texture": "concrete", "color": Color(0.95, 0.9, 0.85), "tags": ["bulky"], "theme": "mall", "note": "它的頭轉向你的方向。剛剛是這個方向嗎？"},
	{"id": 107, "name": "自動販賣機門板", "rarity": 2, "weight": 45.0, "value": 420, "size": Vector3(0.9, 1.8, 0.12), "shape": "vending_door", "texture": "rust_metal", "color": Color(0.9, 0.25, 0.22), "tags": ["bulky", "fragile"], "theme": "mall"},
	{"id": 108, "name": "古董鋼琴椅", "rarity": 1, "weight": 22.0, "value": 320, "size": Vector3(0.9, 0.5, 0.4), "shape": "bench", "texture": "wood", "color": Color(0.45, 0.28, 0.2), "tags": ["bulky"], "theme": "mall"},
	{"id": 109, "name": "巨型布偶熊", "rarity": 1, "weight": 20.0, "value": 260, "size": Vector3(0.9, 1.3, 0.7), "shape": "bear", "texture": "concrete", "color": Color(1.0, 0.7, 0.82), "tags": ["bulky"], "theme": "mall", "note": "抱起來很軟。肚子裡有東西在跳，像心跳。"},
	{"id": 110, "name": "整箱啤酒", "rarity": 1, "weight": 24.0, "value": 210, "size": Vector3(0.6, 0.35, 0.4), "shape": "beer_crate", "texture": "brick", "color": Color(1.0, 0.7, 0.25), "tags": ["bulky", "noisy", "fragile"], "theme": "mall"},
	{"id": 111, "name": "收銀機", "rarity": 2, "weight": 30.0, "value": 560, "size": Vector3(0.5, 0.4, 0.5), "shape": "register", "texture": "brass", "color": Color(0.85, 0.85, 0.8), "tags": ["bulky", "noisy"], "theme": "mall"},
	{"id": 112, "name": "地鐵站牌", "rarity": 1, "weight": 35.0, "value": 360, "size": Vector3(0.9, 2.2, 0.12), "shape": "station_sign", "texture": "pipe", "color": Color(0.35, 0.55, 0.95), "tags": ["bulky"], "theme": "subway", "note": "站名被刮掉了。下面一行小字：「終點站」。"},
	{"id": 113, "name": "電話亭話筒座", "rarity": 2, "weight": 40.0, "value": 430, "size": Vector3(0.45, 0.75, 0.3), "shape": "payphone", "texture": "rust_metal", "color": Color(0.3, 0.55, 0.42), "tags": ["bulky"], "theme": "subway"},
	{"id": 114, "name": "驗票閘門", "rarity": 2, "weight": 65.0, "value": 620, "size": Vector3(0.9, 1.0, 0.8), "shape": "turnstile", "texture": "rust_metal", "color": Color(0.7, 0.74, 0.8), "tags": ["bulky"], "theme": "subway"},
	{"id": 115, "name": "舊電視牆", "rarity": 3, "weight": 95.0, "value": 1050, "size": Vector3(1.1, 1.1, 0.55), "shape": "tv_wall", "texture": "wood", "color": Color(0.5, 0.4, 0.35), "tags": ["bulky", "fragile"], "theme": "subway", "note": "九個螢幕，每一個都在播你剛剛走過的地方。"},
	{"id": 116, "name": "鑄鐵消防栓", "rarity": 1, "weight": 45.0, "value": 330, "size": Vector3(0.45, 0.8, 0.45), "shape": "hydrant", "texture": "rust_metal", "color": Color(0.95, 0.25, 0.18), "tags": ["bulky"], "theme": "subway"},
	{"id": 117, "name": "青銅雕像", "rarity": 3, "weight": 110.0, "value": 1400, "size": Vector3(0.6, 1.7, 0.6), "shape": "statue", "texture": "brass", "color": Color(0.55, 0.78, 0.62), "tags": ["bulky"], "theme": "dream", "note": "雕像的臉是你。比現在的你老一點。"},
	{"id": 118, "name": "旋轉木馬的馬", "rarity": 2, "weight": 40.0, "value": 720, "size": Vector3(0.35, 1.8, 1.2), "shape": "carousel_horse", "texture": "brass", "color": Color(1.0, 0.92, 0.95), "tags": ["bulky"], "theme": "dream"},
	{"id": 119, "name": "祖父的落地鐘", "rarity": 3, "weight": 60.0, "value": 860, "size": Vector3(0.55, 2.0, 0.4), "shape": "grandfather_clock", "texture": "wood", "color": Color(0.55, 0.35, 0.25), "tags": ["bulky", "noisy"], "theme": "dream"},
	{"id": 120, "name": "腳爪浴缸", "rarity": 3, "weight": 120.0, "value": 1500, "size": Vector3(1.6, 0.7, 0.8), "shape": "bathtub", "texture": "concrete", "color": Color(0.95, 0.95, 1.0), "tags": ["bulky"], "theme": "dream", "note": "裡面沒有水，但一直有水聲。"},
	# --- Heavy but cheap: dead weight for the backpack. Greed against your legs. ---
	{"id": 121, "name": "磚頭", "rarity": 0, "weight": 4.0, "value": 5, "size": Vector3(0.22, 0.07, 0.11), "shape": "brick", "texture": "brick", "color": Color(0.85, 0.5, 0.4), "tags": []},
	{"id": 122, "name": "鉛塊", "rarity": 0, "weight": 12.0, "value": 35, "size": Vector3(0.2, 0.1, 0.12), "shape": "ingot", "texture": "pipe", "color": Color(0.55, 0.55, 0.6), "tags": []},
	{"id": 123, "name": "一袋螺帽", "rarity": 0, "weight": 6.0, "value": 15, "size": Vector3(0.25, 0.3, 0.25), "shape": "sack", "texture": "concrete", "color": Color(0.75, 0.65, 0.5), "tags": ["noisy"]},
	{"id": 124, "name": "舊汽車電池", "rarity": 0, "weight": 14.0, "value": 30, "size": Vector3(0.3, 0.22, 0.18), "shape": "car_battery", "texture": "rust_metal", "color": Color(0.25, 0.25, 0.28), "tags": []},
	{"id": 125, "name": "鐵啞鈴", "rarity": 0, "weight": 10.0, "value": 20, "size": Vector3(0.4, 0.14, 0.14), "shape": "dumbbell", "texture": "rust_metal", "color": Color(0.5, 0.5, 0.55), "tags": []},
	{"id": 126, "name": "一捆電線", "rarity": 0, "weight": 7.0, "value": 18, "size": Vector3(0.4, 0.15, 0.4), "shape": "spool", "texture": "pipe", "color": Color(0.3, 0.3, 0.32), "tags": []},
	{"id": 127, "name": "水泥塊", "rarity": 0, "weight": 15.0, "value": 8, "size": Vector3(0.35, 0.25, 0.3), "shape": "rubble", "texture": "concrete", "color": Color(0.75, 0.75, 0.72), "tags": []},
	{"id": 128, "name": "鑄鐵平底鍋", "rarity": 0, "weight": 5.0, "value": 12, "size": Vector3(0.28, 0.06, 0.5), "shape": "pan", "texture": "rust_metal", "color": Color(0.35, 0.35, 0.38), "tags": []},
	{"id": 129, "name": "一疊舊電話簿", "rarity": 0, "weight": 8.0, "value": 6, "size": Vector3(0.24, 0.25, 0.3), "shape": "book_stack", "texture": "concrete", "color": Color(1.0, 0.92, 0.55), "tags": []},
	{"id": 130, "name": "生鏽的鐵鍊", "rarity": 0, "weight": 9.0, "value": 14, "size": Vector3(0.35, 0.12, 0.35), "shape": "chain", "texture": "rust_metal", "color": Color(0.75, 0.55, 0.4), "tags": ["noisy"]},
]

## Bonus paid at extraction for complete sets: item id -> [set size, bonus per set].
const SET_BONUSES := {5: [2, 200], 19: [3, 150]}
## The neon sign letters (item 66) pay out per complete "OPEN".
const NEON_ID := 66
const NEON_LETTERS := ["O", "P", "E", "N"]
const NEON_BONUS := 600
## How many kinds of item each run's pool holds, per rarity (about 30 of the 100).
const POOL_SIZE := [17, 9, 6, 2]
## Each map places this many bulky hauls (GameMap.roll_loot).
const BULKY_COUNT := Vector2i(2, 5)
## How much likelier a bulky item is on its own map.
const THEME_WEIGHT := 3.0

const TAG_NAMES := {"fragile": "易碎", "noisy": "吵鬧", "hot": "燙手", "collect": "收集", "scratch": "特殊",
	"heavy": "重物", "cursed": "詛咒", "alive": "活的", "music": "音樂", "cold": "冰冷", "bulky": "大件"}
## What R does, shown on the pick-up prompt and the HUD.
const USE_NAMES := {"milk": "喝掉", "eat": "吃掉", "remote": "按下去", "candle": "點燃/熄滅", "powder": "灑出去",
	"key": "開鎖", "fork": "敲響", "walkman": "播放", "camera": "拍照", "button": "按下去", "hourglass": "翻轉"}


## This run's item pool: ids of the kinds that can show up at all (some won't this run).
static func make_pool(rng: RandomNumberGenerator, luck := 0.0) -> Array[int]:
	var by_rarity := [[], [], [], []]
	for item in ITEMS:
		if item.get("pool", true) and not has_tag(item, "bulky"):
			by_rarity[item.rarity].append(item.id)
	var pool: Array[int] = []
	for rarity in 4:
		var ids: Array = by_rarity[rarity]
		for i in range(ids.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = ids[i]
			ids[i] = ids[j]
			ids[j] = tmp
		var count := mini(POOL_SIZE[rarity] + (int(luck * 2.0) if rarity >= 2 else 0), ids.size())
		for i in count:
			pool.append(ids[i])
	return pool


## Rolls one item. luck shifts weight toward rarer items (0 = normal). With a pool,
## only those kinds can come up.
static func roll(rng: RandomNumberGenerator, luck := 0.0, pool: Array = []) -> Dictionary:
	var weights := []
	var total := 0.0
	for item in ITEMS:
		var allowed: bool = (item.id in pool if not pool.is_empty() else item.get("pool", true)) and not has_tag(item, "bulky")
		var w: float = RARITY_WEIGHT[item.rarity] * (1.0 + luck * item.rarity) if allowed else 0.0
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in ITEMS.size():
		pick -= weights[i]
		if pick <= 0.0 and weights[i] > 0.0:
			return _instance(ITEMS[i], rng)
	return _instance(ITEMS[0], rng)


## Rolls one bulky haul for a map. theme favours that map's own (any map can still get
## any of them); luck 0 favours the cheaper ones, 1 and up the most valuable.
static func roll_bulky(rng: RandomNumberGenerator, luck := 0.0, theme := "") -> Dictionary:
	var picks: Array[Dictionary] = []
	var weights: Array[float] = []
	var total := 0.0
	for item: Dictionary in ITEMS:
		if not has_tag(item, "bulky") or not item.get("pool", true):
			continue
		var worth := float(item.value) / 500.0
		var w := lerpf(1.0 / worth, worth, clampf(luck, 0.0, 1.0)) * (THEME_WEIGHT if item.get("theme", "") == theme else 1.0)
		picks.append(item)
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in picks.size():
		pick -= weights[i]
		if pick <= 0.0:
			return _instance(picks[i], rng)
	return _instance(picks[-1], rng)


static func is_bulky(data: Dictionary) -> bool:
	return has_tag(data, "bulky")


## A specific item by id, ready to spawn.
static func make(id: int, rng: RandomNumberGenerator = null) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return _instance(item, rng)
	return {}


static func find(id: int) -> Dictionary:
	for item in ITEMS:
		if item.id == id:
			return item
	return {}


static func _instance(item: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = item.duplicate(true)
	if data.id == NEON_ID:
		var letter: String = NEON_LETTERS[rng.randi_range(0, 3) if rng != null else randi_range(0, 3)]
		data.letter = letter
		data.name += "「%s」" % letter
	return data


static func has_tag(data: Dictionary, tag: String) -> bool:
	return tag in data.get("tags", [])


## What the interaction prompt says about an item (real or a mimic pretending).
static func prompt(data: Dictionary) -> String:
	if has_tag(data, "bulky"):
		return "[按住 E] 搬起 %s　$%d　%.0fkg　大件（雙手搬，找隊友一起抬）" % [data.get("name", "?"), data.get("value", 0), data.get("weight", 0.0)]
	var tags := "　%d 格" % GridBag.footprint(data).size()
	for tag in data.get("tags", []):
		if TAG_NAMES.has(tag):
			tags += "　" + TAG_NAMES[tag]
	if USE_NAMES.has(data.get("use", "")):
		tags += "　X " + USE_NAMES[data.use]
	if data.has("organ"):
		# Organs aren't sold: carried out, they become a gun part in the stash.
		return "[E] 撿起 %s　器官（%s）　%.1fkg%s" % [data.get("name", "?"),
			Arsenal.SLOT_NAMES.get(Arsenal.part(str(data.organ)).get("slot", ""), "零件"), data.get("weight", 0.0), tags]
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
	var letters := {}
	for item in resolved:
		if item.id == NEON_ID:
			letters[item.get("letter", "O")] = letters.get(item.get("letter", "O"), 0) + 1
	var opens := 999
	for letter in NEON_LETTERS:
		opens = mini(opens, letters.get(letter, 0))
	bonus += opens * NEON_BONUS
	return {"items": total, "bonus": bonus, "total": total + bonus, "items_list": resolved}
