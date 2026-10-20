class_name ThirdRail
extends Trap
## A stretch of the live third rail with its yellow guard board knocked off, running
## along local x on squat ceramic insulators. While the map's power is on, stepping on
## it throws you back with a bang and a jolt; a blackout (or before the guardian cuts
## the power) makes it safe. Footprint 2.6 x 0.5, free-standing.
## Tell: it hums, a blue spark jumps off the broken end every few seconds, and the guard
## board lies in the dirt next to it.

const HALF := Vector2(1.3, 0.28)
const DAMAGE := 14.0
const INTERVAL := 0.9
const NOISE := 18.0
const SHOVE := 6.0

var _spark := 0.0
var _hum: AudioStreamPlayer3D


func build() -> void:
	_spark = rng.randf_range(0.5, 2.5)
	var parts := [slab(Vector3(2.6, 0.09, 0.14), Vector3(0, 0.2, 0)), slab(Vector3(2.6, 0.03, 0.2), Vector3(0, 0.255, 0))]
	part(parts, "rust_metal", Color(0.55, 0.52, 0.5), Color(0.02, 0.03, 0.05), null, "third_rail_bar")
	var pots := []
	for x: float in [-1.0, 0.0, 1.0]:
		pots.append([LowPoly.prism(6, 0.09, 0.06, 0.16), LowPoly.at(Vector3(x, 0.08, 0))])
	part(pots, "tile", Color(0.85, 0.82, 0.72), Color.BLACK, null, "third_rail_pots")
	# The guard board, knocked into the ballast.
	part([slab(Vector3(1.6, 0.03, 0.32), Vector3(0.3, 0.03, 0.42), Vector3(0, rng.randf_range(-15, 15), rng.randf_range(4, 10)))],
		"wood", Color(0.85, 0.7, 0.15))
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = Sfx.looped("drone")
	_hum.volume_db = -14.0
	_hum.pitch_scale = 2.6
	_hum.max_distance = 9.0
	_hum.autoplay = true
	add_child(_hum)


func is_live() -> bool:
	return map == null or map.power_on


func host_tick(_delta: float) -> void:
	if not is_live():
		return
	for player in players():
		if feet_in(player, HALF, 0.45) and host_cooldown(player, INTERVAL):
			host_noise(NOISE, GameNoise.Kind.IMPACT)
			_spark_fx.rpc()
			# Thrown back the way you came, across the rail.
			var side := signf(to_local(player.global_position).z)
			if side == 0.0:
				side = 1.0
			var push := global_transform.basis.z * side * SHOVE + Vector3.UP * 3.0
			host_affect(player, {"damage": DAMAGE, "cause": "踩到第三軌，被電死了", "note": "腳下的鐵軌有電！",
				"push": push, "slow": 0.8, "slow_factor": 0.4, "shake": 0.7})


func local_tick(delta: float) -> void:
	_hum.stream_paused = not is_live()
	if not is_live():
		return
	_spark -= delta
	if _spark <= 0.0:
		_spark = rng.randf_range(2.0, 5.0)
		_sparks(false)


@rpc("authority", "call_local", "unreliable")
func _spark_fx() -> void:
	_sparks(true)


func _sparks(big: bool) -> void:
	burst(to_global(Vector3(1.3, 0.28, 0)), Color(0.6, 0.8, 1.0), 14 if big else 5, 3.0 if big else 1.6, 70.0, -9.0, 0.35, 0.025, true)
	sound("zap", 2.0 if big else -8.0, 22.0 if big else 12.0, randf_range(0.8, 1.2))
