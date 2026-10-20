class_name BoilerLever
extends StaticBody3D
## The main boiler's restart lever. Pulling it powers the extraction elevator,
## and wakes the whole factory up.

## The run decides whether the pull happens (the host owns it), then calls play_pull().
signal interact_requested()

var is_pulled := false
var prompt := "[E] 拉下拉桿"
var _handle: Node3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	var housing := PS1Materials.get_material("rust_metal", Color(0.7, 0.7, 0.75), true)
	var dark := PS1Materials.get_material("rust_metal", Color(0.35, 0.35, 0.38), true)
	var brass := PS1Materials.get_material("brass", Color.WHITE, true)
	var size := Vector3(1.0, 1.4, 0.4)
	# A bevelled control cabinet on a plinth, with a slotted faceplate for the lever,
	# rivets, a pressure gauge and conduit into the top.
	var panel := MeshInstance3D.new()
	var parts := [
		[LowPoly.chamfer_box(Vector3(size.x, size.y - 0.1, size.z), 0.05), LowPoly.at(Vector3(0, 0.05, 0))],
		[LowPoly.chamfer_box(Vector3(size.x, 0.1, size.z), 0.02), LowPoly.at(Vector3(0, -size.y / 2.0 + 0.05, 0))],
		[LowPoly.chamfer_box(Vector3(size.x * 0.9, 0.06, size.z * 0.9), 0.02), LowPoly.at(Vector3(0, size.y / 2.0 - 0.03, 0))],
		[LowPoly.prism(6, 0.05, 0.05, 0.2), LowPoly.at(Vector3(-0.3, size.y / 2.0 + 0.0, 0.0))],
	]
	for corner in [Vector2(-0.42, 0.55), Vector2(0.42, 0.55), Vector2(-0.42, -0.5), Vector2(0.42, -0.5)]:
		parts.append([LowPoly.prism(5, 0.02, 0.012, 0.02), LowPoly.at(Vector3(corner.x, corner.y, size.z / 2.0 + 0.005), Vector3(90, 0, 0))])
	panel.mesh = _uv(LowPoly.merge(parts))
	panel.material_override = housing
	panel.position.y = 0.7
	add_child(panel)
	var plate := MeshInstance3D.new()
	plate.mesh = _uv(LowPoly.merge([
		[LowPoly.chamfer_box(Vector3(0.24, 0.62, 0.03), 0.01), Transform3D.IDENTITY],
		[LowPoly.prism(6, 0.09, 0.09, 0.07), LowPoly.at(Vector3(0.3, 0.12, -0.01), Vector3(90, 0, 0))],
	]))
	plate.material_override = dark
	plate.position = Vector3(0, 1.0, 0.21)
	add_child(plate)
	var gauge := MeshInstance3D.new()
	gauge.mesh = _uv(LowPoly.lathe(PackedVector2Array([Vector2(0, -0.02), Vector2(0.075, -0.02), Vector2(0.08, 0.01),
		Vector2(0.065, 0.02), Vector2(0, 0.015)]), 8))
	gauge.material_override = brass
	gauge.position = Vector3(0.3, 1.12, 0.245)
	gauge.rotation.x = PI / 2.0
	add_child(gauge)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = 0.7
	add_child(collider)

	_handle = Node3D.new()
	_handle.position = Vector3(0.0, 1.0, 0.22)
	_handle.rotation.x = deg_to_rad(-40.0)
	add_child(_handle)
	# An axle boss, a hexagonal steel shaft and a lathed red grip.
	var stick := MeshInstance3D.new()
	stick.mesh = _uv(LowPoly.merge([
		[LowPoly.prism(8, 0.06, 0.06, 0.14), LowPoly.at(Vector3(0, -0.27, 0), Vector3(0, 0, 90))],
		[LowPoly.prism(6, 0.03, 0.025, 0.5), Transform3D.IDENTITY],
	]))
	stick.position.y = 0.27
	stick.material_override = PS1Materials.get_material("brass", Color.WHITE, true)
	_handle.add_child(stick)
	var knob := MeshInstance3D.new()
	knob.mesh = _uv(LowPoly.lathe(PackedVector2Array([Vector2(0, -0.07), Vector2(0.04, -0.07), Vector2(0.065, -0.04),
		Vector2(0.075, 0.0), Vector2(0.07, 0.035), Vector2(0.045, 0.065), Vector2(0, 0.075)]), 7))
	knob.position.y = 0.55
	knob.material_override = PS1Materials.get_material("brick", Color(1.0, 0.4, 0.3), true)
	_handle.add_child(knob)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 1.5)


func get_prompt(_player: Player = null) -> String:
	if is_pulled:
		return ""
	return prompt


func interact(_player: Player) -> void:
	if not is_pulled:
		interact_requested.emit()


func play_pull() -> void:
	if is_pulled:
		return
	is_pulled = true
	var tween := create_tween()
	tween.tween_property(_handle, "rotation:x", deg_to_rad(40.0), 0.5)
	Sfx.play_3d(get_parent(), global_position, "clank", 6.0, 80.0, 0.6)
	Sfx.play_3d(get_parent(), global_position, "whistle", 6.0, 120.0, 0.7)
