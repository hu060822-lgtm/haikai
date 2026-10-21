class_name Awakening
extends Node
## 會醒來的廢墟: how awake the map is. Noise and light wake it, quiet lets it doze off
## again, and time alone always pushes it up, so every match escalates:
##   0-33 沉睡 (asleep) → 34-66 驚醒 (startled) → 67-100 暴走 (rampaging).
## Stages only ever go up. Each one sharpens every monster's senses and speeds them up,
## wakes a new wave of monsters, and at 暴走 the exit lift takes twice as long.
## Lives under the Run on every peer; the host owns level/stage and broadcasts them.

signal stage_changed(stage: int)
## Local only: the local player's shot just woke the ruin by this much (the HUD's eye pulse).
signal shot_woke(amount: float)

const STAGE_NAMES := ["沉睡", "驚醒", "暴走"]
const STAGE_COLORS := [Color(0.45, 0.62, 0.85), Color(0.98, 0.72, 0.2), Color(0.95, 0.18, 0.12)]
## Where each stage starts; once reached, the level never decays below it.
const FLOORS := [0.0, 34.0, 67.0]
const SENSE := [1.0, 1.3, 1.6]
const SPEED := [1.0, 1.1, 1.2]
const MAX_LEVEL := 100.0

## Time alone: a match always escalates (驚醒 at ~7 minutes, 暴走 at ~14 with no noise).
const TRICKLE := 0.08
## A lit lantern (and a gun light on top) wakes it a little, per player, per second.
const LANTERN_RATE := 0.012
const GUN_LIGHT_RATE := 0.012
## After this long without real noise it starts to settle (never below the stage floor).
const QUIET_DELAY := 10.0
const DECAY := 0.3
## Per metre of noise radius, by GameNoise.Kind, and the most one noise can add.
const NOISE_WEIGHT := {
	GameNoise.Kind.FOOTSTEP: 0.003, GameNoise.Kind.LANDING: 0.01, GameNoise.Kind.ITEM: 0.005,
	GameNoise.Kind.IMPACT: 0.02, GameNoise.Kind.TOOL: 0.03, GameNoise.Kind.MACHINE: 0.0,
	GameNoise.Kind.VOICE: 0.003, GameNoise.Kind.MUSIC: 0.06,
}
const NOISE_CAP := 2.0
## A gunshot: this much, plus this much per metre the shot is heard from.
const SHOT_BASE := 1.0
const SHOT_PER_METRE := 0.12
const KILL := 6.0
const BREAK := 10.0
const OBJECTIVE := 8.0
## Waves: small kinds that come in extra copies, and how many at 驚醒 / 暴走.
const SWARM_KINDS := ["rats", "eyes", "mimic", "screamer"]
const SWARM_COUNT := [0, 2, 3]
const EXIT_SLOWDOWN := 2.0

## Tests hold the map still so noise in unrelated checks never sets off a wave: no time
## or light trickle, no settling, no stage changes (add() still raises the level, and
## host_force_stage() still works).
static var frozen := false

## 0..100, synced from the host.
var level := 0.0
## 0 沉睡 / 1 驚醒 / 2 暴走, synced from the host.
var stage := 0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var run: Run

var _quiet := 0.0
var _broadcast := 0.0
var _base_hold := -1.0


## Monster senses (hearing radius, sight and light ranges) under the current stage.
static func sense_mult() -> float:
	var awake := _current()
	return SENSE[awake.stage] if awake != null else 1.0


## Monster speed under the current stage.
static func speed_mult() -> float:
	var awake := _current()
	return SPEED[awake.stage] if awake != null else 1.0


static func _current() -> Awakening:
	if Run.instance == null or not is_instance_valid(Run.instance):
		return null
	return Run.instance.awakening


static func stage_for(value: float) -> int:
	if value >= FLOORS[2]:
		return 2
	if value >= FLOORS[1]:
		return 1
	return 0


func _process(delta: float) -> void:
	if not _is_host() or frozen:
		return
	elapsed += delta
	_quiet += delta
	var light := 0.0
	if run != null and run.level != null and not run.level.bright:
		for player in run.all_players():
			if player.is_active() and player.lantern_on:
				light += LANTERN_RATE + (GUN_LIGHT_RATE if player.gun_light_on else 0.0)
	level += (TRICKLE + light) * delta
	if _quiet > QUIET_DELAY:
		level -= DECAY * delta
	level = clampf(level, floor_level(), MAX_LEVEL)
	_check_stage()
	_broadcast -= delta
	if _broadcast <= 0.0:
		_broadcast = 0.5
		_sync.rpc(level)


## The lowest the level can settle to right now: the stage floor, or what time alone gives.
func floor_level() -> float:
	return maxf(FLOORS[stage], minf(elapsed * TRICKLE, MAX_LEVEL))


## Host: something woke the map (a living organ squirming, heavy loot crashing down...).
func add(amount: float, _at := Vector3.ZERO) -> void:
	if not _is_host() or amount <= 0.0:
		return
	level = minf(level + amount, MAX_LEVEL)
	if amount >= 0.05:
		_quiet = 0.0
	_check_stage()


## Host: every noise anywhere (GameNoise.emit_local), weighted by how far it carries.
func hear(_position: Vector3, radius: float, kind: int) -> void:
	add(minf(radius * NOISE_WEIGHT.get(kind, 0.0), NOISE_CAP))


## Host: a gun went off. Shots are the loudest thing a scavenger does, by far.
## A hushed shot (the shadow organ) barely registers: a tenth of the base.
func host_shot(at: Vector3, noise: float, hush := false) -> float:
	var amount := SHOT_BASE * (0.1 if hush else 1.0) + noise * SHOT_PER_METRE
	add(amount, at)
	return amount


func host_kill(at: Vector3) -> void:
	add(KILL, at)


func host_break(at: Vector3) -> void:
	add(BREAK, at)


## Tests and tools: jump straight to a stage (host).
func host_force_stage(new_stage: int) -> void:
	level = maxf(level, FLOORS[clampi(new_stage, 0, 2)])
	_check_stage(true)


func _check_stage(forced := false) -> void:
	if frozen and not forced:
		return
	var reached := stage_for(level)
	if reached > stage:
		for next in range(stage + 1, reached + 1):
			_set_stage.rpc(next, level)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(value: float) -> void:
	level = value


@rpc("authority", "call_local", "reliable")
func _set_stage(new_stage: int, value: float) -> void:
	if new_stage <= stage:
		return
	stage = new_stage
	level = maxf(level, value)
	_apply_exit()
	if _is_host():
		host_wave(stage)
	stage_changed.emit(stage)


# --- Stage effects -------------------------------------------------------------------

## Host: the map wakes up some more: one kind it hasn't seen yet, plus a few small ones.
## Returns the kinds spawned (tests look at it).
func host_wave(for_stage: int) -> Array[String]:
	var spawned: Array[String] = []
	if run == null or run.level == null or run.level.patrol_points.is_empty():
		return spawned
	var fresh := _fresh_kind()
	if fresh != "":
		run.monster_kinds.append(fresh)
		run.host_spawn_monster(fresh, _spawn_point(fresh))
		spawned.append(fresh)
	var swarm := _swarm_kind()
	if swarm != "":
		if not swarm in run.monster_kinds:
			run.monster_kinds.append(swarm)
		for i in SWARM_COUNT[clampi(for_stage, 0, 2)]:
			run.host_spawn_monster(swarm, _spawn_point(swarm))
			spawned.append(swarm)
	return spawned


## A roster kind not yet in this run (never large: the big ones are the map's own).
func _fresh_kind() -> String:
	var options: Array[String] = []
	for kind: String in MonsterRoster.MONSTERS:
		var entry: Dictionary = MonsterRoster.MONSTERS[kind]
		if entry.get("spawned_only", false) or entry.size == "large" or kind in run.monster_kinds:
			continue
		if kind == "child" or kind in SWARM_KINDS:
			continue  # the child's game is a one-off; swarm kinds come as the extra copies
		options.append(kind)
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else ""


## The small kind that comes in numbers: one already here if possible.
func _swarm_kind() -> String:
	var here: Array[String] = []
	for kind: String in SWARM_KINDS:
		if kind in run.monster_kinds:
			here.append(kind)
	var pool: Array = here if not here.is_empty() else SWARM_KINDS
	return pool[rng.randi_range(0, pool.size() - 1)]


## A patrol point far from every scavenger (a little jitter between copies).
func _spawn_point(kind: String) -> Vector3:
	var players := run.all_players().filter(func(player: Player) -> bool: return player.is_active())
	var best: Vector3 = run.level.patrol_points[0]
	var best_score := -1.0
	for point: Vector3 in run.level.patrol_points:
		var nearest := INF
		for player: Player in players:
			nearest = minf(nearest, point.distance_to(player.global_position))
		if players.is_empty():
			nearest = point.distance_to(run.level.player_spawn)
		var score := nearest + rng.randf_range(0.0, 6.0)
		if score > best_score:
			best_score = score
			best = point
	var lift := 3.0 if MonsterRoster.MONSTERS[kind].get("spawn", "") == "air" else 0.1
	return best + Vector3.UP * lift


## At 暴走 the exit lift takes twice as long, and its light pulses red.
func _apply_exit() -> void:
	var zone := _zone()
	if zone == null:
		return
	if _base_hold < 0.0:
		_base_hold = zone.hold_time
	zone.hold_time = _base_hold * (EXIT_SLOWDOWN if stage >= 2 else 1.0)
	zone.alarm = stage >= 2


func _zone() -> ExtractionZone:
	if run == null or run.level == null:
		return null
	return run.level.extraction_zone


func _is_host() -> bool:
	return multiplayer.is_server()
