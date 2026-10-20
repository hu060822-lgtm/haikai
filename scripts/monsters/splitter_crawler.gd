class_name SplitterCrawler
extends CharacterBody3D
## 分裂幼體: one of the pieces a splitter tears into when it dies: a head and a few arms
## on the floor, dragging itself along faster than you can run. They are born knowing
## where you are and hunt in a pack.
## Weaknesses players can learn:
##   - They starve: a minute after splitting off they curl up and die. Run, hide, wait.
##   - One shot each, and fire twice over.
## Tells: a fast wet patter, and little high squeals.

const RADIUS := 0.25
const SPEED := 6.2
const LIFE := 60.0
const HUNT_RANGE := 40.0
const BITE_RANGE := 0.9
const BITE_DAMAGE := 8.0
const BITE_INTERVAL := 0.7
const POUNCE_TIME := 0.8

## Replicated: whether it is withering (the last few seconds of its life).
var withering := false
var patrol_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _agent: NavigationAgent3D
var _model: Node3D
var _arms: Array[Node3D] = []
var _life := LIFE
var _bite := 0.0
var _hesitate := 0.4
var _patter := 0.0


func _ready() -> void:
	add_to_group("monsters")
	collision_layer = Layers.MONSTER
	collision_mask = Layers.WORLD
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	collider.shape = sphere
	collider.position.y = RADIUS
	add_child(collider)
	_agent = NavigationAgent3D.new()
	_agent.radius = RADIUS
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 0.4
	add_child(_agent)
	_life = LIFE + rng.randf_range(-5.0, 5.0)
	_build_model()
	MonsterKit.add_sync(self, [".:position", ".:rotation", ".:withering"])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	if multiplayer.is_server():
		_think(delta)
	_animate(delta)


func host_kill() -> void:
	if is_queued_for_deletion():
		return
	_squeal.rpc(global_position, 0.8)
	queue_free()


func _think(delta: float) -> void:
	_life -= delta
	_bite = maxf(_bite - delta, 0.0)
	_hesitate -= delta
	withering = _life < 6.0
	if _life <= 0.0:
		host_kill()
		return
	var target := MonsterKit.nearest_player(self, HUNT_RANGE)
	if target == null or _hesitate > 0.0 or withering:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		move_and_slide()
		return
	_agent.target_position = target.global_position
	var next := global_position
	if _nav_ready() and not _agent.is_navigation_finished():
		next = _agent.get_next_path_position()
	if global_position.distance_to(target.global_position) < 2.5:
		next = target.global_position
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
	var offset := target.global_position - global_position
	if _bite <= 0.0 and Vector2(offset.x, offset.z).length() < BITE_RANGE + Player.RADIUS and absf(offset.y) < 1.0:
		_bite = BITE_INTERVAL
		MonsterKit.tell(target, &"remote_damage", [BITE_DAMAGE, "被分裂幼體啃食殆盡"])
		_squeal.rpc(global_position, 1.8)


@rpc("authority", "call_local", "reliable")
func _squeal(at: Vector3, pitch: float) -> void:
	Sfx.play_3d(get_parent(), at, "screech", -8.0, 18.0, pitch * 1.6)


func _nav_ready() -> bool:
	return NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0


func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var speed := Vector2(velocity.x, velocity.z).length()
	for i in _arms.size():
		_arms[i].rotation.x = sin(t * 22.0 + i * PI * 0.5) * (0.7 if speed > 0.5 else 0.1)
	_model.scale = Vector3.ONE * (0.75 if withering else 1.0)
	if speed > 0.5:
		_patter -= delta
		if _patter <= 0.0:
			_patter = 0.14
			Sfx.play_3d(get_parent(), global_position, "step", -16.0, 12.0, rng.randf_range(1.8, 2.3))


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var flesh := PS1Materials.get_material("concrete", Color(0.6, 0.5, 0.48), true)
	var pale := PS1Materials.get_material("concrete", Color(0.75, 0.68, 0.62), true)
	var black := PS1Materials.get_material("concrete", Color(0.03, 0.02, 0.02), true)
	var seam := PS1Materials.get_material("concrete", Color(0.6, 0.12, 0.08), true, Vector2.ONE, Color(0.6, 0.06, 0.03))
	# A lump of torn body with a raw red underside and a head out front.
	MonsterKit.part(_model, _uv(LowPoly.blob(0.2, Vector3(1.0, 0.7, 1.3), 1, 0.2, rng.randi() % 50)), Vector3(0, 0.2, 0.05), flesh)
	MonsterKit.part(_model, LowPoly.blob(0.17, Vector3(1.0, 0.4, 1.2), 0), Vector3(0, 0.12, 0.05), seam)
	MonsterKit.part(_model, _uv(LowPoly.blob(0.12, Vector3(0.9, 1.0, 1.0), 1, 0.06, 3)), Vector3(0, 0.25, -0.22), pale)
	MonsterKit.part(_model, LowPoly.blob(0.05, Vector3(1.0, 1.3, 0.4), 0), Vector3(0, 0.2, -0.33), black)
	for side: float in [-1.0, 1.0]:
		MonsterKit.part(_model, LowPoly.chamfer_box(Vector3(0.05, 0.012, 0.012), 0.003), Vector3(0.045 * side, 0.28, -0.33), black)
	# Arms it drags itself along with.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var front := -1.0 if i < 2 else 1.0
		var arm := Node3D.new()
		arm.position = Vector3(0.15 * side, 0.22, 0.12 * front)
		_model.add_child(arm)
		var hand := Vector3(0.28 * side, -0.2, 0.1 * front - 0.05)
		MonsterKit.part(arm, _uv(LowPoly.tube(PackedVector3Array([Vector3.ZERO, Vector3(0.2 * side, 0.05, 0.05 * front), hand]),
			PackedFloat32Array([0.04, 0.03, 0.02]), 4)), Vector3.ZERO, flesh)
		_arms.append(arm)


static func _uv(mesh: Mesh) -> Mesh:
	return LootShapes.with_uvs(mesh, 4.0)
