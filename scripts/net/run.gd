class_name Run
extends Node3D
## One run on a randomly drawn map, shared by every peer. Lives at the same node path on
## all machines (Main/RunView/Viewport/World) so its RPCs and spawners line up.
## The host owns loot, monsters, the lever and lockers; clients ask it for changes.

signal local_player_spawned(player: Player)
signal local_finished(result: Dictionary)
signal colossus_spawned(colossus: BoilerColossus)

const MATCH_TIME := 900.0  # 15 minutes: the maps have big random wings to explore
const BODY_SCATTER := 0.6

static var instance: Run
## Tests pin the monster kinds; empty means a random draw (see MonsterRoster).
static var forced_monsters: Array = []
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
var warp: TimeWarp
## 會醒來的廢墟: how awake the map is (Awakening.sense_mult / speed_mult read it).
var awakening: Awakening
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

	awakening = Awakening.new()
	awakening.name = "Awakening"
	awakening.run = self
	add_child(awakening)


	players_root = _root("Players")
	monsters_root = _root("Monsters")
	loot_root = _root("Loot")
	_player_spawner = _spawner(players_root, _spawn_player)
	_monster_spawner = _spawner(monsters_root, _spawn_monster)
	_loot_spawner = _spawner(loot_root, _spawn_loot)

	var session := Session.instance
	if _is_host():
		session.world_ready_all.connect(_host_populate, CONNECT_ONE_SHOT)
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
	if _is_host() and not _burning.is_empty():
		_host_burn(delta)
	if time_left <= 0.0 and local_player != null and local_player.is_active():
		local_player.die(level.timeout_cause)
	if _is_host():
		_time_broadcast -= delta
		if _time_broadcast <= 0.0:
			_time_broadcast = 1.0
			Session.instance.broadcast_time(time_left)


func all_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in players_root.get_children():
		if node is Player:
			result.append(node)
	return result


# --- Host: populate the world once every peer has built it ---------------------------

func _host_populate() -> void:
	var squads: Array = Session.instance.active_squads()
	var counts := {}
	for id in Session.instance.scavenger_ids():
		var squad := Session.instance.squad_of(id)
		var index: int = counts.get(squad, 0)
		counts[squad] = index + 1
		_player_spawner.spawn({"id": id, "name": roster[id].name, "index": index,
			"squad": squad, "slot": squads.find(squad)})
	awakening.rng.seed = rng.randi()
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
				_:
					# Roster-driven monsters: "spawn" is far (away from players), air or patrol.
					match MonsterRoster.MONSTERS[kind].get("spawn", "patrol"):
						"far":
							data.pos = _far_patrol_point()
						"air":
							data.pos = level.random_patrol_point() + Vector3(0, 3.0, 0)
						_:
							data.pos = level.random_patrol_point() + Vector3.UP * 0.1
			_monster_spawner.spawn(data)


## Host: a gate (shop shutter, a door the tuner slams) closes or rolls back up.
func host_set_gate(index: int, closed: bool) -> void:
	_gate_set.rpc(index, closed)


@rpc("authority", "call_local", "reliable")
func _gate_set(index: int, closed: bool) -> void:
	if index >= 0 and index < level.gates.size():
		level.gates[index].set_closed(closed)


## Host: quietly adds a monster of any roster kind (a splitter's crawlers), no hiss.
func host_spawn_monster(kind: String, pos: Vector3) -> void:
	if not _is_host() or not MonsterRoster.MONSTERS.has(kind):
		return
	_monster_serial += 1
	var data := {"type": kind, "name": "%s%d" % [kind.capitalize(), _monster_serial], "seed": rng.randi(), "pos": pos}
	if kind == "mimic":
		data.rot = rng.randf_range(0.0, TAU)
		data.disguise = LootTable.roll(rng, 0.8, level.loot_pool)
	_monster_spawner.spawn(data)


## The patrol point farthest from where players start.
## Where each squad starts: the first at the map's own spawn, the others at the patrol
## points that are farthest from every squad placed so far, facing the map's centre.
## Pure function of the level, so every peer works out the same answer.
func squad_start(slot: int) -> Dictionary:
	if slot <= 0 or level.patrol_points.is_empty():
		return {"pos": level.player_spawn, "yaw": level.player_spawn_yaw}
	var taken: Array[Vector3] = [level.player_spawn, level.monster_spawn]
	var pick := level.player_spawn
	for i in slot:
		var best := -1.0
		for point in level.patrol_points:
			var nearest := INF
			for other in taken:
				nearest = minf(nearest, point.distance_to(other))
			if nearest > best:
				best = nearest
				pick = point
		taken.append(pick)
	var centre := Vector3.ZERO
	for point in level.patrol_points:
		centre += point
	centre /= level.patrol_points.size()
	var to := centre - pick
	return {"pos": pick + Vector3.UP * 0.1, "yaw": atan2(-to.x, -to.z)}


func _far_patrol_point() -> Vector3:
	var best: Vector3 = level.patrol_points[0]
	for point in level.patrol_points:
		if point.distance_to(level.player_spawn) > best.distance_to(level.player_spawn):
			best = point
	return best + Vector3.UP * 0.1


func host_spawn_loot(item: Dictionary, pos: Vector3, rot := 0.0, frozen := true, velocity := Vector3.ZERO) -> LootItem:
	_loot_counter += 1
	if item.has("bag"):
		# Its place in someone's backpack grid means nothing on the floor.
		item = item.duplicate(true)
		item.erase("bag")
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
	player.squad = data.get("squad", 0)
	player.set_multiplayer_authority(data.id)
	# Each scavenger's own random backpack shape for this run (see GridBag).
	player.bag_cells = GridBag.generate(hash([seed, int(data.id)]))
	player.build_sync()
	var start := squad_start(data.get("slot", 0))
	var offset := Vector3((data.index % 2) * 1.2 - 0.6, 0.0, (data.index / 2) * 1.2).rotated(Vector3.UP, start.yaw)
	player.position = start.pos + offset
	player.rotation.y = start.yaw
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
		"colossus":
			var giant := BoilerColossus.new()
			giant.rng.seed = data.seed
			giant.patrol_points.assign(level.patrol_points)
			colossus = giant
			giant.ready.connect(func() -> void: colossus_spawned.emit(giant), CONNECT_ONE_SHOT)
			monster = giant
		_:
			# Roster-driven monsters: MonsterRoster.MONSTERS[kind].script names the class
			# file; the usual hand-offs are filled in when the monster has them.
			monster = load(MonsterRoster.MONSTERS[data.type].script).new()
			if "patrol_points" in monster:
				monster.patrol_points.assign(level.patrol_points)
			if "hide_spots" in monster:
				monster.hide_spots.assign(level.loot_spots)
			if "home" in monster:
				monster.home = data.pos
			if "level" in monster:
				monster.level = level
			if "rng" in monster:
				monster.rng.seed = data.seed
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
		# It no longer fits the backpack grid (something else went in meanwhile): put it back.
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
# Players fire Arsenal builds; the host resolves every shot. A shot's numbers come
# from Arsenal.stats(build), worked out again on the host from the build the shooter
# sent. Monsters keep health as meta "hp" / "max_hp" (from MonsterRoster); small and
# medium ones die at 0, large ones are only ever broken: knocked out for a while.

## Monster health when the roster doesn't say.
const SIZE_HEALTH := {"small": 40.0, "medium": 160.0, "large": 600.0}
## Hit cylinders used for aiming at monsters, by size: [radius, height].
const SIZE_BOX := {"small": [0.5, 1.0], "medium": [0.6, 2.0], "large": [1.4, 4.5]}
## How much of a stun / shove each size actually feels.
const STUN_SCALE := {"small": 1.0, "medium": 0.8, "large": 0.35}
const KNOCK_SCALE := {"small": 1.0, "medium": 0.6, "large": 0.1}
const BREAK_STUN := 8.0
## Scavengers have 100 health; a projectile does this many times its monster damage to one.
const PVP_SCALE := 1.2
const KNIFE_REACH := 2.3
const KNIFE_DAMAGE := 12.0
const KNIFE_PLAYER := 15.0
const BURN_DPS := 6.0
const CHAIN_REACH := 6.0
const SAW_SEEK := 8.0
const LURE_RADIUS := 18.0
const FLAME_CONE := 0.92  # cos of the flame jet's half angle (about 23 degrees)
const ARC_CONE := 0.95
## Effects that only matter to the shooter's machine, never to what is hit.
const LOCAL_EFFECTS := ["light", "thermal", "bayonet", "ghost", "motion_sight", "squeal", "guard", "fang"]
## Effects that only change the numbers; a hit with nothing else is a plain (bullet) hit.
const MODIFIER_EFFECTS := ["soft", "armor", "leech", "bounty", "lure", "scream", "hush", "lullaby"]

var _burning := {}  # monster -> {"time", "tick", "attacker"}


## A direction inside a cone of the given half-angle (degrees) around forward.
static func scatter(forward: Vector3, degrees: float, rng: RandomNumberGenerator = null) -> Vector3:
	forward = forward.normalized()
	if degrees <= 0.0:
		return forward
	var r1 := rng.randf() if rng != null else randf()
	var r2 := rng.randf() if rng != null else randf()
	var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(forward).normalized()
	var angle := deg_to_rad(degrees) * sqrt(r1)
	var around := TAU * r2
	return (forward * cos(angle) + (side * cos(around) + up * sin(around)) * sin(angle)).normalized()


## A player pulled the trigger: one direction per pellet, already spread.
func request_shot(build: Dictionary, origin: Vector3, directions: Array) -> void:
	_to_host(&"_shot", [build, origin, directions])


@rpc("any_peer", "call_local", "reliable")
func _shot(build: Dictionary, origin: Vector3, directions: Array) -> void:
	if not _is_host() or directions.is_empty():
		return
	var attacker := players_root.get_node_or_null(str(_sender())) as Player
	if attacker != null and not attacker.is_active():
		return
	host_fire(Arsenal.stats(build), origin, directions, attacker)


## Host: carries out one shot of a finished weapon (Arsenal.stats) by its kind.
func host_fire(stats: Dictionary, origin: Vector3, directions: Array, attacker: Player = null) -> void:
	var effects: Dictionary = {}
	for effect in stats.effects:
		if not effect in LOCAL_EFFECTS:
			effects[effect] = stats.effects[effect]
	var rule := {"range": float(stats.range), "pierce": effects.get("pierce", false)}
	var damage: float = stats.damage
	var aim: Vector3 = (directions[0] as Vector3).normalized()
	GameNoise.emit_local(get_tree(), origin, stats.noise, GameNoise.Kind.IMPACT)
	awakening.host_shot(origin, float(stats.noise), stats.effects.has("hush"))
	var segments := []  # [from, to] of each tracer / arc / saw leg
	var impacts := []
	var to_monsters := {}  # monster -> damage this shot
	var to_players := {}  # player -> damage this shot
	match stats.kind:
		"cone":
			rule.cone = FLAME_CONE
			for monster in weapon_targets(rule, origin, aim):
				to_monsters[monster] = damage
			if attacker != null:
				for victim in player_targets(rule, origin, aim, attacker):
					to_players[victim] = damage
			var flame_end := _wall_point(origin, aim, rule.range)
			segments.append([origin, flame_end])
			# Fire burns away webs along the jet.
			for monster in live_monsters():
				if monster.has_method("host_burn_webs"):
					monster.host_burn_webs(origin.lerp(flame_end, 0.6), rule.range * 0.6)
		"arc":
			var first := _arc_target(origin, aim, rule.range)
			var end := _wall_point(origin, aim, rule.range)
			if first != null:
				end = _chest(first)
				to_monsters[first] = damage
				var last := first
				var jolt := damage
				for i in int(effects.get("chain", 0)):
					var next := _nearest_monster(_chest(last), CHAIN_REACH, to_monsters.keys())
					if next == null:
						break
					jolt *= 0.75
					to_monsters[next] = jolt
					segments.append([_chest(last), _chest(next)])
					last = next
			elif attacker != null:
				var arc_rule := {"range": rule.range, "cone": ARC_CONE}
				var victims := player_targets(arc_rule, origin, aim, attacker)
				if not victims.is_empty():
					to_players[victims[0]] = damage
					end = victims[0].global_position + Vector3.UP
			segments.push_front([origin, end])
		"lob":
			var shooter := attacker.get_multiplayer_authority() if attacker != null else 0
			_throw_duck.rpc(origin + aim * 0.6, aim * 13.0 + Vector3.UP * 3.0, damage,
				float(effects.get("explode", 4.0)), effects, shooter)
		"bounce":
			_saw_path(origin, aim, rule, damage, int(effects.get("chain", 0)), to_monsters, segments, impacts)
			if attacker != null:
				for victim in player_targets(rule, origin, aim, attacker):
					to_players[victim] = damage
					break
		_:
			# hitscan and charge: every pellet is its own line.
			effects["bullet"] = true
			for direction in directions:
				var dir := (direction as Vector3).normalized()
				var end := _wall_point(origin, dir, rule.range)
				var hits := weapon_hits(rule, origin, dir)
				for hit in hits:
					to_monsters[hit[1]] = to_monsters.get(hit[1], 0.0) + damage
					if not rule.pierce:
						end = origin + dir * float(hit[0])
						break
				if attacker != null:
					for victim in player_targets(rule, origin, dir, attacker):
						to_players[victim] = to_players.get(victim, 0.0) + damage
				segments.append([origin, end])
				impacts.append(end)
	for monster in to_monsters:
		host_damage_monster(monster, to_monsters[monster], effects, origin, attacker)
	var weapon_name := Arsenal.name_of(stats.frame)
	for victim in to_players:
		_hit_player(victim, attacker, to_players[victim] * PVP_SCALE, weapon_name)
	if stats.kind != "lob":
		var landing: Vector3 = impacts[0] if not impacts.is_empty() else (segments[0][1] if not segments.is_empty() else origin)
		if effects.has("explode"):
			host_explode(landing, damage, float(effects.explode), effects, attacker)
		if effects.get("lure", false):
			GameNoise.emit_local(get_tree(), landing, LURE_RADIUS, GameNoise.Kind.ITEM)
		Organs.host_impact(self, effects, landing, attacker)
	var quiet: bool = stats.parts.get("muzzle", "") == "suppressor"
	var shooter_name := String(attacker.name) if attacker != null else ""
	_shot_fx.rpc(shooter_name, str(stats.frame), str(stats.kind), quiet, segments, impacts, effects.get("lure", false))


## The saw blade: flies straight, ricochets off up to three walls, and after biting a
## monster swerves toward the next one nearby (chain).
func _saw_path(origin: Vector3, aim: Vector3, rule: Dictionary, damage: float, chain: int,
		to_monsters: Dictionary, segments: Array, impacts: Array) -> void:
	var from := origin
	var dir := aim
	var left: float = rule.range
	var bites := 1 + chain
	for leg in 6:
		if left <= 0.5:
			break
		var wall := _wall_hit(from, dir, left)
		var end: Vector3 = wall.position if not wall.is_empty() else from + dir * left
		var reach := from.distance_to(end)
		var bit: Node3D = null
		var bite_at := end
		if bites > 0:
			for hit in weapon_hits({"range": reach}, from, dir):
				if not to_monsters.has(hit[1]):
					bit = hit[1]
					bite_at = from + dir * float(hit[0])
					break
		if bit != null:
			to_monsters[bit] = damage
			bites -= 1
			segments.append([from, bite_at])
			impacts.append(bite_at)
			left -= from.distance_to(bite_at)
			var next := _nearest_monster(bite_at, SAW_SEEK, to_monsters.keys()) if bites > 0 else null
			if next == null:
				break
			from = bite_at
			dir = (_chest(next) - bite_at).normalized()
			continue
		segments.append([from, end])
		impacts.append(end)
		if wall.is_empty():
			break
		left -= reach
		dir = dir.bounce(wall.normal).normalized()
		from = end + wall.normal * 0.05


## A knife stab (V), or a bayonet thrust.
func request_melee(origin: Vector3, direction: Vector3, bayonet: bool, fang := false) -> void:
	_to_host(&"_melee", [origin, direction, bayonet, fang])


@rpc("any_peer", "call_local", "reliable")
func _melee(origin: Vector3, direction: Vector3, bayonet: bool, fang := false) -> void:
	if not _is_host():
		return
	var attacker := players_root.get_node_or_null(str(_sender())) as Player
	if attacker != null and not attacker.is_active():
		return
	var rule := {"range": KNIFE_REACH}
	direction = direction.normalized()
	var effects := {"melee": true}
	if bayonet:
		effects["bayonet"] = true
	var strength := 2.0 if bayonet else 1.0
	if fang:
		# The hound's jaw: three times the knife, and what it bites slows down.
		strength = 3.0
		effects["slow"] = 1.5
	var hits := weapon_hits(rule, origin, direction)
	if not hits.is_empty():
		var monster: Node3D = hits[0][1]
		host_damage_monster(monster, KNIFE_DAMAGE * strength, effects, origin, attacker, origin + direction * float(hits[0][0]))
		_melee_fx.rpc(origin + direction * float(hits[0][0]))
		return
	if attacker != null:
		var victims := player_targets(rule, origin, direction, attacker)
		if not victims.is_empty():
			_hit_player(victims[0], attacker, KNIFE_PLAYER * strength, "小刀")
			_melee_fx.rpc(victims[0].global_position + Vector3.UP * 1.1)


@rpc("authority", "call_local", "reliable")
func _melee_fx(at: Vector3) -> void:
	Sfx.play_3d(self, at, "thump", -4.0, 15.0, 1.3)
	ShotFx.impact(self, at, Color(0.7, 0.1, 0.08), 6)


## Host: hurts a monster. Health comes from MonsterRoster (health, weak per effect; the
## size sets it otherwise); the monster's on_hit(hit) can scale it (0 = armour, 3 = weak
## spot) and react. Small and medium monsters die at 0, large ones are broken: down
## for a while, then back at full health. Returns the damage dealt.
func host_damage_monster(monster: Node3D, amount: float, effects: Dictionary, from_pos: Vector3,
		attacker: Player = null, point := Vector3.INF) -> float:
	if not _is_host() or monster == null or not is_instance_valid(monster) or monster.is_queued_for_deletion():
		return 0.0
	var entry: Dictionary = MonsterRoster.MONSTERS.get(monster.get_meta("kind", ""), {})
	var size: String = entry.get("size", "medium")
	if not monster.has_meta("max_hp"):
		var max_hp := float(entry.get("health", SIZE_HEALTH.get(size, 160.0)))
		monster.set_meta("max_hp", max_hp)
		monster.set_meta("hp", max_hp)
	if point == Vector3.INF:
		point = _chest(monster)
	var dot: bool = effects.get("dot", false)
	# Rock salt and the like drag hidden things into view (the fog walker can only be
	# hurt while it shows; its on_hit decides that).
	if effects.get("reveal", false) and monster.has_method("reveal"):
		monster.reveal()
	var multiplier := 1.0
	if monster.has_method("on_hit"):
		multiplier = float(monster.on_hit({"amount": amount, "effects": effects, "from": from_pos,
			"point": point, "attacker": attacker}))
	var weak: Dictionary = entry.get("weak", {})
	var plain := true
	for effect in effects:
		if weak.has(effect):
			multiplier *= float(weak[effect])
		if not effect in MODIFIER_EFFECTS:
			plain = false
	# A plain hit (nothing but damage) counts as a bullet.
	if plain and not effects.has("bullet") and weak.has("bullet"):
		multiplier *= float(weak.bullet)
	if effects.get("soft", false):
		multiplier *= 0.7 if size == "large" else 1.4
	if effects.get("armor", false) and size == "large":
		multiplier *= 1.5
	if not is_instance_valid(monster) or monster.is_queued_for_deletion():
		return 0.0
	var dealt := maxf(amount * multiplier, 0.0)
	if dealt <= 0.0:
		if attacker != null and not dot:
			MonsterKit.tell(attacker, &"remote_hit", [0.0, "blocked"])
			_monster_hit_fx.rpc(String(monster.name), point, "blocked")
		return 0.0
	if not dot:
		_apply_effects(monster, size, effects, from_pos, attacker)
	if attacker != null and effects.has("leech"):
		MonsterKit.tell(attacker, &"remote_heal", [dealt * float(effects.leech)])
	var hp: float = float(monster.get_meta("hp")) - dealt
	var result := "hit"
	if hp <= 0.0:
		if size == "large":
			result = "break"
			hp = float(monster.get_meta("max_hp"))
			_break_monster(monster)
		else:
			result = "kill"
	monster.set_meta("hp", maxf(hp, 0.0))
	if attacker != null and (not dot or result != "hit"):
		MonsterKit.tell(attacker, &"remote_hit", [dealt, result])
	if not dot or result != "hit":
		_monster_hit_fx.rpc(String(monster.name), point, result)
	if result == "kill":
		if effects.get("bounty", false):
			var luck: float = effects.bounty if effects.bounty is float else 1.0
			host_spawn_loot(LootTable.roll(rng, luck, level.loot_pool), monster.global_position + Vector3.UP * 0.6, 0.0, false)
		Organs.host_drop(self, monster, false)
		_burning.erase(monster)
		_kill_monster(monster)
	return dealt


## Stun, slow, shove, burn and bubble from a hit that landed.
func _apply_effects(monster: Node3D, size: String, effects: Dictionary, from_pos: Vector3, attacker: Player) -> void:
	if effects.get("melee", false):
		TimeWarp.stun(monster, 1.0 if size == "small" else (0.25 if size == "medium" else 0.0))
	if effects.has("stun"):
		TimeWarp.stun(monster, float(effects.stun) * STUN_SCALE[size])
	if effects.has("slow"):
		TimeWarp.slow(monster, float(effects.slow) * (0.5 if size == "large" else 1.0))
	if effects.has("knock"):
		var away := monster.global_position - from_pos
		away.y = 0.0
		if away.length() > 0.01:
			var shove: Vector3 = away.normalized() * float(effects.knock) * float(KNOCK_SCALE[size])
			if monster is CharacterBody3D:
				(monster as CharacterBody3D).move_and_collide(shove)
			else:
				monster.global_position += shove
	if effects.has("burn") and float(effects.burn) > 0.0:
		var burning: Dictionary = _burning.get(monster, {"time": 0.0, "tick": 0.5})
		var seconds := float(effects.burn)
		burning.time = maxf(burning.time, seconds)
		burning.attacker = attacker
		_burning[monster] = burning
		_status_fx.rpc(String(monster.name), "burn", seconds)
	if effects.has("bubble"):
		var seconds := float(effects.bubble)
		match size:
			"small":
				TimeWarp.stun(monster, seconds)
				_status_fx.rpc(String(monster.name), "bubble", seconds)
			"medium":
				# Medium monsters take a few bubbles before they're wrapped up.
				var stacks: int = monster.get_meta("bubbles", 0) + 1
				monster.set_meta("bubbles", stacks)
				if stacks >= 4:
					monster.set_meta("bubbles", 0)
					TimeWarp.stun(monster, seconds * 0.6)
					_status_fx.rpc(String(monster.name), "bubble", seconds * 0.6)
			_:
				TimeWarp.slow(monster, 0.5)


## Host: burning monsters keep taking damage.
func _host_burn(delta: float) -> void:
	for monster in _burning.keys():
		if not is_instance_valid(monster) or monster.is_queued_for_deletion():
			_burning.erase(monster)
			continue
		var burning: Dictionary = _burning[monster]
		burning.time -= delta
		burning.tick -= delta
		if burning.tick <= 0.0:
			burning.tick = 0.5
			var attacker = burning.get("attacker")
			host_damage_monster(monster, BURN_DPS * 0.5, {"burn": 0.0, "dot": true}, monster.global_position,
				attacker if is_instance_valid(attacker) else null)
		if burning.time <= 0.0:
			_burning.erase(monster)


## A large monster ran out of health: it goes down for a long while (and can react).
func _break_monster(monster: Node3D) -> void:
	TimeWarp.stun(monster, BREAK_STUN)
	awakening.host_break(monster.global_position)
	_burning.erase(monster)
	if monster.has_method("on_broken"):
		monster.on_broken()
	_monster_broken.rpc(monster.global_position)
	Organs.host_drop(self, monster, true)


## Host: an organ effect went off at a spot (scream, lullaby, acid puddle); every peer shows it.
func host_organ_fx(kind: String, at: Vector3) -> void:
	_organ_fx.rpc(kind, at)


@rpc("authority", "call_local", "reliable")
func _organ_fx(kind: String, at: Vector3) -> void:
	Organs.play_fx(self, kind, at)


@rpc("authority", "call_local", "reliable")
func _monster_broken(pos: Vector3) -> void:
	Sfx.play_3d(self, pos, "roar", 0.0, 60.0, 0.55)
	Sfx.play_3d(self, pos, "thump", 4.0, 40.0, 0.5)


## Monsters a weapon's line hits, nearest first: everything in a cone ("cone" in the
## rule: cos of the half angle), or the first (with "pierce": every) monster along the
## aim line before it meets a wall.
func weapon_targets(rule: Dictionary, origin: Vector3, direction: Vector3) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var reach: float = rule.range
	if rule.has("cone"):
		for monster in live_monsters():
			if not monster is Node3D:
				continue
			var to: Vector3 = _chest(monster) - origin
			if to.length() < reach and direction.dot(to.normalized()) > rule.cone \
					and MonsterKit.clear_line(get_world_3d(), origin, origin + to):
				result.append(monster)
		return result
	for hit in weapon_hits(rule, origin, direction):
		result.append(hit[1])
		if not rule.get("pierce", false):
			break
	return result


## Every monster the aim line passes through before a wall: [[distance, monster], ...].
func weapon_hits(rule: Dictionary, origin: Vector3, direction: Vector3) -> Array:
	var reach: float = rule.range
	var wall_distance := origin.distance_to(_wall_point(origin, direction, reach))
	var hits := []
	for monster in live_monsters():
		if not monster is Node3D or monster.is_queued_for_deletion():
			continue
		var box: Array = SIZE_BOX[_size_of(monster)]
		var radius: float = box[0]
		var height: float = box[1]
		var base: Vector3 = monster.global_position
		# Closest approach of the aim line to the monster's vertical axis.
		var flat_dir := Vector2(direction.x, direction.z)
		var flat_to := Vector2(base.x - origin.x, base.z - origin.z)
		var t := flat_to.dot(flat_dir) / maxf(flat_dir.length_squared(), 0.0001)
		if flat_dir.length_squared() < 0.0001:
			t = (base.y + height * 0.5 - origin.y) / direction.y
		if t < 0.0 or t > wall_distance:
			continue
		var point := origin + direction * t
		if Vector2(point.x - base.x, point.z - base.z).length() < radius and point.y > base.y - 0.2 and point.y < base.y + height:
			hits.append([t, monster])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return hits


## Scavengers from other squads a weapon hits (nobody, in a one-squad match).
func player_targets(rule: Dictionary, origin: Vector3, direction: Vector3, attacker: Player) -> Array[Player]:
	var result: Array[Player] = []
	var reach: float = rule.range
	var wall_distance := origin.distance_to(_wall_point(origin, direction, reach))
	var hits := []
	for player in all_players():
		if player == attacker or (attacker != null and player.squad == attacker.squad) or not player.is_active():
			continue
		var base := player.global_position
		var chest := base + Vector3.UP * 1.0
		if rule.has("cone"):
			var to := chest - origin
			if to.length() < reach and direction.dot(to.normalized()) > rule.cone \
					and MonsterKit.clear_line(get_world_3d(), origin, chest):
				result.append(player)
			continue
		var t := (chest - origin).dot(direction)
		if t < 0.0 or t > wall_distance:
			continue
		var point := origin + direction * t
		if Vector2(point.x - base.x, point.z - base.z).length() < 0.45 and point.y > base.y - 0.1 and point.y < base.y + 1.9:
			hits.append([t, player])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for hit in hits:
		result.append(hit[1])
		if not rule.get("pierce", false):
			break
	return result


func _hit_player(victim: Player, attacker: Player, damage: float, weapon_name: String) -> void:
	if damage <= 0.0:
		return
	var who := attacker.display_name if attacker != null else "某人"
	var cause := "被%s的 %s（%s）打死了" % [Session.SQUAD_NAMES[attacker.squad], who, weapon_name] if attacker != null \
		else "被%s打死了" % weapon_name
	MonsterKit.tell(victim, &"remote_damage", [damage, cause, "你被 %s 的%s打中了！" % [who, weapon_name]])
	if attacker != null:
		MonsterKit.tell(attacker, &"remote_hit", [damage, "player"])


## The first monster in a narrow cone in front of a tesla gun (it arcs to it).
func _arc_target(origin: Vector3, direction: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_score := -INF
	for monster in live_monsters():
		if not monster is Node3D or monster.is_queued_for_deletion():
			continue
		var to: Vector3 = _chest(monster) - origin
		var along := direction.dot(to.normalized())
		if to.length() > reach or along < ARC_CONE or not MonsterKit.clear_line(get_world_3d(), origin, origin + to):
			continue
		var score := along * 10.0 - to.length() * 0.2
		if score > best_score:
			best_score = score
			best = monster
	return best


func _nearest_monster(from: Vector3, reach: float, skip: Array) -> Node3D:
	var best: Node3D = null
	var best_distance := reach
	for monster in live_monsters():
		if not monster is Node3D or monster in skip or monster.is_queued_for_deletion():
			continue
		var distance := from.distance_to(_chest(monster))
		if distance < best_distance and MonsterKit.clear_line(get_world_3d(), from, _chest(monster)):
			best_distance = distance
			best = monster
	return best


## The monsters in the run (not the spawner or sounds that land under the same root).
func live_monsters() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in monsters_root.get_children():
		if node is Node3D and node.has_meta("kind") and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _chest(monster: Node3D) -> Vector3:
	var box: Array = SIZE_BOX[_size_of(monster)]
	return monster.global_position + Vector3.UP * minf(float(box[1]) * 0.5, 1.4)


## Small and medium monsters can die: the monster's own host_kill() decides how (the
## child runs off to play elsewhere), otherwise it is gone.
func _kill_monster(monster: Node3D) -> void:
	awakening.host_kill(monster.global_position)
	if monster is Mimic:
		monster.host_action("kill", null)
	elif monster.has_method("host_kill"):
		monster.host_kill()
	else:
		_monster_died.rpc(monster.global_position)
		monster.queue_free()


@rpc("authority", "call_local", "reliable")
func _monster_died(pos: Vector3) -> void:
	Sfx.play_3d(self, pos, "screech", -2.0, 30.0, 1.6)
	ShotFx.impact(self, pos + Vector3.UP * 0.5, Color(0.6, 0.08, 0.06), 20)


func _size_of(monster: Node) -> String:
	return MonsterRoster.MONSTERS.get(monster.get_meta("kind", ""), {}).get("size", "medium")


func _wall_point(origin: Vector3, direction: Vector3, reach: float) -> Vector3:
	var hit := _wall_hit(origin, direction, reach)
	return hit.position if not hit.is_empty() else origin + direction * reach


## The first piece of level geometry along a line (players are see-through).
func _wall_hit(origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var to := origin + direction * reach
	var exclude: Array[RID] = []
	for attempt in 4:
		var query := PhysicsRayQueryParameters3D.create(origin, to, Layers.WORLD | Layers.WALKWAY, exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		if hit.collider is Player:
			exclude.append(hit.rid)
			continue
		return hit
	return {}


## Every peer: the bang, the muzzle flash at the shooter's gun, tracers and sparks.
@rpc("authority", "call_local", "unreliable")
func _shot_fx(shooter_name: String, frame: String, kind: String, quiet: bool, segments: Array, impacts: Array, lure: bool) -> void:
	var shooter := players_root.get_node_or_null(shooter_name) as Player if shooter_name != "" else null
	var muzzle: Vector3 = segments[0][0] if not segments.is_empty() else Vector3.ZERO
	var aim := Vector3.FORWARD
	if shooter != null:
		muzzle = shooter.muzzle_position()
		aim = shooter.look_direction()
	if not segments.is_empty():
		aim = ((segments[0][1] as Vector3) - (segments[0][0] as Vector3)).normalized()
	ShotFx.fire_sound(self, muzzle, frame, quiet)
	var own := shooter != null and shooter == local_player
	if own:
		awakening.shot_woke.emit(0.4 if quiet else 1.0)  # the HUD's eye flinches
	if not own and kind != "cone":
		ShotFx.muzzle_flash(self, muzzle, aim, Color(0.6, 0.85, 1.0) if kind == "arc" else Color(1.0, 0.75, 0.3))
	match kind:
		"cone":
			ShotFx.flames(self, muzzle, aim, (segments[0][0] as Vector3).distance_to(segments[0][1]) if not segments.is_empty() else 6.0)
		"arc":
			var points := [muzzle]
			for segment in segments:
				points.append(segment[1])
			ShotFx.arc(self, points)
		"bounce":
			var path := [muzzle]
			for segment in segments:
				path.append(segment[1])
			ShotFx.saw(self, path)
			for at in impacts:
				ShotFx.impact(self, at, Color(1.0, 0.9, 0.6), 6)
		"lob":
			pass
		_:
			var color := Color(0.6, 0.9, 1.0) if kind == "charge" else (Color(0.8, 1.0, 1.0, 0.7) if frame == "bubble_gun" else Color(1.0, 0.85, 0.5))
			var width := 0.07 if kind == "charge" else (0.03 if frame in ["harpoon", "crossbow"] else 0.016)
			for segment in segments:
				var end: Vector3 = segment[1]
				var from := muzzle
				# Your own tracer starts a little out from the barrel so it doesn't fill the screen.
				if own:
					from = muzzle + (end - muzzle).normalized() * minf(1.2, muzzle.distance_to(end) * 0.5)
				ShotFx.tracer(self, from, end, color, width, 0.3 if kind == "charge" else 0.07)
			for at in impacts:
				ShotFx.impact(self, at, Color(1.0, 0.8, 0.4), 4)
	if lure:
		for at in impacts:
			Sfx.play_3d(self, at, "chime", -2.0, 35.0, 1.8)


## Every peer: the monster that was hit flashes and sprays a little.
@rpc("authority", "call_local", "unreliable")
func _monster_hit_fx(monster_name: String, point: Vector3, result: String) -> void:
	var monster := monsters_root.get_node_or_null(monster_name)
	ShotFx.flash_monster(monster, result)
	if result == "blocked":
		ShotFx.impact(self, point, Color(0.8, 0.85, 0.9), 6)
		Sfx.play_3d(self, point, "clank", -6.0, 20.0, 1.8)
	else:
		ShotFx.impact(self, point, Color(0.55, 0.05, 0.04), 7)


## Every peer: a burning or bubbled monster shows it.
@rpc("authority", "call_local", "reliable")
func _status_fx(monster_name: String, status: String, seconds: float) -> void:
	var monster := monsters_root.get_node_or_null(monster_name) as Node3D
	if monster == null:
		return
	if status == "burn":
		ShotFx.attach_burn(monster, seconds)
	else:
		var box: Array = SIZE_BOX[_size_of(monster)]
		ShotFx.attach_bubble(monster, seconds, float(box[0]) * 1.4)
		Sfx.play_3d(self, monster.global_position, "tink", -4.0, 15.0, 2.6)


## A launched duck: every peer simulates its own copy; the host's copy explodes for real.
@rpc("authority", "call_local", "reliable")
func _throw_duck(origin: Vector3, velocity: Vector3, damage: float, radius: float, effects: Dictionary, shooter: int) -> void:
	var duck := RubberDuck.new()
	duck.damage = damage
	duck.radius = radius
	duck.effects = effects
	duck.shooter = shooter
	add_child(duck)
	duck.global_position = origin
	duck.linear_velocity = velocity


## Host: something went off. Hurts monsters and scavengers alike (teammates too).
func host_explode(pos: Vector3, damage := 90.0, radius := 4.0, effects := {}, attacker: Player = null) -> void:
	var blast := effects.duplicate()
	blast.erase("explode")
	blast.erase("bullet")
	blast.erase("pierce")
	blast["explode"] = 0.0
	blast["knock"] = 2.0
	for monster in live_monsters():
		if not monster is Node3D or monster.is_queued_for_deletion():
			continue
		var distance: float = (monster as Node3D).global_position.distance_to(pos)
		if distance < radius + 0.5 and MonsterKit.clear_line(get_world_3d(), pos + Vector3.UP * 0.3, _chest(monster)):
			var falloff := 1.0 - 0.5 * clampf(distance / radius, 0.0, 1.0)
			host_damage_monster(monster, damage * falloff, blast, pos, attacker)
	for player in all_players():
		var chest := player.global_position + Vector3.UP
		var distance := chest.distance_to(pos)
		if player.is_active() and distance < radius and MonsterKit.clear_line(get_world_3d(), pos + Vector3.UP * 0.3, chest):
			var falloff := 1.0 - 0.5 * clampf(distance / radius, 0.0, 1.0)
			var cause := "被爆炸炸死了"
			if attacker != null and attacker != player:
				cause = "被 %s 的爆炸炸死了" % attacker.display_name
			MonsterKit.tell(player, &"remote_damage", [damage * falloff * PVP_SCALE * 0.8, cause, "被爆炸波及了！"])
			var push := (chest - pos).normalized() * 6.0 * falloff + Vector3.UP * 2.0
			MonsterKit.tell(player, &"remote_push", [push])
	GameNoise.emit_local(get_tree(), pos, 40.0, GameNoise.Kind.IMPACT)
	_explosion_fx.rpc(pos, radius)


@rpc("authority", "call_local", "reliable")
func _explosion_fx(pos: Vector3, radius: float) -> void:
	Sfx.play_3d(self, pos, "boom", 6.0, 70.0)
	ShotFx.explosion(self, pos, radius)
	if local_player != null and local_player.global_position.distance_to(pos) < radius * 4.0:
		local_player.add_shake(0.5)


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
	host_spawn_monster(kinds[rng.randi_range(0, kinds.size() - 1)], _far_patrol_point())


@rpc("any_peer", "call_local", "reliable")
func _pull_lever() -> void:
	if _is_host() and not level.lever.is_pulled:
		_lever_pulled.rpc()


@rpc("authority", "call_local", "reliable")
func _lever_pulled() -> void:
	level.lever.play_pull()
	level.complete_objective()
	if _is_host():
		awakening.add(Awakening.OBJECTIVE, level.lever.global_position)
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
	# Organs are never sold: they go into the stash as gun parts.
	var haul := Organs.split(local_player.take_all_items())
	var payout := LootTable.payout(haul.rest, rng)
	var gear := local_player.remaining_gear()
	gear.append_array(haul.organs)
	local_player.set_extracted()
	GameState.record_extraction(payout.total, gear)
	Session.instance.report_finished(payout.total)
	local_finished.emit({"survived": true, "items": payout.items_list, "payout": payout, "cause": "", "lost_gear": [],
		"organs": haul.organs})


## The dreamcore map woke this player up: out you go, but half your loot stays in the dream.
func local_woken() -> void:
	if finished or local_player == null:
		return
	var kept: Array[Dictionary] = []
	var items := local_player.items.duplicate()
	items.shuffle()
	for i in items.size() / 2:
		kept.append(items[i])
	local_player.items.assign(kept)
	local_player.message.emit("有人把你叫醒了。你手上的東西少了一半。")
	local_extracted()


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
