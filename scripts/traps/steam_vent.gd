class_name SteamVent
extends Trap
## A floor grate over a cracked steam main. It breathes on a cycle: a thin hiss and a
## few wisps for a second and a half, then a scalding burst that burns and throws you
## back. Count the hisses and cross between them. Only cycles while someone is near.
## Tell: the hiss, the wisps, and a brass valve wheel by the grate.

enum { IDLE, HISS, BURST }

const PERIOD := 7.0
const HISS_TIME := 1.5
const BURST_TIME := 1.0
const RADIUS := 0.75
const DAMAGE := 18.0
const PUSH := 6.0
const NOISE := 12.0
const ACTIVE_RANGE := 30.0

var _clock := 0.0
var _hit: Array[String] = []
var _plume: CPUParticles3D
var _wisp := 0.0


func build() -> void:
	_clock = rng.randf_range(0.0, PERIOD)
	var parts := [[LowPoly.chamfer_box(Vector3(0.8, 0.04, 0.8), 0.015), LowPoly.at(Vector3(0, 0.02, 0))]]
	part(parts, "grate", Color(0.55, 0.52, 0.48), Color.BLACK, null, "vent_grate")
	part([[LowPoly.tube(PackedVector3Array([Vector3(0.45, 0.0, -0.3), Vector3(0.5, 0.2, -0.3), Vector3(0.5, 0.35, -0.3)]),
			PackedFloat32Array([0.06, 0.06, 0.06]), 5), Transform3D.IDENTITY],
		[LowPoly.prism(6, 0.09, 0.09, 0.02), LowPoly.at(Vector3(0.5, 0.37, -0.3))]],
		"brass", Color(0.8, 0.7, 0.5), Color.BLACK, null, "vent_valve")
	_plume = CPUParticles3D.new()
	_plume.emitting = false
	_plume.amount = 24
	_plume.lifetime = 0.8
	_plume.direction = Vector3.UP
	_plume.spread = 12.0
	_plume.initial_velocity_min = 4.0
	_plume.initial_velocity_max = 6.5
	_plume.gravity = Vector3(0, 1.0, 0)
	_plume.scale_amount_min = 1.0
	_plume.scale_amount_max = 1.6
	_plume.mesh = LowPoly.blob(0.08, Vector3.ONE, 0)
	_plume.material_override = PS1Materials.get_material("concrete", Color(0.85, 0.85, 0.85, 1.0), true)
	_plume.position.y = 0.05
	add_child(_plume)


func host_tick(delta: float) -> void:
	var near := false
	for player in players():
		if player.global_position.distance_to(global_position) < ACTIVE_RANGE:
			near = true
	if not near:
		if state != IDLE:
			host_set_state(IDLE)
		return
	_clock += delta
	var phase := fmod(_clock, PERIOD)
	var want := IDLE
	if phase > PERIOD - BURST_TIME:
		want = BURST
	elif phase > PERIOD - BURST_TIME - HISS_TIME:
		want = HISS
	if want != state:
		host_set_state(want)
		if want == BURST:
			_hit.clear()
			host_noise(NOISE, GameNoise.Kind.MACHINE)
	if state == BURST:
		for player in players():
			if feet_within(player, RADIUS, 1.5) and not String(player.name) in _hit:
				_hit.append(String(player.name))
				var away := player.global_position - global_position
				away.y = 0.0
				away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
				host_affect(player, {"damage": DAMAGE, "cause": "被蒸氣活活燙死了", "note": "滾燙的蒸氣從地上噴出來！",
					"push": away * PUSH + Vector3.UP * 3.0, "shake": 0.6})


func local_tick(delta: float) -> void:
	if state == HISS:
		_wisp -= delta
		if _wisp <= 0.0:
			_wisp = 0.3
			burst(global_position + Vector3.UP * 0.05, Color(0.8, 0.8, 0.8), 3, 1.2, 15.0, 0.5, 0.7, 0.06)


func apply_state(new_state: int, _arg: int) -> void:
	_plume.emitting = new_state == BURST
	match new_state:
		HISS:
			sound("hiss", -10.0, 18.0, 1.6)
		BURST:
			sound("hiss", 4.0, 35.0, 0.8)
