class_name MapData
extends RefCounted
## Generates 24+ distinct maps as DATA (no downloaded map images). Each level maps
## to one layout+biome deterministically, so progression shows constant variety.
##
## A map = {
##   path:  PackedVector2Array (waypoints, entering off-screen, ending at the gate)
##   biome: "grass"|"desert"|"stone"
##   decos: Array[{pos, kind, scale}]      — trees/bushes/rocks, partly clustered
##   ponds: Array[{pos, r}]                — small lakes for visual depth
##   tufts: Array[{pos, kind}]             — tiny painted details (grass/flowers/pebbles)
## }

const BIOMES := ["grass", "desert", "stone"]
const BIOME_NAMES := {"grass": "Greenwood", "desert": "Scorched Sands", "stone": "Grey Hollow"}
const W := 1280.0
const H := 720.0
const MARGIN_X := 130.0
const MARGIN_TOP := 110.0
const MARGIN_BOT := 560.0     # keep gates/path clear of the bottom deploy bar


static func get_for_level(level: int) -> Dictionary:
	var idx: int = max(0, level - 1)
	var biome: String = BIOMES[idx % BIOMES.size()]
	var shape: int = idx % 4
	var lanes: int = 3 + (idx / 4) % 3            # 3..5 lanes -> more/denser paths
	var path: PackedVector2Array
	match shape:
		0: path = _serpentine_h(lanes, idx % 2 == 0)
		1: path = _serpentine_v(lanes, idx % 2 == 0)
		2: path = _zigzag(lanes + 1, idx % 2 == 0)
		_: path = _stairs(lanes + 2, idx % 2 == 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + idx
	return {
		"path": path,
		"biome": biome,
		"decos": _decos(rng, path),
		"ponds": _ponds(rng, path),
		"tufts": _tufts(rng, path, biome),
	}


static func biome_name(biome: String) -> String:
	return BIOME_NAMES.get(biome, biome.capitalize())


# Horizontal snake: rows swept left<->right, connected by vertical hops.
static func _serpentine_h(rows: int, start_left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lane_h := (MARGIN_BOT - MARGIN_TOP) / float(max(1, rows - 1))
	var left := start_left
	# spawn INSIDE the arena so the orc cave (drawn at path[0]) is visible
	pts.append(Vector2(52, MARGIN_TOP))
	for i in range(rows):
		var y := MARGIN_TOP + i * lane_h
		if left:
			pts.append(Vector2(MARGIN_X, y)); pts.append(Vector2(W - MARGIN_X, y))
		else:
			pts.append(Vector2(W - MARGIN_X, y)); pts.append(Vector2(MARGIN_X, y))
		left = not left
	return pts


# Vertical snake: columns swept top<->bottom.
static func _serpentine_v(cols: int, start_top: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lane_w := (W - 2 * MARGIN_X) / float(max(1, cols - 1))
	var top := start_top
	pts.append(Vector2(MARGIN_X, 52))
	for i in range(cols):
		var x := MARGIN_X + i * lane_w
		if top:
			pts.append(Vector2(x, MARGIN_TOP)); pts.append(Vector2(x, MARGIN_BOT))
		else:
			pts.append(Vector2(x, MARGIN_BOT)); pts.append(Vector2(x, MARGIN_TOP))
		top = not top
	return pts


# Diagonal zig-zag from a corner to the opposite side.
static func _zigzag(steps: int, from_left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lane_w := (W - 2 * MARGIN_X) / float(steps)
	var x0: float = MARGIN_X if from_left else W - MARGIN_X
	var dirx: float = 1.0 if from_left else -1.0
	pts.append(Vector2(clampf(x0 - dirx * 80.0, 52.0, W - 52.0), 52))
	var hi := true
	for i in range(steps + 1):
		var x := x0 + dirx * lane_w * i
		x = clampf(x, MARGIN_X, W - MARGIN_X)
		pts.append(Vector2(x, MARGIN_TOP if hi else MARGIN_BOT))
		hi = not hi
	return pts


# Descending staircase (short horizontal + vertical steps).
static func _stairs(steps: int, from_left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var stepx := (W - 2 * MARGIN_X) / float(steps)
	var stepy := (MARGIN_BOT - MARGIN_TOP) / float(steps)
	var x: float = MARGIN_X if from_left else W - MARGIN_X
	var dirx: float = 1.0 if from_left else -1.0
	pts.append(Vector2(x, 52))
	pts.append(Vector2(x, MARGIN_TOP))
	for i in range(steps):
		x = clampf(x + dirx * stepx, MARGIN_X, W - MARGIN_X)
		pts.append(Vector2(x, MARGIN_TOP + i * stepy))
		pts.append(Vector2(x, MARGIN_TOP + (i + 1) * stepy))
	return pts


# Decorations: some scattered singles + a few natural-looking clusters
# (tree groves, rock fields), always kept off the road.
static func _decos(rng: RandomNumberGenerator, path: PackedVector2Array) -> Array:
	var kinds := ["bush", "bush2", "tree", "tree_big", "tree_big", "plant", "rock", "rock2", "rock3"]
	var out: Array = []
	# 1) clusters: pick 3-4 anchor points and sprinkle 3-5 decos around each
	var clusters := 3 + rng.randi() % 2
	var tries := 0
	while clusters > 0 and tries < 80:
		tries += 1
		var anchor := Vector2(rng.randf_range(90, W - 90), rng.randf_range(90, H - 150))
		if _dist_to_path(anchor, path) < 110.0:
			continue
		var kind: String = kinds[rng.randi() % kinds.size()]
		var n := 3 + rng.randi() % 3
		for i in range(n):
			var p := anchor + Vector2(rng.randf_range(-70, 70), rng.randf_range(-55, 55))
			if _dist_to_path(p, path) < 58.0 or p.x < 55 or p.x > W - 55 or p.y < 55 or p.y > H - 120:
				continue
			out.append({"pos": p, "kind": kind, "scale": rng.randf_range(0.75, 1.35)})
		clusters -= 1
	# 2) scattered singles for variety
	tries = 0
	var singles := 10
	while singles > 0 and tries < 90:
		tries += 1
		var p := Vector2(rng.randf_range(60, W - 60), rng.randf_range(60, H - 130))
		if _dist_to_path(p, path) < 58.0:
			continue
		out.append({"pos": p, "kind": kinds[rng.randi() % kinds.size()],
			"scale": rng.randf_range(0.7, 1.3)})
		singles -= 1
	# draw order: top-most first so lower decos overlap naturally
	out.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	return out


# 0-2 small ponds per map, kept well away from the road.
static func _ponds(rng: RandomNumberGenerator, path: PackedVector2Array) -> Array:
	var out: Array = []
	var want := rng.randi() % 3
	var tries := 0
	while out.size() < want and tries < 50:
		tries += 1
		var p := Vector2(rng.randf_range(160, W - 160), rng.randf_range(150, H - 190))
		var r := rng.randf_range(46, 78)
		if _dist_to_path(p, path) < r + 70.0:
			continue
		out.append({"pos": p, "r": r})
	return out


# Tiny painted details: grass tufts + flowers (grass), pebbles (stone),
# ripples/bones (desert). Cheap draws, huge boost in ground detail.
static func _tufts(rng: RandomNumberGenerator, path: PackedVector2Array, _biome: String) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < 60 and tries < 160:
		tries += 1
		var p := Vector2(rng.randf_range(40, W - 40), rng.randf_range(40, H - 110))
		if _dist_to_path(p, path) < 42.0:
			continue
		out.append({"pos": p, "kind": rng.randi() % 3})
	return out


static func _dist_to_path(p: Vector2, path: PackedVector2Array) -> float:
	var best := INF
	for i in range(path.size() - 1):
		best = min(best, _seg_dist(p, path[i], path[i + 1]))
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 == 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
