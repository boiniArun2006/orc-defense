class_name GroundLayer
extends Node2D
## Static map background: tiled biome ground, a stamped path, scattered decorations,
## and a dark border frame so the map doesn't look flat/dull. Drawn ONCE (behind
## everything) for performance.

var battle: Node
var biome := "grass"
var decos: Array = []
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
	# 1) tiled biome ground over a generous area
	if _ground != null:
		var x := -384.0
		while x < 1728.0:
			var y := -384.0
			while y < 1152.0:
				draw_texture_rect(_ground, Rect2(x, y, TILE, TILE), false)
				y += TILE
			x += TILE
	else:
		draw_rect(Rect2(Vector2(-400, -400), Vector2(2080, 1520)), Color(0.16, 0.34, 0.16))

	# 2) the road: a soft dark under-stroke, then stamped path tiles for texture
	var pts: PackedVector2Array = battle.path_points
	if pts.size() >= 2:
		draw_polyline(pts, Color(0, 0, 0, 0.18), 58.0)
		if _path != null:
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var n := int(a.distance_to(b) / 22.0) + 1
				for j in range(n + 1):
					var p: Vector2 = a.lerp(b, float(j) / n)
					draw_texture_rect(_path, Rect2(p - Vector2(26, 26), Vector2(52, 52)), false)

	# 3) decorations (bushes/trees/rocks) off the road
	for d in decos:
		var t: Texture2D = Assets.tex(d["kind"])
		if t != null:
			var s := 40.0
			draw_texture_rect(t, Rect2(d["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), false)

	# 4) the orc cave at the path entrance — the horde pours out of here,
	#    instead of materialising out of thin air
	if pts.size() > 0:
		_draw_cave(pts[0])

	# 5) a framed border so the arena reads as a designed level, not a flat field
	var m := 8.0
	var frame := Rect2(m, m, 1280.0 - 2 * m, 720.0 - 2 * m)
	draw_rect(frame, Color(0.08, 0.06, 0.05, 0.9), false, 10.0)
	draw_rect(Rect2(m + 6, m + 6, 1280.0 - 2 * m - 12, 720.0 - 2 * m - 12),
		Color(1, 1, 1, 0.06), false, 2.0)


func _draw_cave(p: Vector2) -> void:
	# rocky mound with a dark mouth (all code-drawn, no extra art needed)
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
