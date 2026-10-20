class_name GameState
## Persistent progress between runs: money and the stash.
## The stash holds weapon frames, weapon parts (Arsenal) and boosts (Gear), counted by id.
## Whatever is taken into a run is lost on death and returned on extraction.

const SAVE_PATH := "user://haikai_save.json"
const START_MONEY := 300

static var money := START_MONEY
static var stash := {}  # frame / part / boost id -> count owned but not equipped
static var extractions := 0
static var deaths := 0
static var best_haul := 0
## What the stash screen has equipped for the next run (already paid for):
## a weapon build (see Arsenal) and up to Gear.MAX_BOOSTS boosts.
static var equipped := empty_loadout()
## Saved weapon plans from the gunsmith bench: [{"name": String, "build": Dictionary}].
## A plan is only a blueprint: equipping it takes the pieces from the stash or buys them.
static var builds: Array = []
const MAX_BUILDS := 6
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
	# Saves from before weapon builds held old Gear weapons: refund them as money (the
	# ones that share a name with a new frame, like the shotgun, simply become that frame).
	for id in stash.keys():
		if Gear.LEGACY_WEAPONS.has(id) and not Arsenal.FRAMES.has(id):
			money += int(Gear.LEGACY_WEAPONS[id]) * int(stash[id])
			stash.erase(id)
	equipped = empty_loadout()
	var saved_loadout = parsed.get("equipped", {})
	if typeof(saved_loadout) == TYPE_DICTIONARY:
		var old_weapon := str(saved_loadout.get("weapon", ""))
		if Gear.LEGACY_WEAPONS.has(old_weapon):
			money += int(Gear.LEGACY_WEAPONS[old_weapon])
		if typeof(saved_loadout.get("build")) == TYPE_DICTIONARY:
			equipped.build = Arsenal.clean(saved_loadout.build)
		for id in saved_loadout.get("boosts", []):
			if Gear.ITEMS.has(str(id)):
				equipped.boosts.append(str(id))
	builds = []
	for plan in parsed.get("builds", []):
		if typeof(plan) == TYPE_DICTIONARY and typeof(plan.get("build")) == TYPE_DICTIONARY:
			builds.append({"name": str(plan.get("name", "")), "build": Arsenal.clean(plan.build)})


static func save_game() -> void:
	if not save_enabled:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"money": money, "stash": stash, "extractions": extractions,
		"deaths": deaths, "best_haul": best_haul, "equipped": equipped, "builds": builds,
	}))


static func reset() -> void:
	money = START_MONEY
	stash = {}
	extractions = 0
	deaths = 0
	best_haul = 0
	equipped = empty_loadout()
	builds = []


static func empty_loadout() -> Dictionary:
	return {"build": Arsenal.STARTER.duplicate(true), "boosts": []}


static func owned(id: String) -> int:
	return stash.get(id, 0)


## Takes one of the gear for a run: from the stash if owned, otherwise buys it.
static func take(id: String) -> bool:
	if owned(id) > 0:
		stash[id] -= 1
		return true
	var price: int = price_of(id)
	if money < price:
		return false
	money -= price
	return true


static func price_of(id: String) -> int:
	if Gear.ITEMS.has(id):
		return int(Gear.ITEMS[id].get("price", 0))
	return Arsenal.price_of(id)


## Buys one into the stash without equipping it (the gunsmith's parts shelf).
static func buy(id: String) -> bool:
	var price := price_of(id)
	if money < price:
		return false
	money -= price
	stash[id] = owned(id) + 1
	return true


## What equipping a build would cost on top of what the stash already holds.
static func build_cost(build: Dictionary) -> int:
	var counts := {}
	var cost := 0
	for id in Arsenal.ids(build):
		counts[id] = counts.get(id, 0) + 1
		if counts[id] > owned(id):
			cost += price_of(id)
	return cost


## Swaps the equipped weapon for this build: the old one's pieces go back to the stash,
## the new one's come out of it (missing pieces are bought). False if it can't be afforded.
static func equip_build(build: Dictionary) -> bool:
	build = Arsenal.clean(build)
	for id in Arsenal.ids(equipped.build):
		give_back(id)
	if build_cost(build) > money:
		for id in Arsenal.ids(equipped.build):
			stash[id] -= 1
		return false
	for id in Arsenal.ids(build):
		take(id)
	equipped.build = build
	save_game()
	return true


## Saves (or overwrites, by name) a plan on the gunsmith bench.
static func save_plan(plan_name: String, build: Dictionary) -> void:
	for plan in builds:
		if plan.name == plan_name:
			plan.build = Arsenal.clean(build)
			save_game()
			return
	if builds.size() >= MAX_BUILDS:
		builds.pop_front()
	builds.append({"name": plan_name, "build": Arsenal.clean(build)})
	save_game()


## Puts gear back (un-equipping in the loadout screen, or surviving a run).
static func give_back(id: String) -> void:
	if Arsenal.price_of(id) == 0 and Arsenal.frame(id).size() > 0:
		return  # the starter revolver is free and never piles up in the stash
	stash[id] = owned(id) + 1


static func record_extraction(earned: int, surviving_gear: Array) -> void:
	money += earned
	extractions += 1
	best_haul = maxi(best_haul, earned)
	for id in surviving_gear:
		give_back(id)
	save_game()


const GUARDIAN_WIN_REWARD := 250
const GUARDIAN_LOSS_REWARD := 50


## The guardian earns money too: a lot for holding the line, a little for showing up.
static func record_guardian(won: bool) -> void:
	money += GUARDIAN_WIN_REWARD if won else GUARDIAN_LOSS_REWARD
	save_game()


static func record_death() -> void:
	deaths += 1
	# Never leave a broke player stuck with nothing: a free lantern run is always possible,
	# and a small stipend keeps the shop reachable.
	if money < 40:
		money = 40
	save_game()


## Hands the equipped gear to a starting run; it is no longer in the stash screen.
static func consume_equipped() -> Dictionary:
	var loadout := equipped.duplicate(true)
	equipped = empty_loadout()
	save_game()
	return loadout
