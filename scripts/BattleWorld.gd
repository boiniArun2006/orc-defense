class_name BattleWorld
extends Node2D
## Per-frame overlay in the camera-transformed layer: the gate marker and the
## turret placement/aim preview. The static map is drawn once by GroundLayer.

var battle: Node


func _draw() -> void:
	if battle == null:
		return
	_draw_gate(battle.gate_pos)
	if battle.mode == battle.MODE_PREVIEW or battle.mode == battle.MODE_AIM:
		_draw_ghost()


func _draw_gate(g: Vector2) -> void:
	# a stone keep the orcs are trying to breach, with a HP bar above it
	var tex: Texture2D = Assets.tex("gate")
	if tex != null:
		var s := 72.0
		# subtle base shadow
		draw_circle(g + Vector2(0, 6), s * 0.5, Color(0, 0, 0, 0.25))
		draw_texture_rect(tex, Rect2(g - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		# two flanking blocks for a "fortress gate" silhouette
		draw_texture_rect(tex, Rect2(g + Vector2(-s * 0.85, -s * 0.2), Vector2(s * 0.6, s * 0.6)), false)
		draw_texture_rect(tex, Rect2(g + Vector2(s * 0.25, -s * 0.2), Vector2(s * 0.6, s * 0.6)), false)
	else:
		draw_circle(g, 34.0, Color(0.45, 0.42, 0.5))
	# HP bar
	var maxhp: float = battle.GATE_HP_MAX
	var pct: float = clamp(float(battle.gate_hp) / maxhp, 0.0, 1.0)
	var bw := 96.0
	var by := -70.0
	draw_rect(Rect2(g.x - bw * 0.5, g.y + by, bw, 12.0), Color(0, 0, 0, 0.7))
	var col := Color(0.3, 0.8, 0.35) if pct > 0.5 else (Color(0.9, 0.75, 0.2) if pct > 0.25 else Color(0.9, 0.25, 0.2))
	draw_rect(Rect2(g.x - bw * 0.5, g.y + by, bw * pct, 12.0), col)
	draw_rect(Rect2(g.x - bw * 0.5, g.y + by, bw, 12.0), Color(1, 1, 1, 0.5), false, 2.0)


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
