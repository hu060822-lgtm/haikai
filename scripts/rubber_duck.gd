class_name RubberDuck
extends RigidBody3D
## The exploding rubber duck. Quacks as it lands so monsters come running, then goes off.
## Every peer simulates its own copy for looks and sound; only the host's copy makes
## noise and does damage.

const FUSE := 4.0
const QUACK_INTERVAL := 0.8
const QUACK_RADIUS := 20.0

var _fuse := FUSE
var _quack := 0.3


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD | Layers.WALKWAY
	mass = 0.3
	continuous_cd = true
	# It should flop where it lands, not roll away down the corridor.
	linear_damp = 1.5
	angular_damp = 6.0
	var surface := PhysicsMaterial.new()
	surface.friction = 1.0
	surface.rough = true
	surface.bounce = 0.1
	physics_material_override = surface
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.2
	sphere.radial_segments = 8
	sphere.rings = 4
	body.mesh = sphere
	body.material_override = PS1Materials.get_material("concrete", Color(1.0, 0.85, 0.1), true)
	add_child(body)
	var head := MeshInstance3D.new()
	var small := SphereMesh.new()
	small.radius = 0.07
	small.height = 0.14
	small.radial_segments = 6
	small.rings = 3
	head.mesh = small
	head.position = Vector3(0, 0.12, -0.08)
	head.material_override = body.material_override
	add_child(head)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	collider.shape = shape
	add_child(collider)


func _physics_process(delta: float) -> void:
	_fuse -= delta
	_quack -= delta
	if _quack <= 0.0:
		_quack = QUACK_INTERVAL
		Sfx.play_3d(get_parent(), global_position, "quack", 0.0, 35.0, randf_range(0.9, 1.1))
		if multiplayer.is_server():
			GameNoise.emit_local(get_tree(), global_position, QUACK_RADIUS, GameNoise.Kind.ITEM)
	if _fuse <= 0.0:
		Sfx.play_3d(get_parent(), global_position, "boom", 6.0, 60.0)
		if multiplayer.is_server() and Run.instance != null:
			Run.instance.host_explode(global_position)
		queue_free()
