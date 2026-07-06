class_name Turret
extends Node2D
## A deployed turret built from two sprites: a static stone BASE and a GUN that
## visibly turns to track whatever it is shooting. All turrets track 360
## degrees: they pick the closest orc in range, slew the barrel onto it and
## open fire once the gun is actually pointing at the victim.
## "bomb" turrets (bomber) lob an arcing missile with splash damage.

var battle: Node                 # Battle reference (enemy list + add_child)
var type_id := "rifle"
var def := {}

var range_px := 190.0
var fire_rate := 0.55
var damage := 24.0
var bullet_speed := 520.0
var kind := "gun"
var blast_radius := 0.0
var turn_speed := 6.0            # rad/s the gun can slew

const MAX_LVL := 3
const AIM_TOLERANCE := 0.22      # must be pointing this close (rad) to fire
var lvl := 1                     # in-battle upgrade level (reset each battle)

var aim_angle := 0.0             # rest facing (radians) when no target

var _cooldown := 0.0
var _muzzle := 0.0               # muzzle-flash timer
var _facing := 0.0               # current gun heading (rad)
var _recoil := 0.0               # gun kick-back on fire
var _base_spr: Sprite2D
var _gun_spr: Sprite2D
var _ti := -1                    # target orc index in the swarm
var _tg := -1                    # target generation (detects reuse/death)
var _cone := 0.0                 # muzzle-cone visibility timer


func setup(t_id: String) -> void:
	type_id = t_id
	def = TurretData.get_def(t_id)
	range_px = def["range"]
	fire_rate = def["fire_rate"]
	damage = def["damage"]
	bullet_speed = def["bullet_speed"]
	kind = def["kind"]
	blast_radius = def["blast_radius"]
	turn_speed = def.get("turn_speed", 6.0)
	_facing = aim_angle
	_base_spr = Sprite2D.new()
	_base_spr.texture = Assets.tex(def["base"])
	_base_spr.scale = Vector2(0.72, 0.72)
	add_child(_base_spr)
	_gun_spr = Sprite2D.new()
	_gun_spr.texture = Assets.tex(def["gun"])
	_gun_spr.scale = Vector2(0.62, 0.62)
	# Kenney gun barrels point UP; rotate so "up" aligns with _facing.
	_gun_spr.rotation = _facing + PI / 2.0
	add_child(_gun_spr)
	queue_redraw()


func upgrade_cost() -> int:
	# scales off the turret's workshop price so big guns cost more to boost
	return int(round(def["base_cost"] * 0.9 * lvl))


func upgrade() -> void:
	if lvl >= MAX_LVL:
		return
	lvl += 1
	damage *= 1.3
	range_px *= 1.1
	fire_rate = max(0.03, fire_rate * 0.93)
	queue_redraw()


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _muzzle > 0.0:
		_muzzle -= delta
		queue_redraw()
	if _recoil > 0.0:
		_recoil = max(0.0, _recoil - delta * 26.0)

	if _cone > 0.0:
		_cone = max(0.0, _cone - delta)
		queue_redraw()

	# keep (or re-)acquire the swarm orc this gun is tracking
	var swarm = battle.swarm
	if not swarm.is_alive(_ti, _tg) or position.distance_to(swarm.pos_of(_ti)) > range_px:
		_ti = swarm.nearest(position, range_px)
		_tg = swarm.gen_of(_ti) if _ti >= 0 else -1

	# the gun visibly slews toward its target; with none it settles to rest
	var desired := aim_angle
	var have := _ti >= 0 and swarm.is_alive(_ti, _tg)
	if have:
		desired = (swarm.pos_of(_ti) - position).angle()
	_facing = rotate_toward(_facing, desired, turn_speed * delta)
	if _gun_spr:
		_gun_spr.rotation = _facing + PI / 2.0
		_gun_spr.position = Vector2(-_recoil, 0).rotated(_facing)

	if _cooldown <= 0.0 and have:
		if absf(wrapf(desired - _facing, -PI, PI)) <= AIM_TOLERANCE:
			_fire_at(swarm.pos_of(_ti))


func _fire_at(target_pos: Vector2) -> void:
	if kind == "bomb":
		var m := Missile.new()
		m.position = position
		m.target_pos = target_pos
		m.damage = damage
		m.blast_radius = blast_radius
		m.battle = battle
		battle.world.add_child(m)
	else:
		var b := Bullet.new()
		b.position = position + Vector2(20, 0).rotated(_facing)
		b.swarm = battle.swarm
		b.ti = _ti
		b.tg = _tg
		b.damage = damage
		b.speed = bullet_speed
		b.color = def.get("color", Color(1.0, 0.9, 0.5))
		battle.world.add_child(b)
	_cooldown = fire_rate
	_muzzle = 0.06
	_cone = 0.09
	_recoil = 4.0
	queue_redraw()


func _draw() -> void:
	# range / arc overlay is drawn under the sprites; sprite children draw the body
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 44, Color(1, 1, 1, 0.06), 1.5)
	# soft drop shadow under the base so the turret sits IN the world
	draw_circle(Vector2(2, 4), 20.0, Color(0, 0, 0, 0.18))
	# bright golden muzzle CONE + flash — the signature "fan of fire" look
	if _cone > 0.0:
		var a := _cone / 0.09
		var muzzle := Vector2(22, 0).rotated(_facing)
		var reach := min(range_px, 150.0)
		var spread := 0.16
		var p1 := muzzle + Vector2(reach, 0).rotated(_facing - spread)
		var p2 := muzzle + Vector2(reach, 0).rotated(_facing + spread)
		draw_colored_polygon(PackedVector2Array([muzzle, p1, p2]),
			Color(1.0, 0.85, 0.35, 0.32 * a))
		var q1 := muzzle + Vector2(reach * 0.6, 0).rotated(_facing - spread * 0.5)
		var q2 := muzzle + Vector2(reach * 0.6, 0).rotated(_facing + spread * 0.5)
		draw_colored_polygon(PackedVector2Array([muzzle, q1, q2]),
			Color(1.0, 0.97, 0.7, 0.5 * a))
	if _muzzle > 0.0:
		var tip := Vector2(26, 0).rotated(_facing)
		draw_circle(tip, 7.0, Color(1.0, 0.85, 0.3, 0.9))
		draw_circle(tip, 3.5, Color(1.0, 1.0, 0.85, 0.95))
	# upgrade pips under the turret (Lv2 = 1 pip, Lv3 = 2 pips)
	for i in range(lvl - 1):
		draw_circle(Vector2(-6.0 + 12.0 * i, 24.0), 4.0, Color(1.0, 0.85, 0.2))
		draw_arc(Vector2(-6.0 + 12.0 * i, 24.0), 4.0, 0.0, TAU, 10, Color(0, 0, 0, 0.8), 1.5)

