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

	# Two rails and rungs, purely visual: hexagonal steel bars with bolted rail feet,
	# merged into one mesh.
	var material := PS1Materials.get_material("rust_metal", Color(0.9, 0.8, 0.7), true)
	var parts := []
	for x in [-0.3, 0.3]:
		parts.append([LowPoly.prism(6, 0.035, 0.035, height), LowPoly.at(Vector3(x, height / 2.0, 0.0), Vector3(0, 30, 0))])
		parts.append([LowPoly.chamfer_box(Vector3(0.1, 0.04, 0.1), 0.012), LowPoly.at(Vector3(x, 0.02, 0.0))])
	var rung := 0.35
	while rung < height:
		parts.append([LowPoly.prism(6, 0.025, 0.025, 0.6), LowPoly.at(Vector3(0.0, rung, 0.0), Vector3(0, 0, 90))])
		rung += 0.4
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = LootShapes.with_uvs(LowPoly.merge(parts), 2.0)
	mesh_instance.material_override = material
	add_child(mesh_instance)
