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

	# 4) a framed border so the arena reads as a designed level, not a flat field
	var m := 8.0
	var frame := Rect2(m, m, 1280.0 - 2 * m, 720.0 - 2 * m)
	draw_rect(frame, Color(0.08, 0.06, 0.05, 0.9), false, 10.0)
	draw_rect(Rect2(m + 6, m + 6, 1280.0 - 2 * m - 12, 720.0 - 2 * m - 12),
		Color(1, 1, 1, 0.06), false, 2.0)
