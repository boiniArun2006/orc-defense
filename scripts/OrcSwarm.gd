class_name OrcSwarm
extends Node2D
## Data-oriented enemy horde. Instead of one Node2D per orc (which caps out in the
## low hundreds on a phone), ALL orcs live in parallel arrays and render through a
## handful of MultiMeshInstance2D (one per type) — a single draw call each. This is
## what lets thousands of orcs flood the path with no lag.
##
## Stable indices: dead slots are recycled via a free list and a per-slot generation
## counter, so bullets/turrets can hold an (index, gen) reference safely.
##
## Death still fires all the juice: gore.add_hit / add_corpse, blood, damage numbers.

# ---- Enemy types (CC0 Kenney art, styled to match the reference game) ----
# px = on-screen size; small so hundreds pack into a carpet.
const TYPES := {
	"orc":      {"tex": "orc",            "px": 24.0, "tint": Color(0.72, 1.12, 0.60), "hp": 1.0, "spd": 1.0,  "armor": 0.0, "coin": 1, "xp": 1, "gate": 3},
	"slime":    {"tex": "enemy_slime",    "px": 22.0, "tint": Color(0.70, 1.05, 0.65), "hp": 0.7, "spd": 0.95, "armor": 0.0, "coin": 1, "xp": 1, "gate": 2},
	"runner":   {"tex": "orc",            "px": 20.0, "tint": Color(1.05, 1.05, 0.45), "hp": 0.6, "spd": 1.9,  "armor": 0.0, "coin": 1, "xp": 1, "gate": 3},
	"skeleton": {"tex": "enemy_skeleton", "px": 24.0, "tint": Color(0.92, 0.95, 1.0),  "hp": 1.2, "spd": 1.2,  "armor": 1.0, "coin": 2, "xp": 1, "gate": 4},
	"brute":    {"tex": "orc_boss",       "px": 40.0, "tint": Color(0.75, 0.78, 0.98), "hp": 3.4, "spd": 0.55, "armor": 4.0, "coin": 3, "xp": 3, "gate": 8},
	"boss":     {"tex": "orc_boss",       "px": 96.0, "tint": Color(1.0, 0.55, 0.9),   "hp": 1.0, "spd": 1.0,  "armor": 6.0, "coin": 1, "xp": 1, "gate": 25},
}
const TYPE_ORDER := ["orc", "slime", "runner", "skeleton", "brute", "boss"]

var battle: Node                 # back-ref for gore + callbacks

# path geometry (centerline + per-segment direction/perpendicular)
var path: PackedVector2Array
var _seg_dir: Array = []          # Vector2 per segment
var _seg_perp: Array = []
var _seg_len: PackedFloat32Array = PackedFloat32Array()

# ---- Orc arrays (SoA). Index is stable; dead slots recycled. ----
var _pos: Array = []              # Vector2
var _hp: PackedFloat32Array = PackedFloat32Array()
var _maxhp: PackedFloat32Array = PackedFloat32Array()
var _speed: PackedFloat32Array = PackedFloat32Array()
var _armor: PackedFloat32Array = PackedFloat32Array()
var _lateral: PackedFloat32Array = PackedFloat32Array()
var _seg: PackedInt32Array = PackedInt32Array()
var _type: PackedInt32Array = PackedInt32Array()      # index into TYPE_ORDER
var _flip: PackedInt32Array = PackedInt32Array()
var _flash: PackedFloat32Array = PackedFloat32Array()
var _coin: PackedInt32Array = PackedInt32Array()
var _xp: PackedInt32Array = PackedInt32Array()
var _gate: PackedInt32Array = PackedInt32Array()
var _alive: PackedByteArray = PackedByteArray()
var _gen: PackedInt32Array = PackedInt32Array()
var _free: Array = []             # stack of reusable slot indices
var _count := 0                   # alive orcs

# ---- Spatial grid for O(nearby) target queries ----
const CELL := 80.0
var _grid := {}                   # cell key (int) -> Array[int] of alive indices

# ---- Rendering ----
var _mmi := {}                    # type name -> MultiMeshInstance2D
var _mm := {}                     # type name -> MultiMesh


func setup(p: PackedVector2Array) -> void:
	path = p
	_seg_dir.clear(); _seg_perp.clear(); _seg_len = PackedFloat32Array()
	for i in range(path.size() - 1):
		var d: Vector2 = path[i + 1] - path[i]
		var l := d.length()
		var dir := d / l if l > 0.0 else Vector2.RIGHT
		_seg_dir.append(dir)
		_seg_perp.append(dir.orthogonal())
		_seg_len.append(l)
	_build_multimeshes()


func _build_multimeshes() -> void:
	for tname in TYPE_ORDER:
		var d: Dictionary = TYPES[tname]
		var mesh := QuadMesh.new()
		mesh.size = Vector2(d["px"], d["px"])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = 0
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		mmi.texture = Assets.tex(d["tex"])
		add_child(mmi)
		_mm[tname] = mm
		_mmi[tname] = mmi


# ---- Spawn ----
func spawn(type_name: String, level: int, wave: int, width: float) -> void:
	var ti: int = TYPE_ORDER.find(type_name)
	if ti < 0:
		ti = 0
		type_name = "orc"
	var d: Dictionary = TYPES[type_name]
	var base_hp := 14.0 + level * 4.0 + wave * 2.0
	var hp: float = (900.0 + level * 200.0) if type_name == "boss" else base_hp * float(d["hp"])
	var spd: float = (46.0 + level) if type_name == "boss" else (50.0 + level * 2.0) * float(d["spd"])
	var lat: float = 0.0 if type_name == "boss" else randf_range(-width, width) * 0.5

	var idx: int
	if _free.size() > 0:
		idx = _free.pop_back()
		_pos[idx] = path[0] + (_seg_perp[0] if _seg_perp.size() > 0 else Vector2.ZERO) * lat
		_hp[idx] = hp; _maxhp[idx] = hp; _speed[idx] = spd
		_armor[idx] = float(d["armor"]); _lateral[idx] = lat
		_seg[idx] = 0; _type[idx] = ti; _flip[idx] = 0; _flash[idx] = 0.0
		_coin[idx] = int(d["coin"]); _xp[idx] = int(d["xp"]); _gate[idx] = int(d["gate"])
		_alive[idx] = 1
	else:
		idx = _pos.size()
		_pos.append(path[0] + (_seg_perp[0] if _seg_perp.size() > 0 else Vector2.ZERO) * lat)
		_hp.append(hp); _maxhp.append(hp); _speed.append(spd)
		_armor.append(float(d["armor"])); _lateral.append(lat)
		_seg.append(0); _type.append(ti); _flip.append(0); _flash.append(0.0)
		_coin.append(int(d["coin"])); _xp.append(int(d["xp"])); _gate.append(int(d["gate"]))
		_alive.append(1); _gen.append(0)
	_count += 1


# ---- Queries (index + generation refs) ----
func alive_count() -> int:
	return _count


func is_alive(idx: int, gen: int) -> bool:
	return idx >= 0 and idx < _alive.size() and _alive[idx] == 1 and _gen[idx] == gen


func gen_of(idx: int) -> int:
	return _gen[idx] if idx >= 0 and idx < _gen.size() else -1


func pos_of(idx: int) -> Vector2:
	return _pos[idx]


func _cell_key(p: Vector2) -> int:
	var cx := int(floor(p.x / CELL))
	var cy := int(floor(p.y / CELL))
	return (cx + 4096) * 100000 + (cy + 4096)


func nearest(from: Vector2, rng: float) -> int:
	# search the grid cells covered by the range, pick the closest alive orc
	var best := -1
	var best_d := rng * rng
	var r := int(ceil(rng / CELL)) + 1
	var cx := int(floor(from.x / CELL))
	var cy := int(floor(from.y / CELL))
	for ox in range(-r, r + 1):
		for oy in range(-r, r + 1):
			var key := (cx + ox + 4096) * 100000 + (cy + oy + 4096)
			var cell = _grid.get(key)
			if cell == null:
				continue
			for i in cell:
				var dd: float = from.distance_squared_to(_pos[i])
				if dd <= best_d:
					best_d = dd
					best = i
	return best


func query_radius(center: Vector2, rad: float) -> Array:
	var out: Array = []
	var r := int(ceil(rad / CELL)) + 1
	var cx := int(floor(center.x / CELL))
	var cy := int(floor(center.y / CELL))
	var rr := rad * rad
	for ox in range(-r, r + 1):
		for oy in range(-r, r + 1):
			var cell = _grid.get((cx + ox + 4096) * 100000 + (cy + oy + 4096))
			if cell == null:
				continue
			for i in cell:
				if center.distance_squared_to(_pos[i]) <= rr:
					out.append(i)
	return out


# ---- Damage / death (keeps ALL the juice) ----
func damage(idx: int, amount: float) -> void:
	if idx < 0 or idx >= _alive.size() or _alive[idx] == 0:
		return
	var dealt: float = max(1.0, amount - _armor[idx])
	_hp[idx] -= dealt
	_flash[idx] = 0.12
	var killed: bool = _hp[idx] <= 0.0
	if battle != null and battle.gore != null:
		battle.gore.add_hit(_pos[idx], dealt, killed)
	if killed:
		_kill(idx)


func _kill(idx: int) -> void:
	var is_boss: bool = TYPE_ORDER[_type[idx]] == "boss"
	if battle != null:
		if battle.gore != null:
			battle.gore.add_corpse(_pos[idx], is_boss)
		battle._on_orc_died(_coin[idx], _xp[idx], is_boss)
	_free_slot(idx)


func _free_slot(idx: int) -> void:
	_alive[idx] = 0
	_gen[idx] += 1
	_free.append(idx)
	_count -= 1


# ---- Simulation + render ----
func _process(delta: float) -> void:
	if path.size() < 2:
		return
	_grid.clear()
	var last_seg := path.size() - 2
	for i in range(_pos.size()):
		if _alive[i] == 0:
			continue
		var seg: int = _seg[i]
		# target = centerline node + lateral offset along this segment's perpendicular
		var perp: Vector2 = _seg_perp[min(seg, last_seg)]
		var target: Vector2 = path[seg + 1] + perp * _lateral[i]
		var to_t: Vector2 = target - _pos[i]
		var dist := to_t.length()
		var step := _speed[i] * delta
		if dist <= step:
			_pos[i] = target
			_seg[i] += 1
			if _seg[i] >= path.size() - 1:
				if battle != null:
					battle._on_gate_hit(_gate[i])
				_free_slot(i)
				continue
		else:
			var dir := to_t / dist
			_pos[i] += dir * step
			_flip[i] = 1 if dir.x < 0.0 else 0
		if _flash[i] > 0.0:
			_flash[i] = max(0.0, _flash[i] - delta)
		# insert into spatial grid
		var key := _cell_key(_pos[i])
		var cell = _grid.get(key)
		if cell == null:
			_grid[key] = [i]
		else:
			cell.append(i)
	_render()


func _render() -> void:
	# bucket alive orcs by type, then fill each type's MultiMesh in one pass
	var buckets := {}
	for tname in TYPE_ORDER:
		buckets[tname] = []
	for i in range(_pos.size()):
		if _alive[i] == 1:
			buckets[TYPE_ORDER[_type[i]]].append(i)
	for tname in TYPE_ORDER:
		var list: Array = buckets[tname]
		var mm: MultiMesh = _mm[tname]
		mm.instance_count = list.size()
		var tint: Color = TYPES[tname]["tint"]
		var k := 0
		for i in list:
			var sx := -1.0 if _flip[i] == 1 else 1.0
			var xf := Transform2D(0.0, _pos[i])
			xf.x *= sx
			mm.set_instance_transform_2d(k, xf)
			var f: float = _flash[i]
			var col := tint.lerp(Color(1, 1, 1), clamp(f / 0.12, 0.0, 1.0)) if f > 0.0 else tint
			mm.set_instance_color(k, col)
			k += 1
