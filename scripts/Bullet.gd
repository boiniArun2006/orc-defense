class_name Bullet
extends Node2D
## A homing tracer round fired by a gun turret. Drawn in code as a glowing,
## elongated tracer streak (tinted per turret type) so gunfire reads as gunfire
## instead of little floating balls. Culled by a max lifetime.

var swarm: OrcSwarm             # the horde this round
var ti := -1                    # target orc index
var tg := -1                    # target generation
var speed := 460.0
var damage := 22.0
var color := Color(1.0, 0.9, 0.5)
var _dir := Vector2.RIGHT
var _life := 0.0
const MAX_LIFE := 3.0


func _process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if swarm != null and swarm.is_alive(ti, tg):
		var to_target: Vector2 = swarm.pos_of(ti) - position
		var dist := to_target.length()
		if dist < 14.0:
			swarm.damage(ti, damage)
			queue_free()
			return
		_dir = to_target / dist
	# no valid target (killed by someone else): keep flying straight, fade via lifetime
	position += _dir * speed * delta
	rotation = _dir.angle()


func _draw() -> void:
	# tracer length scales with projectile speed (sniper rounds streak longer)
	var l: float = clamp(speed * 0.028, 14.0, 30.0)
	# soft outer glow
	draw_line(Vector2(-l, 0), Vector2(2, 0), Color(color.r, color.g, color.b, 0.22), 7.0)
	# tracer body
	draw_line(Vector2(-l, 0), Vector2(0, 0), Color(color.r, color.g, color.b, 0.85), 3.0)
	# hot white-ish tip
	draw_line(Vector2(-4, 0), Vector2(3, 0), Color(1, 1, 0.92, 0.95), 3.5)
