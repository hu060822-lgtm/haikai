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

var _player: Player = null
var _elapsed := 0.0
var _done := false
var _light: OmniLight3D


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
