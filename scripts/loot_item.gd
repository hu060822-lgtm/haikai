class_name LootItem
extends RigidBody3D
## A pick-up-able piece of loot. Spawned frozen so it stays where it was placed;
## items the player drops are unfrozen and fall with physics.

@export var item_name := "黃銅齒輪"
@export var value := 35
@export var weight := 1.5
@export var size := Vector3(0.3, 0.3, 0.08)
@export var texture_name := "brass"
@export var tint := Color.WHITE


static func from_data(data: Dictionary) -> LootItem:
	var item := LootItem.new()
	item.item_name = data.name
	item.value = data.value
	item.weight = data.weight
	item.size = data.size
	item.texture_name = data.texture
	item.tint = data.color
	return item


func _ready() -> void:
	add_to_group("loot")
	# Loot sits on its own layer so it never blocks the player's movement.
	collision_layer = 2
	collision_mask = 1
	mass = maxf(weight, 0.2)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = PS1Materials.get_material(texture_name, tint, true)
	add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)


func to_data() -> Dictionary:
	return {
		"name": item_name,
		"value": value,
		"weight": weight,
		"size": size,
		"texture": texture_name,
		"color": tint,
	}


func get_prompt() -> String:
	return "[E] 撿起 %s　$%d　%.1fkg" % [item_name, value, weight]


func interact(player: Player) -> void:
	if player.pickup(to_data()):
		queue_free()
