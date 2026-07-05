class_name Bullet
extends Node2D
## A homing tracer round fired by a gun turret. Drawn in code as a glowing,
## elongated tracer streak (tinted per turret type) so gunfire reads as gunfire
## instead of little floating balls. Culled by a max lifetime.

var target: Node2D
var speed := 460.0
var damage := 22.0
var color := Color(1.0, 0.9, 0.5)
var _dir := Vector2.RIGHT
var _life := 0.0
const MAX_LIFE := 3.0


func _ready() -> void:
	rotation = _dir.angle()


func _process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		var dist := to_target.length()
		if dist < 12.0:
			target.take_damage(damage)
			queue_free()
			return
		_dir = to_target / dist
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
