class_name RubberDuck
extends RigidBody3D
## The duck launcher's grenade. Quacks as it lands so monsters come running, then goes off.
## Every peer simulates its own copy for looks and sound; only the host's copy makes
## noise and does damage (Run.host_explode with the launcher's numbers).

const FUSE := 3.0
const QUACK_INTERVAL := 0.8
const QUACK_RADIUS := 20.0

## Set by Run before it enters the tree: the blast, and the shooter's peer id.
var damage := 90.0
var radius := 4.0
var effects := {}
var shooter := 0
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
	# A faceted rubber duck: plump body with an upturned tail, round head, flat orange
	# bill and two painted eyes. Head and bill face -z, as before.
	var yellow := PS1Materials.get_material("concrete", Color(1.0, 0.85, 0.1), true)
	var body := MeshInstance3D.new()
	body.mesh = LootShapes.with_uvs(LowPoly.merge([
		[LowPoly.blob(0.12, Vector3(0.85, 0.72, 1.0), 1, 0.03, 3), LowPoly.at(Vector3(0, -0.01, 0.01))],
		[LowPoly.prism(4, 0.05, 0.0, 0.09), LowPoly.at(Vector3(0, 0.05, 0.11), Vector3(55, 45, 0), Vector3(1.0, 0.6, 1.0))],
		[LowPoly.blob(0.045, Vector3(0.5, 0.6, 1.2), 0), LowPoly.at(Vector3(0.09, 0.0, 0.02))],
		[LowPoly.blob(0.045, Vector3(0.5, 0.6, 1.2), 0), LowPoly.at(Vector3(-0.09, 0.0, 0.02))],
	]), 6.0)
	body.material_override = yellow
	add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = LootShapes.with_uvs(LowPoly.blob(0.07, Vector3(1.0, 1.0, 1.05), 1, 0.02, 1), 6.0)
	head.position = Vector3(0, 0.12, -0.08)
	head.material_override = yellow
	add_child(head)
	var bill := MeshInstance3D.new()
	bill.mesh = LowPoly.extrude(PackedVector2Array([Vector2(-0.035, 0.0), Vector2(0.035, 0.0), Vector2(0.03, -0.05),
		Vector2(0.0, -0.06), Vector2(-0.03, -0.05)]), 0.022)
	bill.rotation.x = PI / 2.0
	bill.material_override = PS1Materials.get_material("concrete", Color(1.0, 0.45, 0.1), true)
	head.add_child(bill)
	bill.position = Vector3(0, -0.015, -0.055)
	var eyes := MeshInstance3D.new()
	eyes.mesh = LowPoly.merge([[LowPoly.blob(0.013, Vector3.ONE, 0), LowPoly.at(Vector3(0.035, 0.02, -0.055))],
		[LowPoly.blob(0.013, Vector3.ONE, 0), LowPoly.at(Vector3(-0.035, 0.02, -0.055))]])
	eyes.material_override = PS1Materials.get_material("concrete", Color(0.05, 0.05, 0.05), true)
	head.add_child(eyes)
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
		if multiplayer.is_server() and Run.instance != null:
			var attacker := Run.instance.players_root.get_node_or_null(str(shooter)) as Player
			Run.instance.host_explode(global_position, damage, radius, effects, attacker)
		queue_free()
