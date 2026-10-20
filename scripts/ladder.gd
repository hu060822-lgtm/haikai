class_name Ladder
extends Area3D
## Climbable ladder. While the player overlaps it, forward/back moves them up/down.

var height := 7.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, height, 0.9)
	collider.shape = shape
	collider.position.y = height / 2.0
	add_child(collider)
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			body.enter_ladder())
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			body.exit_ladder())

	# Two rails and rungs, purely visual.
	var material := PS1Materials.get_material("rust_metal", Color(0.9, 0.8, 0.7), true)
	for x in [-0.3, 0.3]:
		_part(Vector3(0.06, height, 0.06), Vector3(x, height / 2.0, 0.0), material)
	var rung := 0.35
	while rung < height:
		_part(Vector3(0.6, 0.05, 0.05), Vector3(0.0, rung, 0.0), material)
		rung += 0.4


func _part(size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)
