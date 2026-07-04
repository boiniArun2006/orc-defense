class_name BattleWorld
extends Node2D
## Per-frame overlay in the camera-transformed layer: the gate marker and the
## turret placement/aim preview. The static map is drawn once by GroundLayer.

var battle: Node


func _draw() -> void:
	if battle == null:
		return
	# gate marker
	var g: Vector2 = battle.gate_pos
	draw_circle(g, 32.0, Color(0.2, 0.3, 0.72))
	draw_arc(g, 32.0, 0.0, TAU, 28, Color(0.85, 0.92, 1.0), 3.0)

	if battle.mode == battle.MODE_PREVIEW or battle.mode == battle.MODE_AIM:
		_draw_ghost()


func _draw_ghost() -> void:
	var def: Dictionary = TurretData.get_def(battle.pending_type)
	var gp: Vector2 = battle.ghost_pos
	var col: Color = def.get("color", Color.WHITE)
	var ok: bool = battle._dist_to_path(gp) >= 40.0
	var tint := Color(col.r, col.g, col.b, 0.5) if ok else Color(1, 0.3, 0.3, 0.5)
	# range ring
	draw_arc(gp, def["range"], 0.0, TAU, 44, Color(1, 1, 1, 0.15), 1.5)
	# ghost turret sprite
	var t: Texture2D = Assets.turret_tex(battle.pending_type)
	if t != null:
		var sz := Vector2(t.get_width(), t.get_height()) * 0.5
		draw_texture_rect(t, Rect2(gp - sz * 0.5, sz), false, tint)
	else:
		draw_rect(Rect2(gp - Vector2(15, 15), Vector2(30, 30)), tint)
	# aim arc preview (guns only, during AIM)
	if battle.mode == battle.MODE_AIM and def["kind"] == "gun":
		var a0: float = battle.aim_dir - battle.aim_half
		var a1: float = battle.aim_dir + battle.aim_half
		var poly := PackedVector2Array([gp])
		for i in range(27):
			var a: float = lerp(a0, a1, i / 26.0)
			poly.append(gp + Vector2(def["range"], 0).rotated(a))
		draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.18))
		draw_line(gp, gp + Vector2(def["range"], 0).rotated(battle.aim_dir), Color(1, 1, 0.5, 0.9), 4.0)
