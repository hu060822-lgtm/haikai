class_name SqueakFloor
extends Trap
## A patch of soft pastel play-mat tiles. Your feet sink into it, so you wade slowly,
## and every step squeaks like a bath toy for the whole house to hear. Crouch-walking
## over it is quieter but still squeaks. Footprint 1.6 x 1.6.
## Tell: the tiles bulge, and they're a slightly different colour from the floor.

const HALF := 0.8
const SLOW := 0.55
const NOISE := 14.0
const CROUCH_NOISE := 6.0
const STEP := 0.45

var _last := {}
var _step := {}


func build() -> void:
	var colors := [Color(0.98, 0.75, 0.82), Color(0.72, 0.88, 0.98), Color(0.98, 0.93, 0.7), Color(0.75, 0.95, 0.8)]
	var first := rng.randi_range(0, 3)
	for i in 4:
		var at := Vector3((i % 2) * 0.8 - 0.4, 0.03, (i / 2) * 0.8 - 0.4)
		part([[LowPoly.lathe(PackedVector2Array([Vector2(0, 0.0), Vector2(0.55, 0.0), Vector2(0.5, 0.035), Vector2(0, 0.05)]), 4),
			LowPoly.at(at - Vector3(0, 0.03, 0), Vector3(0, 45, 0), Vector3(1, 1, 1))]],
			"snow", colors[(first + i) % 4], Color.BLACK, null, "squeak_tile%d" % i)


func host_tick(_delta: float) -> void:
	for player in players():
		var key := String(player.name)
		if not feet_in(player, Vector2(HALF, HALF), 0.3):
			_last.erase(key)
			continue
		var pos := player.global_position
		var moved: float = Vector2(pos.x - _last.get(key, pos).x, pos.z - _last.get(key, pos).z).length()
		_last[key] = pos
		if host_cooldown(player, 0.3):
			host_affect(player, {"slow": 0.4, "slow_factor": SLOW})
		_step[key] = _step.get(key, 0.0) + moved
		if _step[key] > STEP:
			_step[key] = 0.0
			var crouched := player.is_crouching
			host_noise(CROUCH_NOISE if crouched else NOISE, GameNoise.Kind.FOOTSTEP, pos)
			_squeak.rpc(pos, crouched)


@rpc("authority", "call_local", "unreliable")
func _squeak(at: Vector3, crouched: bool) -> void:
	Sfx.play_3d(self, at, "quack", -10.0 if crouched else 0.0, 30.0, randf_range(1.5, 1.9))
