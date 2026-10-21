class_name Gate
extends StaticBody3D
## A steel shutter over a doorway or duct mouth. The map (mall shutters) or a monster
## (the tuner) slams it shut for a while; it rolls back up again.

@export var size := Vector3(0.15, 2.2, 1.0)

var closed := false
var _shutter: MeshInstance3D
var _collider: CollisionShape3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	_shutter = MeshInstance3D.new()
	_shutter.mesh = _shutter_mesh(size)
	_shutter.material_override = PS1Materials.get_material("rust_metal", Color(0.75, 0.7, 0.55), true)
	add_child(_shutter)
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_collider.shape = shape
	add_child(_collider)
	# A hazard stripe so it reads as a gate even in the dark: the heavy bottom bar.
	var stripe := MeshInstance3D.new()
	stripe.mesh = LootShapes.with_uvs(LowPoly.chamfer_box(Vector3(size.x + 0.02, 0.12, size.z + 0.02), 0.03), 2.0)
	stripe.material_override = PS1Materials.get_material("brass", Color(1.0, 0.8, 0.2), true)
	stripe.position.y = -size.y / 2.0 + 0.1
	_shutter.add_child(stripe)
	_apply(false)


## Runs on every peer (the run sends it from the host).
func set_closed(value: bool) -> void:
	if value == closed:
		return
	closed = value
	_apply(true)
	Sfx.play_3d(get_parent(), global_position, "clank", 0.0, 35.0, 0.6 if value else 0.8)
	if value:
		Sfx.play_3d(get_parent(), global_position, "thump", -4.0, 35.0, 1.4)


func _apply(animate: bool) -> void:
	collision_layer = Layers.WORLD if closed else 0
	var target := 0.0 if closed else size.y
	if _tween != null:
		_tween.kill()
	if animate:
		_shutter.visible = true
		_tween = create_tween()
		_tween.tween_property(_shutter, "position:y", target, 0.35 if closed else 1.2)
		if not closed:
			_tween.tween_callback(func() -> void: _shutter.visible = false)
	else:
		_shutter.position.y = target
		_shutter.visible = closed


## True if a body standing here would be crushed (the host won't close on someone).
func is_blocked(players: Array) -> bool:
	for player in players:
		var local: Vector3 = to_local(player.global_position + Vector3.UP * 0.5)
		if absf(local.x) < size.x / 2.0 + 0.35 and absf(local.z) < size.z / 2.0 + 0.35 and local.y > -size.y:
			return true
	return false


## A roll-down shutter: rounded steel slats stacked up the doorway, with guide-rail
## edges down both sides. Fills the gate's size box.
static func _shutter_mesh(box: Vector3) -> Mesh:
	var parts := []
	var count := maxi(int(round(box.y / 0.16)), 2)
	var pitch := box.y / count
	for i in count:
		var y := -box.y / 2.0 + pitch * (i + 0.5)
		parts.append([LowPoly.prism(6, box.x * 0.42, box.x * 0.42, box.z * 0.96), LowPoly.at(Vector3(0, y, 0), Vector3(90, 0, 0), Vector3(1.0, pitch / (box.x * 0.75), 1.0))])
	for side in [-1.0, 1.0]:
		parts.append([LowPoly.chamfer_box(Vector3(box.x, box.y, 0.04), 0.01), LowPoly.at(Vector3(0, 0, (box.z / 2.0 - 0.02) * side))])
	return LootShapes.with_uvs(LowPoly.merge(parts), 1.5)
