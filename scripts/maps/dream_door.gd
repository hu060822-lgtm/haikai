class_name DreamDoor
extends StaticBody3D
## The white door of the dreamcore map. It never opens onto the same room twice.
## Only the player who opens it goes through (the move is replicated like any step).

var map: EndlessAfternoon


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 2.3, 0.12)
	frame.mesh = box
	frame.position.y = 1.15
	frame.material_override = PS1Materials.get_material("wood", Color(1.0, 1.0, 1.0), true)
	add_child(frame)
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		knob.mesh = sphere
		knob.position = Vector3(0.45, 1.05, 0.08 * side)
		knob.material_override = PS1Materials.get_material("brass", Color.WHITE, true)
		add_child(knob)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	collider.position.y = 1.15
	add_child(collider)


func get_prompt(_player: Player = null) -> String:
	return "[E] 打開白色的門"


func interact(player: Player) -> void:
	if map != null and player.is_multiplayer_authority():
		map.open_dream_door(player)
