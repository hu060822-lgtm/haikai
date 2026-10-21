class_name Mimic
extends CharacterBody3D
## 擬態蟲: a bug that passes itself off as loot. Dominates by INTELLIGENCE: it looks and
## reads exactly like a real item. Pick it up and it bites your hand, so you can't use
## weapons or gear for a while; then it scuttles off to disguise itself somewhere else.
## Tells: it ticks softly and twitches now and then.
## Weakness players can learn: poke it with a weapon (crowbar or marble) and it dies.
## How you kill it is your choice: a knife or bayonet kills it quietly, but shoot a mimic
## and it dies SHRIEKING, and everything nearby hears where you are.

const BITE_SECONDS := 8.0
const BITE_DAMAGE := 15.0
const FLEE_SPEED := 4.0
const FLEE_TIME := 2.5
const HIDE_TIME := 25.0
const SHRIEK_RADIUS := 22.0

## Replicated: the item it pretends to be, and whether it's currently pretending.
## The last hit was a blade (or a poke): it dies without its shriek.
var _quiet_death := false
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
	_quiet_death = true  # a poke, not a gunshot
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
			host_kill()


## Host: a weapon hit it. If it somehow lives, it drops the act and scuttles off.
func on_hit(hit: Dictionary) -> float:
	if hidden:
		return 0.0
	var effects: Dictionary = hit.get("effects", {})
	_quiet_death = effects.has("melee") or effects.has("bayonet")
	if disguised:
		_flee_from = hit.get("from", global_position)
		disguised = false
		_timer = FLEE_TIME
	return 1.0


## Host: it dies with a shriek that carries, unless a blade got it first (a wet crunch).
func host_kill() -> void:
	if is_queued_for_deletion():
		return
	if _quiet_death:
		_play.rpc("bite")
	else:
		_play.rpc("screech")
		GameNoise.emit_local(get_tree(), global_position, SHRIEK_RADIUS, GameNoise.Kind.VOICE)
	queue_free()


@rpc("authority", "call_local", "reliable")
func _play(sound: String) -> void:
	var shriek := sound == "screech"
	Sfx.play_3d(get_parent(), global_position, sound, 4.0 if shriek else -2.0, 45.0 if shriek else 25.0, 2.2 if shriek else 1.0)


func _redisguise() -> void:
	var run := Run.instance
	if run == null:
		return
	var spots: Array = run.level.roll_loot()
	var spot: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
	global_position = spot.pos
	rotation = Vector3(0, spot.rot, 0)
	velocity = Vector3.ZERO
	disguise = LootTable.roll(rng, 0.8, Run.instance.level.loot_pool if Run.instance != null else [])
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
	var belly := PS1Materials.get_material("concrete", Color(0.5, 0.55, 0.35), true)
	var eye := PS1Materials.get_material("concrete", Color(0.2, 0.3, 0.05), true, Vector2.ONE, Color(0.35, 0.6, 0.1))
	# A domed, faceted carapace split down the middle into two wing cases, over a flat belly.
	var dome := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.21, 0.03), Vector2(0.18, 0.09),
		Vector2(0.12, 0.15), Vector2(0.0, 0.17)])
	for side in [-1.0, 1.0]:
		MonsterKit.part(_bug, _uv(LowPoly.lathe(dome, 8)), Vector3(0.095 * side, 0.03, 0.02), shell, Vector3(0, 22.5, 0), Vector3(0.52, 0.8, 1.4))
	MonsterKit.part(_bug, _uv(LowPoly.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.18, 0), Vector2(0.19, 0.04), Vector2(0, 0.05)]), 8)),
		Vector3(0, 0.0, 0.0), belly, Vector3(0, 22.5, 0), Vector3(1.0, 1.0, 1.35))
	# Head with a pair of hooked mandibles and long feelers.
	MonsterKit.part(_bug, _uv(LowPoly.blob(0.08, Vector3(1.1, 0.8, 1.0), 1, 0.08, 7)), Vector3(0, 0.09, -0.3), leg)
	for side in [-1.0, 1.0]:
		MonsterKit.part(_bug, LowPoly.blob(0.026, Vector3.ONE, 0), Vector3(0.05 * side, 0.12, -0.35), eye)
		var mandible := PackedVector3Array([Vector3(0.04 * side, 0.06, -0.36), Vector3(0.05 * side, 0.05, -0.42), Vector3(0.0, 0.04, -0.45)])
		MonsterKit.part(_bug, LowPoly.tube(mandible, PackedFloat32Array([0.018, 0.012, 0.0]), 4), Vector3.ZERO, leg)
		var feeler := PackedVector3Array([Vector3(0.03 * side, 0.14, -0.35), Vector3(0.1 * side, 0.22, -0.45), Vector3(0.2 * side, 0.2, -0.55)])
		MonsterKit.part(_bug, LowPoly.tube(feeler, PackedFloat32Array([0.008, 0.005, 0.0]), 3), Vector3.ZERO, leg)
	# Three pairs of jointed legs: up to a knee, then down to a pointed foot.
	for i in 3:
		for side in [-1.0, 1.0]:
			var z := -0.12 + i * 0.12
			var splay := 0.4 * (i - 1)
			var path := PackedVector3Array([Vector3(0.14 * side, 0.05, z), Vector3(0.27 * side, 0.12, z + splay * 0.12),
				Vector3(0.36 * side, -0.02, z + splay * 0.25)])
			MonsterKit.part(_bug, LowPoly.tube(path, PackedFloat32Array([0.018, 0.014, 0.0]), 4), Vector3.ZERO, leg)
	# Beady eyes that catch the lantern light.
	var eyes := OmniLight3D.new()
	eyes.light_color = Color(0.7, 1.0, 0.4)
	eyes.light_energy = 0.3
	eyes.omni_range = 0.7
	eyes.position = Vector3(0, 0.15, -0.35)
	_bug.add_child(eyes)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 5.0)
