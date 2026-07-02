class_name Turret
extends Node2D
## A deployed turret. "gun" turrets fire straight bullets and only shoot orcs
## inside their aim arc (settable when placed). "bomb" turrets (bomber) lob an
## arcing missile with splash damage at any orc in range (no arc). Snipers may be
## toggled to tap-fire instead of auto-fire.

var battle: Node                 # Battle reference (enemy list + add_child)
var type_id := "rifle"
var def := {}

var range_px := 190.0
var fire_rate := 0.55
var damage := 24.0
var bullet_speed := 520.0
var kind := "gun"
var blast_radius := 0.0

var aim_angle := 0.0             # facing, radians
var arc_half := deg_to_rad(60)   # half of the firing arc; full arc <= 120 deg
var auto_fire := true            # sniper may set this false (tap-fire)

var _cooldown := 0.0


func setup(t_id: String) -> void:
	type_id = t_id
	def = TurretData.get_def(t_id)
	range_px = def["range"]
	fire_rate = def["fire_rate"]
	damage = def["damage"]
	bullet_speed = def["bullet_speed"]
	kind = def["kind"]
	blast_radius = def["blast_radius"]
	queue_redraw()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	# Bombers and auto-fire guns acquire on their own. Tap-fire guns wait for tap.
	if kind == "gun" and not auto_fire:
		return
	if _cooldown <= 0.0:
		var target := _acquire()
		if target != null:
			_fire_at(target)


func tap_fire() -> void:
	# Called by Battle when the player taps a tap-fire turret.
	if _cooldown > 0.0:
		return
	var target := _acquire()
	if target != null:
		_fire_at(target)


func _acquire() -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for e in battle.enemies:
		if not is_instance_valid(e):
			continue
		var d: float = position.distance_to(e.position)
		if d > range_px:
			continue
		if kind == "gun" and not _in_arc(e.position):
			continue
		if d <= best_d:
			best_d = d
			best = e
	return best


func _in_arc(world_pos: Vector2) -> bool:
	var ang := (world_pos - position).angle()
	var diff: float = abs(wrapf(ang - aim_angle, -PI, PI))
	return diff <= arc_half


func _fire_at(target: Node2D) -> void:
	if kind == "bomb":
		var m := Missile.new()
		m.position = position
		m.target_pos = target.position
		m.damage = damage
		m.blast_radius = blast_radius
		m.battle = battle
		battle.world.add_child(m)
	else:
		var b := Bullet.new()
		b.position = position
		b.target = target
		b.damage = damage
		b.speed = bullet_speed
		battle.world.add_child(b)
	_cooldown = fire_rate
	queue_redraw()


func _draw() -> void:
	var col: Color = def.get("color", Color(0.6, 0.6, 0.65))
	if kind == "gun":
		_draw_arc_region(col)
	else:
		draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 44, Color(1, 1, 1, 0.06), 1.5)
	# body
	draw_rect(Rect2(Vector2(-15, -15), Vector2(30, 30)), col)
	draw_rect(Rect2(Vector2(-15, -15), Vector2(30, 30)), Color(1, 1, 1, 0.55), false, 2.0)
	# barrel pointing at aim_angle (guns only)
	if kind == "gun":
		draw_line(Vector2.ZERO, Vector2(30, 0).rotated(aim_angle), Color(0.95, 0.95, 1.0), 5.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.2, 0.25))


func _draw_arc_region(col: Color) -> void:
	var steps := 26
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var a0 := aim_angle - arc_half
	var a1 := aim_angle + arc_half
	for i in range(steps + 1):
		var a: float = lerp(a0, a1, float(i) / steps)
		pts.append(Vector2(range_px, 0).rotated(a))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.10))
	draw_line(Vector2.ZERO, Vector2(range_px, 0).rotated(a0), Color(1, 1, 1, 0.16), 1.5)
	draw_line(Vector2.ZERO, Vector2(range_px, 0).rotated(a1), Color(1, 1, 1, 0.16), 1.5)
