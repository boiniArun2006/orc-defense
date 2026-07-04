class_name GroundLayer
extends Node2D
## Static map background: tiled grass + a stamped dirt path. Drawn ONCE (not every
## frame) for performance — sits behind all units via a low z_index.

var battle: Node
const TILE := 64.0
var _grass: Texture2D
var _dirt: Texture2D


func _ready() -> void:
	z_index = -10
	_grass = Assets.tex("grass")
	_dirt = Assets.tex("dirt")
	queue_redraw()   # one-shot; nothing calls queue_redraw again


func _draw() -> void:
	if battle == null:
		return
	# tile grass over a generous area so zoom-out never shows void
	if _grass != null:
		var x := -384.0
		while x < 1728.0:
			var y := -384.0
			while y < 1152.0:
				draw_texture_rect(_grass, Rect2(x, y, TILE, TILE), false)
				y += TILE
			x += TILE
	else:
		draw_rect(Rect2(Vector2(-400, -400), Vector2(2080, 1520)), Color(0.16, 0.34, 0.16))

	var pts: PackedVector2Array = battle.path_points
	if pts.size() >= 2:
		draw_polyline(pts, Color(0.42, 0.29, 0.17), 46.0)
		if _dirt != null:
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var n := int(a.distance_to(b) / 24.0) + 1
				for j in range(n + 1):
					var p: Vector2 = a.lerp(b, float(j) / n)
					draw_texture_rect(_dirt, Rect2(p - Vector2(24, 24), Vector2(48, 48)), false)
