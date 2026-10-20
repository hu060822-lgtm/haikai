class_name Locker
extends StaticBody3D
## A locked metal cabinet with better loot inside. Needs a crowbar, and prying it
## open is loud.

signal opened(locker: Locker)

const PRY_NOISE := 12.0
const LUCK := 1.5

var is_open := false
var rng: RandomNumberGenerator
var _door: Node3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	var body_material := PS1Materials.get_material("rust_metal", Color(0.6, 0.7, 0.75), true)
	var shell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.9, 0.6)
	shell.mesh = box
	shell.material_override = body_material
	shell.position.y = 0.95
	add_child(shell)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	collider.position.y = 0.95
	add_child(collider)

	# Door hinge on the left edge of the +z face.
	_door = Node3D.new()
	_door.position = Vector3(-0.45, 0.95, 0.31)
	add_child(_door)
	var door_mesh := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.88, 1.85, 0.04)
	door_mesh.mesh = door_box
	door_mesh.material_override = PS1Materials.get_material("rust_metal", Color(0.75, 0.8, 0.85), true)
	door_mesh.position.x = 0.44
	_door.add_child(door_mesh)
	var padlock := MeshInstance3D.new()
	var lock_box := BoxMesh.new()
	lock_box.size = Vector3(0.08, 0.1, 0.05)
	padlock.mesh = lock_box
	padlock.material_override = PS1Materials.get_material("brass", Color.WHITE, true)
	padlock.position = Vector3(0.8, 0.0, 0.04)
	padlock.name = "Padlock"
	_door.add_child(padlock)


func get_prompt(player: Player = null) -> String:
	if is_open:
		return ""
	if player != null and player.has_gear("crowbar"):
		return "[E / 左鍵] 撬開上鎖的櫃子（很吵）"
	return "上鎖的櫃子：需要撬棍"


func interact(player: Player) -> void:
	if is_open:
		return
	if player.has_gear("crowbar"):
		pry(player)
	else:
		player.message.emit("鎖住了，需要撬棍")


func pry(_player: Player) -> void:
	if is_open:
		return
	is_open = true
	_door.get_node("Padlock").queue_free()
	var tween := create_tween()
	tween.tween_property(_door, "rotation:y", deg_to_rad(-110.0), 0.4)
	Sfx.play_3d(get_parent(), global_position, "clank", 4.0, 45.0, 0.8)
	GameNoise.emit(get_tree(), global_position, PRY_NOISE, GameNoise.Kind.TOOL)
	var r := rng if rng != null else RandomNumberGenerator.new()
	for i in r.randi_range(1, 2):
		var item := LootItem.from_data(LootTable.roll(r, LUCK))
		item.freeze = true
		get_parent().add_child(item)
		item.global_position = to_global(Vector3(-0.2 + 0.4 * i, 0.2, 0.6))
	opened.emit(self)
