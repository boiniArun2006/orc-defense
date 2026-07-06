class_name GroundLayer
extends Node2D
## Static map background, drawn ONCE for performance but layered for depth:
##  1. tiled biome ground with per-tile tone variation (kills the flat look)
##  2. tiny painted details: grass tufts, flowers, pebbles
##  3. ponds with banks and highlights
##  4. the orc road: dark edge, stamped tiles, worn centerline
##  5. decorations with drop shadows (trees/bushes/rocks, partly clustered)
##  6. the orc cave at the spawn mouth
##  7. soft vignette + border frame so the arena reads as a designed level

var battle: Node
var biome := "grass"
var decos: Array = []
var ponds: Array = []
var tufts: Array = []
const TILE := 64.0
var _ground: Texture2D
var _path: Texture2D


func _ready() -> void:
	z_index = -10
	var keys: Array = Assets.BIOME_TILES.get(biome, ["grass", "path_grass"])
	_ground = Assets.tex(keys[0])
	_path = Assets.tex(keys[1])
	queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	_draw_ground()
	_draw_tufts()
	for pond in ponds:
		_draw_pond(pond["pos"], pond["r"])
	_draw_road()
	_draw_decos()
	var pts: PackedVector2Array = battle.path_points
	if pts.size() > 0:
		_draw_cave(pts[0])
	_draw_vignette()


func _draw_ground() -> void:
	if _ground == null:
		draw_rect(Rect2(Vector2(-400, -400), Vector2(2080, 1520)), Color(0.16, 0.34, 0.16))
		return
	# per-tile tone variation via a cheap hash -> the ground stops looking flat
	var xi := -6
	while xi < 27:
		var yi := -6
		while yi < 18:
			var h := ((xi * 73856093) ^ (yi * 19349663)) & 1023
			var v := 0.94 + 0.08 * (float(h) / 1023.0)          # 0.94..1.02 brightness
			var warm := 1.0 + 0.02 * (float((h >> 3) & 7) / 7.0) # tiny hue shift
			draw_texture_rect(_ground, Rect2(xi * TILE, yi * TILE, TILE, TILE), false,
				Color(v * warm, v, v))
			yi += 1
		xi += 1


func _draw_tufts() -> void:
	for t in tufts:
		var p: Vector2 = t["pos"]
		var k: int = t["kind"]
		match biome:
			"grass":
				if k == 0:   # grass tuft: three little blades
					var g := Color(0.14, 0.42, 0.16, 0.85)
					draw_line(p, p + Vector2(-3, -7), g, 2.0)
					draw_line(p, p + Vector2(0, -9), g, 2.0)
					draw_line(p, p + Vector2(3, -6), g, 2.0)
				elif k == 1: # flower
					draw_circle(p, 3.2, Color(0.95, 0.85, 0.3, 0.9))
					draw_circle(p, 1.4, Color(0.85, 0.4, 0.2, 0.95))
				else:        # dark grass patch
					draw_circle(p, 5.0, Color(0.16, 0.38, 0.15, 0.35))
			"desert":
				if k == 0:   # wind ripple
					draw_arc(p, 9.0, PI * 0.15, PI * 0.85, 8, Color(0.75, 0.62, 0.42, 0.55), 2.0)
				elif k == 1: # sun-bleached pebble
					draw_circle(p, 2.6, Color(0.88, 0.80, 0.62, 0.9))
				else:        # dry shrub
					var dsh := Color(0.55, 0.48, 0.28, 0.8)
					draw_line(p, p + Vector2(-3, -6), dsh, 1.6)
					draw_line(p, p + Vector2(2, -7), dsh, 1.6)
			_:
				if k == 0:   # pebbles
					draw_circle(p, 2.8, Color(0.52, 0.55, 0.58, 0.85))
					draw_circle(p + Vector2(5, 3), 1.8, Color(0.44, 0.47, 0.50, 0.85))
				elif k == 1: # crack
					draw_line(p, p + Vector2(7, 4), Color(0.30, 0.32, 0.35, 0.6), 1.6)
					draw_line(p + Vector2(7, 4), p + Vector2(11, 2), Color(0.30, 0.32, 0.35, 0.6), 1.4)
				else:        # moss spot
					draw_circle(p, 4.2, Color(0.30, 0.42, 0.28, 0.35))


func _draw_pond(p: Vector2, r: float) -> void:
	# sandy bank -> deep water -> lighter shallows -> sparkle highlights
	draw_circle(p, r + 8.0, Color(0.72, 0.65, 0.45, 0.9))
	draw_circle(p, r, Color(0.18, 0.35, 0.52))
	draw_circle(p + Vector2(-r * 0.15, -r * 0.15), r * 0.72, Color(0.24, 0.44, 0.62))
	draw_arc(p + Vector2(-r * 0.25, -r * 0.3), r * 0.4, PI * 1.1, PI * 1.9, 12,
		Color(0.8, 0.92, 1.0, 0.35), 2.5)
	draw_arc(p + Vector2(r * 0.2, r * 0.25), r * 0.3, PI * 0.1, PI * 0.9, 10,
		Color(0.8, 0.92, 1.0, 0.2), 2.0)


func _draw_road() -> void:
	var pts: PackedVector2Array = battle.path_points
	if pts.size() < 2:
		return
	var w: float = battle.path_width      # wide corridor the horde floods through
	var half := w * 0.5
	var tile := w * 0.55
	# soft dark shoulder so the road sits INTO the ground
	draw_polyline(pts, Color(0, 0, 0, 0.22), w + 8.0)
	# stamped path tiles for texture, laid in rows across the full width
	if _path != null:
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var perp := (b - a).normalized().orthogonal()
			var n := int(a.distance_to(b) / (tile * 0.5)) + 1
			for j in range(n + 1):
				var c: Vector2 = a.lerp(b, float(j) / n)
				# lay 2-3 tiles across the corridor width
				var lanes := int(w / tile) + 1
				for k in range(lanes + 1):
					var off := lerpf(-half, half, float(k) / lanes)
					var p := c + perp * off
					draw_texture_rect(_path, Rect2(p - Vector2(tile, tile) * 0.5, Vector2(tile, tile)), false)
	# worn centerline
	draw_polyline(pts, Color(0, 0, 0, 0.10), w * 0.3)
	# crisp edge strokes give the road definition
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var perp := (b - a).normalized().orthogonal() * half
		draw_line(a + perp, b + perp, Color(0.1, 0.07, 0.04, 0.35), 3.0)
		draw_line(a - perp, b - perp, Color(0.1, 0.07, 0.04, 0.35), 3.0)


func _draw_decos() -> void:
	for d in decos:
		var t: Texture2D = Assets.tex(d["kind"])
		if t == null:
			continue
		var s: float = 40.0 * float(d.get("scale", 1.0))
		var p: Vector2 = d["pos"]
		# drop shadow anchors the deco to the ground (depth!)
		draw_rect(Rect2(p + Vector2(-s * 0.42, s * 0.18), Vector2(s * 0.84, s * 0.3)),
			Color(0, 0, 0, 0.0))  # keep rect path warm-up cheap
		draw_circle(p + Vector2(2, s * 0.28), s * 0.38, Color(0, 0, 0, 0.20))
		draw_texture_rect(t, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), false)


func _draw_cave(p: Vector2) -> void:
	# rocky mound with a dark mouth (all code-drawn, no extra art needed)
	draw_circle(p + Vector2(4, 12), 46.0, Color(0, 0, 0, 0.25))   # mound shadow
	draw_circle(p + Vector2(0, 6), 42.0, Color(0.20, 0.17, 0.15))
	draw_circle(p + Vector2(0, -8), 34.0, Color(0.30, 0.26, 0.23))
	draw_circle(p + Vector2(-16, -20), 16.0, Color(0.34, 0.30, 0.26))
	draw_circle(p + Vector2(14, -18), 13.0, Color(0.27, 0.23, 0.20))
	# pitch-black entrance with a stone arch
	draw_circle(p + Vector2(0, 8), 22.0, Color(0.02, 0.015, 0.015))
	draw_arc(p + Vector2(0, 8), 22.0, PI, TAU, 20, Color(0.44, 0.37, 0.29), 5.0)
	# flanking boulders (reuse deco art)
	var rock: Texture2D = Assets.tex("rock")
	var rock2: Texture2D = Assets.tex("rock2")
	if rock != null:
		draw_texture_rect(rock, Rect2(p + Vector2(-56, -12), Vector2(32, 32)), false)
	if rock2 != null:
		draw_texture_rect(rock2, Rect2(p + Vector2(26, -14), Vector2(32, 32)), false)
	# menacing eyes glowing in the dark
	draw_circle(p + Vector2(-6, 6), 2.6, Color(1, 0.25, 0.15, 0.9))
	draw_circle(p + Vector2(7, 7), 2.6, Color(1, 0.25, 0.15, 0.9))


func _draw_vignette() -> void:
	# layered translucent strips darken the edges -> the middle pops forward
	var w := 1280.0
	var h := 720.0
	for i in range(3):
		var t := 26.0 + i * 22.0
		var a := 0.10 - i * 0.03
		draw_rect(Rect2(0, 0, w, t), Color(0, 0, 0, a))
		draw_rect(Rect2(0, h - t, w, t), Color(0, 0, 0, a))
		draw_rect(Rect2(0, t, t, h - 2 * t), Color(0, 0, 0, a))
		draw_rect(Rect2(w - t, t, t, h - 2 * t), Color(0, 0, 0, a))
	# framed border so the arena reads as a designed level, not a flat field
	var m := 8.0
	draw_rect(Rect2(m, m, w - 2 * m, h - 2 * m), Color(0.08, 0.06, 0.05, 0.9), false, 10.0)
	draw_rect(Rect2(m + 6, m + 6, w - 2 * m - 12, h - 2 * m - 12),
		Color(1, 1, 1, 0.06), false, 2.0)
