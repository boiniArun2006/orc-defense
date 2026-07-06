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
var _target: Node2D = null


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

	# keep (or re-)acquire the target this gun is tracking
	if not is_instance_valid(_target):
		_target = null   # victim was freed (killed) — drop the stale reference
	if not _is_valid_target(_target):
		_target = _acquire()

	# the gun visibly slews toward its target; with no target it settles back
	# to the arc center (guns) or just holds (bomber)
	var desired := aim_angle
	if _target != null:
		desired = (_target.position - position).angle()
	_facing = rotate_toward(_facing, desired, turn_speed * delta)
	if _gun_spr:
		_gun_spr.rotation = _facing + PI / 2.0
		_gun_spr.position = Vector2(-_recoil, 0).rotated(_facing)

	if _cooldown <= 0.0 and _target != null:
		# only fire once the barrel is actually pointing at the victim
		if absf(wrapf(desired - _facing, -PI, PI)) <= AIM_TOLERANCE:
			_fire_at(_target)


func _is_valid_target(e: Node2D) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	return position.distance_to(e.position) <= range_px


func _acquire() -> Node2D:
	var best: Node2D = null
	var best_d := range_px
	for e in battle.enemies:
		if not is_instance_valid(e):
			continue
		var d: float = position.distance_to(e.position)
		if d > range_px:
			continue
		if d <= best_d:
			best_d = d
			best = e
	return best


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
		b.position = position + Vector2(20, 0).rotated(_facing)
		b.target = target
		b.damage = damage
		b.speed = bullet_speed
		b.color = def.get("color", Color(1.0, 0.9, 0.5))
		battle.world.add_child(b)
	_cooldown = fire_rate
	_muzzle = 0.06
	_recoil = 4.0
	queue_redraw()


func _draw() -> void:
	# range / arc overlay is drawn under the sprites; sprite children draw the body
	draw_arc(Vector2.ZERO, range_px, 0.0, TAU, 44, Color(1, 1, 1, 0.06), 1.5)
	# soft drop shadow under the base so the turret sits IN the world
	draw_circle(Vector2(2, 4), 20.0, Color(0, 0, 0, 0.18))
	# muzzle flash at the barrel tip when recently fired
	if _muzzle > 0.0:
		var tip := Vector2(26, 0).rotated(_facing)
		draw_circle(tip, 7.0, Color(1.0, 0.85, 0.3, 0.9))
		draw_circle(tip, 3.5, Color(1.0, 1.0, 0.85, 0.95))
	# upgrade pips under the turret (Lv2 = 1 pip, Lv3 = 2 pips)
	for i in range(lvl - 1):
		draw_circle(Vector2(-6.0 + 12.0 * i, 24.0), 4.0, Color(1.0, 0.85, 0.2))
		draw_arc(Vector2(-6.0 + 12.0 * i, 24.0), 4.0, 0.0, TAU, 10, Color(0, 0, 0, 0.8), 1.5)

