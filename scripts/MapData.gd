class_name MapData
extends RefCounted
## Generates 24+ distinct maps as DATA (no downloaded map images). Each level maps
## to one layout+biome deterministically, so progression shows constant variety.
##
## A map = { path: PackedVector2Array (waypoints, entering off-screen, ending at
## the gate), biome: "grass"|"desert"|"stone", decos: Array[{pos,kind}] }.

const BIOMES := ["grass", "desert", "stone"]
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
	return {"path": path, "biome": biome, "decos": _decos(idx, path)}


# Horizontal snake: rows swept left<->right, connected by vertical hops.
static func _serpentine_h(rows: int, start_left: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var lane_h := (MARGIN_BOT - MARGIN_TOP) / float(max(1, rows - 1))
	var left := start_left
	pts.append(Vector2(-60, MARGIN_TOP))
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
	pts.append(Vector2(MARGIN_X, -60))
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
	pts.append(Vector2(x0 - dirx * 190.0, -60))
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
	pts.append(Vector2(x, -60))
	pts.append(Vector2(x, MARGIN_TOP))
	for i in range(steps):
		x = clampf(x + dirx * stepx, MARGIN_X, W - MARGIN_X)
		pts.append(Vector2(x, MARGIN_TOP + i * stepy))
		pts.append(Vector2(x, MARGIN_TOP + (i + 1) * stepy))
	return pts


# Scatter a few decorations off the path, deterministically per level.
static func _decos(seed_i: int, path: PackedVector2Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_i
	var kinds := ["bush", "tree", "rock", "rock2"]
	var out: Array = []
	var tries := 0
	while out.size() < 10 and tries < 60:
		tries += 1
		var p := Vector2(rng.randf_range(60, W - 60), rng.randf_range(60, H - 130))
		if _dist_to_path(p, path) < 60.0:
			continue    # keep decorations off the road
		out.append({"pos": p, "kind": kinds[rng.randi() % kinds.size()]})
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
