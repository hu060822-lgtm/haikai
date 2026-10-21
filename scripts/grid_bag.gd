class_name GridBag
## The backpack is a grid. Every scavenger starts each run with a bag whose cells form a
## random connected shape (a polyomino) of exactly CELLS cells, no bigger than MAX_SIZE,
## rolled from a per-player seed. Every backpack item has a footprint (a few cells, from
## its size, or a hand-drawn L/T shape in FOOTPRINTS); it has to fit somewhere in the
## grid to be carried. Bulky hauls (tag "bulky") are carried in both hands instead.
##
## Where an item sits is stored on the item itself: data.bag = Vector3i(x, y, rotation),
## so whatever takes items out of Player.items (a drop, rats, a living item escaping,
## using it up) frees its cells with no extra bookkeeping.
##
## Every scavenger also has a 保險箱: a fixed BOX_SIZE grid next to the bag. Items in it
## stay in Player.items but sit at data.box instead of data.bag; they are paid out even
## if you die, and nothing steals from it. The functions below take key "box" for it.

const CELLS := 24
const MAX_SIZE := Vector2i(8, 6)
## Every bag grows out of a 3x3 block, so every footprint (all fit in 3x3) fits an empty bag.
const CORE := 3
const NONE := Vector3i(-1, -1, -1)
const STYLES := ["long", "blob", "branchy"]
## The secure container: 2 wide, 3 tall.
const BOX_SIZE := Vector2i(2, 3)

## Hand-drawn footprints for odd shapes ("X" = a cell, one row per line). By item id, or by
## organ id for monster organs. Everything else is a rectangle from its size.
const FOOTPRINTS := {
	26: "XXX\nX..",          # umbrella: shaft and hook
	29: ".X.\n.X.\nXXX",     # mop: stick and head
	32: "XX\nX.",            # toy gun
	49: "X..\nXXX\nX..",     # very big screw: head and shaft
	55: "XX\nXX\nX.",        # cuckoo clock and its pendulum
	58: ".X.\nXXX",          # mini anchor
	73: "XXX\n.XX",          # electric guitar: neck and body
	79: "XXX\n.X.\n.X.",     # trophy: cup and stem
	80: "XXX\n..X",          # brass arm and hand
	82: ".X.\nXXX\n.X.",     # orrery
	83: ".X.\nXXX\nXXX",     # diving helmet
	96: "X.X\nXXX",          # the cradle
	"hound_fang": "XXX\n.X.",
	"mannequin_arm": "XXX\nX..",
	"dropper_arm": "XXX\n..X",
}
## The neon sign letters are shaped like their letter.
const NEON_FOOTPRINTS := {"O": "XX\nXX", "P": "XX\nXX\nX.", "E": "XX\nX.\nXX", "N": "X.\nXX\n.X"}


# --- Bag shapes -------------------------------------------------------------------------

## A random bag: CELLS cells, 4-connected, inside MAX_SIZE, the same for the same seed.
## Grows from a 3x3 core in one of three styles: long (stretches along one axis), blob
## (fills in round), branchy (arms and notches).
static func generate(seed: int) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var style: String = STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var horizontal := rng.randf() < 0.65
	var cells := {}
	var core := Vector2i(rng.randi_range(0, MAX_SIZE.x - CORE), rng.randi_range(0, MAX_SIZE.y - CORE))
	for y in CORE:
		for x in CORE:
			cells[core + Vector2i(x, y)] = true
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	while cells.size() < CELLS:
		var frontier: Array[Vector2i] = []
		var weights: Array[float] = []
		var total := 0.0
		var seen := {}
		var low := Vector2i(MAX_SIZE)
		var high := Vector2i(-1, -1)
		for cell: Vector2i in cells:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		for cell: Vector2i in cells:
			for dir in dirs:
				var next: Vector2i = cell + dir
				if seen.has(next) or cells.has(next) or next.x < 0 or next.y < 0 or next.x >= MAX_SIZE.x or next.y >= MAX_SIZE.y:
					continue
				seen[next] = true
				var touching := 0
				for d in dirs:
					if cells.has(next + d):
						touching += 1
				var w := 1.0
				match style:
					"blob":
						w = 0.3 + float(touching * touching)
					"branchy":
						w = 2.0 if touching == 1 else 1.0
					"long":
						var along: bool = next.x < low.x or next.x > high.x if horizontal else next.y < low.y or next.y > high.y
						var across: bool = next.y < low.y or next.y > high.y if horizontal else next.x < low.x or next.x > high.x
						w = (4.0 if along else 1.0) * (0.15 if across else 1.0)
				frontier.append(next)
				weights.append(w)
				total += w
		var pick := rng.randf() * total
		var chosen: Vector2i = frontier[frontier.size() - 1]
		for i in frontier.size():
			pick -= weights[i]
			if pick <= 0.0:
				chosen = frontier[i]
				break
		cells[chosen] = true
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell)
	return normalized(result)


## The 保險箱's cells: a plain BOX_SIZE rectangle.
static func box_shape() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in BOX_SIZE.y:
		for x in BOX_SIZE.x:
			cells.append(Vector2i(x, y))
	return cells


## Whether an item could go in an empty 保險箱 at all (in some rotation; never bulky).
static func fits_box(data: Dictionary) -> bool:
	return find_spot(box_shape(), [], data, -1, "box") != NONE


## The bag's width and height in cells.
static func extent(shape: Array[Vector2i]) -> Vector2i:
	var size := Vector2i.ZERO
	for cell in shape:
		size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
	return size


static func is_linked(shape: Array[Vector2i]) -> bool:
	if shape.is_empty():
		return false
	var lookup := {}
	for cell in shape:
		lookup[cell] = true
	var reached := {shape[0]: true}
	var queue: Array[Vector2i] = [shape[0]]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = cell + dir
			if lookup.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached.size() == lookup.size()


# --- Footprints -------------------------------------------------------------------------

## The cells an item takes in the backpack, unrotated, with its corner at (0, 0).
static func footprint(data: Dictionary) -> Array[Vector2i]:
	var art := ""
	if data.has("organ") and FOOTPRINTS.has(str(data.organ)):
		art = FOOTPRINTS[str(data.organ)]
	elif int(data.get("id", 0)) == LootTable.NEON_ID:
		art = NEON_FOOTPRINTS.get(str(data.get("letter", "O")), NEON_FOOTPRINTS.O)
	elif FOOTPRINTS.has(int(data.get("id", 0))):
		art = FOOTPRINTS[int(data.get("id", 0))]
	if art != "":
		return parse(art)
	var size: Vector3 = data.get("size", Vector3(0.2, 0.2, 0.2))
	var dims: Array[float] = [size.x, size.y, size.z]
	dims.sort()
	var w := _cells_long(dims[2])
	var h := _cells_short(dims[1])
	var cells: Array[Vector2i] = []
	for y in h:
		for x in w:
			cells.append(Vector2i(x, y))
	return cells


static func _cells_long(metres: float) -> int:
	return 1 if metres <= 0.2 else (2 if metres <= 0.42 else 3)


static func _cells_short(metres: float) -> int:
	return 1 if metres <= 0.25 else (2 if metres <= 0.45 else 3)


static func parse(art: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rows := art.split("\n")
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "X":
				cells.append(Vector2i(x, y))
	return cells


## The footprint turned a quarter-turn clockwise `turns` times, moved back to (0, 0).
## Cells keep their order, so cell i of the result is cell i of the input, turned.
static func rotated(cells: Array[Vector2i], turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = cells.duplicate()
	for i in posmod(turns, 4):
		for j in result.size():
			result[j] = Vector2i(-result[j].y, result[j].x)
	return normalized(result)


static func normalized(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells
	var low := cells[0]
	for cell in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell - low)
	return result


## Footprint size (w, h) of an item at a rotation.
static func footprint_size(data: Dictionary, turns := 0) -> Vector2i:
	return extent(rotated(footprint(data), turns))


# --- Placing ----------------------------------------------------------------------------

## The grid cells an item occupies where it sits now (empty if it has no place in that
## grid: key "bag" for the backpack, "box" for the 保險箱).
static func placed_cells(data: Dictionary, key := "bag") -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not data.has(key):
		return cells
	var at: Vector3i = data[key]
	for cell in rotated(footprint(data), at.z):
		cells.append(Vector2i(at.x, at.y) + cell)
	return cells


## Which item index sits on each cell: {Vector2i: index}. skip leaves one item out.
static func occupancy(items: Array, skip := -1, key := "bag") -> Dictionary:
	var taken := {}
	for i in items.size():
		if i == skip:
			continue
		for cell in placed_cells(items[i], key):
			taken[cell] = i
	return taken


## Whether the footprint, turned and with its corner at origin, fits the bag's free cells.
static func fits(shape: Array[Vector2i], taken: Dictionary, cells: Array[Vector2i], origin: Vector2i) -> bool:
	for cell in cells:
		var at := origin + cell
		if taken.has(at) or not shape.has(at):
			return false
	return true


## Where a new item goes: Vector3i(x, y, turns), or NONE if it fits nowhere. Of every
## place and turn it fits, takes the snuggest one (most of its edges against the bag's
## edge or other loot), so quick pickups pack tight and leave room in one piece; ties go
## to the item's own orientation, then top-left first. skip ignores one carried item
## (the one being moved).
static func find_spot(shape: Array[Vector2i], items: Array, data: Dictionary, skip := -1, key := "bag") -> Vector3i:
	if LootTable.is_bulky(data):
		return NONE
	var taken := occupancy(items, skip, key)
	if shape.size() - taken.size() < footprint(data).size():
		return NONE
	var lookup := {}
	for cell in shape:
		lookup[cell] = true
	var size := extent(shape)
	var tried := []
	var best := NONE
	var best_score := -1
	for turns in 4:
		var cells := rotated(footprint(data), turns)
		if cells in tried:
			continue
		tried.append(cells)
		var own := {}
		for cell in cells:
			own[cell] = true
		for y in size.y:
			for x in size.x:
				var origin := Vector2i(x, y)
				if not fits(shape, taken, cells, origin):
					continue
				var score := 0
				for cell in cells:
					for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
						var next: Vector2i = cell + dir
						if own.has(next):
							continue
						if not lookup.has(origin + next) or taken.has(origin + next):
							score += 1
				if score > best_score:
					best_score = score
					best = Vector3i(x, y, turns)
	return best


## Cells of the bag nothing sits on.
static func free_cells(shape: Array[Vector2i], items: Array, key := "bag") -> int:
	return shape.size() - occupancy(items, -1, key).size()
