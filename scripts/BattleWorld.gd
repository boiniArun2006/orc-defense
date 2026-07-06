class_name BattleWorld
extends Node2D
## Per-frame overlay in the camera-transformed layer: the gate marker, the
## turret placement/aim preview, and the air-strike corridor preview.
## The static map is drawn once by GroundLayer.

var battle: Node


func _draw() -> void:
	if battle == null:
		return
	_draw_gate(battle.gate_pos)
	if battle.mode == battle.MODE_PREVIEW:
		_draw_ghost()
	elif battle.mode == battle.MODE_STRIKE:
		_draw_strike_preview()


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
	var ok: bool = battle._placement_ok(gp)
	var tint := Color(col.r, col.g, col.b, 0.55) if ok else Color(1, 0.3, 0.3, 0.55)
	# range ring
	draw_arc(gp, def["range"], 0.0, TAU, 44, Color(1, 1, 1, 0.15), 1.5)
	# ghost turret: base + gun composed like the real thing
	var base_t: Texture2D = Assets.tex(def.get("base", ""))
	var gun_t: Texture2D = Assets.tex(def.get("gun", ""))
	if base_t != null:
		var bs := Vector2(base_t.get_width(), base_t.get_height()) * 0.72
		draw_texture_rect(base_t, Rect2(gp - bs * 0.5, bs), false, tint)
	if gun_t != null:
		var gs := Vector2(gun_t.get_width(), gun_t.get_height()) * 0.62
		draw_texture_rect(gun_t, Rect2(gp - gs * 0.5, gs), false, tint)


func _draw_strike_preview() -> void:
	if not battle.strike_dragging:
		return
	var a: Vector2 = battle.strike_from
	var b: Vector2 = battle.strike_to
	var d: float = a.distance_to(b)
	if d < 4.0:
		# anchored but not yet aimed: pulse a target ring where the run starts
		draw_arc(a, 46.0, 0.0, TAU, 40, Color(1.0, 0.4, 0.2, 0.8), 3.0)
		draw_circle(a, 6.0, Color(1.0, 0.4, 0.2, 0.9))
		return
	var dir: Vector2 = (b - a) / d
	var perp: Vector2 = dir.orthogonal() * float(battle.STRIKE_RADIUS)
	var ok: bool = d >= battle.STRIKE_LEN * 0.5
	var col := Color(1.0, 0.35, 0.2, 0.22) if ok else Color(1, 1, 1, 0.12)
	var edge := Color(1.0, 0.4, 0.2, 0.8) if ok else Color(1, 1, 1, 0.4)
	# the bombing corridor
	draw_colored_polygon(PackedVector2Array([a + perp, b + perp, b - perp, a - perp]), col)
	draw_line(a + perp, b + perp, edge, 2.5)
	draw_line(a - perp, b - perp, edge, 2.5)
	# flight direction: dashed centerline + arrowhead
	var dashes := int(d / 34.0)
	for i in range(dashes):
		var p0 := a + dir * (i * 34.0)
		draw_line(p0, p0 + dir * 18.0, Color(1, 1, 1, 0.75), 3.0)
	var tip := b + dir * 14.0
	draw_colored_polygon(PackedVector2Array([
		tip, b - dir * 12.0 + perp.normalized() * 14.0, b - dir * 12.0 - perp.normalized() * 14.0,
	]), Color(1, 1, 1, 0.85))
	# an incoming-plane silhouette at the start of the run
	var shadow: Texture2D = Assets.tex("plane_shadow")
	if shadow != null:
		draw_set_transform(a - dir * 60.0, dir.angle() + PI, Vector2(1.3, 1.3))
		draw_texture(shadow, -shadow.get_size() * 0.5, Color(1, 1, 1, 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
