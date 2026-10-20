class_name TippingShelf
extends Trap
## A tall display shelf with a snapped wall bracket, leaning out over the aisle. Linger
## in front of it and it groans, wobbles, then comes down on you. One use; the fallen
## shelf is just scenery you can step over. Back against a wall, facing into the room
## (local +z is the fall side). Footprint 1.6 x 0.5 standing, falls 1.9 m forward.
## Tell: it already leans a few degrees and creaks when you get close.

enum { STANDING, WOBBLE, FALLEN }

const WIDTH := 1.6
const HEIGHT := 1.9
const DEPTH := 0.45
const DELAY := 1.0
const DAMAGE := 30.0
const NOISE := 30.0

var _pivot: Node3D
var _block: StaticBody3D
var _timer := 0.0
var _creak := 0.0


func build() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0, DEPTH / 2.0)
	_pivot.rotation.x = deg_to_rad(4.0)
	add_child(_pivot)
	var tint := Color(0.7, 0.66, 0.6)
	var post := LowPoly.prism(4, 0.035, 0.035, HEIGHT)
	var parts := []
	for sx in [-1.0, 1.0]:
		for sz in [0.0, -1.0]:
			parts.append([post, LowPoly.at(Vector3(sx * (WIDTH / 2.0 - 0.04), HEIGHT / 2.0, sz * (DEPTH - 0.04) - 0.02), Vector3(0, 45, 0))])
	for i in 4:
		parts.append(slab(Vector3(WIDTH, 0.04, DEPTH), Vector3(0, 0.1 + i * (HEIGHT - 0.15) / 3.0, -DEPTH / 2.0)))
	part(parts, "rust_metal", tint, Color.BLACK, _pivot, "shelf_frame")
	# Leftover stock: a few boxes still on the boards.
	var stock := []
	for i in 3:
		stock.append(slab(Vector3(0.3, 0.25, 0.25), Vector3(rng.randf_range(-0.6, 0.6), 0.1 + i * (HEIGHT - 0.15) / 3.0 + 0.145, -DEPTH / 2.0),
			Vector3(0, rng.randf_range(-20, 20), 0)))
	part(stock, "wood", Color(0.75, 0.6, 0.45), Color.BLACK, _pivot)
	_block = StaticBody3D.new()
	_block.collision_layer = Layers.WORLD
	_block.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	collider.shape = shape
	_block.add_child(collider)
	_block.position = Vector3(0, HEIGHT / 2.0, 0)
	add_child(_block)


## Feet in the strip the shelf lands on.
func _in_zone(player: Player, margin := 0.0) -> bool:
	var local := to_local(player.global_position)
	return absf(local.x) < WIDTH / 2.0 + 0.2 + margin and local.z > DEPTH / 2.0 - 0.05 and local.z < DEPTH / 2.0 + HEIGHT + margin \
		and local.y > -0.6 and local.y < 1.2


func host_tick(delta: float) -> void:
	match state:
		STANDING:
			for player in players():
				var local := to_local(player.global_position)
				if _in_zone(player) and local.z < DEPTH / 2.0 + 1.2:
					host_set_state(WOBBLE)
					_timer = DELAY
					return
		WOBBLE:
			_timer -= delta
			if _timer <= 0.0:
				host_set_state(FALLEN)
				host_noise(NOISE)
				for player in players():
					if _in_zone(player):
						host_affect(player, {"damage": DAMAGE, "cause": "被倒下來的貨架壓死了", "note": "貨架倒下來壓到你了！", "shake": 1.0})


func local_tick(delta: float) -> void:
	if state == WOBBLE:
		_creak += delta
		_pivot.rotation.x = deg_to_rad(4.0 + 3.0 * absf(sin(_creak * 14.0)) + _creak * 4.0)


func apply_state(new_state: int, _arg: int) -> void:
	match new_state:
		WOBBLE:
			sound("creak", 2.0, 25.0, 0.6, Vector3(0, HEIGHT, 0))
		FALLEN:
			_block.queue_free()
			var tween := create_tween()
			tween.tween_property(_pivot, "rotation:x", deg_to_rad(84.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_callback(func() -> void:
				sound("bang", 4.0, 50.0, 0.6, Vector3(0, 0.2, HEIGHT * 0.6))
				sound("clank", 2.0, 40.0, 0.7, Vector3(0, 0.2, HEIGHT * 0.6))
				burst(to_global(Vector3(0, 0.1, HEIGHT * 0.7)), Color(0.5, 0.45, 0.4), 14, 3.0, 70.0))
