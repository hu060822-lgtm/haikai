class_name BoilerLever
extends StaticBody3D
## The main boiler's restart lever. Pulling it powers the extraction elevator,
## and wakes the whole factory up.

signal pulled(position: Vector3)

var is_pulled := false
var _handle: Node3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.4, 0.4)
	panel.mesh = box
	panel.material_override = PS1Materials.get_material("rust_metal", Color(0.7, 0.7, 0.75), true)
	panel.position.y = 0.7
	add_child(panel)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	collider.position.y = 0.7
	add_child(collider)

	_handle = Node3D.new()
	_handle.position = Vector3(0.0, 1.0, 0.22)
	_handle.rotation.x = deg_to_rad(-40.0)
	add_child(_handle)
	var stick := MeshInstance3D.new()
	var stick_box := BoxMesh.new()
	stick_box.size = Vector3(0.08, 0.55, 0.08)
	stick.mesh = stick_box
	stick.position.y = 0.27
	stick.material_override = PS1Materials.get_material("brass", Color.WHITE, true)
	_handle.add_child(stick)
	var knob := MeshInstance3D.new()
	var knob_box := BoxMesh.new()
	knob_box.size = Vector3(0.16, 0.12, 0.16)
	knob.mesh = knob_box
	knob.position.y = 0.55
	knob.material_override = PS1Materials.get_material("brick", Color(1.0, 0.4, 0.3), true)
	_handle.add_child(knob)


func get_prompt(_player: Player = null) -> String:
	if is_pulled:
		return ""
	return "[E] 重啟主鍋爐（升降梯會通電，但整座工廠會醒來）"


func interact(_player: Player) -> void:
	if is_pulled:
		return
	is_pulled = true
	var tween := create_tween()
	tween.tween_property(_handle, "rotation:x", deg_to_rad(40.0), 0.5)
	Sfx.play_3d(get_parent(), global_position, "clank", 6.0, 80.0, 0.6)
	Sfx.play_3d(get_parent(), global_position, "whistle", 6.0, 120.0, 0.7)
	pulled.emit(global_position)
