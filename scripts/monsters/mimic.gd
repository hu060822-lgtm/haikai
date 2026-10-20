class_name Mimic
extends CharacterBody3D
## 擬態蟲: a bug that passes itself off as loot. Dominates by INTELLIGENCE: it looks and
## reads exactly like a real item. Pick it up and it bites your hand, so you can't use
## weapons or gear for a while; then it scuttles off to disguise itself somewhere else.
## Tells: it ticks softly and twitches now and then.
## Weakness players can learn: poke it with a weapon (crowbar or marble) and it dies.

const BITE_SECONDS := 8.0
const BITE_DAMAGE := 15.0
const FLEE_SPEED := 4.0
const FLEE_TIME := 2.5
const HIDE_TIME := 25.0

## Replicated: the item it pretends to be, and whether it's currently pretending.
var disguise: Dictionary = {}:
	set(value):
		disguise = value
		if is_node_ready():
			_rebuild_disguise()
var disguised := true:
	set(value):
		disguised = value
		if is_node_ready():
			_apply_disguised()
var hidden := false:
	set(value):
		hidden = value
		visible = not value
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _item_mesh: MeshInstance3D
var _bug: Node3D
var _collider: CollisionShape3D
var _flee_from := Vector3.ZERO
var _timer := 0.0
var _tick_timer := 2.0


func _ready() -> void:
	add_to_group("monsters")
	collision_mask = Layers.WORLD | Layers.WALKWAY
	_collider = CollisionShape3D.new()
	_collider.shape = BoxShape3D.new()
	add_child(_collider)
	_item_mesh = MeshInstance3D.new()
	add_child(_item_mesh)
	_build_bug()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:disguise", ".:disguised", ".:hidden"])
	_rebuild_disguise()
	_apply_disguised()
	visible = not hidden


func _physics_process(delta: float) -> void:
	if not hidden:
		_tells(delta)
	if not multiplayer.is_server():
		return
	if disguised:
		return
	_timer -= delta
	if not hidden:
		# Scuttle away from whoever found it.
		if not is_on_floor():
			velocity.y -= _gravity * delta
		var away := global_position - _flee_from
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
		velocity.x = away.x * FLEE_SPEED
		velocity.z = away.z * FLEE_SPEED
		rotation.y = atan2(-away.x, -away.z)
		move_and_slide()
		if _timer <= 0.0:
			hidden = true
			_timer = HIDE_TIME
	elif _timer <= 0.0:
		_redisguise()


func get_prompt(_player: Player = null) -> String:
	return LootTable.prompt(disguise)


func interact(_player: Player) -> void:
	if disguised and Run.instance != null:
		Run.instance.request_monster_action(self, "bite")


## Crowbar: the player swings at what they're looking at.
func pry(_player: Player) -> void:
	weapon_hit()


## Crowbar or slingshot marble.
func weapon_hit() -> void:
	if Run.instance != null and not hidden:
		Run.instance.request_monster_action(self, "kill")


## Host: a player did something to it.
func host_action(action: String, player: Player) -> void:
	match action:
		"bite":
			if not disguised or player == null:
				return
			MonsterKit.tell(player, &"remote_bitten", [BITE_SECONDS, BITE_DAMAGE])
			_flee_from = player.global_position
			disguised = false
			_timer = FLEE_TIME
			_play.rpc("bite")
		"kill":
			_play.rpc("screech")
			queue_free()


@rpc("authority", "call_local", "reliable")
func _play(sound: String) -> void:
	var pitch := 2.2 if sound == "screech" else 1.0
	Sfx.play_3d(get_parent(), global_position, sound, -2.0, 25.0, pitch)


func _redisguise() -> void:
	var run := Run.instance
	if run == null:
		return
	var spots: Array = run.level.roll_loot()
	var spot: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
	global_position = spot.pos
	rotation = Vector3(0, spot.rot, 0)
	velocity = Vector3.ZERO
	disguise = LootTable.roll(rng, 0.8)
	disguised = true
	hidden = false


func _tells(delta: float) -> void:
	if not disguised:
		_bug.position.y = 0.04 + absf(sin(Time.get_ticks_msec() * 0.03)) * 0.03
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = rng.randf_range(2.5, 5.0)
		Sfx.play_3d(get_parent(), global_position, "tick", -16.0, 7.0, rng.randf_range(0.9, 1.1))
		# A little twitch, like something breathing inside.
		var tween := create_tween()
		tween.tween_property(_item_mesh, "rotation:z", 0.08, 0.05)
		tween.tween_property(_item_mesh, "rotation:z", 0.0, 0.1)


func _rebuild_disguise() -> void:
	if disguise.is_empty():
		return
	var size: Vector3 = disguise.size
	var mesh := LootShapes.mesh_for(disguise)
	_item_mesh.mesh = mesh
	_item_mesh.material_override = PS1Materials.get_material(disguise.texture, disguise.color, true)
	_item_mesh.position.y = 0.0
	(_collider.shape as BoxShape3D).size = size
	# Real loot this valuable glints; so does the fake.
	for child in _item_mesh.get_children():
		child.queue_free()
	if disguise.rarity >= 2:
		var glint := OmniLight3D.new()
		glint.light_color = LootTable.RARITY_COLORS[disguise.rarity]
		glint.light_energy = 0.4
		glint.omni_range = 1.2
		_item_mesh.add_child(glint)


func _apply_disguised() -> void:
	_item_mesh.visible = disguised
	_bug.visible = not disguised
	# Only a disguised mimic can be looked at and "picked up".
	collision_layer = Layers.LOOT if disguised else 0


func _build_bug() -> void:
	_bug = Node3D.new()
	add_child(_bug)
	var shell := PS1Materials.get_material("rust_metal", Color(0.75, 0.95, 0.55), true)
	var leg := PS1Materials.get_material("concrete", Color(0.35, 0.3, 0.25), true)
	MonsterKit.sphere(_bug, 0.2, Vector3(0, 0.08, 0), shell, Vector3(1.0, 0.5, 1.4))
	MonsterKit.sphere(_bug, 0.08, Vector3(0, 0.09, -0.3), leg)
	for i in 3:
		for side in [-1.0, 1.0]:
			var leg_part := MonsterKit.box(_bug, Vector3(0.26, 0.025, 0.025), Vector3(0.17 * side, 0.03, -0.12 + i * 0.12), leg)
			leg_part.rotation.y = 0.4 * side * (i - 1)
	# Beady eyes that catch the lantern light.
	var eyes := OmniLight3D.new()
	eyes.light_color = Color(0.7, 1.0, 0.4)
	eyes.light_energy = 0.3
	eyes.omni_range = 0.7
	eyes.position = Vector3(0, 0.15, -0.35)
	_bug.add_child(eyes)
