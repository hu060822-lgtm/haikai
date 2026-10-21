class_name TimeWarp
extends Node
## Host-side: stuns and slows monsters without each monster knowing about it.
## A stunned monster simply stops thinking; a slowed one thinks every other frame,
## so its movement, timers and attacks all run at half speed.
## Weapons and items call TimeWarp.stun()/slow(); Run owns the single instance.
## The awakening speeds them up the same way: at speed_mult() 1.2 every monster gets one
## extra think every fifth frame (movement, timers, attacks, all of it).

static var instance: TimeWarp

var _stun := {}   # monster -> seconds left
var _slow := {}   # monster -> seconds left
var _frame := 0
var _boost := 0.0
## script -> [has _physics_process, has _process]
var _ticks := {}


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
	_awake_boost(delta)
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


## Host: the awakening's speed-up. Stunned or slowed monsters don't get the extra thinks.
func _awake_boost(delta: float) -> void:
	var mult := Awakening.speed_mult()
	if mult <= 1.0 or not multiplayer.is_server() or Run.instance == null:
		_boost = 0.0
		return
	_boost += mult - 1.0
	if _boost < 1.0:
		return
	_boost -= 1.0
	for monster in Run.instance.live_monsters():
		if not is_instance_valid(monster) or not monster.is_inside_tree() or not monster.can_process() \
				or not monster.is_physics_processing() or _slow.has(monster):
			continue
		var has := _tick_methods(monster)
		if has[0]:
			monster._physics_process(delta)
		if has[1] and monster.is_processing():
			monster._process(delta)


func _tick_methods(monster: Node) -> Array:
	var script: Script = monster.get_script()
	if script == null:
		return [false, false]
	if not _ticks.has(script):
		var names := {}
		for method in script.get_script_method_list():
			names[method.name] = true
		_ticks[script] = [names.has("_physics_process"), names.has("_process")]
	return _ticks[script]
