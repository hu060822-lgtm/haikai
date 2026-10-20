class_name Traps
## The trap catalogue and the one place maps make traps from. Every peer builds the map
## from the same seed and calls create() with the same arguments, so each trap comes out
## identical (and at the same node path, which its RPCs rely on). Only the host sets
## traps off; see Trap for how state and effects travel.
##
## Placement: pos is the trap's footprint centre on the floor, yaw_deg turns it. Kinds
## marked "doorway" go across a doorway (pos at the doorway centre, yaw along the wall:
## 0 for a wall running along world x, 90 for one along z; params.width = the opening).
## "wall": "back" kinds read best with their back to a wall (local +z faces the room).

const KINDS := {
	"bear_trap": {"name": "捕獸夾", "styles": ["any"], "footprint": Vector2(0.5, 0.5), "script": "res://scripts/traps/bear_trap.gd"},
	"tripwire": {"name": "絆線警報", "styles": ["any"], "footprint": Vector2(1.6, 0.3), "doorway": true,
		"params": {"width": 1.6}, "script": "res://scripts/traps/tripwire.gd"},
	"debris_plate": {"name": "壓力板沙包", "styles": ["any"], "footprint": Vector2(1.8, 1.8),
		"params": {"ceiling": 5.6}, "script": "res://scripts/traps/debris_plate.gd"},
	"steam_vent": {"name": "蒸氣噴口", "styles": ["factory"], "footprint": Vector2(1.5, 1.5), "script": "res://scripts/traps/steam_vent.gd"},
	"live_puddle": {"name": "漏電積水", "styles": ["factory"], "footprint": Vector2(1.9, 1.9), "script": "res://scripts/traps/live_puddle.gd"},
	"alarm_gate": {"name": "防盜感應門", "styles": ["mall"], "footprint": Vector2(1.7, 0.5), "doorway": true,
		"params": {"width": 1.6}, "script": "res://scripts/traps/alarm_gate.gd"},
	"tipping_shelf": {"name": "傾倒的貨架", "styles": ["mall"], "footprint": Vector2(1.6, 2.4), "wall": "back",
		"script": "res://scripts/traps/tipping_shelf.gd"},
	"thin_ice": {"name": "薄冰", "styles": ["station"], "footprint": Vector2(1.7, 1.7), "script": "res://scripts/traps/thin_ice.gd"},
	"icicles": {"name": "冰柱", "styles": ["station"], "footprint": Vector2(1.5, 1.0),
		"script": "res://scripts/traps/icicles.gd"},
	"music_box": {"name": "自己會響的音樂盒", "styles": ["dream"], "footprint": Vector2(0.3, 0.3), "script": "res://scripts/traps/music_box.gd"},
	"squeak_floor": {"name": "會叫的軟地墊", "styles": ["dream"], "footprint": Vector2(1.6, 1.6), "script": "res://scripts/traps/squeak_floor.gd"},
}

const STYLES := ["factory", "mall", "station", "dream", "any"]


## Builds a trap of `kind` at pos (map space), adds it under `map` and lists it in
## map.traps when the map has that array. Deterministic in its arguments.
static func create(kind: String, map: GameMap, pos: Vector3, yaw_deg: float, seed: int, params := {}) -> Node3D:
	assert(KINDS.has(kind), "unknown trap kind %s" % kind)
	var info: Dictionary = KINDS[kind]
	var trap: Trap = load(info.script).new()
	trap.kind = kind
	trap.map = map
	var merged: Dictionary = info.get("params", {}).duplicate()
	merged.merge(params, true)
	trap.params = merged
	trap.rng.seed = seed
	trap.position = pos
	trap.rotation.y = deg_to_rad(yaw_deg)
	var list = map.get("traps")
	var index: int = list.size() if list is Array else map.get_child_count()
	trap.name = "Trap%d_%s" % [index, kind]
	map.add_child(trap)
	if list is Array:
		list.append(trap)
	return trap


## Trap kinds that suit a map style: its own kinds plus the ones that fit anywhere
## ("any" alone gives just those).
static func kinds_for(map_style: String) -> Array[String]:
	var result: Array[String] = []
	for kind in KINDS:
		var styles: Array = KINDS[kind].styles
		if map_style in styles or "any" in styles:
			result.append(kind)
	return result
