class_name Run
extends Node3D
## One run on a randomly drawn map, shared by every peer. Lives at the same node path on
## all machines (Main/RunView/Viewport/World) so its RPCs and spawners line up.
## The host owns loot, monsters, the lever and lockers; clients ask it for changes.

signal local_player_spawned(player: Player)
signal local_finished(result: Dictionary)
signal colossus_spawned(colossus: BoilerColossus)
## Guardian's machine only: live energy, cooldowns and loot extracted so far.
signal guardian_state(energy: float, cooldowns: Dictionary, extracted: int)
signal guardian_ping(position: Vector3, radius: float)
signal power_changed(on: bool)

const MATCH_TIME := 720.0
const BODY_SCATTER := 0.6

static var instance: Run
## Tests pin the monster kinds; empty means a random draw (see MonsterRoster).
static var forced_monsters: Array = []
## Tests switch the AI director off so it doesn't meddle.
static var director_enabled := true
## Tests pin the map; empty means a random draw (see MapRoster).
static var forced_map := ""

var seed := 0
var roster := {}
var loadout := {}
var level: GameMap
var map_id := ""
var local_player: Player
var colossus: BoilerColossus
var monster_kinds: Array[String] = []
var field: FieldControl
var warp: TimeWarp
var director: Director
var is_guardian := false
var time_left := MATCH_TIME
var finished := false
var rng := RandomNumberGenerator.new()

var players_root: Node3D
var monsters_root: Node3D
var loot_root: Node3D
var _player_spawner: MultiplayerSpawner
var _monster_spawner: MultiplayerSpawner
var _loot_spawner: MultiplayerSpawner
var _loot_counter := 0
var _monster_serial := 0
var _time_broadcast := 0.0
var _guardian_broadcast := 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	rng.seed = seed
	map_id = forced_map if forced_map != "" else MapRoster.pick(seed)
	level = MapRoster.create(map_id)
	level.name = "Level"
	level.rng.seed = seed
	level.build_navigation = _is_host()
	add_child(level)
	level.lever.interact_requested.connect(func() -> void: _to_host(&"_pull_lever"))
	for i in level.lockers.size():
		var index := i
		level.lockers[i].interact_requested.connect(func() -> void: _to_host(&"_pry_locker", [index]))

	warp = TimeWarp.new()
	warp.name = "Warp"
	add_child(warp)

	field = FieldControl.new()
	field.name = "Field"
	field.run = self
	add_child(field)
	is_guardian = roster.get(multiplayer.get_unique_id(), {}).get("role", "") == "guardian"

	players_root = _root("Players")
	monsters_root = _root("Monsters")
	loot_root = _root("Loot")
	_player_spawner = _spawner(players_root, _spawn_player)
	_monster_spawner = _spawner(monsters_root, _spawn_monster)
	_loot_spawner = _spawner(loot_root, _spawn_loot)

	var session := Session.instance
	if _is_host():
		session.world_ready_all.connect(_host_populate, CONNECT_ONE_SHOT)
		field.pinged.connect(func(pos: Vector3, radius: float) -> void:
			var guardian := Session.instance.guardian_id()
			if guardian != 0:
				_send_to(guardian, &"_guardian_ping", [pos, radius]))
		multiplayer.peer_disconnected.connect(func(id: int) -> void:
			var gone := players_root.get_node_or_null(str(id))
			if gone != null:
				gone.queue_free())
		session.noise_received.connect(func(pos: Vector3, radius: float, kind: int) -> void:
			GameNoise.emit_local(get_tree(), pos, radius, kind))
	else:
		session.time_synced.connect(func(seconds: float) -> void: time_left = seconds)
	session.report_world_ready.call_deferred()


func _process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and local_player != null and local_player.is_active():
		local_player.die(level.timeout_cause)
	if _is_host():
		_time_broadcast -= delta
		if _time_broadcast <= 0.0:
			_time_broadcast = 1.0
			Session.instance.broadcast_time(time_left)
		_guardian_broadcast -= delta
		var guardian := Session.instance.guardian_id()
		if guardian != 0 and _guardian_broadcast <= 0.0:
			_guardian_broadcast = 0.25
			_send_to(guardian, &"_guardian_state", [field.energy, field.cooldowns, Session.instance.extracted_total])


func all_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in players_root.get_children():
		if node is Player:
			result.append(node)
	return result


# --- Host: populate the world once every peer has built it ---------------------------

func _host_populate() -> void:
	var index := 0
	for id in Session.instance.scavenger_ids():
		_player_spawner.spawn({"id": id, "name": roster[id].name, "index": index})
		index += 1
	if Session.instance.guardian_id() == 0 and director_enabled:
		director = Director.new()
		director.name = "Director"
		director.field = field
		director.run = self
		director.rng.seed = rng.randi()
		add_child(director)
	level.loot_pool = LootTable.make_pool(rng)
	var loot := level.roll_loot()
	for entry in loot:
		host_spawn_loot(entry.item, entry.pos, entry.rot, true)
	_host_spawn_monsters()


func _host_spawn_monsters() -> void:
	monster_kinds.clear()
	if forced_monsters.is_empty():
		monster_kinds = MonsterRoster.pick(rng)
	else:
		monster_kinds.assign(forced_monsters)
	var spots := level.roll_loot()
	for kind in monster_kinds:
		var count_range: Array = MonsterRoster.MONSTERS[kind].count
		for i in rng.randi_range(count_range[0], count_range[1]):
			_monster_serial += 1
			var serial := _monster_serial
			var data := {"type": kind, "name": "%s%d" % [kind.capitalize(), serial], "seed": rng.randi()}
			match kind:
				"colossus":
					data.name = "Colossus"
					data.pos = level.monster_spawn
				"mannequin":
					data.pos = _far_patrol_point()
				"moth":
					data.pos = level.random_patrol_point() + Vector3(0, 3.0, 0)
				"watcher":
					data.pos = _far_patrol_point()
				"centipede", "mother":
					data.pos = _far_patrol_point()
				"greeter", "collector", "rats", "fog_walker", "tuner", "child":
					data.pos = level.random_patrol_point() + Vector3.UP * 0.1
				"mimic":
					var spot: Dictionary = spots[serial % spots.size()]
					data.pos = spot.pos
					data.rot = spot.rot
					data.disguise = LootTable.roll(rng, 0.8, level.loot_pool)
			_monster_spawner.spawn(data)


## Field control (host): the guardian or director closed a gate, cut power, released a monster.
func host_set_gate(index: int, closed: bool) -> void:
	_gate_set.rpc(index, closed)


@rpc("authority", "call_local", "reliable")
func _gate_set(index: int, closed: bool) -> void:
	if index >= 0 and index < level.gates.size():
		level.gates[index].set_closed(closed)


func host_set_power(on: bool) -> void:
	_power_set.rpc(on)


@rpc("authority", "call_local", "reliable")
func _power_set(on: bool) -> void:
	level.set_power(on)
	power_changed.emit(on)


func host_release_monster(kind: String, pos: Vector3) -> void:
	_monster_serial += 1
	var data := {"type": kind, "name": "%s%d" % [kind.capitalize(), _monster_serial], "seed": rng.randi(), "pos": pos}
	match kind:
		"moth":
			data.pos = pos + Vector3.UP * 1.5
		"mimic":
			data.rot = rng.randf_range(0.0, TAU)
			data.disguise = LootTable.roll(rng, 0.8, level.loot_pool)
	_monster_spawner.spawn(data)
	_monster_released.rpc(pos)


@rpc("authority", "call_local", "reliable")
func _monster_released(pos: Vector3) -> void:
	Sfx.play_3d(self, pos, "hiss", -2.0, 25.0, 0.7)


## Guardian's machine: ask the host to use a power. args: gate index, or [kind, position].
func request_ability(ability: String, args := []) -> void:
	_to_host(&"_ability", [ability, args])


@rpc("any_peer", "call_local", "reliable")
func _ability(ability: String, args: Array) -> void:
	if not _is_host() or _sender() != Session.instance.guardian_id():
		return
	match ability:
		"gate":
			if args.size() == 1:
				field.use_gate(int(args[0]))
		"power":
			field.use_power()
		"monster":
			if args.size() == 2:
				field.use_monster(str(args[0]), args[1])


@rpc("authority", "call_local", "unreliable_ordered")
func _guardian_state(energy: float, cooldowns: Dictionary, extracted: int) -> void:
	guardian_state.emit(energy, cooldowns, extracted)


@rpc("authority", "call_local", "unreliable")
func _guardian_ping(pos: Vector3, radius: float) -> void:
	guardian_ping.emit(pos, radius)


## The patrol point farthest from where players start.
func _far_patrol_point() -> Vector3:
	var best: Vector3 = level.patrol_points[0]
	for point in level.patrol_points:
		if point.distance_to(level.player_spawn) > best.distance_to(level.player_spawn):
			best = point
	return best + Vector3.UP * 0.1


func host_spawn_loot(item: Dictionary, pos: Vector3, rot := 0.0, frozen := true, velocity := Vector3.ZERO) -> LootItem:
	_loot_counter += 1
	var node: LootItem = _loot_spawner.spawn({
		"name": "L%d" % _loot_counter, "item": item, "pos": pos, "rot": rot, "frozen": frozen,
	})
	if velocity != Vector3.ZERO:
		node.linear_velocity = velocity
	return node


# --- Spawn functions (run on every peer) ---------------------------------------------

func _spawn_player(data: Dictionary) -> Node:
	var player := Player.new()
	player.name = str(data.id)
	player.display_name = data.name
	player.set_multiplayer_authority(data.id)
	player.build_sync()
	var offset := Vector3((data.index % 2) * 1.2 - 0.6, 0.0, (data.index / 2) * 1.2)
	player.position = level.player_spawn + offset
	player.rotation.y = level.player_spawn_yaw
	if data.id == multiplayer.get_unique_id():
		local_player = player
		player.ready.connect(func() -> void:
			player.equip(loadout)
			player.died.connect(_on_local_died)
			local_player_spawned.emit(player), CONNECT_ONE_SHOT)
	return player


func _spawn_monster(data: Dictionary) -> Node:
	var monster: Node3D
	match data.type:
		"mannequin":
			var mannequin := Mannequin.new()
			mannequin.patrol_points.assign(level.patrol_points)
			mannequin.rng.seed = data.seed
			monster = mannequin
		"moth":
			var moth := Moth.new()
			moth.home = data.pos
			moth.rng.seed = data.seed
			monster = moth
		"mimic":
			var mimic := Mimic.new()
			mimic.disguise = data.disguise
			mimic.rotation.y = data.rot
			mimic.rng.seed = data.seed
			monster = mimic
		"watcher":
			var watcher := Watcher.new()
			watcher.patrol_points.assign(level.patrol_points)
			watcher.rng.seed = data.seed
			monster = watcher
		"greeter":
			var greeter := Greeter.new()
			greeter.patrol_points.assign(level.patrol_points)
			greeter.rng.seed = data.seed
			monster = greeter
		"collector":
			var collector := Collector.new()
			collector.patrol_points.assign(level.patrol_points)
			collector.rng.seed = data.seed
			monster = collector
		"rats":
			var rats := RatSwarm.new()
			rats.home = data.pos
			rats.rng.seed = data.seed
			monster = rats
		"centipede":
			var centipede := Centipede.new()
			centipede.route = Centipede.make_route(level.patrol_points)
			centipede.rng.seed = data.seed
			monster = centipede
		"mother":
			var mother := LullabyMother.new()
			mother.patrol_points.assign(level.patrol_points)
			mother.rng.seed = data.seed
			monster = mother
		"fog_walker":
			var walker := FogWalker.new()
			walker.patrol_points.assign(level.patrol_points)
			walker.rng.seed = data.seed
			monster = walker
		"tuner":
			var tuner := Tuner.new()
			tuner.patrol_points.assign(level.patrol_points)
			tuner.rng.seed = data.seed
			monster = tuner
		"child":
			var child := HideChild.new()
			child.patrol_points.assign(level.patrol_points)
			child.hide_spots.assign(level.loot_spots)
			child.rng.seed = data.seed
			monster = child
		_:
			var giant := BoilerColossus.new()
			giant.rng.seed = data.seed
			giant.patrol_points.assign(level.patrol_points)
			colossus = giant
			giant.ready.connect(func() -> void: colossus_spawned.emit(giant), CONNECT_ONE_SHOT)
			monster = giant
	monster.name = data.name
	monster.position = data.pos
	monster.set_meta("kind", data.type)
	return monster


func _spawn_loot(data: Dictionary) -> Node:
	var item := LootItem.from_data(data.item)
	item.name = data.name
	item.position = data.pos
	item.rotation.y = data.rot
	# Only the host simulates loot physics; clients just follow the synced transform.
	item.freeze = data.frozen or not _is_host()
	return item


# --- Requests from players -----------------------------------------------------------

func request_pickup(item: LootItem) -> void:
	_to_host(&"_pickup", [String(item.name)])


@rpc("any_peer", "call_local", "reliable")
func _pickup(item_name: String) -> void:
	if not _is_host():
		return
	var item := loot_root.get_node_or_null(item_name) as LootItem
	if item == null or item.is_queued_for_deletion():
		return
	var data := item.to_data()
	var at := item.global_position
	item.queue_free()
	_send_to(_sender(), &"_grant_item", [data, at])


@rpc("authority", "call_local", "reliable")
func _grant_item(data: Dictionary, at: Vector3) -> void:
	if local_player != null and local_player.pickup(data):
		Sfx.play_3d(self, at, "pickup", -6.0)
	elif local_player != null:
		# Couldn't carry it after all (weight changed meanwhile): put it back.
		request_drop(data, at, Vector3.ZERO)


func request_drop(data: Dictionary, pos: Vector3, velocity: Vector3) -> void:
	_to_host(&"_drop", [data, pos, velocity])


@rpc("any_peer", "call_local", "reliable")
func _drop(data: Dictionary, pos: Vector3, velocity: Vector3) -> void:
	if _is_host():
		host_spawn_loot(data, pos, 0.0, false, velocity)


## A player poked, picked up or hit a monster; the host decides what happens.
func request_monster_action(monster: Node, action: String) -> void:
	_to_host(&"_monster_action", [String(monster.name), action])


@rpc("any_peer", "call_local", "reliable")
func _monster_action(monster_name: String, action: String) -> void:
	if not _is_host():
		return
	var monster := monsters_root.get_node_or_null(monster_name)
	if monster == null or monster.is_queued_for_deletion() or not monster.has_method("host_action"):
		return
	monster.host_action(action, players_root.get_node_or_null(str(_sender())) as Player)


## Host: hand a player an item directly (a monster's prize, a button's gift).
func host_give(player: Player, data: Dictionary) -> void:
	_send_to(player.get_multiplayer_authority(), &"_grant_item", [data, player.global_position])


## A player used a piece of loot whose effect the host has to carry out.
func request_item_effect(effect: String, pos: Vector3) -> void:
	_to_host(&"_item_effect", [effect, pos])


@rpc("any_peer", "call_local", "reliable")
func _item_effect(effect: String, pos: Vector3) -> void:
	if not _is_host():
		return
	var player := players_root.get_node_or_null(str(_sender())) as Player
	match effect:
		"hourglass":
			for monster in monsters_root.get_children():
				if monster is Node3D and monster.global_position.distance_to(pos) < 10.0:
					TimeWarp.slow(monster, 5.0)
		"button":
			if player == null:
				return
			var kinds := ["heal", "gift", "alarm", "teleport", "dark"]
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var at := pos
			match kind:
				"gift":
					host_spawn_loot(LootTable.roll(rng, 3.0), pos + Vector3.UP * 0.6, 0.0, false)
				"alarm":
					Sfx.play_3d(self, pos, "whistle", 6.0, 60.0, 1.5)
					GameNoise.emit_local(get_tree(), pos, 45.0, GameNoise.Kind.MACHINE)
				"teleport":
					at = level.random_patrol_point() + Vector3.UP * 0.2
			MonsterKit.tell(player, &"remote_event", [kind, at])


# --- Weapons ------------------------------------------------------------------------

## A player fired a weapon; the host works out what it hit (see Gear.WEAPON_HITS).
func request_weapon(weapon: String, origin: Vector3, direction: Vector3) -> void:
	_to_host(&"_weapon", [weapon, origin, direction])


@rpc("any_peer", "call_local", "reliable")
func _weapon(weapon: String, origin: Vector3, direction: Vector3) -> void:
	if not _is_host() or not Gear.WEAPON_HITS.has(weapon):
		return
	var rule: Dictionary = Gear.WEAPON_HITS[weapon]
	direction = direction.normalized()
	for monster in weapon_targets(rule, origin, direction):
		_apply_hit(monster, rule)
	var end := _wall_point(origin, direction, rule.range)
	# The boomerang clangs where it lands; everything else is loud where you stand.
	GameNoise.emit_local(get_tree(), end if weapon == "boomerang" else origin, rule.noise, GameNoise.Kind.IMPACT)
	if weapon == "flamethrower":
		for item in loot_root.get_children():
			if item is LootItem:
				var to: Vector3 = item.global_position - origin
				if to.length() < rule.range and direction.dot(to.normalized()) > rule.cone:
					item.queue_free()
	_weapon_fx.rpc(weapon, origin, end)


## Monsters a weapon hits: everything in a cone, or the first (railgun: every) monster
## along the aim line before it meets a wall.
func weapon_targets(rule: Dictionary, origin: Vector3, direction: Vector3) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var reach: float = rule.range
	if rule.has("cone"):
		for monster in monsters_root.get_children():
			if not monster is Node3D:
				continue
			var to: Vector3 = monster.global_position + Vector3.UP * 0.8 - origin
			if to.length() < reach and direction.dot(to.normalized()) > rule.cone \
					and MonsterKit.clear_line(get_world_3d(), origin, origin + to):
				result.append(monster)
		return result
	var wall_distance := origin.distance_to(_wall_point(origin, direction, reach))
	var hits := []
	for monster in monsters_root.get_children():
		if not monster is Node3D:
			continue
		var size := _size_of(monster)
		var radius: float = {"small": 0.5, "medium": 0.6, "large": 1.4}[size]
		var height: float = {"small": 1.0, "medium": 2.0, "large": 4.5}[size]
		var base: Vector3 = monster.global_position - (Vector3.UP * 0.5 if monster is Moth else Vector3.ZERO)
		# Closest approach of the aim line to the monster's vertical axis.
		var flat_dir := Vector2(direction.x, direction.z)
		var flat_to := Vector2(base.x - origin.x, base.z - origin.z)
		var t := flat_to.dot(flat_dir) / maxf(flat_dir.length_squared(), 0.0001)
		if t < 0.0 or t > wall_distance:
			continue
		var point := origin + direction * t
		if Vector2(point.x - base.x, point.z - base.z).length() < radius and point.y > base.y - 0.2 and point.y < base.y + height:
			hits.append([t, monster])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for hit in hits:
		result.append(hit[1])
		if not rule.get("pierce", false):
			break
	return result


func _apply_hit(monster: Node3D, rule: Dictionary) -> void:
	if monster is FogWalker:
		monster.reveal()
	var effect = rule.get(_size_of(monster), 0.0)
	if effect is String:
		_kill_monster(monster)
	elif effect > 0.0:
		TimeWarp.stun(monster, effect)


## Small monsters can die. The child just runs off to play elsewhere for a while.
func _kill_monster(monster: Node3D) -> void:
	if monster is Mimic:
		monster.host_action("kill", null)
	elif monster is HideChild:
		monster.host_kill()
	else:
		_monster_died.rpc(monster.global_position)
		monster.queue_free()


@rpc("authority", "call_local", "reliable")
func _monster_died(pos: Vector3) -> void:
	Sfx.play_3d(self, pos, "screech", -2.0, 30.0, 1.6)


func _size_of(monster: Node) -> String:
	return MonsterRoster.MONSTERS.get(monster.get_meta("kind", ""), {}).get("size", "medium")


func _wall_point(origin: Vector3, direction: Vector3, reach: float) -> Vector3:
	var to := origin + direction * reach
	var query := PhysicsRayQueryParameters3D.create(origin, to, Layers.WORLD | Layers.WALKWAY)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() and not hit.collider is Player else to


@rpc("authority", "call_local", "reliable")
func _weapon_fx(weapon: String, origin: Vector3, end: Vector3) -> void:
	match weapon:
		"boomerang":
			Sfx.play_3d(self, end, "clank", 0.0, 35.0, 1.2)
		"nail_gun":
			Sfx.play_3d(self, origin, "tink", -2.0, 25.0, 2.2)
		"shock_glove":
			Sfx.play_3d(self, origin, "zap", 0.0, 20.0)
		"megaphone":
			Sfx.play_3d(self, origin, "roar", 6.0, 80.0)
		"flamethrower":
			Sfx.play_3d(self, origin, "hiss", 2.0, 30.0, 0.6)
			_flames(origin, end)
		"shotgun":
			Sfx.play_3d(self, origin, "bang", 6.0, 90.0)
		"railgun":
			Sfx.play_3d(self, origin, "bang", 8.0, 90.0, 0.5)
			_beam(origin, end)


func _flames(origin: Vector3, end: Vector3) -> void:
	var fire := CPUParticles3D.new()
	fire.one_shot = true
	fire.amount = 40
	fire.lifetime = 0.6
	fire.explosiveness = 0.7
	fire.direction = (end - origin).normalized()
	fire.spread = 18.0
	fire.initial_velocity_min = 6.0
	fire.initial_velocity_max = 9.0
	fire.gravity = Vector3(0, 2.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 4
	mesh.rings = 2
	fire.mesh = mesh
	fire.material_override = PS1Materials.get_material("concrete", Color(1.0, 0.5, 0.1), true, Vector2.ONE, Color(1.0, 0.45, 0.1))
	add_child(fire)
	fire.global_position = origin + fire.direction * 0.6
	fire.emitting = true
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.2)
	glow.light_energy = 2.0
	glow.omni_range = 6.0
	fire.add_child(glow)
	get_tree().create_timer(1.2).timeout.connect(fire.queue_free)


func _beam(origin: Vector3, end: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, origin.distance_to(end))
	beam.mesh = box
	beam.material_override = PS1Materials.get_material("concrete", Color(0.6, 0.9, 1.0), true, Vector2.ONE, Color(0.5, 0.9, 1.0))
	add_child(beam)
	beam.global_position = (origin + end) / 2.0
	beam.look_at_from_position(beam.global_position, end, Vector3.UP if absf((end - origin).normalized().y) < 0.95 else Vector3.RIGHT)
	get_tree().create_timer(0.3).timeout.connect(beam.queue_free)


## A thrown rubber duck: every peer simulates its own copy.
func request_duck(origin: Vector3, velocity: Vector3) -> void:
	_to_host(&"_duck", [origin, velocity])


@rpc("any_peer", "call_local", "reliable")
func _duck(origin: Vector3, velocity: Vector3) -> void:
	if _is_host():
		_throw_duck.rpc(origin, velocity)


@rpc("authority", "call_local", "reliable")
func _throw_duck(origin: Vector3, velocity: Vector3) -> void:
	var duck := RubberDuck.new()
	add_child(duck)
	duck.global_position = origin
	duck.linear_velocity = velocity


## Host: the duck went off. Hurts monsters and scavengers alike.
func host_explode(pos: Vector3) -> void:
	var rule: Dictionary = Gear.WEAPON_HITS.rubber_duck
	for monster in monsters_root.get_children():
		if monster is Node3D and monster.global_position.distance_to(pos) < rule.range:
			_apply_hit(monster, rule)
	for player in all_players():
		if player.is_active() and player.global_position.distance_to(pos) < rule.range:
			MonsterKit.tell(player, &"remote_damage", [60.0, "被爆炸橡皮鴨炸死了", "被橡皮鴨的爆炸波及了！"])
	GameNoise.emit_local(get_tree(), pos, rule.noise, GameNoise.Kind.IMPACT)


## A scavenger brought a rabbit's foot: a few more good things, and one more monster.
func request_lucky() -> void:
	_to_host(&"_lucky")


@rpc("any_peer", "call_local", "reliable")
func _lucky() -> void:
	if not _is_host():
		return
	var spots := level.loot_spots.duplicate()
	for i in 3:
		var spot: Vector3 = spots[rng.randi_range(0, spots.size() - 1)]
		host_spawn_loot(LootTable.roll(rng, 3.0, level.loot_pool), spot, rng.randf_range(0.0, TAU))
	var kinds := []
	for kind in MonsterRoster.MONSTERS:
		if MonsterRoster.MONSTERS[kind].size != "large":
			kinds.append(kind)
	host_release_monster(kinds[rng.randi_range(0, kinds.size() - 1)], _far_patrol_point())


@rpc("any_peer", "call_local", "reliable")
func _pull_lever() -> void:
	if _is_host() and not level.lever.is_pulled:
		_lever_pulled.rpc()


@rpc("authority", "call_local", "reliable")
func _lever_pulled() -> void:
	level.lever.play_pull()
	level.complete_objective()
	if _is_host() and colossus != null:
		colossus.enrage(level.lever.global_position)


@rpc("any_peer", "call_local", "reliable")
func _pry_locker(index: int) -> void:
	if not _is_host() or index < 0 or index >= level.lockers.size():
		return
	var locker: Locker = level.lockers[index]
	if locker.is_open:
		return
	_locker_opened.rpc(index)
	for i in rng.randi_range(1, 2):
		var pos := locker.to_global(Vector3(-0.2 + 0.4 * i, 0.2, 0.6))
		host_spawn_loot(LootTable.roll(rng, Locker.LUCK, level.loot_pool), pos)


@rpc("authority", "call_local", "reliable")
func _locker_opened(index: int) -> void:
	level.lockers[index].play_open()


## Host tells a player's owner they were caught.
func host_kill(player: Player, cause: String) -> void:
	if not _is_host() or not player.is_active():
		return
	player.remote_die.rpc_id(player.get_multiplayer_authority(), cause)


# --- Local player end of run --------------------------------------------------------

func local_extracted() -> void:
	if finished or local_player == null:
		return
	finished = true
	var taken := local_player.take_all_items()
	var payout := LootTable.payout(taken, rng)
	var gear := local_player.remaining_gear()
	local_player.set_extracted()
	GameState.record_extraction(payout.total, gear)
	Session.instance.report_finished(payout.total)
	local_finished.emit({"survived": true, "items": payout.items_list, "payout": payout, "cause": "", "lost_gear": []})


func _on_local_died(cause: String) -> void:
	if finished:
		return
	finished = true
	var items := local_player.items.duplicate()
	# Your backpack spills where you fell, for teammates to pick up.
	_to_host(&"_spill_body", [items, local_player.global_position])
	GameState.record_death()
	Session.instance.report_finished()
	local_finished.emit({"survived": false, "items": items, "payout": {}, "cause": cause,
		"lost_gear": local_player.remaining_gear()})


@rpc("any_peer", "call_local", "reliable")
func _spill_body(items: Array, pos: Vector3) -> void:
	if not _is_host():
		return
	for item in items:
		var offset := Vector3(rng.randf_range(-BODY_SCATTER, BODY_SCATTER), 0.6, rng.randf_range(-BODY_SCATTER, BODY_SCATTER))
		host_spawn_loot(item, pos + offset, rng.randf_range(0.0, TAU), false)


# --- Helpers --------------------------------------------------------------------------

func _root(root_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = root_name
	add_child(node)
	return node


func _spawner(root: Node3D, spawn: Callable) -> MultiplayerSpawner:
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Spawner"
	root.add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(root)
	spawner.spawn_function = spawn
	return spawner


func _is_host() -> bool:
	return multiplayer.is_server()


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _to_host(method: StringName, args := []) -> void:
	if _is_host():
		callv(method, args)
	else:
		var call_args := [1, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)


func _send_to(peer: int, method: StringName, args := []) -> void:
	if peer == multiplayer.get_unique_id():
		callv(method, args)
	else:
		var call_args := [peer, method]
		call_args.append_array(args)
		callv("rpc_id", call_args)
