class_name MonsterRoster
## Which monsters show up in a run. Every monster is its own creature and can appear on
## any map; each run draws 2 to 4 kinds, at most one of them large.

const MONSTERS := {
	"colossus": {"name": "鍋爐巨像", "size": "large", "count": [1, 1]},
	"mannequin": {"name": "假人", "size": "medium", "count": [1, 1]},
	"moth": {"name": "撲燈蛾", "size": "small", "count": [2, 3]},
	"mimic": {"name": "擬態蟲", "size": "small", "count": [2, 3]},
	"watcher": {"name": "長頸觀察者", "size": "large", "count": [1, 1]},
	"greeter": {"name": "迎賓員", "size": "medium", "count": [1, 1]},
	"collector": {"name": "回收員", "size": "medium", "count": [1, 1]},
	"rats": {"name": "發條鼠群", "size": "small", "count": [1, 2]},
	"centipede": {"name": "蜈蚣列車", "size": "large", "count": [1, 1]},
	"mother": {"name": "哄睡的母親", "size": "large", "count": [1, 1]},
	"fog_walker": {"name": "霧行者", "size": "medium", "count": [1, 1]},
	"tuner": {"name": "調音師", "size": "medium", "count": [1, 1]},
	"child": {"name": "捉迷藏的孩子", "size": "small", "count": [1, 1]},
}
const MIN_KINDS := 3  # the maps are big: a few more things roam them
const MAX_KINDS := 5
const MAX_LARGE := 1


static func pick(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = MONSTERS.keys()
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
