class_name TimeWarp
extends Node
## Host-side: stuns and slows monsters without each monster knowing about it.
## A stunned monster simply stops thinking; a slowed one thinks every other frame,
## so its movement, timers and attacks all run at half speed.
## Weapons and items call TimeWarp.stun()/slow(); Run owns the single instance.

static var instance: TimeWarp

var _stun := {}   # monster -> seconds left
var _slow := {}   # monster -> seconds left
var _frame := 0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


static func stun(monster: Node, seconds: float) -> void:
	if instance != null and is_instance_valid(monster):
		instance._stun[monster] = maxf(instance._stun.get(monster, 0.0), seconds)


static func slow(monster: Node, seconds: float) -> void:
	if instance != null and is_instance_valid(monster):
		instance._slow[monster] = maxf(instance._slow.get(monster, 0.0), seconds)


static func is_stunned(monster: Node) -> bool:
	return instance != null and instance._stun.get(monster, 0.0) > 0.0


func _physics_process(delta: float) -> void:
	_frame += 1
	var touched := {}
	for monster in _stun.keys() + _slow.keys():
		touched[monster] = true
	for monster in touched:
		if not is_instance_valid(monster):
			_stun.erase(monster)
			_slow.erase(monster)
			continue
		var stun_left: float = _stun.get(monster, 0.0) - delta
		var slow_left: float = _slow.get(monster, 0.0) - delta
		var run := true
		if stun_left > 0.0:
			run = false
			_stun[monster] = stun_left
		else:
			_stun.erase(monster)
		if slow_left > 0.0:
			_slow[monster] = slow_left
			if run:
				run = _frame % 2 == 0
		else:
			_slow.erase(monster)
		monster.set_physics_process(run)
		monster.set_process(run)
