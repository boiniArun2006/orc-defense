class_name Bullet
extends Node2D
## A homing projectile fired by a gun turret. Lives in the camera-transformed world
## layer, so it's culled by a max lifetime rather than screen coordinates.

var target: Node2D
var speed := 460.0
var damage := 22.0
var _dir := Vector2.RIGHT
var _life := 0.0
const MAX_LIFE := 3.0


func _process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if is_instance_valid(target):
		var to_target: Vector2 = target.position - position
		var dist := to_target.length()
		if dist < 10.0:
			target.take_damage(damage)
			queue_free()
			return
		_dir = to_target / dist
	# keep flying (toward last-known direction if the target is gone)
	position += _dir * speed * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.85, 0.2))
