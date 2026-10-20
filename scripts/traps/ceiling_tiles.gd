class_name CeilingTiles
extends Trap
## A patch of sodden ceiling tiles bellied down out of their grid, a cable hanging out of
## the hole. Walk under it and plaster dust trickles out and the grid groans; a moment
## later the lot comes down on whoever is still underneath. Keep moving and it misses.
## One use: the broken tiles stay on the floor. params.ceiling: the room's height.
## Footprint 1.6 x 1.6, free-standing.
## Tell: the sag and the dangling cable, and dust drifting down in your lantern light.

enum { SAGGING, GROANING, FALLEN }

const TRIGGER := 1.0
const RADIUS := 1.0
const DELAY := 0.9
const DAMAGE := 22.0
const NOISE := 18.0

var ceiling := 4.5
var _sag: Node3D
var _debris: MeshInstance3D
var _timer := 0.0
var _dust := 0.0


func build() -> void:
	ceiling = maxf(params.get("ceiling", 4.5), 2.8)
	_sag = Node3D.new()
	_sag.position.y = ceiling
	add_child(_sag)
	var tiles := []
	for i in 4:
		var x := -0.4 + (i % 2) * 0.8
		var z := -0.4 + (i / 2) * 0.8
		tiles.append(slab(Vector3(0.78, 0.04, 0.78), Vector3(x, -0.08 - rng.randf_range(0.05, 0.22), z),
			Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))))
	part(tiles, "panel", Color(0.62, 0.6, 0.5), Color.BLACK, _sag)
	var frame := [slab(Vector3(1.7, 0.04, 0.04), Vector3(0, -0.03, -0.82)), slab(Vector3(1.7, 0.04, 0.04), Vector3(0, -0.03, 0.82)),
		slab(Vector3(0.04, 0.04, 1.7), Vector3(-0.82, -0.03, 0)), slab(Vector3(0.04, 0.04, 1.7), Vector3(0.82, -0.03, 0))]
	part(frame, "rust_metal", Color(0.5, 0.48, 0.45), Color.BLACK, null, "ceiling_frame%s" % ceiling).position.y = ceiling
	var cable := PackedVector3Array([Vector3(0.1, 0, 0.1), Vector3(0.2, -0.5, 0.15), Vector3(0.12, -1.0, 0.3), Vector3(0.25, -1.35, 0.25)])
	part([[LowPoly.tube(cable, PackedFloat32Array([0.02, 0.02, 0.02, 0.015]), 4), Transform3D.IDENTITY]],
		"rust_metal", Color(0.12, 0.12, 0.12), Color.BLACK, _sag)
	var bits := []
	for i in 7:
		bits.append(slab(Vector3(rng.randf_range(0.2, 0.45), 0.04, rng.randf_range(0.2, 0.4)),
			Vector3(rng.randf_range(-0.8, 0.8), 0.02, rng.randf_range(-0.8, 0.8)), Vector3(0, rng.randf_range(0, 180), rng.randf_range(-8, 8))))
	_debris = part(bits, "panel", Color(0.55, 0.53, 0.45))
	_debris.visible = false
	_dust = rng.randf_range(1.0, 4.0)


func host_tick(delta: float) -> void:
	match state:
		SAGGING:
			for player in players():
				if feet_within(player, TRIGGER, 1.2):
					host_set_state(GROANING)
					_timer = DELAY
					return
		GROANING:
			_timer -= delta
			if _timer <= 0.0:
				host_set_state(FALLEN)
				host_noise(NOISE)
				for player in players():
					if feet_within(player, RADIUS, 1.2):
						host_affect(player, {"damage": DAMAGE, "cause": "被塌下來的天花板砸死了",
							"note": "天花板塌下來了！", "shake": 0.9, "slow": 1.0, "slow_factor": 0.6})


func local_tick(delta: float) -> void:
	if state == FALLEN:
		return
	_dust -= delta
	if _dust <= 0.0:
		_dust = rng.randf_range(3.0, 7.0) if state == SAGGING else 0.15
		burst(to_global(Vector3(rng.randf_range(-0.4, 0.4), ceiling - 0.3, rng.randf_range(-0.4, 0.4))),
			Color(0.7, 0.68, 0.6), 4, 0.3, 20.0, -2.0, 1.4, 0.02)
	if state == GROANING:
		_sag.position.y = ceiling - 0.05 + sin(Time.get_ticks_msec() * 0.05) * 0.02


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		GROANING:
			sound("creak", 0.0, 22.0, 0.8, Vector3(0, ceiling, 0))
			burst(to_global(Vector3(0, ceiling - 0.3, 0)), Color(0.7, 0.68, 0.6), 14, 0.6, 40.0, -3.0, 1.0, 0.03)
		FALLEN:
			var tween := create_tween()
			tween.tween_property(_sag, "position:y", 0.25, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void:
				_sag.visible = false
				_debris.visible = true
				sound("thump", 4.0, 40.0, 1.1)
				sound("clank", -4.0, 30.0, 0.8)
				burst(global_position + Vector3.UP * 0.2, Color(0.65, 0.62, 0.55), 18, 3.0, 80.0))
