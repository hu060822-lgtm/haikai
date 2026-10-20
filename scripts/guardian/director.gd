class_name Director
extends Node
## AI 導演: plays the guardian when no human does, through the same FieldControl
## powers. Deliberately a bit slower and gentler than a sharp human player.

const THINK_INTERVAL := 3.0
const GAIN_MULTIPLIER := 0.7
const PING_MEMORY := 20.0
const NEAR_EXTRACTION := 12.0
const NEAR_GATE := 5.0

var field: FieldControl
var run: Run
var rng := RandomNumberGenerator.new()

var _think := THINK_INTERVAL
var _pings: Array[Dictionary] = []  # {pos, radius, age}


func _ready() -> void:
	field.gain_multiplier = GAIN_MULTIPLIER
	field.pinged.connect(func(pos: Vector3, radius: float) -> void:
		_pings.append({"pos": pos, "radius": radius, "age": 0.0}))


func _process(delta: float) -> void:
	for ping in _pings:
		ping.age += delta
	_pings = _pings.filter(func(ping: Dictionary) -> bool: return ping.age < PING_MEMORY)
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK_INTERVAL
	decide()


## One decision, in priority order. Public so tests can drive it.
func decide() -> String:
	var players := run.all_players().filter(func(player: Player) -> bool: return player.is_active())
	if players.is_empty():
		return ""
	var level := run.level

	# Someone is about to leave: kill the lift's power.
	if level.boiler_on and field.can_use("power"):
		for player in players:
			if player.global_position.distance_to(level.extraction_zone.global_position) < NEAR_EXTRACTION:
				if field.use_power():
					return "power"

	# Loud scavengers: send something at them, from a little way off.
	if field.can_use("monster") and not _pings.is_empty():
		var loudest: Dictionary = _pings[0]
		for ping in _pings:
			if ping.radius > loudest.radius:
				loudest = ping
		for attempt in 6:
			var angle := rng.randf_range(0.0, TAU)
			var spot: Vector3 = loudest.pos + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(7.0, 10.0)
			spot.y = maxf(loudest.pos.y, 0.1)
			var kind: String = FieldControl.RELEASABLE[rng.randi_range(0, 1)]  # moths and mimics
			if field.use_monster(kind, spot):
				_pings.clear()
				return "monster"

	# Someone by a doorway or duct: shut it on them.
	if field.can_use("gate"):
		for i in level.gates.size():
			for player in players:
				if level.gates[i].global_position.distance_to(player.global_position) < NEAR_GATE:
					if field.use_gate(i):
						return "gate"
	return ""
