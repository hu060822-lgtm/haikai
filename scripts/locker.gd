class_name Locker
extends StaticBody3D
## A locked metal cabinet with better loot inside. Needs a crowbar, and prying it
## open is loud.

## The run decides whether it opens (the host owns it), then calls play_open().
signal interact_requested()

const PRY_NOISE := 12.0
const LUCK := 1.5

var is_open := false
var _door: Node3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	var body_material := PS1Materials.get_material("rust_metal", Color(0.6, 0.7, 0.75), true)
	var door_material := PS1Materials.get_material("rust_metal", Color(0.75, 0.8, 0.85), true)
	var dark := PS1Materials.get_material("rust_metal", Color(0.3, 0.33, 0.35), true)
	var size := Vector3(0.9, 1.9, 0.6)
	# The cabinet: a bevelled steel shell with a top lip and little feet.
	var shell := MeshInstance3D.new()
	shell.mesh = _uv(LowPoly.merge([
		[LowPoly.chamfer_box(Vector3(size.x, size.y - 0.08, size.z), 0.035), LowPoly.at(Vector3(0, 0.04, 0))],
		[LowPoly.chamfer_box(Vector3(size.x, 0.05, size.z), 0.02), LowPoly.at(Vector3(0, size.y / 2.0 - 0.025, 0))],
		[LowPoly.prism(4, 0.05, 0.04, 0.08), LowPoly.at(Vector3(0.38, -size.y / 2.0 + 0.04, 0.24), Vector3(0, 45, 0))],
		[LowPoly.prism(4, 0.05, 0.04, 0.08), LowPoly.at(Vector3(-0.38, -size.y / 2.0 + 0.04, 0.24), Vector3(0, 45, 0))],
		[LowPoly.prism(4, 0.05, 0.04, 0.08), LowPoly.at(Vector3(0.38, -size.y / 2.0 + 0.04, -0.24), Vector3(0, 45, 0))],
		[LowPoly.prism(4, 0.05, 0.04, 0.08), LowPoly.at(Vector3(-0.38, -size.y / 2.0 + 0.04, -0.24), Vector3(0, 45, 0))],
	]))
	shell.material_override = body_material
	shell.position.y = 0.95
	add_child(shell)
	# The dark inside, seen when the door swings open.
	var inside := MeshInstance3D.new()
	inside.mesh = LowPoly.chamfer_box(Vector3(size.x - 0.08, size.y - 0.16, 0.02), 0.005)
	inside.material_override = dark
	inside.position = Vector3(0, 0.98, size.z / 2.0 + 0.001)
	add_child(inside)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = 0.95
	add_child(collider)

	# Door hinge on the left edge of the +z face.
	_door = Node3D.new()
	_door.position = Vector3(-0.45, 0.95, 0.31)
	add_child(_door)
	var door_mesh := MeshInstance3D.new()
	var door_parts := [[LowPoly.chamfer_box(Vector3(0.88, 1.85, 0.04), 0.012), Transform3D.IDENTITY]]
	# Louvred vents near the top and bottom, a pressed panel between them.
	for y in [0.62, 0.68, 0.74, -0.66, -0.72]:
		door_parts.append([LowPoly.prism(3, 0.018, 0.018, 0.5), LowPoly.at(Vector3(0, y, 0.02), Vector3(0, 0, 90))])
	door_parts.append([LowPoly.chamfer_box(Vector3(0.62, 0.95, 0.015), 0.006), LowPoly.at(Vector3(-0.02, 0.0, 0.022))])
	# A latch handle by the lock, and three hinge knuckles.
	door_parts.append([LowPoly.chamfer_box(Vector3(0.05, 0.2, 0.03), 0.01), LowPoly.at(Vector3(0.36, 0.12, 0.03))])
	door_parts.append([LowPoly.prism(6, 0.012, 0.012, 0.05), LowPoly.at(Vector3(0.36, 0.17, 0.06), Vector3(90, 0, 0))])
	for y in [-0.7, 0.0, 0.7]:
		door_parts.append([LowPoly.prism(6, 0.018, 0.018, 0.12), LowPoly.at(Vector3(-0.44, y, 0.0))])
	door_mesh.mesh = _uv(LowPoly.merge(door_parts))
	door_mesh.material_override = door_material
	door_mesh.position.x = 0.44
	_door.add_child(door_mesh)
	# The padlock: a squat brass body and its shackle through the hasp.
	var brass := PS1Materials.get_material("brass", Color.WHITE, true)
	var padlock := MeshInstance3D.new()
	padlock.mesh = _uv(LowPoly.chamfer_box(Vector3(0.08, 0.08, 0.04), 0.012))
	padlock.material_override = brass
	padlock.position = Vector3(0.8, -0.01, 0.05)
	padlock.name = "Padlock"
	_door.add_child(padlock)
	var shackle := MeshInstance3D.new()
	shackle.mesh = LowPoly.tube(PackedVector3Array([Vector3(-0.025, 0.035, 0), Vector3(-0.025, 0.07, 0), Vector3(0.0, 0.085, 0),
		Vector3(0.025, 0.07, 0), Vector3(0.025, 0.035, 0)]), PackedFloat32Array([0.007, 0.007, 0.007, 0.007, 0.007]), 4)
	shackle.material_override = PS1Materials.get_material("rust_metal", Color(0.8, 0.8, 0.8), true)
	padlock.add_child(shackle)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 1.0)


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
	if not is_open:
		interact_requested.emit()


func play_open() -> void:
	if is_open:
		return
	is_open = true
	_door.get_node("Padlock").queue_free()
	var tween := create_tween()
	tween.tween_property(_door, "rotation:y", deg_to_rad(-110.0), 0.4)
	Sfx.play_3d(get_parent(), global_position, "clank", 4.0, 45.0, 0.8)
	if multiplayer.is_server():
		GameNoise.emit(get_tree(), global_position, PRY_NOISE, GameNoise.Kind.TOOL)
