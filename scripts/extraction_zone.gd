class_name ExtractionZone
extends Area3D
## Stand inside for hold_time seconds to extract. Leaving resets the countdown.

signal progress_changed(ratio: float)
signal extracted(player: Player)

@export var hold_time := 4.0
@export var size := Vector3(2.6, 2.5, 2.6)

var _player: Player = null
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	add_child(collider)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _player != null:
		_elapsed += delta
		progress_changed.emit(minf(_elapsed / hold_time, 1.0))
		if _elapsed >= hold_time:
			_done = true
			extracted.emit(_player)
	elif _elapsed > 0.0:
		_elapsed = 0.0
		progress_changed.emit(0.0)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player = null
