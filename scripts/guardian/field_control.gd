class_name FieldControl
extends Node
## 場域控制: the guardian's powers over the map, shared by a human guardian and the AI
## director. Lives on every peer under the run; only the host spends energy and acts.
## Energy builds up from the noise scavengers make (talking included) plus a slow trickle.

signal pinged(position: Vector3, radius: float)

const MAX_ENERGY := 100.0
const START_ENERGY := 20.0
const TRICKLE := 0.6  # per second
const NOISE_GAIN := 0.12  # per metre of noise radius
const PING_MIN_RADIUS := 5.0

const ABILITIES := {
	"gate": {"name": "關閘門", "cost": 25.0, "cooldown": 20.0, "duration": 15.0,
		"desc": "點地圖上的閘門，關上 15 秒。可以把人關在房間裡，或擋住退路。"},
	"power": {"name": "斷電", "cost": 45.0, "cooldown": 60.0, "duration": 20.0,
		"desc": "全場燈光熄滅 20 秒，出口也停擺。"},
	"monster": {"name": "放出怪物", "cost": 60.0, "cooldown": 45.0, "duration": 0.0,
		"desc": "在點的位置放出一隻怪物（撲燈蛾 / 擬態蟲 / 假人）。"},
}
const RELEASABLE := ["moth", "mimic", "mannequin"]
const RELEASE_MIN_DISTANCE := 5.0  # never right on top of someone

var energy := START_ENERGY
var gain_multiplier := 1.0
## ability -> seconds until usable again
var cooldowns := {"gate": 0.0, "power": 0.0, "monster": 0.0}
var run: Run

var _gate_timers := {}  # gate index -> seconds until it reopens
var _power_timer := 0.0


func _ready() -> void:
	if multiplayer.is_server():
		add_to_group("listeners")


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	energy = minf(energy + TRICKLE * gain_multiplier * delta, MAX_ENERGY)
	for ability in cooldowns:
		cooldowns[ability] = maxf(cooldowns[ability] - delta, 0.0)
	for index in _gate_timers.keys():
		_gate_timers[index] -= delta
		if _gate_timers[index] <= 0.0:
			_gate_timers.erase(index)
			run.host_set_gate(index, false)
	if _power_timer > 0.0:
		_power_timer -= delta
		if _power_timer <= 0.0:
			run.host_set_power(true)


## Noise from anywhere in the map (host only): energy, and a ping for the guardian's map.
func hear(position: Vector3, radius: float, kind: int) -> void:
	if kind == GameNoise.Kind.MACHINE:
		return  # the factory and its monsters don't feed the guardian
	energy = minf(energy + radius * NOISE_GAIN * gain_multiplier, MAX_ENERGY)
	if radius >= PING_MIN_RADIUS:
		pinged.emit(position, radius)


func can_use(ability: String) -> bool:
	return ABILITIES.has(ability) and cooldowns[ability] <= 0.0 and energy >= ABILITIES[ability].cost


## Host: close a gate. Returns false if it can't (energy, cooldown, someone in the way).
func use_gate(index: int) -> bool:
	if not can_use("gate") or index < 0 or index >= run.level.gates.size():
		return false
	var gate: Gate = run.level.gates[index]
	if gate.closed or gate.is_blocked(run.all_players()):
		return false
	_spend("gate")
	_gate_timers[index] = ABILITIES.gate.duration
	run.host_set_gate(index, true)
	return true


func use_power() -> bool:
	if not can_use("power") or not run.level.power_on:
		return false
	_spend("power")
	_power_timer = ABILITIES.power.duration
	run.host_set_power(false)
	return true


func use_monster(kind: String, position: Vector3) -> bool:
	if not can_use("monster") or not kind in RELEASABLE or not _valid_release(position):
		return false
	_spend("monster")
	run.host_release_monster(kind, position)
	return true


func _valid_release(position: Vector3) -> bool:
	if not run.level.in_bounds(position):
		return false
	for player in run.all_players():
		if player.is_active() and player.global_position.distance_to(position) < RELEASE_MIN_DISTANCE:
			return false
	return true


func _spend(ability: String) -> void:
	energy -= ABILITIES[ability].cost
	cooldowns[ability] = ABILITIES[ability].cooldown
