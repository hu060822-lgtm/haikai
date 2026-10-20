class_name ColossusBolt
extends StaticBody3D
## The loose bolt on the colossus's hip. Only while it vents (blind, deaf and harmless)
## can a brave scavenger walk up and wrench it out: a legendary prize.

var colossus: BoilerColossus

var _visual: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.LOOT
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = BoilerColossus.RADIUS + 0.2
	shape.height = 1.6
	collider.shape = shape
	collider.position.y = 1.2
	add_child(collider)
	# The bolt itself, visual only: a big hex head and washer sticking out of the front
	# of the pelvis gearbox, a little crooked. Gone once someone wrenches it out.
	_visual = MeshInstance3D.new()
	_visual.mesh = LootShapes.with_uvs(LowPoly.merge([
		[LowPoly.prism(8, 0.12, 0.12, 0.03), LowPoly.at(Vector3(0, 0.015, 0))],
		[LowPoly.prism(6, 0.09, 0.09, 0.09), LowPoly.at(Vector3(0, 0.075, 0), Vector3(0, 15, 0))],
		[LowPoly.prism(6, 0.075, 0.06, 0.02), LowPoly.at(Vector3(0, 0.13, 0), Vector3(0, 15, 0))],
		[LowPoly.prism(6, 0.035, 0.035, 0.12), LowPoly.at(Vector3(0, -0.05, 0))],
	]), 4.0)
	_visual.material_override = PS1Materials.get_material("rust_metal", Color(0.8, 0.8, 0.85), true)
	_visual.position = Vector3(0.42, 1.72, -0.47)
	_visual.rotation_degrees = Vector3(-80, 0, 12)
	add_child(_visual)


func _process(_delta: float) -> void:
	if _visual != null:
		_visual.visible = colossus == null or not colossus.bolt_taken


func get_prompt(_player: Player = null) -> String:
	if colossus.bolt_taken:
		return ""
	if colossus.state == BoilerColossus.State.VENT:
		return "[E] 趁它排氣，拔下巨像的螺栓！"
	return "（巨像腰上有一顆鬆掉的螺栓…等它排氣的時候）"


func interact(_player: Player) -> void:
	if colossus.state == BoilerColossus.State.VENT and not colossus.bolt_taken and Run.instance != null:
		Run.instance.request_monster_action(colossus, "bolt")
