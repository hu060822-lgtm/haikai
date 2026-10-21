class_name MonsterRoster
## Which monsters show up in a run. Every monster is its own creature and can appear on
## any map; each run draws 4 to 6 kinds, at most two of them large.
## health is hit points (large monsters are never killed, only "broken" for a while);
## weak multiplies damage per hit effect ("bullet" = a plain hit), see Run.host_damage_monster.
## "organ" is the Arsenal part the monster drops (see Organs); the crawlers have none.
## Entries with "spawned_only" are never drawn: another monster makes them (splitter crawlers).
## senses: how strongly it reacts to each of the three things that give you away, 0-3:
## sound (footsteps, shots, talking), light (a lit lantern or gun light) and motion
## (moving where it can see you). All three sharpen as the ruin wakes (Awakening).

const MONSTERS := {
	"colossus": {"name": "鍋爐巨像", "senses": {"sound": 3, "light": 3, "motion": 1},
		"organ": "colossus_heart", "size": "large", "count": [1, 1], "health": 900,
		"weak": {"explode": 1.4, "burn": 0.4, "stun": 0.5}},
	"mannequin": {"name": "假人", "senses": {"sound": 0, "light": 1, "motion": 2},
		"organ": "mannequin_arm", "size": "medium", "count": [1, 1], "health": 200,
		"weak": {"explode": 2.0, "knock": 1.5, "burn": 0.5}},
	"mimic": {"name": "擬態蟲", "senses": {"sound": 0, "light": 0, "motion": 1},
		"organ": "mimic_shell", "size": "small", "count": [2, 3], "health": 25,
		"weak": {"bullet": 1.5, "bayonet": 2.0}},
	"watcher": {"name": "長頸觀察者", "senses": {"sound": 2, "light": 0, "motion": 3},
		"organ": "watcher_eye", "size": "large", "count": [1, 1], "health": 700,
		"weak": {"stun": 0.5, "slow": 1.3}},
	"greeter": {"name": "迎賓員", "senses": {"sound": 0, "light": 0, "motion": 3},
		"organ": "greeter_smile", "size": "medium", "count": [1, 1], "health": 220,
		"weak": {"burn": 1.5}},
	"collector": {"name": "回收員", "senses": {"sound": 0, "light": 2, "motion": 1},
		"organ": "collector_sack", "size": "medium", "count": [1, 1], "health": 180,
		"weak": {"stun": 1.5, "pierce": 1.3}},
	"rats": {"name": "發條鼠群", "senses": {"sound": 1, "light": 0, "motion": 2},
		"organ": "rat_spring", "size": "small", "count": [1, 2], "health": 70,
		"weak": {"explode": 2.5, "chain": 2.0, "bullet": 0.7}},
	"centipede": {"name": "蜈蚣列車", "senses": {"sound": 0, "light": 0, "motion": 0},
		"organ": "centipede_segment", "size": "large", "count": [1, 1], "health": 1000,
		"weak": {"explode": 1.5, "slow": 0.5}},
	"mother": {"name": "哄睡的母親", "senses": {"sound": 1, "light": 2, "motion": 2},
		"organ": "mother_musicbox", "size": "large", "count": [1, 1], "health": 800,
		"weak": {"stun": 0.6, "burn": 0.6}},
	"fog_walker": {"name": "霧行者", "senses": {"sound": 0, "light": 0, "motion": 2},
		"organ": "fog_lung", "size": "medium", "count": [1, 1], "health": 120,
		"weak": {"reveal": 1.5, "burn": 1.5}},
	"tuner": {"name": "調音師", "senses": {"sound": 3, "light": 0, "motion": 1},
		"organ": "tuner_cords", "size": "medium", "count": [1, 1], "health": 160,
		"weak": {"chain": 1.6, "stun": 1.5}},
	"child": {"name": "捉迷藏的孩子", "senses": {"sound": 0, "light": 2, "motion": 1},
		"organ": "child_marble", "size": "small", "count": [1, 1], "health": 40, "weak": {}},
	# Monster worker A's new five (plus the splitter's crawlers).
	"spitter": {"name": "噴吐者", "senses": {"sound": 0, "light": 2, "motion": 1},
		"organ": "spitter_sac", "size": "medium", "count": [1, 2], "health": 140,
		"weak": {"burn": 1.5}, "script": "res://scripts/monsters/spitter.gd", "spawn": "patrol"},
	"burrower": {"name": "鐵甲穿山者", "senses": {"sound": 3, "light": 0, "motion": 0},
		"organ": "burrower_drill", "size": "large", "count": [1, 1], "health": 750,
		"weak": {"explode": 1.5, "stun": 0.6}, "script": "res://scripts/monsters/burrower.gd", "spawn": "far"},
	"splitter": {"name": "分裂者", "senses": {"sound": 2, "light": 2, "motion": 1},
		"organ": "splitter_core", "size": "medium", "count": [1, 1], "health": 180,
		"weak": {"burn": 2.0}, "script": "res://scripts/monsters/splitter.gd", "spawn": "patrol"},
	"crawler": {"name": "分裂幼體", "senses": {"sound": 0, "light": 0, "motion": 2},
		"size": "small", "count": [1, 1], "health": 18, "spawned_only": true,
		"weak": {"burn": 2.0}, "script": "res://scripts/monsters/splitter_crawler.gd", "spawn": "patrol"},
	"dropper": {"name": "吊頂者", "senses": {"sound": 0, "light": 3, "motion": 2},
		"organ": "dropper_arm", "size": "medium", "count": [1, 2], "health": 110,
		"weak": {"burn": 3.0, "stun": 1.5}, "script": "res://scripts/monsters/ceiling_dropper.gd", "spawn": "patrol"},
	"screamer": {"name": "尖叫面具", "senses": {"sound": 0, "light": 2, "motion": 2},
		"organ": "screamer_mask", "size": "small", "count": [1, 2], "health": 30,
		"weak": {"bullet": 1.5}, "script": "res://scripts/monsters/screamer.gd", "spawn": "patrol"},
	# Monster worker B's new five.
	"hounds": {"name": "剝皮獵犬", "senses": {"sound": 0, "light": 0, "motion": 3},
		"organ": "hound_fang", "size": "medium", "count": [2, 3], "health": 90,
		"weak": {"burn": 1.5, "explode": 1.5}, "script": "res://scripts/monsters/hound.gd", "spawn": "far"},
	"weaver": {"name": "蛛網織者", "senses": {"sound": 0, "light": 1, "motion": 2},
		"organ": "weaver_gland", "size": "medium", "count": [1, 1], "health": 170,
		"weak": {"burn": 2.0, "stun": 1.3}, "script": "res://scripts/monsters/web_weaver.gd", "spawn": "patrol"},
	"shield_knight": {"name": "盾甲騎士", "senses": {"sound": 0, "light": 0, "motion": 3},
		"organ": "knight_door", "size": "large", "count": [1, 1], "health": 800,
		"weak": {"explode": 1.3, "pierce": 1.3}, "script": "res://scripts/monsters/shield_knight.gd", "spawn": "far"},
	"stalker": {"name": "影子跟蹤者", "senses": {"sound": 0, "light": 3, "motion": 1},
		"organ": "stalker_shadow", "size": "medium", "count": [1, 1], "health": 130,
		"weak": {"burn": 1.5, "reveal": 2.0}, "script": "res://scripts/monsters/shadow_stalker.gd", "spawn": "far"},
	"eyes": {"name": "窺視眼", "senses": {"sound": 0, "light": 0, "motion": 3},
		"organ": "eye_lens", "size": "small", "count": [2, 4], "health": 22,
		"weak": {"bullet": 1.2, "chain": 2.0, "stun": 2.0}, "script": "res://scripts/monsters/drift_eye.gd", "spawn": "air"},
}
const MIN_KINDS := 4  # players shoot back now: more kinds roam the big maps
const MAX_KINDS := 6
const MAX_LARGE := 2


static func pick(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = MONSTERS.keys().filter(func(kind) -> bool: return not MONSTERS[kind].get("spawned_only", false))
	# Fisher-Yates with the run's rng so every peer could reproduce it.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var wanted := rng.randi_range(MIN_KINDS, mini(MAX_KINDS, pool.size()))
	var result: Array[String] = []
	var large := 0
	for kind in pool:
		if result.size() >= wanted:
			break
		if MONSTERS[kind].size == "large":
			if large >= MAX_LARGE:
				continue
			large += 1
		result.append(kind)
	return result
