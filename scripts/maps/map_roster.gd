class_name MapRoster
## Every map is in the random pool from the start; each run draws one.

const MAPS := ["factory", "mall", "station", "afternoon"]


static func pick(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x5EED
	return MAPS[rng.randi_range(0, MAPS.size() - 1)]


static func create(id: String) -> GameMap:
	match id:
		"mall":
			return MidnightMall.new()
		"station":
			return ResearchStation.new()
		"afternoon":
			return EndlessAfternoon.new()
		_:
			return BoilerFactory.new()
