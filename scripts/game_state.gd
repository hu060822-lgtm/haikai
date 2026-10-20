class_name GameState
## Persistent progress between runs: money and the gear stash.
## Gear taken into a run is lost on death and returned on extraction.

const SAVE_PATH := "user://haikai_save.json"
const START_MONEY := 300

static var money := START_MONEY
static var stash := {}  # gear id -> count owned but not equipped
static var extractions := 0
static var deaths := 0
static var best_haul := 0
## Tests turn this off so they never touch the player's real save.
static var save_enabled := true


static func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	money = int(parsed.get("money", START_MONEY))
	stash = parsed.get("stash", {})
	for id in stash.keys():
		stash[id] = int(stash[id])
	extractions = int(parsed.get("extractions", 0))
	deaths = int(parsed.get("deaths", 0))
	best_haul = int(parsed.get("best_haul", 0))


static func save_game() -> void:
	if not save_enabled:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"money": money, "stash": stash, "extractions": extractions,
		"deaths": deaths, "best_haul": best_haul,
	}))


static func reset() -> void:
	money = START_MONEY
	stash = {}
	extractions = 0
	deaths = 0
	best_haul = 0


static func owned(id: String) -> int:
	return stash.get(id, 0)


## Takes one of the gear for a run: from the stash if owned, otherwise buys it.
static func take(id: String) -> bool:
	if owned(id) > 0:
		stash[id] -= 1
		return true
	var price: int = Gear.info(id).get("price", 0)
	if money < price:
		return false
	money -= price
	return true


## Puts gear back (un-equipping in the loadout screen, or surviving a run).
static func give_back(id: String) -> void:
	stash[id] = owned(id) + 1


static func record_extraction(earned: int, surviving_gear: Array) -> void:
	money += earned
	extractions += 1
	best_haul = maxi(best_haul, earned)
	for id in surviving_gear:
		give_back(id)
	save_game()


static func record_death() -> void:
	deaths += 1
	# Never leave a broke player stuck with nothing: a free lantern run is always possible,
	# and a small stipend keeps the shop reachable.
	if money < 40:
		money = 40
	save_game()
