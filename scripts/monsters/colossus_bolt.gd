class_name ColossusBolt
extends StaticBody3D
## The loose bolt on the colossus's hip. Only while it vents (blind, deaf and harmless)
## can a brave scavenger walk up and wrench it out: a legendary prize.

var colossus: BoilerColossus


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


func get_prompt(_player: Player = null) -> String:
	if colossus.bolt_taken:
		return ""
	if colossus.state == BoilerColossus.State.VENT:
		return "[E] 趁它排氣，拔下巨像的螺栓！"
	return "（巨像腰上有一顆鬆掉的螺栓…等它排氣的時候）"


func interact(_player: Player) -> void:
	if colossus.state == BoilerColossus.State.VENT and not colossus.bolt_taken and Run.instance != null:
		Run.instance.request_monster_action(colossus, "bolt")
