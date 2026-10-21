class_name Organs
## 怪物就是零件: monster organs are rare gun parts (Arsenal.PARTS with "organ": true).
## Small and medium monsters drop theirs when they die (DROP_CHANCE, rolled on the host's
## run rng); large ones the first time they are broken. The organ lies at the body as
## loot (tag "organ", data "organ": part id, worth $0): heavy, and some of them alive,
## twitching and making noise. Carried out, it goes into GameState.stash as its part id.
##
## Organ hit effects the host resolves here (Run.host_fire calls host_impact):
##   scream  the hit spot screams: monsters there come to it, not to you
##   lullaby the hit spot plays a lullaby: monsters nearby slow down and listen
##   acid    the hit spot gets an acid puddle that eats monsters (and you) for N seconds

const DROP_CHANCE := 0.7
const LOOT_ID_BASE := 900
const SCREAM_RADIUS := 40.0
const LULLABY_RADIUS := 8.0
const LULLABY_SLOW := 3.0
## Alive organs on the floor twitch every few seconds and wake the place a little.
const TWITCH_NOISE := 9.0
const TWITCH_AWAKEN := 0.6

## How each organ is as loot: kg, size of the lump on the floor (m), extra tags, and how
## the model is turned to lie on the floor ("lie", degrees; a mask lies face up).
const LOOT := {
	"screamer_mask": {"kg": 5.0, "size": Vector3(0.36, 0.16, 0.44), "tags": ["alive", "noisy"], "lie": Vector3(90, 0, 0)},
	"stalker_shadow": {"kg": 6.0, "size": Vector3(0.5, 0.18, 0.6), "tags": ["cold"]},
	"greeter_smile": {"kg": 9.0, "size": Vector3(0.44, 0.2, 0.36), "tags": [], "lie": Vector3(90, 0, 0)},
	"fog_lung": {"kg": 9.0, "size": Vector3(0.5, 0.42, 0.3), "tags": ["noisy", "cold"]},
	"splitter_core": {"kg": 12.0, "size": Vector3(0.5, 0.4, 0.45), "tags": ["alive"]},
	"burrower_drill": {"kg": 22.0, "size": Vector3(0.6, 0.4, 0.9), "tags": ["heavy"]},
	"watcher_eye": {"kg": 18.0, "size": Vector3(0.6, 0.6, 0.9), "tags": ["alive"]},
	"eye_lens": {"kg": 5.0, "size": Vector3(0.5, 0.24, 0.26), "tags": ["alive", "noisy"]},
	"centipede_segment": {"kg": 25.0, "size": Vector3(0.9, 0.55, 0.6), "tags": ["heavy", "alive"]},
	"mimic_shell": {"kg": 5.0, "size": Vector3(0.36, 0.2, 0.44), "tags": ["alive"]},
	"collector_sack": {"kg": 14.0, "size": Vector3(0.5, 0.5, 0.45), "tags": ["noisy"]},
	"knight_door": {"kg": 25.0, "size": Vector3(0.75, 0.2, 1.1), "tags": ["heavy"], "lie": Vector3(90, 0, 0)},
	"mannequin_arm": {"kg": 10.0, "size": Vector3(0.2, 0.2, 0.9), "tags": []},
	"hound_fang": {"kg": 8.0, "size": Vector3(0.44, 0.2, 0.5), "tags": []},
	"dropper_arm": {"kg": 10.0, "size": Vector3(0.24, 0.16, 1.0), "tags": ["alive"]},
	"colossus_heart": {"kg": 25.0, "size": Vector3(0.7, 0.75, 0.65), "tags": ["heavy", "hot", "noisy"]},
	"spitter_sac": {"kg": 8.0, "size": Vector3(0.42, 0.4, 0.42), "tags": ["alive", "hot"]},
	"weaver_gland": {"kg": 7.0, "size": Vector3(0.36, 0.34, 0.6), "tags": []},
	"mother_musicbox": {"kg": 20.0, "size": Vector3(0.6, 0.5, 0.45), "tags": ["heavy", "music"]},
	"rat_spring": {"kg": 5.0, "size": Vector3(0.36, 0.3, 0.42), "tags": ["alive", "noisy"]},
	"tuner_cords": {"kg": 6.0, "size": Vector3(0.6, 0.15, 0.24), "tags": ["noisy"], "lie": Vector3(0, 0, 90)},
	"child_marble": {"kg": 5.0, "size": Vector3(0.34, 0.26, 0.34), "tags": []},
}


## The organ a monster kind drops ("" when none).
static func of_monster(kind: String) -> String:
	return str(MonsterRoster.MONSTERS.get(kind, {}).get("organ", ""))


## The loot an organ makes on the floor (a LootItem's data).
static func loot_data(part_id: String) -> Dictionary:
	var part := Arsenal.part(part_id)
	var look: Dictionary = LOOT.get(part_id, {"kg": 8.0, "size": Vector3(0.4, 0.3, 0.4), "tags": []})
	var tags: Array = ["organ"]
	tags.append_array(look.tags)
	var monster := str(MonsterRoster.MONSTERS.get(part.get("monster", ""), {}).get("name", "怪物"))
	return {
		"id": LOOT_ID_BASE + Arsenal.organ_ids().find(part_id), "name": part.get("name", part_id),
		"rarity": 2, "weight": float(look.kg), "value": 0, "size": look.size, "shape": "organ",
		"texture": "concrete", "color": Color(0.8, 0.3, 0.28), "tags": tags, "pool": false,
		"organ": part_id, "note": "%s的器官。帶出去就能裝到槍上（%s）。" % [monster, Arsenal.SLOT_NAMES.get(part.get("slot", ""), "")],
	}


## The organ's model for the floor, turned the way it lies there.
static func floor_model(part_id: String, size: Vector3) -> Node3D:
	var model := GunModels.organ(part_id, maxf(size.x, maxf(size.y, size.z)))
	model.rotation_degrees = LOOT.get(part_id, {}).get("lie", Vector3.ZERO)
	return model


static func is_organ(data: Dictionary) -> bool:
	return str(data.get("organ", "")) != ""


## Host: a monster died (or a large one was broken): maybe its organ falls out.
## Large monsters give theirs only the first time they break; the others roll DROP_CHANCE.
static func host_drop(run: Run, monster: Node3D, broken: bool) -> LootItem:
	if run == null or monster == null or not is_instance_valid(monster):
		return null
	var part_id := of_monster(str(monster.get_meta("kind", "")))
	if part_id == "" or not Arsenal.PARTS.has(part_id):
		return null
	if broken:
		if monster.get_meta("organ_dropped", false):
			return null
		monster.set_meta("organ_dropped", true)
	elif run.rng.randf() >= DROP_CHANCE:
		return null
	var at := monster.global_position + Vector3.UP * (1.2 if broken else 0.6)
	var spin := Vector3(run.rng.randf_range(-1.0, 1.0), 2.5, run.rng.randf_range(-1.0, 1.0))
	return run.host_spawn_loot(loot_data(part_id), at, run.rng.randf_range(0.0, TAU), false, spin)


## Host: what an organ does where a shot landed (after the damage).
static func host_impact(run: Run, effects: Dictionary, at: Vector3, _attacker: Player) -> void:
	var tree := run.get_tree()
	if effects.get("scream", false):
		GameNoise.emit_local(tree, at, SCREAM_RADIUS, GameNoise.Kind.VOICE)
		run.host_organ_fx("scream", at)
	if effects.get("lullaby", false):
		GameNoise.emit_local(tree, at, 14.0, GameNoise.Kind.MUSIC)
		for monster in run.live_monsters():
			if monster.global_position.distance_to(at) < LULLABY_RADIUS:
				TimeWarp.slow(monster, LULLABY_SLOW)
		run.host_organ_fx("lullaby", at)
	if float(effects.get("acid", 0.0)) > 0.0:
		var floor_at := at
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 4.0, Layers.WORLD | Layers.WALKWAY)
		var hit := run.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			floor_at = hit.position
		run.host_organ_fx("acid", floor_at)


## Every peer: the visible / audible side of an organ effect.
static func play_fx(run: Run, kind: String, at: Vector3) -> void:
	match kind:
		"scream":
			Sfx.play_3d(run, at, "screech", 2.0, 50.0, 1.2)
		"lullaby":
			Sfx.play_3d(run, at, "lullaby", -2.0, 30.0, 1.1)
			ShotFx.impact(run, at, Color(1.0, 0.75, 0.9), 8)
		"acid":
			Sfx.play_3d(run, at, "hiss", 0.0, 25.0, 1.1)
			var puddle := AcidPool.new()
			run.add_child(puddle)
			puddle.global_position = at + Vector3.UP * 0.02


## Splits an extraction haul: organs (part ids, for the stash) and everything else.
static func split(items: Array) -> Dictionary:
	var organs: Array[String] = []
	var rest: Array[Dictionary] = []
	for item: Dictionary in items:
		if is_organ(item):
			organs.append(str(item.organ))
		else:
			rest.append(item)
	return {"organs": organs, "rest": rest}


## Host: an alive organ on the floor twitched.
static func host_twitch(item: Node3D) -> void:
	GameNoise.emit_local(item.get_tree(), item.global_position, TWITCH_NOISE, GameNoise.Kind.ITEM)
	var awakening = Run.instance.get("awakening") if Run.instance != null else null
	if awakening != null:
		awakening.add(TWITCH_AWAKEN, item.global_position)


## The spitter's acid, fired out of a gun: a green puddle that eats monsters standing in
## it (and scavengers: it doesn't know whose side it is on). Smaller than the spitter's.
class AcidPool extends Spitter.AcidPuddle:
	const MONSTER_DPS := 8.0

	var _bite := 0.5

	func _ready() -> void:
		super._ready()
		_life = 8.0

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not multiplayer.is_server() or Run.instance == null or is_queued_for_deletion():
			return
		_bite -= delta
		if _bite > 0.0:
			return
		_bite = 0.5
		for monster in Run.instance.live_monsters():
			var offset := monster.global_position - global_position
			if Vector2(offset.x, offset.z).length() < RADIUS * scale.x + 0.4 and absf(offset.y) < 1.2:
				Run.instance.host_damage_monster(monster, MONSTER_DPS * 0.5, {"acid": 0.0, "dot": true}, global_position)
