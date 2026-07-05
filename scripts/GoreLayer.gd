class_name GoreLayer
extends Node2D
## Battlefield juice drawn in ONE canvas item (mobile-cheap): lingering corpses,
## blood splats, and floating damage numbers. Everything is capped so a 200-orc
## massacre can't blow up draw time or memory. Sits between the ground and units.

const MAX_CORPSES := 220
const MAX_SPLATS := 320
const MAX_NUMBERS := 30
const CORPSE_LIFE := 22.0        # seconds a corpse lingers before fading out
const NUMBER_LIFE := 0.7

# blobby splat polygon, scaled/rotated per splat so no two look identical
var SPLAT_POLY := PackedVector2Array([
	Vector2(6, 0), Vector2(4, 4), Vector2(0, 6), Vector2(-3, 3),
	Vector2(-6, 1), Vector2(-4, -3), Vector2(-1, -6), Vector2(3, -4),
])

var _corpses: Array = []         # {pos, rot, scale, boss, t}
var _splats: Array = []          # {pos, rot, size, a}
var _numbers: Array = []         # {pos, txt, t, col}
var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/ui.ttf")
	# draw order comes from tree position: ground -> gore -> world (units on top)


## Called by Enemy.take_damage on every hit.
func add_hit(pos: Vector2, amount: float, killed: bool) -> void:
	if killed or randf() < 0.22:
		_add_splat(pos, killed)
	if (killed or amount >= 15.0) and _numbers.size() < MAX_NUMBERS:
		var col := Color(1.0, 0.85, 0.25) if killed else Color(1.0, 0.45, 0.3)
		_numbers.append({
			"pos": pos + Vector2(randf_range(-8, 8), -18),
			"txt": str(int(round(amount))), "t": 0.0, "col": col,
		})


## Called by Battle when an orc dies: leave a body on the field.
func add_corpse(pos: Vector2, boss: bool) -> void:
	if _corpses.size() >= MAX_CORPSES:
		_corpses.pop_front()
	_corpses.append({
		"pos": pos, "rot": randf_range(-PI * 0.6, PI * 0.6) + (PI * 0.5 if randf() < 0.5 else -PI * 0.5),
		"scale": (3.4 if boss else 2.0) * randf_range(0.9, 1.05),
		"boss": boss, "t": 0.0,
	})


func _add_splat(pos: Vector2, big: bool) -> void:
	if _splats.size() >= MAX_SPLATS:
		_splats.pop_front()
	_splats.append({
		"pos": pos + Vector2(randf_range(-6, 6), randf_range(-2, 8)),
		"rot": randf() * TAU,
		"size": randf_range(1.6, 2.6) * (1.6 if big else 1.0),
		"a": randf_range(0.5, 0.75),
	})


func _process(delta: float) -> void:
	var dirty := false
	for c in _corpses:
		c.t += delta
	while not _corpses.is_empty() and _corpses[0].t > CORPSE_LIFE:
		_corpses.pop_front()
		dirty = true
	if not _numbers.is_empty():
		for n in _numbers:
			n.t += delta
		_numbers = _numbers.filter(func(n): return n.t < NUMBER_LIFE)
		dirty = true
	if dirty or not _corpses.is_empty():
		queue_redraw()


func _draw() -> void:
	# blood splats (dark red blobs, oldest first)
	for s in _splats:
		draw_set_transform(s.pos, s.rot, Vector2.ONE * s.size)
		draw_colored_polygon(SPLAT_POLY, Color(0.42, 0.04, 0.04, s.a))
	# corpses: the orc sprite toppled sideways, desaturated, fading out at end of life
	var tex: Texture2D = Assets.tex("orc")
	var boss_tex: Texture2D = Assets.tex("orc_boss")
	for c in _corpses:
		var fade: float = clamp((CORPSE_LIFE - c.t) / 3.0, 0.0, 1.0) * 0.85
		var t: Texture2D = boss_tex if c.boss else tex
		if t == null:
			continue
		draw_set_transform(c.pos, c.rot, Vector2.ONE * c.scale)
		draw_texture(t, -t.get_size() * 0.5, Color(0.55, 0.42, 0.42, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# floating damage numbers (rise + fade)
	if _font == null:
		return
	for n in _numbers:
		var k: float = n.t / NUMBER_LIFE
		var col: Color = n.col
		col.a = 1.0 - k * k
		var p: Vector2 = n.pos + Vector2(0, -26.0 * k)
		draw_string_outline(_font, p, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, 4, Color(0, 0, 0, col.a))
		draw_string(_font, p, n.txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 17, col)
