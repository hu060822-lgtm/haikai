class_name DreamDoor
extends StaticBody3D
## The white door of the dreamcore map. It never opens onto the same room twice.
## Only the player who opens it goes through (the move is replicated like any step).

var map: EndlessAfternoon


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var size := Vector3(1.3, 2.3, 0.12)
	# A white panelled door in its frame: jambs and a header round a slab with four
	# raised panels on each face.
	var parts := [
		[LowPoly.chamfer_box(Vector3(0.1, size.y, size.z), 0.02), LowPoly.at(Vector3(-size.x / 2.0 + 0.05, 0, 0))],
		[LowPoly.chamfer_box(Vector3(0.1, size.y, size.z), 0.02), LowPoly.at(Vector3(size.x / 2.0 - 0.05, 0, 0))],
		[LowPoly.chamfer_box(Vector3(size.x, 0.12, size.z), 0.02), LowPoly.at(Vector3(0, size.y / 2.0 - 0.06, 0))],
		[LowPoly.chamfer_box(Vector3(size.x - 0.2, size.y - 0.14, size.z * 0.6), 0.015), LowPoly.at(Vector3(0, -0.07, 0))],
	]
	for face in [-1.0, 1.0]:
		for panel in [Vector3(-0.24, 0.45, 0), Vector3(0.24, 0.45, 0), Vector3(-0.24, -0.5, 0), Vector3(0.24, -0.5, 0)]:
			parts.append([LowPoly.chamfer_box(Vector3(0.36, 0.8, 0.03), 0.012), LowPoly.at(panel + Vector3(0, 0, face * size.z * 0.3))])
	var frame := MeshInstance3D.new()
	frame.mesh = LootShapes.with_uvs(LowPoly.merge(parts), 1.0)
	frame.position.y = 1.15
	frame.material_override = PS1Materials.get_material("wood", Color(1.0, 1.0, 1.0), true)
	add_child(frame)
	# Round brass knobs on a rose, one each side.
	var knob_mesh := LootShapes.with_uvs(LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.035, 0), Vector2(0.03, 0.012),
		Vector2(0.012, 0.02), Vector2(0.012, 0.04), Vector2(0.045, 0.06), Vector2(0.04, 0.085), Vector2(0, 0.09)]), 7), 8.0)
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		knob.mesh = knob_mesh
		knob.position = Vector3(0.45, 1.05, 0.036 * side)
		knob.rotation.x = PI / 2.0 * side
		knob.material_override = PS1Materials.get_material("brass", Color.WHITE, true)
		add_child(knob)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = 1.15
	add_child(collider)


func get_prompt(_player: Player = null) -> String:
	return "[E] 打開白色的門"


func interact(player: Player) -> void:
	if map != null and player.is_multiplayer_authority():
		map.open_dream_door(player)
