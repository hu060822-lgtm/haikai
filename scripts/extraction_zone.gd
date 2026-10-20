class_name ExtractionZone
extends Area3D
## Stand inside for hold_time seconds to extract. Leaving resets the countdown.
## Every player extracts on their own; the others can keep looting.
## Does nothing until powered (the boiler lever).

signal progress_changed(ratio: float)
signal extracted(player: Player)
signal blocked()

@export var hold_time := 4.0
@export var size := Vector3(2.6, 2.5, 2.6)

var powered := false:
	set(value):
		powered = value
		if _light != null:
			_light.light_color = Color(0.5, 1.0, 0.6) if value else Color(1.0, 0.25, 0.2)
		if _marks != null:
			var glow := Color(0.2, 0.6, 0.3) if value else Color(0.5, 0.1, 0.08)
			_marks.material_override = PS1Materials.get_material("concrete", glow * 1.4, true, Vector2.ONE, glow * 0.6)

var _player: Player = null
var _elapsed := 0.0
var _done := false
var _light: OmniLight3D
var _marks: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)
	_light = OmniLight3D.new()
	_light.position.y = 1.3
	_light.light_energy = 1.0
	_light.omni_range = 6.0
	add_child(_light)
	# Painted corner brackets and arrow chevrons on the floor mark out the pad; they take
	# the light's colour (red until powered, then green). Visual only.
	_marks = MeshInstance3D.new()
	_marks.mesh = _marks_mesh(size)
	_marks.position.y = -size.y / 2.0 + 0.012
	add_child(_marks)
	powered = powered
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _player != null and powered and not _player.is_dead:
		_elapsed += delta
		progress_changed.emit(minf(_elapsed / hold_time, 1.0))
		if _elapsed >= hold_time:
			_done = true
			extracted.emit(_player)
	elif _elapsed > 0.0:
		_elapsed = 0.0
		progress_changed.emit(0.0)


func _on_body_entered(body: Node3D) -> void:
	# Each machine only extracts its own player.
	if body is Player and body.is_multiplayer_authority():
		_player = body
		if not powered:
			blocked.emit()


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null


static func _marks_mesh(box: Vector3) -> Mesh:
	var half := Vector2(box.x, box.z) / 2.0 - Vector2(0.08, 0.08)
	var arm := minf(half.x, half.y) * 0.45
	var w := 0.08
	var bracket := PackedVector2Array([Vector2(0, 0), Vector2(arm, 0), Vector2(arm, w), Vector2(w, w), Vector2(w, arm), Vector2(0, arm)])
	var chevron := PackedVector2Array([Vector2(-0.22, 0.0), Vector2(0.0, 0.16), Vector2(0.22, 0.0), Vector2(0.22, 0.09),
		Vector2(0.0, 0.25), Vector2(-0.22, 0.09)])
	var parts := []
	var yaws := [0.0, -90.0, 180.0, 90.0]
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in 4:
		var corner: Vector2 = corners[c]
		var yaw: float = yaws[c]
		parts.append([LowPoly.extrude(bracket, 0.012), LowPoly.at(Vector3(corner.x * half.x, 0, corner.y * half.y), Vector3(90, yaw, 0))])
	for i in 2:
		parts.append([LowPoly.extrude(chevron, 0.012), LowPoly.at(Vector3(0, 0, -0.1 + i * 0.32), Vector3(90, 0, 0))])
	return LowPoly.merge(parts)
